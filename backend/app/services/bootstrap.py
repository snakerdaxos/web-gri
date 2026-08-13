"""Startup bootstrap: ensure the platform super-admin exists.

The super-admin is the trust root — the first principal that can create
restaurantes and staff (PLAT-02/03). Its password lives ONLY in the
environment (.env, gitignored); this function creates the row idempotently on
every startup so deploys are self-bootstrapping. Safe to run every boot: if a
super_admin already exists, it returns immediately.

RESEARCH Pattern 5.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.usuario import RolUsuario, Usuario


async def ensure_super_admin(session: AsyncSession) -> None:
    """Create the bootstrap super_admin from env vars if none exists.

    No-op when SUPER_ADMIN_EMAIL/PASSWORD are unset (dev convenience) or when a
    super_admin already exists (idempotency — restarts never duplicate).
    """
    if not settings.SUPER_ADMIN_EMAIL or not settings.SUPER_ADMIN_PASSWORD:
        return  # not configured; skip silently

    stmt = (
        select(Usuario).where(Usuario.role == RolUsuario.super_admin).limit(1)
    )
    existing = (await session.execute(stmt)).scalar_one_or_none()
    if existing is not None:
        return  # already bootstrapped

    admin = Usuario(
        nombre="Super Admin",
        email=settings.SUPER_ADMIN_EMAIL,
        password_hash=hash_password(settings.SUPER_ADMIN_PASSWORD),
        role=RolUsuario.super_admin,
        restaurant_id=None,
    )
    session.add(admin)
    await session.commit()
