"""Admin router — platform management endpoints (PLAT-02/03) + the AUTH-04
tenant-scoped read.

Role matrix (research Pattern 4), enforced via require_roles / get_tenant_scope:

| Endpoint                              | Allowed roles            | Denied ->                        |
|---------------------------------------|--------------------------|----------------------------------|
| POST /admin/restaurantes              | super_admin              | 403 (others) / 401 (no token)    |
| GET  /admin/restaurantes              | super_admin              | 403 (others) / 401 (no token)    |
| POST /admin/restaurantes/{id}/staff   | super_admin              | 403 (others) / 401 (no token)    |
| GET  /admin/restaurantes/{id}         | staff (any) + super_admin| 403 (cliente) / 404 (wrong tenant) |

The router is a thin parse -> call service -> return layer; all logic lives in
admin_service.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.deps.auth import CurrentUser, TenantScope, get_tenant_scope, require_roles
from app.models.usuario import RolUsuario
from app.schemas.restaurante import (
    RestauranteCreate,
    RestauranteRead,
    StaffCreate,
    StaffRead,
)
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


# --- PLAT-02: super-admin platform management --------------------------------


@router.post(
    "/restaurantes", response_model=RestauranteRead, status_code=status.HTTP_201_CREATED
)
async def create_restaurante(
    body: RestauranteCreate,
    session: AsyncSession = Depends(get_session),
    _: CurrentUser = Depends(require_roles(RolUsuario.super_admin)),
):
    """Create a restaurante (tenant root). Super-admin only."""
    return await admin_service.create_restaurante(session, body)


@router.get("/restaurantes", response_model=list[RestauranteRead])
async def list_restaurantes(
    session: AsyncSession = Depends(get_session),
    _: CurrentUser = Depends(require_roles(RolUsuario.super_admin)),
):
    """List active restaurantes. Super-admin only."""
    return await admin_service.list_restaurantes(session)


# --- PLAT-03: super-admin creates staff assigned to a restaurante ------------


@router.post(
    "/restaurantes/{restaurante_id}/staff",
    response_model=StaffRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_staff(
    restaurante_id: int,
    body: StaffCreate,
    session: AsyncSession = Depends(get_session),
    _: CurrentUser = Depends(require_roles(RolUsuario.super_admin)),
):
    """Create a staff user (admin_restaurante|mesero|cocina) for a restaurante.

    Invalid staff role -> 422 (StaffRole enum). Missing restaurante -> 404.
    """
    return await admin_service.create_staff(session, restaurante_id, body)


# --- AUTH-04 verification: tenant-scoped read ---------------------------------


@router.get("/restaurantes/{restaurante_id}", response_model=RestauranteRead)
async def get_restaurante(
    restaurante_id: int,
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """Read a restaurante within the caller's tenant scope.

    - staff of THAT restaurante -> 200
    - staff of ANOTHER restaurante -> 404 (uniform "not found": never 403,
      never 200 — existence of other tenants' resources is not revealed)
    - cliente -> 403 (get_tenant_scope defense-in-depth)
    - super_admin -> 200 for any ACTIVE restaurante (no tenant filter)
    """
    restaurante = await admin_service.get_restaurante_for_staff(
        session, restaurante_id, scope
    )
    if restaurante is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurante no encontrado")
    return RestauranteRead.model_validate(restaurante)
