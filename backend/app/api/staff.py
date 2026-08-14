"""Staff router — operational reads + mesa state writes for the panel admin
(ADMN-01 + ADMN-02 + RESV-05 + MESA-04).

Separated from /admin (platform ops) per the research convention: /staff holds
the endpoints the panel dashboard consumes (mesas, stats, reservas del día,
mesa state transitions; pedidos follow in Phase 6).

Role matrix, enforced via get_tenant_scope (no require_roles needed — the
scope dep already rejects cliente with 403):

| Endpoint                    | Allowed roles               | Denied ->                              |
|-----------------------------|-----------------------------|----------------------------------------|
| GET  /staff/mesas           | staff (any) + super_admin*  | 401 (no token) / 403 (cliente)         |
| GET  /staff/stats           | staff (any) + super_admin*  | 401 / 403 (same)                       |
| GET  /staff/reservas        | staff (any) + super_admin*  | 401 / 403 / 400 / 404 (same rules)     |
| POST /staff/mesas/{id}/estado | staff (any) + super_admin* | 401 / 403 / 404 / 409                  |
|                             |                             | 400 (super_admin sin ?restaurante_id=) |
|                             |                             | 404 (restaurante/mesa inexistente/ajena)|
|                             |                             | 409 (transición MESA_TRANSITIONS inválida)|

* super_admin MUST pass ?restaurante_id= (a hint, validated 404-if-unknown);
  for staff the param is IGNORED — the tenant always comes from the token
  (T-04-02, mirrored from admin_service.get_restaurante_for_staff).

Existence hiding cross-tenant (AUTH-04 style): una mesa de OTRO tenant es
indistinguible de una mesa inexistente → 404 (nunca 403, nunca 200).
"""

import datetime as dt

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.state_machines import TransicionInvalidaError
from app.deps.auth import (
    CurrentUser,
    TenantScope,
    get_current_user,
    get_tenant_scope,
)
from app.schemas.dashboard import DashboardStats
from app.schemas.mesa import MesaEstadoUpdate, MesaRead
from app.schemas.pedido import PedidoEstadoUpdate, PedidoStaffRead
from app.schemas.reserva import ReservaRead
from app.services import pedido_service, staff_service

router = APIRouter(prefix="/staff", tags=["staff"])


@router.get("/mesas", response_model=list[MesaRead])
async def list_mesas(
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """Mesa map for the caller's tenant (ADMN-02), ordered by numero."""
    mesas = await staff_service.list_mesas(session, scope, restaurante_id)
    return [MesaRead.model_validate(m) for m in mesas]


@router.get("/stats", response_model=DashboardStats)
async def get_stats(
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """Dashboard counts for the caller's tenant (ADMN-01)."""
    return await staff_service.get_stats(session, scope, restaurante_id)


@router.get("/reservas", response_model=list[ReservaRead])
async def list_reservas(
    fecha: dt.date | None = Query(
        default=None, description="Default: hoy (computado DB-side)."
    ),
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """RESV-05 (ver): reservas del día del caller's tenant, con joins display
    (restaurante_nombre, mesa_numero). Incluye canceladas (el campo estado
    discrimina). Orden por hora_inicio."""
    return await staff_service.list_reservas_by_fecha(
        session, scope, restaurante_id, fecha
    )


@router.post("/mesas/{mesa_id}/estado", response_model=MesaRead)
async def set_mesa_estado(
    mesa_id: int,
    body: MesaEstadoUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """RESV-05 (marcar) + MESA-04: transicionar el estado de una mesa.

    Caso de uso principal: el cliente llega y el admin marca la mesa
    ocupada (reservada→ocupada, o disponible→ocupada para walk-ins). El
    ciclo sigue con ocupada→limpieza→disponible.

    - 200 MesaRead actualizada (transición válida en MESA_TRANSITIONS).
    - 404 mesa inexistente O de otro tenant (existence hiding).
    - 409 transición inválida (ej. limpieza→ocupada) — el dominio
      (``TransicionInvalidaError``) no decide códigos HTTP; el router mapea.
    """
    try:
        mesa = await staff_service.set_mesa_estado(
            session, scope, mesa_id, body, restaurante_id
        )
    except TransicionInvalidaError as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Transición de estado no permitida: {exc}",
        ) from exc
    return MesaRead.model_validate(mesa)


# --- PEDI-06 + PEDI-03/05: cola de pedidos + transiciones (Phase 6) ----------


@router.get("/pedidos", response_model=list[PedidoStaffRead])
async def list_pedidos_cola(
    activos: bool = Query(
        default=True,
        description="Solo ?activos=true está soportado en v1 (la cola "
        "excluye terminales pagado/rechazado).",
    ),
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """PEDI-06: cola de pedidos activos del tenant (FIFO por etapa de
    preparación: FIELD(estado,'enviado','aceptado','en_preparacion',
    'servido'), created_at ASC) con items, total, notas, usuario_nombre y el
    badge solicita_cuenta (PAGO-01).

    - 400 super_admin sin ?restaurante_id= (patrón list_mesas).
    - 403 cliente (get_tenant_scope).
    - Cross-tenant: ausente de la lista (existence hiding).
    """
    if not activos:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Solo ?activos=true está soportado en v1",
        )
    return await pedido_service.cola_activos(session, scope, restaurante_id)


@router.post("/pedidos/{pedido_id}/estado", response_model=PedidoStaffRead)
async def set_pedido_estado(
    pedido_id: int,
    body: PedidoEstadoUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    user: CurrentUser = Depends(get_current_user),
):
    """PEDI-03/05: avanzar el estado de un pedido (matriz rol×transición).

    - 200 PedidoStaffRead (transición válida + rol autorizado).
    - 404 pedido inexistente O de otro tenant (existence hiding).
    - 409 transición inválida (PEDIDO_TRANSITIONS) — evaluada ANTES que la
      matriz de roles (un rol no autorizado con salto inválido recibe 409).
    - 403 rol no autorizado para ESA transición (mesero solo puede servido).
    """
    try:
        return await pedido_service.transicionar(
            session, scope, user, pedido_id, body.estado, restaurante_id
        )
    except TransicionInvalidaError as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Transición de estado no permitida: {exc}",
        ) from exc
