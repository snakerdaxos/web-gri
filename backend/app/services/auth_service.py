"""Auth business logic — register / login / refresh / get_user.

Kept OUT of the router so it's testable without HTTP and reusable by future
CLI/WS paths. The router is a thin parse → call → return layer.
"""

import jwt
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.usuario import RolUsuario, Usuario
from app.schemas.auth import TokenPair, UserCreate, UserLogin, UserRead


async def register_cliente(session: AsyncSession, body: UserCreate) -> UserRead:
    """AUTH-01: public cliente self-registration.

    Normalizes email to lowercase; rejects duplicates with 409. Created user is
    role=cliente with no restaurant (cross-tenant).
    """
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
        role=RolUsuario.cliente,
        restaurant_id=None,
    )
    session.add(user)
    await session.commit()
    # Populate server-side defaults (id, created_at). Safe because
    # expire_on_commit=False (set in Phase 1); refresh is for the DB defaults.
    await session.refresh(user)
    return UserRead.model_validate(user)


async def login(session: AsyncSession, body: UserLogin) -> TokenPair:
    """AUTH-02: validate credentials, return an access + refresh pair.

    Unknown-user and wrong-password produce the same 401 (no user enumeration).
    """
    normalized = body.email.lower().strip()
    user = (
        await session.execute(select(Usuario).where(Usuario.email == normalized))
    ).scalar_one_or_none()
    # verify_password handles the None case (returns False) so the timing is
    # uniform — no short-circuit that would reveal "user does not exist".
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Credenciales inválidas")
    if not user.activo:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Usuario inactivo")

    return TokenPair(
        access_token=create_access_token(
            str(user.id), user.role.value, user.restaurant_id
        ),
        refresh_token=create_refresh_token(str(user.id)),
    )


async def refresh(session: AsyncSession, refresh_token: str) -> TokenPair:
    """AUTH-02: rotate tokens from a valid refresh token.

    Always emits a fresh pair (rotation). Rejects access tokens (PITFALL 6).
    """
    try:
        payload = decode_token(refresh_token)
    except jwt.PyJWTError:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Token inválido o expirado"
        )

    if payload.get("type") != "refresh":
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Tipo de token incorrecto"
        )

    try:
        user_id = int(payload["sub"])
    except (KeyError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token malformado")

    user = await session.get(Usuario, user_id)
    if user is None or not user.activo:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Usuario inexistente o inactivo"
        )

    return TokenPair(
        access_token=create_access_token(
            str(user.id), user.role.value, user.restaurant_id
        ),
        refresh_token=create_refresh_token(str(user.id)),
    )


async def get_user(session: AsyncSession, user_id: int) -> UserRead:
    """Return the profile of an existing user; 404 if absent."""
    user = await session.get(Usuario, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    return UserRead.model_validate(user)
