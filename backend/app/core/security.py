"""Security primitives.

Phase 2 Task 1 shipped the bcrypt password helpers; Task 2 adds the JWT
functions (access + refresh + decode).

Why bcrypt direct (no passlib): passlib is frozen at 1.7.4 (released 2020-10-08,
verified via PyPI) — effectively abandoned for ~6 years, and it breaks against
bcrypt>=4.1. The `bcrypt` package (4.x/5.x, Rust core) does the same job in
two function calls. See RESEARCH Pitfall 1.
"""

from datetime import datetime, timedelta, timezone
from secrets import token_hex

import bcrypt
import jwt

from app.core.config import settings

# bcrypt truncates input at 72 bytes. We cap password length at the schema
# layer (UserCreate.password max_length=64) so this is never hit at runtime.
# The constant is documented here for reviewers (RESEARCH Pitfall 5).
_BCRYPT_MAX_BYTES = 72


def hash_password(plain: str) -> str:
    """Hash a password with bcrypt (cost 12 via gensalt default). Returns a
    utf-8 str ready to store in `usuario.password_hash`."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Constant-time bcrypt verification. Returns False (never raises) on
    mismatch, so the caller treats unknown-user and wrong-password the same
    (avoid user enumeration via timing)."""
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def create_access_token(sub: str, role: str, restaurant_id: int | None) -> str:
    """Issue a short-lived access JWT (HS256).

    Claims: sub=user_id, role, restaurant_id (nullable for cross-tenant),
    type="access", iat, exp. Access tokens are accepted by `get_current_user`.
    """
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "role": role,
        "restaurant_id": restaurant_id,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.ACCESS_TTL_MIN),
        # jti (JWT ID): unique per issued token. Two access tokens minted in
        # the same second would otherwise be byte-identical (same iat/exp),
        # which makes rotation unverifiable. jti is also the standard hook for
        # future per-token revocation (denylist) in v2.
        "jti": token_hex(8),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def create_refresh_token(sub: str) -> str:
    """Issue a long-lived refresh JWT (HS256).

    Claims: sub=user_id, type="refresh", iat, exp. Refresh tokens are accepted
    ONLY by /auth/refresh; using them elsewhere is rejected by the type check.
    """
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=settings.REFRESH_TTL_DAYS),
        "jti": token_hex(8),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def decode_token(token: str) -> dict:
    """Decode + verify signature + exp. `algorithms=["HS256"]` is MANDATORY
    (Pitfall 4 — prevents algorithm-confusion attacks). PyJWT verifies `exp`
    by default; we NEVER pass options={"verify_exp": False}. Raises
    jwt.PyJWTError on any failure; the caller maps it to the HTTP status.
    """
    return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
