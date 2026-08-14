"""Staff read services — tenant-scoped mesa list + dashboard stats (ADMN-01/02).

Same layering as admin_service (Phase 2): the router is a thin
parse -> call service -> return layer. Every query here repeats the proven
tenant-filter pattern:

    where(Model.restaurant_id == rid)

where `rid` comes from `_resolve_rid` — NEVER from the raw `restaurante_id`
query param for staff (T-04-02: the param is a hint for super_admin only;
for staff it is ignored and `scope.restaurant_id` is forced, making
cross-tenant reads structurally impossible).
"""

import datetime as dt
from collections import defaultdict
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.broadcaster import emit_event
from app.core.state_machines import validar_transicion
from app.deps.auth import TenantScope
from app.models.menu import Categoria, Producto
from app.models.mesa import EstadoMesa, Mesa
from app.models.pedido import EstadoPedido, Pedido, PedidoItem
from app.models.reserva import EstadoReserva, Reserva
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa
from app.models.usuario import Usuario
from app.schemas.cliente import ClienteResumen
from app.schemas.dashboard import DashboardStats
from app.schemas.menu import (
    CategoriaCreate,
    CategoriaStaff,
    CategoriaUpdate,
    ProductoCreate,
    ProductoStaff,
    ProductoUpdate,
)
from app.schemas.mesa import MesaEstadoUpdate
from app.schemas.pedido import PedidoItemRead, PedidoStaffRead
from app.schemas.reserva import ReservaRead

# The "active" pedido states for the dashboard card: everything after envio
# except the terminals (pagado/rechazado). borrador is excluded — the cliente
# is still composing it, kitchen doesn't care yet.
_PEDIDOS_ACTIVOS = [
    EstadoPedido.enviado,
    EstadoPedido.aceptado,
    EstadoPedido.en_preparacion,
    EstadoPedido.servido,
]


async def _resolve_rid(
    session: AsyncSession, scope: TenantScope, restaurante_id: int | None
) -> int:
    """Resolve the restaurant_id that every query in this service filters by.

    - super_admin: `restaurante_id` is REQUIRED (400 if missing — Pitfall 4)
      and must point to an existing ACTIVE restaurante (404 otherwise,
      existence hiding, AUTH-04 style).
    - staff: ALWAYS `scope.restaurant_id`; the query param is ignored (T-04-02
      — it is never a source of truth, so a staff token cannot read another
      tenant no matter what it sends).
    """
    if scope.is_super_admin:
        if restaurante_id is None:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "restaurante_id requerido para super_admin",
            )
        restaurante = await session.get(Restaurante, restaurante_id)
        if restaurante is None or not restaurante.activo:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND, "Restaurante no encontrado"
            )
        return restaurante_id
    # get_tenant_scope guarantees staff => restaurant_id is not None (403 else).
    assert scope.restaurant_id is not None
    return scope.restaurant_id


async def list_mesas(
    session: AsyncSession, scope: TenantScope, restaurante_id: int | None
) -> list[Mesa]:
    """All mesas of the resolved tenant, ordered by numero (ADMN-02)."""
    rid = await _resolve_rid(session, scope, restaurante_id)
    stmt = select(Mesa).where(Mesa.restaurant_id == rid).order_by(Mesa.numero)
    return list((await session.execute(stmt)).scalars().all())


async def list_reservas_by_fecha(
    session: AsyncSession,
    scope: TenantScope,
    restaurante_id: int | None,
    fecha: dt.date | None,
) -> list[ReservaRead]:
    """RESV-05 (ver): reservas del tenant resuelto para una fecha (RESV-05).

    - Tenant filter: ``_resolve_rid`` (el param crudo NUNCA filtra para
      staff — T-04-02; cross-tenant es estructuralmente imposible).
    - ``fecha`` None → ``func.curdate()`` DB-side (Pitfall 6 — la misma BD
      que guardó los rows computa "hoy"; NUNCA ``date.today()`` Python-side,
      que puede divergir por TZ del contenedor). Misma decisión que Phase 4
      ``reservas_hoy``.
    - Incluye TODAS las reservas del día (también canceladas): el admin ve
      el historial completo y el campo ``estado`` discrimina. Decisión del
      plan (05-02 Task 1, action §5).
    - Joins display (Restaurante.nombre, Mesa.numero) para el panel; mismo
      patrón que ``reserva_service.list_reservas_usuario`` (05-01).
    """
    rid = await _resolve_rid(session, scope, restaurante_id)
    target_fecha = fecha if fecha is not None else func.curdate()
    stmt = (
        select(Reserva, Restaurante.nombre, Mesa.numero)
        .join(Restaurante, Restaurante.id == Reserva.restaurant_id)
        .join(Mesa, Mesa.id == Reserva.mesa_id)
        .where(Reserva.restaurant_id == rid, Reserva.fecha == target_fecha)
        .order_by(Reserva.hora_inicio, Reserva.id)
    )
    rows = (await session.execute(stmt)).all()
    return [
        ReservaRead(
            id=reserva.id,
            restaurante_id=reserva.restaurant_id,
            restaurante_nombre=nombre,
            mesa_id=reserva.mesa_id,
            mesa_numero=numero,
            fecha=reserva.fecha,
            hora_inicio=reserva.hora_inicio,
            num_personas=reserva.num_personas,
            estado=reserva.estado,
            created_at=reserva.created_at,
        )
        for reserva, nombre, numero in rows
    ]


async def set_mesa_estado(
    session: AsyncSession,
    scope: TenantScope,
    mesa_id: int,
    body: MesaEstadoUpdate,
    restaurante_id: int | None,
) -> Mesa:
    """RESV-05 (marcar) + MESA-04: transicionar el estado de una mesa del
    tenant resuelto aplicando MESA_TRANSITIONS.

    Orden de las validaciones (importante para no revelar información):

    1. ``_resolve_rid`` — super_admin sin param → 400; restaurante
       inexistente/inactivo → 404 (mismo contrato que el resto de /staff).
    2. Existence hiding cross-tenant: mesa inexistente O de OTRO tenant →
       404 idéntico (la mesa ajena "no existe" para el caller — AUTH-04
       style; NUNCA 403, que confirmaría su existencia).
    3. ``validar_transicion("mesa", actual, nueva)`` — MESA_TRANSITIONS es
       la ÚNICA fuente de verdad (nunca inline ``if estado == ...``).
       ``TransicionInvalidaError`` sube al router, que la mapea a 409.
    4. Mutación + commit solo si TODO lo anterior pasó (sin estado drift
       en rechazos).
    """
    rid = await _resolve_rid(session, scope, restaurante_id)

    mesa = await session.get(Mesa, mesa_id)
    if mesa is None or mesa.restaurant_id != rid:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Mesa no encontrada")

    # MESA-04: la state machine decide. Raise TransicionInvalidaError → 409
    # en el router (el dominio no decide códigos HTTP).
    validar_transicion("mesa", mesa.estado, body.estado)

    mesa.estado = body.estado
    zombi_usuario_id: int | None = None
    if body.estado == EstadoMesa.limpieza:
        # Anti-zombi (06-01 Task 3): mesa→limpieza cierra la sesión activa
        # de esa mesa EN LA MISMA tx (estado=cerrada, cerrada_en=now). Sin
        # esto, una sesión abierta bloquearía la mesa para siempre (no hay
        # cierre de sesión cliente en v1 — el cierre al pagar llega en F9).
        # UPDATE de 0 filas es no-op: no rompe el caso sin sesión.
        #
        # Phase 7: MySQL 8 NO soporta RETURNING — capturar el usuario_id de
        # la sesión activa ANTES del UPDATE, como int PLANO (lección
        # MissingGreenlet: valores capturados antes de commit/expire).
        zombi_usuario_id = (
            await session.execute(
                select(SesionMesa.usuario_id).where(
                    SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None)
                )
            )
        ).scalar_one_or_none()
        await session.execute(
            update(SesionMesa)
            .where(
                SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None)
            )
            .values(estado=EstadoSesion.cerrada, cerrada_en=func.now())
        )
    await session.commit()
    await session.refresh(mesa)
    # Phase 7 (RT-02): emisión post-commit — mapa del panel en vivo.
    await emit_event(
        "mesa.estado",
        restaurante_id=rid,
        usuario_id=None,
        data={"mesa_id": mesa.id, "estado": body.estado.value},
    )
    if zombi_usuario_id is not None:
        # El anti-zombi cerró una sesión viva → el dueño se entera en su
        # user room (su app re-sincroniza: la sesión murió).
        await emit_event(
            "sesion.cerrada",
            restaurante_id=None,
            usuario_id=zombi_usuario_id,
            data={"mesa_id": mesa.id},
        )
    return mesa


async def get_stats(
    session: AsyncSession, scope: TenantScope, restaurante_id: int | None
) -> DashboardStats:
    """Dashboard counts for the resolved tenant (ADMN-01).

    - Mesa counts: ONE GROUP BY query (1 round-trip); estados with zero mesas
      simply don't appear in the result and default to 0.
    - reservas_hoy: `func.curdate()` computes "today" DB-side (America/Bogota
      TZ — Pitfall 6), NEVER Python's `date.today()` (container TZ skew).
    - pedidos_activos: estado in the 4 active states, riding the existing
      ix_pedido_restaurante_estado index (T-04-04).
    """
    rid = await _resolve_rid(session, scope, restaurante_id)

    # --- mesas por estado (single GROUP BY) ---
    rows = (
        await session.execute(
            select(Mesa.estado, func.count())
            .where(Mesa.restaurant_id == rid)
            .group_by(Mesa.estado)
        )
    ).all()
    # EstadoMesa(estado) normalizes whatever the driver returns (enum member
    # or raw str) into the enum; missing estados => 0.
    counts = {EstadoMesa(estado): total for estado, total in rows}
    mesas_disponibles = counts.get(EstadoMesa.disponible, 0)
    mesas_ocupadas = counts.get(EstadoMesa.ocupada, 0)
    mesas_reservadas = counts.get(EstadoMesa.reservada, 0)
    mesas_limpieza = counts.get(EstadoMesa.limpieza, 0)

    # --- reservas de hoy (no canceladas) ---
    reservas_hoy = (
        await session.execute(
            select(func.count())
            .select_from(Reserva)
            .where(
                Reserva.restaurant_id == rid,
                Reserva.fecha == func.curdate(),
                Reserva.estado != EstadoReserva.cancelada,
            )
        )
    ).scalar_one()

    # --- pedidos activos ---
    pedidos_activos = (
        await session.execute(
            select(func.count())
            .select_from(Pedido)
            .where(
                Pedido.restaurant_id == rid,
                Pedido.estado.in_(_PEDIDOS_ACTIVOS),
            )
        )
    ).scalar_one()

    return DashboardStats(
        mesas_disponibles=mesas_disponibles,
        mesas_ocupadas=mesas_ocupadas,
        mesas_reservadas=mesas_reservadas,
        mesas_limpieza=mesas_limpieza,
        total_mesas=(
            mesas_disponibles + mesas_ocupadas + mesas_reservadas + mesas_limpieza
        ),
        reservas_hoy=reservas_hoy,
        pedidos_activos=pedidos_activos,
    )


# --- Phase 8 (MENU-01/02): menú CRUD staff ------------------------------------
#
# Semántica de los toggles (decision locked del research):
# - ``activo`` = soft-delete: desaparece del menú público, la fila vive y los
#   FK de pedido_item siguen válidos (historia intacta).
# - ``disponible`` = agotado transitorio: SIGUE en /public con su flag.
# PROHIBIDO reutilizar disponible como soft-delete.


async def get_menu_staff(
    session: AsyncSession, scope: TenantScope, restaurante_id: int | None
) -> list[CategoriaStaff]:
    """Menú completo del tenant para el panel: 2 queries (patrón
    public_service) agrupadas en Python, INCLUYENDO inactivos y agotados —
    el staff ve TODO con flags; /public es el que filtra ``activo``."""
    rid = await _resolve_rid(session, scope, restaurante_id)
    cat_rows = (
        await session.execute(
            select(Categoria)
            .where(Categoria.restaurant_id == rid)
            .order_by(Categoria.orden, Categoria.id)
        )
    ).scalars().all()
    prod_rows = (
        await session.execute(
            select(Producto)
            .where(Producto.restaurant_id == rid)
            .order_by(Producto.categoria_id, Producto.nombre)
        )
    ).scalars().all()
    by_cat: dict[int, list[ProductoStaff]] = {}
    for p in prod_rows:
        by_cat.setdefault(p.categoria_id, []).append(ProductoStaff.model_validate(p))
    return [
        CategoriaStaff(
            id=c.id,
            nombre=c.nombre,
            orden=c.orden,
            activo=c.activo,
            productos=by_cat.get(c.id, []),
        )
        for c in cat_rows
    ]


async def _categoria_dup(
    session: AsyncSession, rid: int, nombre: str
) -> bool:
    """Pre-check amigable del unique (restaurant_id, nombre) — la constraint
    ``uq_categoria_restaurante_nombre`` es la autoridad (red de seguridad en
    el commit para la carrera, Pitfall 7)."""
    dup = await session.execute(
        select(func.count())
        .select_from(Categoria)
        .where(Categoria.restaurant_id == rid, Categoria.nombre == nombre)
    )
    return bool(dup.scalar_one())


async def create_categoria(
    session: AsyncSession,
    scope: TenantScope,
    body: CategoriaCreate,
    restaurante_id: int | None,
) -> Categoria:
    """MENU-01: crear categoría en el tenant resuelto.

    - 400 super_admin sin ?restaurante_id= / 404 restaurante (via _resolve_rid).
    - 409 nombre duplicado en el tenant (pre-check + IntegrityError safety net).
    """
    rid = await _resolve_rid(session, scope, restaurante_id)
    if await _categoria_dup(session, rid, body.nombre):
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Ya existe una categoría con ese nombre"
        )
    cat = Categoria(restaurant_id=rid, nombre=body.nombre, orden=body.orden)
    session.add(cat)
    try:
        await session.commit()
    except IntegrityError as exc:  # carrera del pre-check (Pitfall 7)
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Ya existe una categoría con ese nombre"
        ) from exc
    await session.refresh(cat)
    return cat


async def update_categoria(
    session: AsyncSession,
    scope: TenantScope,
    categoria_id: int,
    body: CategoriaUpdate,
    restaurante_id: int | None,
) -> Categoria:
    """MENU-01: editar categoría (nombre/orden/activo) con existence hiding
    cross-tenant (ajena == inexistente → 404 idéntico)."""
    rid = await _resolve_rid(session, scope, restaurante_id)
    cat = await session.get(Categoria, categoria_id)
    if cat is None or cat.restaurant_id != rid:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Categoría no encontrada")
    changes = body.model_dump(exclude_unset=True)
    if "nombre" in changes and changes["nombre"] != cat.nombre:
        if await _categoria_dup(session, rid, changes["nombre"]):
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Ya existe una categoría con ese nombre"
            )
    for field, value in changes.items():
        setattr(cat, field, value)
    try:
        await session.commit()
    except IntegrityError as exc:  # safety net de la carrera
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Ya existe una categoría con ese nombre"
        ) from exc
    await session.refresh(cat)
    return cat


async def create_producto(
    session: AsyncSession,
    scope: TenantScope,
    body: ProductoCreate,
    restaurante_id: int | None,
) -> Producto:
    """MENU-02: crear producto bajo una categoría DEL tenant.

    - 422 precio<=0 (Pydantic gt=0, server-side).
    - 404 categoría inexistente O de otro tenant (existence hiding).
    - ``precio`` float → ``Decimal(str(...))`` — conversión exacta.
    """
    rid = await _resolve_rid(session, scope, restaurante_id)
    cat = await session.get(Categoria, body.categoria_id)
    if cat is None or cat.restaurant_id != rid:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Categoría no encontrada")
    prod = Producto(
        restaurant_id=rid,
        categoria_id=body.categoria_id,
        nombre=body.nombre,
        descripcion=body.descripcion,
        precio=Decimal(str(body.precio)),
        imagen_url=body.imagen_url,
    )
    session.add(prod)
    await session.commit()
    await session.refresh(prod)
    return prod


async def update_producto(
    session: AsyncSession,
    scope: TenantScope,
    producto_id: int,
    body: ProductoUpdate,
    restaurante_id: int | None,
) -> Producto:
    """MENU-02: editar producto (nombre/descripción/precio/imagen_url/
    disponible/activo) con existence hiding cross-tenant."""
    rid = await _resolve_rid(session, scope, restaurante_id)
    prod = await session.get(Producto, producto_id)
    if prod is None or prod.restaurant_id != rid:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Producto no encontrado")
    changes = body.model_dump(exclude_unset=True)
    if "precio" in changes:
        changes["precio"] = Decimal(str(changes["precio"]))
    for field, value in changes.items():
        setattr(prod, field, value)
    await session.commit()
    await session.refresh(prod)
    return prod


# --- Phase 8 (ADMN-03): clientes del restaurante --------------------------------
#
# "Cliente del restaurante" = usuario CON pedidos en el tenant (JOIN
# pedido→usuario, decisión v1 del research: un usuario que solo reservó NO
# aparece). La tabla usuario es GLOBAL — el único acceso seguro es a través
# del JOIN filtrado por ``Pedido.restaurant_id == rid``; JAMÁS se expone la
# tabla global de usuarios.


async def list_clientes(
    session: AsyncSession, scope: TenantScope, restaurante_id: int | None
) -> list[ClienteResumen]:
    """ADMN-03: clientes del tenant con num_pedidos, total_gastado y
    ultimo_pedido_at (una sola query GROUP BY), orden total_gastado DESC.

    count/SUM sobre TODOS los pedidos del tenant, CUALQUIER estado (incluye
    rechazados — decisión documentada: el listado describe el comportamiento
    del cliente, no la facturación; los reportes de ventas REPO-01 filtran
    por estado en su propio endpoint).
    """
    rid = await _resolve_rid(session, scope, restaurante_id)
    stmt = (
        select(
            Usuario.id,
            Usuario.nombre,
            Usuario.email,
            func.count(Pedido.id).label("num_pedidos"),
            func.sum(Pedido.total).label("total_gastado"),
            func.max(Pedido.created_at).label("ultimo_pedido_at"),
        )
        .join(Pedido, Pedido.usuario_id == Usuario.id)
        .where(Pedido.restaurant_id == rid)
        .group_by(Usuario.id, Usuario.nombre, Usuario.email)
        .order_by(func.sum(Pedido.total).desc())
    )
    rows = (await session.execute(stmt)).all()
    return [
        ClienteResumen(
            usuario_id=usuario_id,
            nombre=nombre,
            email=email,
            num_pedidos=num_pedidos,
            total_gastado=total_gastado,  # Decimal → float en el serializer
            ultimo_pedido_at=ultimo_pedido_at,
        )
        for usuario_id, nombre, email, num_pedidos, total_gastado, ultimo_pedido_at in rows
    ]


async def get_cliente_historial(
    session: AsyncSession,
    scope: TenantScope,
    usuario_id: int,
    restaurante_id: int | None,
) -> list[PedidoStaffRead]:
    """ADMN-03: pedidos del usuario EN el tenant (todos los estados),
    newest first, reusando PedidoStaffRead (F6) sin modificarlo — items con
    producto.nombre, mesa_numero y usuario_nombre vía joins en batch.

    Usuario sin pedidos en el tenant → 404 "Cliente no encontrado"
    (existence hiding RELACIONAL: la relación usuario↔tenant no existe,
    aunque el usuario exista en la tabla global).
    """
    rid = await _resolve_rid(session, scope, restaurante_id)
    pedidos = (
        await session.execute(
            select(Pedido)
            .where(
                Pedido.restaurant_id == rid, Pedido.usuario_id == usuario_id
            )
            .order_by(Pedido.created_at.desc(), Pedido.id.desc())
        )
    ).scalars().all()
    if not pedidos:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cliente no encontrado")

    # --- joins display en batch (patrón cola_activos — sin N+1) ---
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
            PedidoItemRead(
                producto_id=item.producto_id,
                nombre=nombre,
                cantidad=item.cantidad,
                precio_unitario=item.precio_unitario,
                subtotal=item.subtotal,
            )
        )

    mesas = (
        await session.execute(
            select(Mesa).where(Mesa.id.in_({p.mesa_id for p in pedidos}))
        )
    ).scalars().all()
    mesa_by_id = {m.id: m for m in mesas}

    usuario = await session.get(Usuario, usuario_id)

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
            usuario_nombre=usuario.nombre if usuario else "",
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
