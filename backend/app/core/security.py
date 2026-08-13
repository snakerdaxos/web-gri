"""Security primitives.

Phase 2 Task 1 ships ONLY the bcrypt password helpers here (bootstrap needs
`hash_password`). The JWT functions (`create_access_token`, `create_refresh_token`,
`decode_token`) are added in Task 2.

Why bcrypt direct (no passlib): passlib is frozen at 1.7.4 (released 2020-10-08,
verified via PyPI) — effectively abandoned for ~6 years, and it breaks against
bcrypt>=4.1. The `bcrypt` package (4.x/5.x, Rust core) does the same job in
two function calls. See RESEARCH Pitfall 1.
"""

import bcrypt

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
