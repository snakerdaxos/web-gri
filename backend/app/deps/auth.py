"""Auth dependencies — identity, roles, and tenant scope from the Bearer JWT.

`get_current_user` is the single entry point for "who is calling this endpoint?".
It decodes the access token, enforces `type == "access"` (PITFALL 6 — refresh
tokens cannot be used here), and loads the live user from the DB (so a disabled
user is rejected even with a valid token).

On top of it, Plan 02-02 adds the authorization layer:

- `require_roles(*roles)` — RBAC gate factory (AUTH-03): 403 unless the user's
  role is in the allowlist.
- `TenantScope` / `get_tenant_scope` — the multi-tenant filter (AUTH-04).
  Every staff-scoped query MUST filter by `scope.restaurant_id`; cross-tenant
  lookups return None → the router answers 404 (NOT 403, so the existence of
  another tenant's resource is never revealed).
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


# --- Plan 02-02: authorization (AUTH-03) + tenancy (AUTH-04) -----------------


def require_roles(*allowed: RolUsuario):
    """Dependency factory: 403 unless the current user's role is in `allowed`.

    Usage: `Depends(require_roles(RolUsuario.super_admin))` — one declaration
    per endpoint; impossible to forget on a new endpoint (research Pattern 4).
    """

    async def _dep(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in allowed:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN, "Rol no autorizado para esta operación"
            )
        return user

    return _dep


@dataclass
class TenantScope:
    """The tenant filter derived from the caller's identity.

    restaurant_id: None => super_admin (no filter, sees any restaurante);
                   int  => staff (filter every query to THIS tenant).
    is_super_admin: lets services skip the filter without re-checking the role.
    """

    restaurant_id: int | None
    is_super_admin: bool


def get_tenant_scope(user: CurrentUser = Depends(get_current_user)) -> TenantScope:
    """Derive the tenant filter for the current request (AUTH-04).

    - super_admin => (None, True) — no filter, may operate on any restaurante.
    - cliente => 403 (defense-in-depth: even if an endpoint forgets the
      require_roles gate, the cliente never gets a tenant scope. The tenant of
      a cliente is derived from the resource, never from the token).
    - staff without restaurant_id => 403 (misconfigured account; a NULL filter
      would match EVERY tenant — the one query we must never run).
    - staff => (user.restaurant_id, False).
    """
    if user.role == RolUsuario.super_admin:
        return TenantScope(restaurant_id=None, is_super_admin=True)
    if user.role == RolUsuario.cliente:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Rol no autorizado")
    if user.restaurant_id is None:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Staff sin restaurante asignado"
        )
    return TenantScope(restaurant_id=user.restaurant_id, is_super_admin=False)
