"""Auth dependencies — identity extraction from the Bearer JWT.

`get_current_user` is the single entry point for "who is calling this endpoint?".
It decodes the access token, enforces `type == "access"` (PITFALL 6 — refresh
tokens cannot be used here), and loads the live user from the DB (so a disabled
user is rejected even with a valid token).

Plan 02-02 adds `require_roles`, `TenantScope`, and `get_tenant_scope` to this
file. This plan ships only `get_current_user` (the /auth endpoints need it).
"""

from dataclasses import dataclass

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.security import decode_token
from app.models.usuario import RolUsuario, Usuario

bearer_scheme = HTTPBearer(auto_error=True)


@dataclass
class CurrentUser:
    """Minimal identity carried through the request lifecycle."""

    id: int
    role: RolUsuario
    restaurant_id: int | None


async def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> CurrentUser:
    """Decode the Bearer JWT and load the active user. 401 on any failure."""
    try:
        payload = decode_token(creds.credentials)
    except jwt.PyJWTError:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Token inválido o expirado"
        )

    # PITFALL 6: reject refresh tokens used as access tokens.
    if payload.get("type") != "access":
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Tipo de token incorrecto"
        )

    try:
        user_id = int(payload["sub"])
    except (KeyError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token malformado")

    # Confirm the user still exists & is active (cheap, indexed by PK).
    db_user = await session.get(Usuario, user_id)
    if db_user is None or not db_user.activo:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Usuario inexistente o inactivo"
        )

    return CurrentUser(
        id=db_user.id, role=db_user.role, restaurant_id=db_user.restaurant_id
    )
