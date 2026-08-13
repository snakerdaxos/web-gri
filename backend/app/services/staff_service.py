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

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps.auth import TenantScope
from app.models.mesa import EstadoMesa, Mesa
from app.models.pedido import EstadoPedido, Pedido
from app.models.reserva import EstadoReserva, Reserva
from app.models.restaurante import Restaurante
from app.schemas.dashboard import DashboardStats

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
