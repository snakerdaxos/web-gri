"""Pedido business logic — crear (total server-side) + pedidos de la sesión
(PEDI-01/02/04) + cola staff y transiciones (PEDI-03/05/06 — Task 3).

``crear_pedido`` defiende el core value anti-tampering (threat model 06-01):

1. Sesión: explícita por id (existence hiding: ajena/inexistente → 404
   idénticos — sesión spoofing P6) o la activa del usuario (404 si no hay).
   Inactiva (cerrada_en seteado) → 409.
2. Productos: SIEMPRE del restaurante de la sesión (cross-restaurante → 404,
   mismo caso que inexistente) y ``disponible == True`` (agotado → 409).
3. Total: precio leído del producto EN EL SERVIDOR; snapshot en
   ``pedido_item.precio_unitario`` (nunca recalculado — reportes F8 exactos).
4. INSERT Pedido(estado=enviado — el carrito es client-side, ``borrador``
   queda sin uso server-side) + items en UNA transacción.
"""

from collections import defaultdict
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.menu import Producto
from app.models.mesa import Mesa
from app.models.pedido import EstadoPedido, Pedido, PedidoItem
from app.models.sesion_mesa import SesionMesa
from app.schemas.pedido import PedidoCreate, PedidoItemRead, PedidoRead


async def _sesion_activa(
    session: AsyncSession, usuario_id: int
) -> SesionMesa | None:
    return (
        await session.execute(
            select(SesionMesa).where(
                SesionMesa.usuario_id == usuario_id,
                SesionMesa.cerrada_en.is_(None),
            )
        )
    ).scalar_one_or_none()


async def _resolver_sesion(
    session: AsyncSession, usuario_id: int, sesion_id: int | None
) -> SesionMesa:
    """Sesión explícita (validada propia) o la activa del usuario.

    Existence hiding: ajena e inexistente → 404 idéntico. Inactiva → 409.
    """
    if sesion_id is not None:
        sesion = await session.get(SesionMesa, sesion_id)
        if sesion is None or sesion.usuario_id != usuario_id:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND, "Sesión no encontrada"
            )
    else:
        sesion = await _sesion_activa(session, usuario_id)
        if sesion is None:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND, "No tienes una sesión activa"
            )
    if sesion.cerrada_en is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "La sesión ya no está activa"
        )
    return sesion


def _to_item_read(
    producto_id: int, nombre: str, cantidad: int, precio: Decimal, subtotal: Decimal
) -> PedidoItemRead:
    return PedidoItemRead(
        producto_id=producto_id,
        nombre=nombre,
        cantidad=cantidad,
        precio_unitario=precio,
        subtotal=subtotal,
    )


async def crear_pedido(
    session: AsyncSession, usuario_id: int, body: PedidoCreate
) -> PedidoRead:
    """PEDI-01/02: crear un pedido en estado=enviado con total server-side.

    Una sola tx: INSERT pedido + items + commit. El response se construye con
    los valores YA cargados (expire_on_commit=False) + refresh del pedido
    para los server-defaults (created_at).
    """
    sesion = await _resolver_sesion(session, usuario_id, body.sesion_id)

    # Productos del restaurante de la sesión (cross-restaurante == inexistente).
    ids = [it.producto_id for it in body.items]
    productos = (
        await session.execute(
            select(Producto).where(
                Producto.id.in_(ids),
                Producto.restaurant_id == sesion.restaurant_id,
            )
        )
    ).scalars().all()
    by_id = {p.id: p for p in productos}
    for it in body.items:
        if it.producto_id not in by_id:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND,
                f"Producto {it.producto_id} no encontrado",
            )
        if not by_id[it.producto_id].disponible:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"Producto '{by_id[it.producto_id].nombre}' agotado",
            )

    # Totales server-side: snapshot de precio + subtotal por línea.
    lineas: list[tuple[Producto, int, Decimal]] = []
    total = Decimal("0.00")
    for it in body.items:
        p = by_id[it.producto_id]
        subtotal = (p.precio * it.cantidad).quantize(Decimal("0.01"))
        lineas.append((p, it.cantidad, subtotal))
        total += subtotal

    pedido = Pedido(
        restaurant_id=sesion.restaurant_id,
        mesa_id=sesion.mesa_id,
        usuario_id=usuario_id,
        sesion_id=sesion.id,
        estado=EstadoPedido.enviado,
        total=total,
        notas=body.notas,
    )
    session.add(pedido)
    await session.flush()  # asigna pedido.id para los FKs de los items
    for p, cantidad, subtotal in lineas:
        session.add(
            PedidoItem(
                restaurant_id=sesion.restaurant_id,
                pedido_id=pedido.id,
                producto_id=p.id,
                cantidad=cantidad,
                precio_unitario=p.precio,
                subtotal=subtotal,
            )
        )
    await session.commit()
    await session.refresh(pedido)  # server-defaults (created_at)

    mesa = await session.get(Mesa, pedido.mesa_id)
    return PedidoRead(
        id=pedido.id,
        sesion_id=pedido.sesion_id,
        mesa_numero=mesa.numero if mesa else 0,
        estado=pedido.estado,
        total=pedido.total,
        notas=pedido.notas,
        created_at=pedido.created_at,
        items=[
            _to_item_read(p.id, p.nombre, cantidad, p.precio, subtotal)
            for p, cantidad, subtotal in lineas
        ],
    )


async def pedidos_de_sesion(
    session: AsyncSession, usuario_id: int
) -> list[PedidoRead]:
    """PEDI-04: TODOS los pedidos de la sesión activa del usuario (cualquier
    estado — el cliente hace polling), newest first (created_at, id DESC)."""
    sesion = await _sesion_activa(session, usuario_id)
    if sesion is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "No tienes una sesión activa"
        )

    pedidos = (
        await session.execute(
            select(Pedido)
            .where(Pedido.sesion_id == sesion.id)
            .order_by(Pedido.created_at.desc(), Pedido.id.desc())
        )
    ).scalars().all()
    if not pedidos:
        return []

    item_rows = (
        await session.execute(
            select(PedidoItem, Producto.nombre)
            .join(Producto, Producto.id == PedidoItem.producto_id)
            .where(PedidoItem.pedido_id.in_([p.id for p in pedidos]))
            .order_by(PedidoItem.id)
        )
    ).all()
    items_by_pedido: dict[int, list[PedidoItemRead]] = defaultdict(list)
    for item, nombre in item_rows:
        items_by_pedido[item.pedido_id].append(
            _to_item_read(
                item.producto_id, nombre, item.cantidad,
                item.precio_unitario, item.subtotal,
            )
        )

    mesa = await session.get(Mesa, sesion.mesa_id)
    mesa_numero = mesa.numero if mesa else 0
    return [
        PedidoRead(
            id=p.id,
            sesion_id=p.sesion_id,
            mesa_numero=mesa_numero,
            estado=p.estado,
            total=p.total,
            notas=p.notas,
            created_at=p.created_at,
            items=items_by_pedido[p.id],
        )
        for p in pedidos
    ]
