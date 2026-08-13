"""Admin business logic — platform management (PLAT-02 + PLAT-03) and the
tenant-scoped read that verifies AUTH-04.

Kept OUT of the router so it's testable without HTTP (same layering as
auth_service). The single most important line in Phase 2 lives here:

    stmt = stmt.where(Restaurante.id == scope.restaurant_id)

That is what makes cross-tenant isolation true. Every staff-scoped service in
every future phase (mesas, pedidos, ...) repeats this exact pattern.
"""

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.deps.auth import TenantScope
from app.models.restaurante import Restaurante
from app.models.usuario import RolUsuario, Usuario
from app.schemas.restaurante import (
    RestauranteCreate,
    RestauranteRead,
    StaffCreate,
    StaffRead,
)


async def create_restaurante(
    session: AsyncSession, body: RestauranteCreate
) -> RestauranteRead:
    """PLAT-02: create a restaurante (tenant root). activo defaults to True."""
    restaurante = Restaurante(**body.model_dump())
    session.add(restaurante)
    await session.commit()
    # Populate server-side defaults (id, created_at). Safe because
    # expire_on_commit=False (Phase 1); refresh is for the DB defaults.
    await session.refresh(restaurante)
    return RestauranteRead.model_validate(restaurante)


async def list_restaurantes(session: AsyncSession) -> list[RestauranteRead]:
    """List ACTIVE restaurantes ordered by id.

    Only active for now (consistency with get_restaurante_for_staff); managing
    inactive ones is Phase 8 (PLAT-05).
    """
    stmt = (
        select(Restaurante)
        .where(Restaurante.activo.is_(True))
        .order_by(Restaurante.id)
    )
    rows = (await session.execute(stmt)).scalars().all()
    return [RestauranteRead.model_validate(r) for r in rows]


async def create_staff(
    session: AsyncSession, restaurante_id: int, body: StaffCreate
) -> StaffRead:
    """PLAT-03: create a staff user assigned to a restaurante.

    - 404 if the restaurante does not exist (or is inactive) — checked BEFORE
      inserting the user (no orphan staff).
    - 409 on duplicate email (emails are globally unique across tenants).
    - role is already restricted to the 3 staff values by StaffCreate (422).
    """
    restaurante = await session.get(Restaurante, restaurante_id)
    if restaurante is None or not restaurante.activo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurante no encontrado")

    normalized = body.email.lower().strip()
    existing = (
        await session.execute(select(Usuario).where(Usuario.email == normalized))
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Email ya registrado")

    user = Usuario(
        nombre=body.nombre,
        email=normalized,
        password_hash=hash_password(body.password),
        # StaffRole -> RolUsuario via the shared string value (both str enums).
        role=RolUsuario(body.role.value),
        restaurant_id=restaurante_id,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return StaffRead.model_validate(user)


async def get_restaurante_for_staff(
    session: AsyncSession, restaurante_id: int, scope: TenantScope
) -> Restaurante | None:
    """AUTH-04 critical read: the restaurante IF the caller may see it.

    Returns None when the restaurante does not exist, is inactive, OR belongs
    to another tenant — the caller cannot distinguish those cases (the router
    answers a uniform 404, never 403, so existence is never revealed).

    super_admin carries no filter and sees any ACTIVE restaurante.
    """
    stmt = select(Restaurante).where(
        Restaurante.id == restaurante_id, Restaurante.activo.is_(True)
    )
    if not scope.is_super_admin:
        # THE tenant filter — cross-tenant lookups return None -> 404.
        stmt = stmt.where(Restaurante.id == scope.restaurant_id)
    return (await session.execute(stmt)).scalar_one_or_none()
