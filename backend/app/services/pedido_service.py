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
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.broadcaster import emit_event
from app.core.state_machines import validar_transicion
from app.deps.auth import CurrentUser, TenantScope
from app.models.menu import Producto
from app.models.mesa import Mesa
from app.models.pedido import EstadoPedido, Pedido, PedidoItem
from app.models.sesion_mesa import SesionMesa
from app.models.usuario import RolUsuario, Usuario
from app.schemas.pedido import (
    PedidoCreate,
    PedidoItemRead,
    PedidoRead,
    PedidoStaffRead,
)
from app.services import staff_service

# Estados "activos" de la cola (mismo criterio que staff_service.get_stats):
# servido sigue siendo activo — el terminal real es pagado/rechazado (F9).
_PEDIDOS_ACTIVOS = staff_service._PEDIDOS_ACTIVOS

# Matriz rol×transición (PEDI-05 — decision locked del research):
# cocina/admin/super_admin hacen TODO; el mesero SOLO marca servido (entrega
# física en mesa). El orden de checks vive en ``transicionar``: PRIMERO la
# validez de la transición (409), DESPUÉS la matriz (403) — la validez nunca
# se filtra por rol.
TRANSITION_ROLES: dict[EstadoPedido, set[RolUsuario]] = {
    EstadoPedido.aceptado: {
        RolUsuario.cocina,
        RolUsuario.admin_restaurante,
        RolUsuario.super_admin,
    },
    EstadoPedido.rechazado: {
        RolUsuario.cocina,
        RolUsuario.admin_restaurante,
        RolUsuario.super_admin,
    },
    EstadoPedido.en_preparacion: {
        RolUsuario.cocina,
        RolUsuario.admin_restaurante,
        RolUsuario.super_admin,
    },
    EstadoPedido.servido: {
        RolUsuario.cocina,
        RolUsuario.mesero,
        RolUsuario.admin_restaurante,
        RolUsuario.super_admin,
    },
}


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

    # Phase 7 (RT-01): emisión post-commit — cocina/mesero ven el pedido
    # nuevo y el dueño ve su pedido. Valores planos ya cargados
    # (expire_on_commit=False); .value porque str() de un enum mixin da
    # "EstadoPedido.enviado" (verificado), no el valor del contrato.
    await emit_event(
        "pedido.creado",
        restaurante_id=sesion.restaurant_id,
        usuario_id=usuario_id,
        data={
            "pedido_id": pedido.id,
            "estado": pedido.estado.value,
            "mesa_id": pedido.mesa_id,
            "total": float(pedido.total),
        },
    )

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


# --- PEDI-06: cola staff -----------------------------------------------------


async def cola_activos(
    session: AsyncSession,
    scope: TenantScope,
    restaurante_id: int | None,
) -> list[PedidoStaffRead]:
    """PEDI-06: cola de pedidos activos del tenant resuelto (FIFO).

    Orden: ``FIELD(estado, 'enviado','aceptado','en_preparacion','servido')``
    + created_at ASC — los recién enviados primero (la cocina despacha en
    orden de llegada dentro de cada etapa). Para cada pedido carga items
    (con producto.nombre), usuario_nombre y la sesión (badge
    solicita_cuenta) vía joins en batch (sin N+1).
    """
    rid = await staff_service._resolve_rid(session, scope, restaurante_id)

    pedidos = (
        await session.execute(
            select(Pedido)
            .where(Pedido.restaurant_id == rid, Pedido.estado.in_(_PEDIDOS_ACTIVOS))
            .order_by(
                func.field(
                    Pedido.estado,
                    EstadoPedido.enviado,
                    EstadoPedido.aceptado,
                    EstadoPedido.en_preparacion,
                    EstadoPedido.servido,
                ),
                Pedido.created_at.asc(),
                Pedido.id.asc(),
            )
        )
    ).scalars().all()
    if not pedidos:
        return []

    # --- joins display en batch (3 queries, N agnóstico) ---
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

    usuarios = (
        await session.execute(
            select(Usuario.id, Usuario.nombre).where(
                Usuario.id.in_({p.usuario_id for p in pedidos})
            )
        )
    ).all()
    nombre_by_usuario = dict(usuarios)

    mesas = (
        await session.execute(
            select(Mesa).where(Mesa.id.in_({p.mesa_id for p in pedidos}))
        )
    ).scalars().all()
    mesa_by_id = {m.id: m for m in mesas}

    sesion_ids = {p.sesion_id for p in pedidos if p.sesion_id is not None}
    sesiones: dict[int, SesionMesa] = {}
    if sesion_ids:
        rows = (
            await session.execute(
                select(SesionMesa).where(SesionMesa.id.in_(sesion_ids))
            )
        ).scalars().all()
        sesiones = {s.id: s for s in rows}

    return [
        PedidoStaffRead(
            id=p.id,
            sesion_id=p.sesion_id,
            mesa_numero=mesa_by_id[p.mesa_id].numero if p.mesa_id in mesa_by_id else 0,
            estado=p.estado,
            total=p.total,
            notas=p.notas,
            created_at=p.created_at,
            items=items_by_pedido[p.id],
            usuario_nombre=nombre_by_usuario.get(p.usuario_id, ""),
            solicita_cuenta=(
                bool(sesiones[p.sesion_id].solicita_cuenta)
                if p.sesion_id in sesiones
                else False
            ),
            solicitada_en=(
                sesiones[p.sesion_id].solicitada_en
                if p.sesion_id in sesiones
                else None
            ),
        )
        for p in pedidos
    ]


async def _staff_read(
    session: AsyncSession, pedido: Pedido
) -> PedidoStaffRead:
    """Construye el PedidoStaffRead de UN pedido (joins display)."""
    item_rows = (
        await session.execute(
            select(PedidoItem, Producto.nombre)
            .join(Producto, Producto.id == PedidoItem.producto_id)
            .where(PedidoItem.pedido_id == pedido.id)
            .order_by(PedidoItem.id)
        )
    ).all()
    usuario = await session.get(Usuario, pedido.usuario_id)
    mesa = await session.get(Mesa, pedido.mesa_id)
    sesion = (
        await session.get(SesionMesa, pedido.sesion_id)
        if pedido.sesion_id is not None
        else None
    )
    return PedidoStaffRead(
        id=pedido.id,
        sesion_id=pedido.sesion_id,
        mesa_numero=mesa.numero if mesa else 0,
        estado=pedido.estado,
        total=pedido.total,
        notas=pedido.notas,
        created_at=pedido.created_at,
        items=[
            _to_item_read(
                item.producto_id, nombre, item.cantidad,
                item.precio_unitario, item.subtotal,
            )
            for item, nombre in item_rows
        ],
        usuario_nombre=usuario.nombre if usuario else "",
        solicita_cuenta=bool(sesion.solicita_cuenta) if sesion else False,
        solicitada_en=sesion.solicitada_en if sesion else None,
    )


# --- PEDI-03/05: transiciones con matriz rol×estado ---------------------------


async def transicionar(
    session: AsyncSession,
    scope: TenantScope,
    user: CurrentUser,
    pedido_id: int,
    nuevo_estado: EstadoPedido,
    restaurante_id: int | None,
) -> PedidoStaffRead:
    """PEDI-03/05: avanzar el estado de un pedido del tenant.

    Orden de las validaciones (threat model #5 — NO filtrar la validez por
    rol):

    1. ``_resolve_rid`` — 400 super_admin sin param / 404 restaurante.
    2. Existence hiding cross-tenant: pedido inexistente O ajeno → 404.
    3. ``validar_transicion("pedido", ...)`` — PEDIDO_TRANSITIONS es la
       ÚNICA fuente de verdad; ``TransicionInvalidaError`` sube al router
       → 409 (ANTES del check de rol).
    4. ``TRANSITION_ROLES[nuevo]`` — 403 si el rol no está autorizado para
       ESA transición.
    5. Mutación + commit solo si todo pasó (sin drift en rechazos).
    """
    rid = await staff_service._resolve_rid(session, scope, restaurante_id)

    pedido = await session.get(Pedido, pedido_id)
    if pedido is None or pedido.restaurant_id != rid:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Pedido no encontrado")

    validar_transicion("pedido", pedido.estado, nuevo_estado)

    if user.role not in TRANSITION_ROLES[nuevo_estado]:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Rol no autorizado para esta transición",
        )

    pedido.estado = nuevo_estado
    await session.commit()
    await session.refresh(pedido)
    # Phase 7 (RT-01): emisión post-commit — cola re-ordenada en cocina y el
    # dueño ve el avance. 409/403 del bloque anterior NUNCA llegan aquí.
    await emit_event(
        "pedido.estado",
        restaurante_id=pedido.restaurant_id,
        usuario_id=pedido.usuario_id,
        data={
            "pedido_id": pedido.id,
            "estado": pedido.estado.value,
            "mesa_id": pedido.mesa_id,
        },
    )
    return await _staff_read(session, pedido)
