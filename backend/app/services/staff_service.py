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

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.broadcaster import emit_event
from app.core.state_machines import validar_transicion
from app.deps.auth import TenantScope
from app.models.mesa import EstadoMesa, Mesa
from app.models.pedido import EstadoPedido, Pedido
from app.models.reserva import EstadoReserva, Reserva
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa
from app.schemas.dashboard import DashboardStats
from app.schemas.mesa import MesaEstadoUpdate
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
