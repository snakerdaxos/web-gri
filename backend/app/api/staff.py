"""Staff router — operational reads for the panel admin (ADMN-01 + ADMN-02).

Separated from /admin (platform ops) per the research convention: /staff holds
the read endpoints the panel dashboard consumes (mesas, stats; pedidos follow
in Phase 5).

Role matrix, enforced via get_tenant_scope (no require_roles needed — the
scope dep already rejects cliente with 403):

| Endpoint         | Allowed roles               | Denied ->                              |
|------------------|-----------------------------|----------------------------------------|
| GET /staff/mesas | staff (any) + super_admin*  | 401 (no token) / 403 (cliente)         |
| GET /staff/stats | staff (any) + super_admin*  | 401 / 403 (same)                       |
|                  |                             | 400 (super_admin sin ?restaurante_id=) |
|                  |                             | 404 (restaurante inexistente/inactivo) |

* super_admin MUST pass ?restaurante_id= (a hint, validated 404-if-unknown);
  for staff the param is IGNORED — the tenant always comes from the token
  (T-04-02, mirrored from admin_service.get_restaurante_for_staff).
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.deps.auth import TenantScope, get_tenant_scope
from app.schemas.dashboard import DashboardStats
from app.schemas.mesa import MesaRead
from app.services import staff_service

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
