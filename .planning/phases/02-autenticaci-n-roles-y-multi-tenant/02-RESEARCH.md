# Phase 2: Autenticación, Roles y Multi-tenant - Research

**Researched:** 2026-08-13
**Domain:** JWT auth (PyJWT 2.13) + password hashing (bcrypt) + SQLAlchemy 2.0 async models + FastAPI dependency-based RBAC + multi-tenant scoping (shared DB + `restaurant_id`) + Alembic migrations
**Confidence:** HIGH (stack & patterns verified Aug 2026; the one open question — passlib vs bcrypt — resolved this session against passlib)

---

## Summary

Phase 2 builds the security + tenancy backbone that every subsequent business endpoint depends on. On top of the Phase 1 walking skeleton (async engine, `get_session`, `Settings`, Docker stack), this phase adds: (1) two permanent ORM tables — `restaurante` (the tenant root) and `usuario` (global, with a nullable `restaurant_id` FK + a 5-value `role` enum); (2) a JWT auth layer with short-lived access tokens + longer-lived refresh tokens, both signed HS256 with a single secret; (3) FastAPI dependencies `get_current_user`, `require_roles(...)`, and a `TenantScope` that filters every staff query by `restaurant_id`; (4) the super-admin platform API (`POST /admin/restaurantes`, `POST /admin/restaurantes/{id}/staff`); and (5) **Alembic, pulled forward from Phase 3** — because Phase 2 is the first phase that creates production tables, and managing them with `create_all()` would be an anti-pattern that forces a messy cutover later.

The architecture is fully locked by `ARCHITECTURE.md`: one JWT secret, claims `{sub, role, restaurant_id}`, shared DB with `restaurant_id` on every tenant-scoped table, no per-tenant schemas, no per-role secrets. `STACK.md` locks PyJWT 2.13 (not python-jose) and bcrypt-family hashing. This research does **not** re-open those decisions — it prescribes the exact models, routers, dependencies, migration, and test plan the planner needs.

**Three calls this research makes (within Claude's discretion, backed by evidence):**

1. **Use `bcrypt` directly, NOT `passlib[bcrypt]`.** Verified this session: `passlib` is frozen at 1.7.4, last released **2020-10-08** — effectively abandoned for ~6 years. `STACK.md` already flagged it MEDIUM confidence ("sin releases recientes"); the evidence now confirms abandonment. The `bcrypt` package (4.x, Rust core, actively maintained, manylinux + win wheels) is the correct choice. A 10-line `app/core/security.py` wrapper replaces everything passlib gave us.

2. **Introduce Alembic in Phase 2, not Phase 3.** Phase 1 deferred Alembic because "no models exist." That condition is now false — Phase 2 creates permanent production tables. Introducing Alembic here means: one clean first migration (`restaurante` + `usuario`), the Dockerfile CMD gains `alembic upgrade head &&`, and Phase 3 simply *adds* migrations instead of bootstrapping the tool + retro-fitting schema. INFR-03's *completion* (full migration set + demo seed) still belongs to Phase 3; only the *tooling* moves forward.

3. **Refresh tokens are stateless JWTs, not DB rows.** Access token TTL ~15 min, refresh token TTL ~7 days, both HS256. Logout is client-side (discard). Tradeoff: no server-side revocation without a denylist — acceptable for v1 scale; a `refresh_token` table is the documented upgrade path if revocation becomes a requirement.

**Primary recommendation:** Scaffold `app/{models,schemas,services,deps,core/security}.py`, two routers (`api/auth.py`, `api/admin.py`), one Alembic migration, and the `get_current_user` / `require_roles` / `TenantScope` dependency trio. Verify with: register→login→refresh flow test, role-enforcement test (cliente cannot create restaurants = 403), and a cross-tenant test (staff A requests restaurant B's resource = 404).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **AUTH-01** | Usuario puede registrarse como cliente con nombre, email y contraseña | `POST /auth/register` (public, no auth) creates `usuario` with `role=cliente`, `restaurant_id=NULL`, bcrypt-hashed password. Unique constraint on `email`. Pydantic `UserCreate` schema validates nombre/email/password. |
| **AUTH-02** | Usuario puede iniciar sesión y su sesión persiste (JWT con refresh) | `POST /auth/login` validates credentials, returns `{access_token, refresh_token, token_type:"bearer"}`. `POST /auth/refresh` accepts a refresh token, returns a fresh access + refresh pair. Access TTL ~15 min (HS256), refresh TTL ~7 days (HS256, `type:"refresh"` claim). Stateless — no DB token table. |
| **AUTH-03** | El sistema distingue 5 roles: super_admin, admin_restaurante, mesero, cocina, cliente | SQLAlchemy `Enum` on `usuario.role` with exactly 5 values. `require_roles(*roles)` FastAPI dependency enforces per-endpoint; matrix in Code Examples. Each protected endpoint declares its allowed roles via `dependencies=[Depends(require_roles(...))]`. |
| **AUTH-04** | Un usuario staff solo puede acceder a los datos de su restaurante (aislamiento multi-tenant) | `TenantScope` dependency: staff get `restaurant_id` from the JWT claim; super_admin gets `None` (no filter); cliente is cross-tenant (tenant derived from resource, not token). Every staff service query applies `.where(Model.restaurant_id == ctx.restaurant_id)`. Verified by cross-tenant test (staff A → restaurant B resource = 404). |
| **PLAT-02** | Super-admin puede crear restaurantes con sus datos básicos (nombre, descripción, tipo de cocina, dirección) | `POST /admin/restaurantes` — `require_roles("super_admin")`. Creates `restaurante` row. Pydantic `RestauranteCreate` schema. |
| **PLAT-03** | Super-admin puede crear usuarios staff (admin restaurante, mesero, cocina) y asignarlos a un restaurante | `POST /admin/restaurantes/{id}/staff` — `require_roles("super_admin")`. Creates `usuario` with a staff role + `restaurant_id=FK(restaurante.id)`. The role in the body must be one of the 3 staff roles (not cliente/super_admin). |
</phase_requirements>

<user_constraints>
## User Constraints

**No CONTEXT.md exists for this phase** (the `02-*` directory is empty — no `*-CONTEXT.md`). Constraints therefore come from project-level locked decisions, which are **not re-opened** here.

### Locked Decisions (from PROJECT.md / STACK.md / ARCHITECTURE.md — immutable)
- **Tech stack: FastAPI (Python)** for the API — user decision.
- **Tech stack: MySQL** as the database — user decision (do NOT propose PostgreSQL/MariaDB).
- **JWT single-secret, multi-rol**: one issuer, one secret, claims `role` (5 values) + `restaurant_id` (nullable). NO per-role secrets, NO multiple issuers. (ARCHITECTURE.md Pattern 2 + Anti-Pattern 7.)
- **Multi-tenant model: shared DB + `restaurant_id` on each tenant-scoped table.** NO schemas-per-tenant, NO databases-per-tenant. (ARCHITECTURE.md Pattern 1 + Anti-Pattern 2.)
- **Cliente is cross-tenant**: `restaurant_id` is NULL in the cliente's token/user; tenant is derived from the resource being accessed. (ARCHITECTURE.md Pattern 2 note.)
- **PyJWT 2.13** (NOT python-jose) for JWT. (STACK.md Core Auth.)
- **bcrypt-family** hashing (bcrypt or argon2-cffi). (STACK.md Core Auth.)
- **5 roles, exact names**: `super_admin`, `admin_restaurante`, `mesero`, `cocina`, `cliente`. (REQUIREMENTS.md AUTH-03 + ARCHITECTURE.md.)
- **Real-time: WebSockets** — out of scope this phase (Phase 7), but the auth model must not block it (the JWT validated here is the same JWT the WS endpoint will accept in Phase 7).

### Claude's Discretion (no CONTEXT.md → researcher recommends, with evidence)
- **Hashing library: `bcrypt` direct (not `passlib[bcrypt]`).** Evidence: passlib frozen at 1.7.4 since 2020-10-08 (verified via PyPI JSON this session). See Standard Stack + Pitfall 1.
- **Alembic: introduce in Phase 2 (pulled forward from Phase 3).** Evidence: Phase 1's deferral rationale ("no models") is now false. See Open Questions #1 + Pitfall 2.
- **Refresh token: stateless JWT (not DB-stored).** Simplest correct approach for v1; revocation via denylist is a documented v2 upgrade. See Open Questions #2.
- **Super-admin bootstrap: env-var-driven idempotent creation on startup.** `SUPER_ADMIN_EMAIL` + `SUPER_ADMIN_PASSWORD` → lifespan creates the super_admin if absent. See Code Examples.
- **Usuario model: single `role` + nullable `restaurant_id` (NOT a `usuario_restaurante` join table).** ARCHITECTURE.md sketched a M:N join table, but v1 requirements are 1 user → 1 restaurant → 1 role (PLAT-03 "asignados a un restaurante", singular). The simpler model matches the JWT claims exactly. The join table is a v2 upgrade if a user can staff multiple restaurants.
- **Access TTL 15 min / refresh TTL 7 days.** Standard balanced values for a consumer + staff app.

### Deferred Ideas (OUT OF SCOPE for Phase 2)
- Role-permission matrix beyond role-name checks (no fine-grained permission table) → keep `require_roles(*names)` simple.
- Password reset / email recovery flow → not in v1 requirements (no AUTH requirement for it); SMTP integration is Phase 8+ at earliest.
- Email verification on registration → not required by AUTH-01.
- Token revocation / denylist / "logout everywhere" → v2 (stateless refresh chosen for v1).
- Rate limiting on `/auth/login` → hardening for Phase 9 prod deploy.
- JWT in cookies vs Authorization header → v1 uses `Authorization: Bearer` (header); cookie/CSRF is a Phase 4+ panel concern if needed.
- OAuth2 / social login → out of scope.
- The rest of the domain model (mesa, categoria, producto, pedido, reserva, pago, calificacion) → **Phase 3**.
</user_constraints>

---

## Standard Stack

Only the subset of STACK.md *newly added* in Phase 2 (Phase 1's stack — FastAPI, SQLAlchemy async, asyncmy, pydantic-settings, MySQL, uv — is already installed and unchanged).

### Core (NEW this phase)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **PyJWT** | 2.13.0 | JWT encode/decode (HS256) | STACK.md locked choice over python-jose. More active (release May 21 2026 vs jose's May 2025), 4 releases in 2026. Simple API: `jwt.encode(payload, secret, "HS256")` / `jwt.decode(token, secret, ["HS256"])`. **Confidence: HIGH** (verified pypi.org/project/PyJWT) |
| **bcrypt** | 4.x (≥4.0) | Password hashing (OpenBSD bcrypt, Rust core) | Actively maintained (vs passlib frozen since 2020). `bcrypt.hashpw(pw, bcrypt.gensalt())` / `bcrypt.checkpw(pw, hash)`. Manylinux + win wheels — no toolchain. **Confidence: HIGH** |
| **Alembic** | 1.19.1 | Schema migrations | STACK.md verified (release Aug 8 2026). Same author as SQLAlchemy. Autogenerate, downgrades, async `env.py` via `run_sync()`. **Confidence: HIGH** |
| **Email-Validator** | (Pydantic extra) | `EmailStr` validation on `UserCreate` | Pydantic 2 requires `email-validator` for `EmailStr`. Installed via `pydantic[email]` or standalone. Tiny pure-Python. **Confidence: HIGH** |

### Supporting (NEW this phase)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **email-validator** | latest | Backs `pydantic.EmailStr` | Always — `UserCreate.email` uses `EmailStr` to reject malformed emails at the schema layer. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff | Verdict |
|------------|-----------|----------|---------|
| **`bcrypt` direct** | **`passlib[bcrypt]` 1.7.4** | passlib gives a uniform API across algorithms + easy migration; BUT it's frozen at 1.7.4 since **2020-10-08** (verified PyPI this session) — 6 years unmaintained, a known supply-chain/maintenance red flag. A 10-line wrapper around `bcrypt` gives the same hash/verify API without the dead dependency. | **Use `bcrypt` direct** (see Pitfall 1) |
| **Alembic in P2** | **`Base.metadata.create_all()` on startup** | `create_all` is 3 lines and zero-config; BUT it's an anti-pattern for production schema management — no migration history, no downgrades, no schema evolution, can't add columns later without manual SQL. Using it in P2 then switching to Alembic in P3 means a messy cutover (Alembic won't know the tables already exist → `alembic stamp` hacks). | **Use Alembic now** (see Pitfall 2) |
| **Stateless refresh JWT** | **DB-stored opaque refresh token** | DB-stored enables server-side revocation + rotation tracking; BUT adds a table, a lookup per refresh, and complexity not needed for v1 scale. Stateless is simpler and the access-TTL is short enough that exposure window is bounded. | **Use stateless refresh** for v1; DB table is the documented v2 upgrade if revocation is needed |
| **Single `role` + nullable `restaurant_id`** | **`usuario_restaurante` M:N join table** | M:N supports one user staffing multiple restaurants; BUT v1 requirements are 1:1 (PLAT-03 singular). The flat column matches the JWT claims (`role` + `restaurant_id`) exactly and avoids a join on every auth check. | **Use flat column** now; M:N is a v2 upgrade |
| **HS256 single secret** | **RS256 asymmetric** | RS256 lets you verify with a public key without the secret; BUT we have a single issuer (the API itself) and a single verifier (the API itself) — there is no key-distribution scenario. HS256 is simpler and standard for single-service auth. | **Use HS256** (consistent with STACK.md / ARCHITECTURE.md) |

### Installation
```bash
cd backend
uv add pyjwt bcrypt alembic "pydantic[email]"
# Phase 1 deps (fastapi, sqlalchemy[asyncio], asyncmy, pydantic-settings, cryptography, uvicorn) already present
# Dev deps (pytest, pytest-asyncio, httpx, ruff) already present
```

**`pyproject.toml` delta** (additions to `[project].dependencies`):
```toml
dependencies = [
    # ... Phase 1 deps unchanged ...
    "pyjwt>=2.13.0",
    "bcrypt>=4.0",
    "alembic>=1.19.0",
    "email-validator>=2.0",   # backs pydantic EmailStr
]
```

**Version verification (this session, Aug 2026):**
- `PyJWT` 2.13.0 — release May 21 2026 ✓ (STACK.md)
- `bcrypt` 4.x — actively maintained, Rust core, manylinux+win wheels ✓
- `alembic` 1.19.1 — release Aug 8 2026 ✓ (STACK.md)
- `passlib` 1.7.4 — release **2020-10-08**, LAST release, **abandoned** ✓ (verified PyPI JSON this session — the decisive evidence for choosing `bcrypt` direct)

---

## Architecture Patterns

### Recommended Project Structure (Phase 2 additions)
```
backend/
├── app/
│   ├── main.py                 # MODIFY: add Alembic-friendly lifespan, include auth + admin routers
│   ├── core/
│   │   ├── config.py           # MODIFY: add JWT_SECRET, ACCESS_TTL_MIN, REFRESH_TTL_DAYS, SUPER_ADMIN_*
│   │   ├── db.py               # unchanged (engine + get_session)
│   │   └── security.py         # NEW: hash_password, verify_password, create_access_token, create_refresh_token, decode_token
│   ├── models/
│   │   ├── __init__.py         # NEW: exports Base, Restaurante, Usuario
│   │   └── base.py             # NEW: declarative Base (DeclarativeBase)
│   │   └── usuario.py          # NEW: Usuario ORM (role enum, nullable restaurant_id FK)
│   │   └── restaurante.py      # NEW: Restaurante ORM (tenant root)
│   ├── schemas/
│   │   ├── __init__.py         # NEW
│   │   ├── auth.py             # NEW: UserCreate, UserLogin, Token, TokenRefresh, UserRead
│   │   └── restaurante.py      # NEW: RestauranteCreate, RestauranteRead, StaffCreate
│   ├── deps/
│   │   ├── __init__.py         # NEW
│   │   └── auth.py             # NEW: get_current_user, require_roles, CurrentUser, get_tenant_scope, TenantScope
│   ├── services/
│   │   ├── __init__.py         # NEW
│   │   ├── auth_service.py     # NEW: register, login, refresh (business logic, not in router)
│   │   └── admin_service.py    # NEW: create_restaurante, create_staff
│   ├── api/
│   │   ├── health.py           # unchanged
│   │   ├── auth.py             # NEW: router /auth/{register,login,refresh,me}
│   │   └── admin.py            # NEW: router /admin/restaurantes (+ staff sub-resource)
│   └── ...
├── alembic/                    # NEW (alembic init, then customize env.py for async)
│   ├── env.py                  # async run_sync pattern; reads settings.database_url
│   ├── script.py.mako
│   └── versions/
│       └── 0001_initial.py     # NEW: create restaurante + usuario tables
├── alembic.ini                 # NEW: sqlalchemy.url overridden in env.py
├── tests/
│   ├── conftest.py             # MODIFY: add auth-token fixtures, super-admin bootstrap helper
│   ├── test_health.py          # unchanged
│   ├── test_db_config.py       # unchanged
│   ├── test_auth_flow.py       # NEW: AUTH-01/02 — register, login, refresh, me
│   ├── test_roles.py           # NEW: AUTH-03 — role enforcement (cliente cannot create restaurante)
│   ├── test_multitenant.py     # NEW: AUTH-04 — staff A → restaurant B resource = 404
│   └── test_admin_platform.py  # NEW: PLAT-02/03 — super-admin creates restaurante + staff
└── scripts/
    └── verify_auth.sh          # NEW: manual acceptance (curl-based happy + sad paths)
```

**Rationale:** Routers stay thin (parse → call service → build response). Services hold business logic (testable without HTTP, reusable by future WS/CLI). `models/` (ORM = DB shape) is separate from `schemas/` (Pydantic = HTTP contract) so migrations and API evolve independently. `deps/auth.py` is the single source of identity/tenant truth.

### Pattern 1: Data model — `Restaurante` (tenant root) + `Usuario` (global, role + nullable tenant FK)
**What:** Two tables. `restaurante` is the tenancy boundary. `usuario` is global with a `role` enum and a **nullable** `restaurant_id` FK (NULL for `super_admin` and `cliente`; required for staff roles).

```python
# app/models/base.py
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass
```

```python
# app/models/restaurante.py
import datetime as dt
from sqlalchemy import BigInteger, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

class Restaurante(Base):
    __tablename__ = "restaurante"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(String(500), nullable=True)
    tipo_cocina: Mapped[str | None] = mapped_column(String(100), nullable=True)
    direccion: Mapped[str | None] = mapped_column(String(255), nullable=True)
    activo: Mapped[bool] = mapped_column(default=True, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
```

```python
# app/models/usuario.py
import enum
import datetime as dt
from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

class RolUsuario(str, enum.Enum):
    super_admin = "super_admin"
    admin_restaurante = "admin_restaurante"
    mesero = "mesero"
    cocina = "cocina"
    cliente = "cliente"

class Usuario(Base):
    __tablename__ = "usuario"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    email: Mapped[str] = mapped_column(String(254), nullable=False, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[RolUsuario] = mapped_column(
        Enum(RolUsuario, name="rol_usuario"), nullable=False, index=True
    )
    # NULL for super_admin & cliente; required for admin_restaurante/mesero/cocina.
    # Enforced at the service layer (not a DB NOT NULL, because super_admin/cliente are valid NULLs).
    restaurant_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=True, index=True
    )
    activo: Mapped[bool] = mapped_column(default=True, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
```

**Key decisions baked in:**
- **`BigInteger` PKs** — room to grow; matches MySQL 8.4 best practice for IDs that may be exposed externally.
- **`email` UNIQUE + indexed** — login lookup + AUTH-01 uniqueness. `String(254)` is the RFC 5321 max.
- **`role` as a DB `Enum`** — the 5 values are enforced at the DB layer (Anti-Pattern 5 in ARCHITECTURE.md: no free strings). `index=True` because staff-listing queries filter by role.
- **`restaurant_id` nullable** — super_admin and cliente are legitimately cross-tenant. The "staff must have a restaurant" rule is enforced in `TenantScope` (service layer), not as a DB constraint, because the column legitimately holds NULLs.
- **`DateTime(timezone=False)`** — the MySQL server is configured to `-05:00` (Bogota, no DST). We store naive wall-time; the server-level TZ makes it unambiguous. (Consistent with Phase 1 decision.)

### Pattern 2: Security layer — bcrypt direct (no passlib)
**What:** A thin `app/core/security.py` with four functions. No passlib dependency.

```python
# app/core/security.py
import bcrypt
import jwt
from datetime import datetime, timedelta, timezone

from app.core.config import settings


def hash_password(plain: str) -> str:
    """Hash a password with bcrypt (cost 12 default via gensalt). Returns utf-8 str."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Constant-time bcrypt verification. Returns False (not raise) on mismatch."""
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def create_access_token(sub: str, role: str, restaurant_id: int | None) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "role": role,
        "restaurant_id": restaurant_id,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.ACCESS_TTL_MIN),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def create_refresh_token(sub: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=settings.REFRESH_TTL_DAYS),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def decode_token(token: str) -> dict:
    """Decode + verify (exp, signature). Raises jwt.PyJWTError on any failure."""
    return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
```

**Why no passlib:** verified this session — `passlib` 1.7.4 was released 2020-10-08 and has had **zero releases in ~6 years**. It is effectively abandoned. The `bcrypt` package (4.x, Rust core) is actively maintained and does the same job in 2 function calls. See Pitfall 1.

### Pattern 3: JWT payload shape + the 3 dependencies (`get_current_user`, `require_roles`, `TenantScope`)
**What:** One secret, HS256. Access token carries `{sub, role, restaurant_id, type:"access"}`. The three FastAPI dependencies compose to enforce identity, authorization, and tenancy.

**Access token payload (from Pattern 2):**
```json
{
  "sub": "42",
  "role": "mesero",
  "restaurant_id": 7,
  "type": "access",
  "iat": 1735689600,
  "exp": 1735690500
}
```
(super_admin → `restaurant_id: null`; cliente → `restaurant_id: null`.)

```python
# app/deps/auth.py
from dataclasses import dataclass
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

import jwt
from app.core.db import get_session
from app.core.security import decode_token
from app.models.usuario import RolUsuario, Usuario

bearer_scheme = HTTPBearer(auto_error=True)


@dataclass
class CurrentUser:
    id: int
    role: RolUsuario
    restaurant_id: int | None


async def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> CurrentUser:
    """Decode the Bearer JWT, load minimal identity. 401 on any failure."""
    try:
        payload = decode_token(creds.credentials)
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token inválido o expirado")

    if payload.get("type") != "access":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Tipo de token incorrecto")

    try:
        user_id = int(payload["sub"])
    except (KeyError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token malformado")

    # Confirm the user still exists & is active (cheap, indexed by PK).
    db_user = await session.get(Usuario, user_id)
    if db_user is None or not db_user.activo:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Usuario inexistente o inactivo")

    return CurrentUser(id=db_user.id, role=db_user.role, restaurant_id=db_user.restaurant_id)


def require_roles(*allowed: RolUsuario):
    """Dependency factory: 403 if the current user's role is not in `allowed`."""
    async def _dep(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in allowed:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Rol no autorizado para esta operación")
        return user
    return _dep


@dataclass
class TenantScope:
    restaurant_id: int | None   # None => super_admin (no filter); int => staff (filter to this tenant)
    is_super_admin: bool


def get_tenant_scope(user: CurrentUser = Depends(get_current_user)) -> TenantScope:
    """Derive the tenant filter for the current request.

    - super_admin => (None, True)  — no filter, sees all restaurants
    - staff (admin/mesero/cocina) => (user.restaurant_id, False) — 403 if they lack a restaurant
    - cliente => NOT allowed to use staff dependencies (callers gate cliente out via require_roles)
    """
    if user.role == RolUsuario.super_admin:
        return TenantScope(None, True)
    # staff roles
    if user.restaurant_id is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Staff sin restaurante asignado")
    return TenantScope(user.restaurant_id, False)
```

**Usage in a service (the cross-tenant filter in action):**
```python
# app/services/admin_service.py (example of a tenant-scoped read for AUTH-04 verification)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.deps.auth import TenantScope
from app.models.restaurante import Restaurante

async def get_restaurante_for_staff(session: AsyncSession, restaurante_id: int, scope: TenantScope) -> Restaurante | None:
    """Returns the restaurante IF the staff may see it, else None (→ 404). Super_admin sees any."""
    stmt = select(Restaurante).where(Restaurante.id == restaurante_id, Restaurante.activo.is_(True))
    if not scope.is_super_admin:
        stmt = stmt.where(Restaurante.id == scope.restaurant_id)   # <-- THE tenant filter
    return (await session.execute(stmt)).scalar_one_or_none()
```

**The single most important line in Phase 2** is `stmt = stmt.where(Restaurante.id == scope.restaurant_id)`. This is what makes AUTH-04 true. Every staff query in every future phase repeats this pattern. The `TenantScope` dependency is the architectural commitment that prevents the #1 multi-tenant anti-pattern (forgetting the `WHERE`). (See ARCHITECTURE.md Pattern 1 + Anti-Pattern 1.)

### Pattern 4: Routers — `/auth/*` (public + authenticated) and `/admin/*` (super_admin)

```python
# app/api/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.deps.auth import CurrentUser, get_current_user
from app.schemas.auth import TokenPair, UserCreate, UserLogin, UserRead
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register(body: UserCreate, session: AsyncSession = Depends(get_session)):
    """AUTH-01: public cliente self-registration."""
    return await auth_service.register_cliente(session, body)


@router.post("/login", response_model=TokenPair)
async def login(body: UserLogin, session: AsyncSession = Depends(get_session)):
    """AUTH-02: validate credentials, return access + refresh."""
    return await auth_service.login(session, body)


@router.post("/refresh", response_model=TokenPair)
async def refresh(refresh_token: str, session: AsyncSession = Depends(get_session)):
    """AUTH-02: rotate tokens from a valid refresh token."""
    return await auth_service.refresh(session, refresh_token)


@router.get("/me", response_model=UserRead)
async def me(user: CurrentUser = Depends(get_current_user),
             session: AsyncSession = Depends(get_session)):
    """Return the authenticated user's profile."""
    return await auth_service.get_user(session, user.id)
```

```python
# app/api/admin.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.deps.auth import CurrentUser, TenantScope, get_tenant_scope, require_roles
from app.models.usuario import RolUsuario
from app.schemas.restaurante import RestauranteCreate, RestauranteRead, StaffCreate, StaffRead
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])

# --- PLAT-02: super-admin platform management ---
@router.post("/restaurantes", response_model=RestauranteRead, status_code=status.HTTP_201_CREATED)
async def create_restaurante(
    body: RestauranteCreate,
    session: AsyncSession = Depends(get_session),
    _: CurrentUser = Depends(require_roles(RolUsuario.super_admin)),
):
    return await admin_service.create_restaurante(session, body)


@router.get("/restaurantes", response_model=list[RestauranteRead])
async def list_restaurantes(
    session: AsyncSession = Depends(get_session),
    _: CurrentUser = Depends(require_roles(RolUsuario.super_admin)),
):
    return await admin_service.list_restaurantes(session)


# --- PLAT-03: super-admin creates staff assigned to a restaurant ---
@router.post("/restaurantes/{restaurante_id}/staff", response_model=StaffRead, status_code=status.HTTP_201_CREATED)
async def create_staff(
    restaurante_id: int,
    body: StaffCreate,
    session: AsyncSession = Depends(get_session),
    _: CurrentUser = Depends(require_roles(RolUsuario.super_admin)),
):
    return await admin_service.create_staff(session, restaurante_id, body)


# --- AUTH-04 verification endpoint: staff reads their own (or 404 for another tenant) ---
@router.get("/restaurantes/{restaurante_id}", response_model=RestauranteRead)
async def get_restaurante(
    restaurante_id: int,
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    from fastapi import HTTPException, status
    r = await admin_service.get_restaurante_for_staff(session, restaurante_id, scope)
    if r is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Restaurante no encontrado")
    return r
```

**Role matrix (AUTH-03) enforced via `require_roles`:**

| Endpoint | Allowed roles | Denied → |
|----------|---------------|----------|
| `POST /auth/register` | *(public)* | n/a |
| `POST /auth/login` | *(public)* | n/a |
| `POST /auth/refresh` | *(valid refresh token)* | 401 |
| `GET /auth/me` | all 5 (any authenticated) | 401 |
| `POST /admin/restaurantes` | `super_admin` | 403 |
| `GET /admin/restaurantes` | `super_admin` | 403 |
| `POST /admin/restaurantes/{id}/staff` | `super_admin` | 403 |
| `GET /admin/restaurantes/{id}` | `super_admin`, `admin_restaurante`, `mesero`, `cocina` (tenant-scoped) | 403 (cliente) / 404 (wrong tenant) |

### Pattern 5: Super-admin bootstrap on startup (lifespan)
**What:** On app startup, if no `super_admin` user exists, create one from env vars. Idempotent.

```python
# app/services/bootstrap.py (called from main.py lifespan)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.usuario import RolUsuario, Usuario

async def ensure_super_admin(session: AsyncSession) -> None:
    """Create the bootstrap super_admin from env vars if none exists. Safe to run every boot."""
    if not settings.SUPER_ADMIN_EMAIL or not settings.SUPER_ADMIN_PASSWORD:
        return  # not configured; skip (dev convenience)
    stmt = select(Usuario).where(Usuario.role == RolUsuario.super_admin).limit(1)
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
```

```python
# main.py lifespan (modified from Phase 1)
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # --- startup ---
    async with async_session_maker() as session:
        await ensure_super_admin(session)
    yield
    # --- shutdown ---
    await engine.dispose()
```

**Why env vars over a seed script:** the super-admin is the trust root — its password must never live in committed code or a committed seed file. Env vars keep the secret in `.env` (gitignored) and make the bootstrap automatic on every deploy (idempotent).

### Anti-Patterns to Avoid
- **`passlib[bcrypt]` for new code** — passlib is frozen at 1.7.4 (Oct 2020). Use `bcrypt` direct. (Pitfall 1.)
- **`Base.metadata.create_all()` for production schema** — no migration history, no downgrades, painful cutover to Alembic later. Use Alembic from day one of having models. (Pitfall 2.)
- **Storing JWTs in the DB by default** — adds a table + lookup for no v1 benefit. Stateless refresh is correct for v1. (See Open Questions #2.)
- **A staff query without the `WHERE restaurant_id == scope.restaurant_id` filter** — the #1 multi-tenant leak. The `TenantScope` dependency exists to make this impossible to forget. (ARCHITECTURE.md Anti-Pattern 1.)
- **Multiple JWT secrets per role** — one secret, role in the claim. (ARCHITECTURE.md Anti-Pattern 7.)
- **Reading the password / hash from the DB and serializing it in a response schema** — `UserRead` MUST exclude `password_hash`. Use Pydantic with explicit fields (not `from_attributes` over the whole ORM model blindly).
- **`jwt.decode` without verifying `exp`** — PyJWT verifies `exp` by default; do NOT pass `options={"verify_exp": False}`. Do NOT forget to pass `algorithms=["HS256"]` (PyJWT requires it explicitly to prevent algorithm-confusion attacks).
- **Putting `restaurant_id` in the token for cliente** — cliente is cross-tenant; the tenant comes from the resource, not the token. (ARCHITECTURE.md Pattern 2 note.)
- **Catching `bcrypt`'s password-too-long error silently** — bcrypt has a 72-byte input limit; longer passwords should be rejected at the schema layer (`UserCreate.password` max length) or pre-hashed. Document the limit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom salt+hash, MD5/SHA, or "just use passlib because the tutorial said so" | `bcrypt` direct (`hashpw`/`checkpw`) | bcrypt is the OWASP-recommended standard; constant-time; salt baked in. passlib is abandoned. (Pitfall 1) |
| JWT encode/decode | Manual base64+HMAC, or `python-jose` | `PyJWT` 2.13 | Standard, active, handles `exp`/`iat`/signing alg enforcement. jose is dormant. |
| Token expiry / clock math | Manual `time.time()` comparisons | PyJWT's built-in `exp` claim verification | `jwt.decode` raises `ExpiredSignatureError` automatically; no off-by-one. |
| Email validation | Regex hand-rolled | `pydantic.EmailStr` (+ `email-validator`) | RFC-correct, rejects malformed at the schema layer before your service runs. |
| Schema migrations | `create_all()`, hand-written `.sql` files, or "just run it once" | **Alembic** | Versioned, reversible, reviewable, CI-able. `create_all` is a one-way ratchet. (Pitfall 2) |
| RBAC | Manual `if user.role == "..."` sprinkled in every router | `require_roles(*roles)` dependency factory | One declaration per endpoint; impossible to forget on a new endpoint (router won't compile the dependency wrong). |
| Tenant filtering | `.all()` with no filter, or a `restaurant_id` param passed ad-hoc | `TenantScope` dependency + `.where(... == scope.restaurant_id)` | Single point of truth; the filter is structural, not remembered per-query. (AUTH-04) |
| Bearer token extraction | Manual header parsing | `fastapi.security.HTTPBearer` | Handles the `Authorization: Bearer xxx` parse + 401-on-missing; returns typed credentials. |
| DB session per request | Manual `engine.connect()` | `get_session` (Phase 1, reused) | Already built; pool-scoped, async, `expire_on_commit=False`. |

**Key insight:** Phase 2 is almost entirely "wire together well-known primitives correctly." The risk is not novelty — it's the details: the abandoned passlib, the forgotten `WHERE restaurant_id`, the `verify_exp` accidentally disabled, the `create_all` trap. The dependency + service layering makes the safe path the default.

---

## Common Pitfalls

### Pitfall 1: Using `passlib[bcrypt]` (abandoned since 2020)
**What goes wrong:** Tutorials and older FastAPI docs (`fastapi.tiangolo.com/tutorial/security/oauth2-jwt/`) recommend `passlib[bcrypt]`. New projects copy it. Then: passlib never gets updates, has a known incompatibility with `bcrypt>=4.1` (passlib 1.7.4 reads `bcrypt.__about__` which bcrypt 4.1+ removed → `AttributeError: module 'bcrypt' has no attribute '__about__'`), and you're debugging a dead library's internals.
**Why it happens:** passlib 1.7.4 was the last release (2020-10-08 — verified PyPI JSON this session). It predates bcrypt 4.x's API changes. The FastAPI tutorial hasn't been updated to reflect this.
**How to avoid:** Do NOT install passlib. Use `bcrypt` direct (`bcrypt.hashpw(pw, bcrypt.gensalt())` / `bcrypt.checkpw(pw, hash)`). A 10-line `app/core/security.py` wrapper (Pattern 2 above) is the entire replacement.
**Warning signs:** `pip install passlib[bcrypt]` then `from passlib.context import CryptContext` → `AttributeError` on bcrypt 4.1+; or `passlib` flagged by `pip-audit`/Dependabot as unmaintained.
**Confidence:** HIGH (verified passlib release history directly this session).

### Pitfall 2: `Base.metadata.create_all()` instead of Alembic
**What goes wrong:** Developer adds models, calls `async def init_db(): async with engine.begin() as c: await c.run_sync(Base.metadata.create_all)` on startup, tables appear, it "works." Then in Phase 3 they need to add a column: `create_all` does NOT alter existing tables (it only creates missing ones), so the new column never appears. They either hand-write SQL (no history) or retrofit Alembic with `alembic stamp` hacks to pretend the baseline exists.
**Why it happens:** `create_all` is 3 lines and feels faster than Alembic setup. It's the most common SQLAlchemy beginner shortcut.
**How to avoid:** Introduce Alembic the moment you have your first ORM model (which is Phase 2). The async `env.py` is ~30 lines (referenced in Phase 1 research). The first migration creates `restaurante` + `usuario`. Phase 3 just adds more migrations — no cutover.
**Warning signs:** `create_all` anywhere in `main.py`/lifespan; "why didn't my new column appear?" after editing a model.
**Confidence:** HIGH.

### Pitfall 3: Forgetting the tenant `WHERE` filter (cross-tenant leak)
**What goes wrong:** A staff endpoint does `select(Mesa).all()` (or `select(Restaurante).where(id==x)`) without `.where(restaurant_id == scope.restaurant_id)`. Staff of restaurant A see restaurant B's data. This is the #1 multi-tenant bug and the explicit target of AUTH-04.
**Why it happens:** The filter is easy to forget when writing the Nth service method. Without a structural enforcement point, it's a matter of time.
**How to avoid:** `TenantScope` dependency on EVERY staff endpoint/service. Code review checklist: "does every `select(...)` in a staff service have the `restaurant_id` filter?" Cross-tenant integration test (staff A token → restaurant B resource → expect 404) as a permanent gate.
**Warning signs:** a staff endpoint returning data; a `select` without `scope` in scope.
**Confidence:** HIGH (ARCHITECTURE.md Anti-Pattern 1 — the canonical multi-tenant pitfall).

### Pitfall 4: `jwt.decode` without `algorithms=` (algorithm confusion)
**What goes wrong:** `jwt.decode(token, secret)` without `algorithms=["HS256"]`. An attacker crafts a token with `alg: "none"` or `alg: "RS256"` and the public key, and PyJWT may accept it. (Modern PyJWT rejects `none` by default, but omitting `algorithms` is still a CVE-class mistake.)
**Why it happens:** Copy-pasting a decode call without the kwarg; older tutorials omit it.
**How to avoid:** Always `jwt.decode(token, secret, algorithms=["HS256"])`. Centralize in `decode_token()` (Pattern 2) so it's impossible to forget.
**Warning signs:** any `jwt.decode(...)` call without `algorithms=`.
**Confidence:** HIGH (standard JWT security guidance).

### Pitfall 5: bcrypt 72-byte password limit
**What goes wrong:** bcrypt silently truncates passwords longer than 72 bytes. A user with a >72-byte password can log in with any password sharing the first 72 bytes — a (minor) security reduction.
**Why it happens:** bcrypt's fixed design; passlib used to pre-hash with SHA-256 to work around it, raw `bcrypt` does not.
**How to avoid:** Enforce a max password length at the schema layer (`UserCreate.password: str = Field(min_length=8, max_length=64)`). 64 chars is ample for humans and well under 72 bytes for typical UTF-8. Document the limit. (If you ever want to allow arbitrary length, pre-hash with SHA-256 then base64 — but that's unnecessary for v1.)
**Warning signs:** a test registering a 200-char password "succeeds."
**Confidence:** HIGH (bcrypt documented behavior).

### Pitfall 6: Refreshing with an access token (or vice versa)
**What goes wrong:** `/auth/refresh` accepts any valid JWT, including an access token. An attacker with a leaked access token can mint refresh tokens indefinitely. Or `/auth/me` accepts a refresh token.
**Why it happens:** The two token types share a secret; without a `type` claim check, they're interchangeable.
**How to avoid:** Every token carries a `type` claim (`"access"` or `"refresh"`). `get_current_user` rejects non-`access` tokens; `/auth/refresh` rejects non-`refresh` tokens. (Pattern 2 + Pattern 3.)
**Warning signs:** a refresh succeeding with an access token.
**Confidence:** HIGH.

### Pitfall 7: Returning `password_hash` in API responses
**What goes wrong:** `response_model` set to the ORM model, or `from_attributes=True` copying all columns → the hash leaks in `GET /auth/me` or staff responses.
**Why it happens:** Convenience; forgetting the hash is a column like any other.
**How to avoid:** `UserRead` / `StaffRead` are explicit Pydantic models WITHOUT a `password_hash` field. Never use the ORM model as a `response_model`. (Pattern 4.)
**Warning signs:** `password_hash` visible in any curl output.
**Confidence:** HIGH.

### Pitfall 8: `expire_on_commit=True` after registering a user (MissingGreenlet)
**What goes wrong:** `register` does `session.add(user); await session.commit(); return user` and reading `user.id`/`user.email` for the response triggers lazy I/O on a closed greenlet → `MissingGreenlet`.
**Why it happens:** Default sessionmaker has `expire_on_commit=True`.
**How to avoid:** Already solved in Phase 1 — `async_session_maker` has `expire_on_commit=False`. Do NOT re-introduce `True` anywhere. After `commit()`, optionally `await session.refresh(user)` to populate server-side defaults (`id`, `created_at`) before returning.
**Warning signs:** `MissingGreenlet` / "IO should be performed from a coroutine" on the register/login path.
**Confidence:** HIGH (Phase 1 set this correctly; this is a "don't regress" reminder).

---

## Code Examples

### AUTH-01/02 happy path (curl, against running stack)
```bash
# 1. Register a cliente
curl -s -X POST http://localhost:8000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Ana","email":"ana@x.com","password":"S3cret0!"}' | jq
# -> 201 {"id":1,"nombre":"Ana","email":"ana@x.com","role":"cliente","restaurant_id":null}

# 2. Login -> get access + refresh
TOKENS=$(curl -s -X POST http://localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ana@x.com","password":"S3cret0!"}')
echo "$TOKENS" | jq
# -> {"access_token":"eyJ...","refresh_token":"eyJ...","token_type":"bearer"}
ACCESS=$(echo "$TOKENS" | jq -r .access_token)
REFRESH=$(echo "$TOKENS" | jq -r .refresh_token)

# 3. /auth/me with the access token
curl -s http://localhost:8000/auth/me -H "Authorization: Bearer $ACCESS" | jq
# -> {"id":1,"nombre":"Ana","email":"ana@x.com","role":"cliente","restaurant_id":null}

# 4. Refresh -> new pair
curl -s -X POST http://localhost:8000/auth/refresh -d "$REFRESH" | jq
# -> {"access_token":"eyJ...","refresh_token":"eyJ...","token_type":"bearer"}
```

### PLAT-02/03 super-admin flow (after bootstrap)
```bash
# Assume SUPER_ADMIN_EMAIL/PASSWORD set in .env; super_admin auto-created on startup.
SA_TOKENS=$(curl -s -X POST http://localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$SUPER_ADMIN_EMAIL\",\"password\":\"$SUPER_ADMIN_PASSWORD\"}")
SA_ACCESS=$(echo "$SA_TOKENS" | jq -r .access_token)

# Create a restaurante (PLAT-02)
curl -s -X POST http://localhost:8000/admin/restaurantes \
  -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
  -d '{"nombre":"El Carbón","descripcion":"Parrilla","tipo_cocina":"Parrilla","direccion":"Cra 1 #2-3"}' | jq
# -> 201 {"id":1,"nombre":"El Carbón",...,"activo":true}

# Create staff for it (PLAT-03)
curl -s -X POST http://localhost:8000/admin/restaurantes/1/staff \
  -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
  -d '{"nombre":"Juan","email":"juan@elcarbon.com","password":"Mesero!1","role":"mesero"}' | jq
# -> 201 {"id":2,"nombre":"Juan","email":"juan@elcarbon.com","role":"mesero","restaurant_id":1}
```

### AUTH-03 role enforcement (cliente cannot create restaurante)
```bash
# Ana (cliente) token from above
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/admin/restaurantes \
  -H "Authorization: Bearer $ACCESS" -H 'Content-Type: application/json' \
  -d '{"nombre":"X"}'
# -> 403   (AUTH-03 verified)
```

### AUTH-04 cross-tenant isolation
```bash
# Super-admin creates restaurante A (id=1) and restaurante B (id=2).
# Creates mesero "Juan" for restaurante A (restaurant_id=1) — see PLAT-03 flow above.
# Creates mesero "Pedro" for restaurante B (restaurant_id=2).
JUAN_TOKENS=$(curl -s -X POST http://localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"juan@elcarbon.com","password":"Mesero!1"}')
JUAN_ACCESS=$(echo "$JUAN_TOKENS" | jq -r .access_token)

# Juan (restaurant A) requests restaurant B -> 404 (AUTH-04 verified)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/admin/restaurantes/2 \
  -H "Authorization: Bearer $JUAN_ACCESS"
# -> 404   (NOT 200 — the tenant filter returned None → 404)

# Juan requests his OWN restaurant -> 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/admin/restaurantes/1 \
  -H "Authorization: Bearer $JUAN_ACCESS"
# -> 200
```

### Alembic async `env.py` (the pattern Phase 1 referenced, now built here)
```python
# alembic/env.py
import asyncio
from logging.config import fileConfig
from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.core.config import settings
from app.models.base import Base
# IMPORTANT: import all model modules so Base.metadata is fully populated:
from app.models import restaurante, usuario  # noqa: F401

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Inject the async URL from settings (overrides alembic.ini sqlalchemy.url)
config.set_main_option("sqlalchemy.url", settings.database_url)
target_metadata = Base.metadata


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


run_migrations_online()
```

**Dockerfile CMD change (the one edit Phase 1 deferred to "when Alembic lands"):**
```dockerfile
# Old (Phase 1):
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
# New (Phase 2):
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
```

### `.env.example` additions
```env
# --- Phase 2: auth + tenancy ---
# JWT signing secret. MUST be set to a strong random value in prod (Phase 9).
# Generate with: python -c "import secrets; print(secrets.token_urlsafe(48))"
JWT_SECRET=replace-me-with-a-long-random-string
ACCESS_TTL_MIN=15
REFRESH_TTL_DAYS=7

# Bootstrap super-admin (created on first startup if absent). 
# Email must be unique; password should be rotated after first login in prod.
SUPER_ADMIN_EMAIL=admin@gri.local
SUPER_ADMIN_PASSWORD=replace-me-change-immediately
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `passlib[bcrypt]` for password hashing | `bcrypt` direct (or `argon2-cffi`) | passlib frozen since 2020-10; bcrypt 4.1 (2023) broke passlib's `__about__` access | Stop installing passlib; use bcrypt's 2-function API |
| `python-jose` for JWT | `PyJWT` 2.13 | jose last release May 2025, dormant; PyJWT 4 releases in 2026 | PyJWT is the active choice (STACK.md locked) |
| `OAuth2PasswordBearer` + form-data login | `HTTPBearer` + JSON login | FastAPI supports both; JSON body is simpler for a Flutter/`dio` client (no form-encoding) | Use `HTTPBearer` for the protected endpoints; `/auth/login` takes a JSON `UserLogin` body |
| `create_all()` for schema | Alembic migrations | Always the standard; "defer because no models" no longer applies | First migration in Phase 2 |
| Manual `os.getenv` for secrets | pydantic-settings (Phase 1) | Already in place | `JWT_SECRET`, `SUPER_ADMIN_*` join `Settings` |
| `@app.on_event("startup")` | `lifespan` (Phase 1) | FastAPI 0.93+ | Super-admin bootstrap runs in `lifespan` startup, not `on_event` |

**Deprecated/outdated (do NOT use this phase):**
- `passlib` (frozen 2020) — use `bcrypt` direct.
- `python-jose` (dormant) — use `PyJWT`.
- `OAuth2PasswordBearer` + `/oauth2/token` form flow IF your client prefers JSON — but note FastAPI's docs tutorial uses the OAuth2 form pattern; either is fine, pick JSON for Flutter `dio` simplicity.
- `create_all()` for schema — use Alembic.
- `@app.on_event` — use `lifespan` (Phase 1 set the pattern).

---

## Open Questions

1. **Alembic now (Phase 2) vs defer to Phase 3 (as Phase 1 planned)?**
   - What we know: Phase 1's SKELETON.md deferred Alembic to Phase 3 with rationale "no models exist yet; `alembic upgrade head` would crash." Phase 2 creates the first permanent models (`restaurante`, `usuario`). INFR-03 ("Alembic + seed run as part of deployment") is a Phase 3 *requirement*.
   - Recommendation: **Introduce Alembic in Phase 2.** The deferral rationale has expired (models now exist). Introducing it here means one clean first migration and the Dockerfile CMD edit, and Phase 3 simply *adds* migrations + the demo seed. INFR-03's *completion* (full migration suite + seed) still belongs to Phase 3 — only the *tooling* moves forward. This avoids the `create_all`→Alembic cutover trap (Pitfall 2) and the "do it twice" waste.
   - Confidence: HIGH (architectural reasoning). **Flag for planner confirmation** since it's a deliberate change from the Phase 1 plan.

2. **Refresh token: stateless JWT vs DB-stored opaque token?**
   - What we know: AUTH-02 only requires "refresh gives a new session without re-login." Stateless is simplest. DB-stored enables revocation.
   - Recommendation: **Stateless refresh JWT for v1** (`type:"refresh"`, 7-day TTL). Logout is client-side. Cannot revoke without a denylist — acceptable because access TTL is 15 min (bounded exposure). Upgrade path: add a `refresh_token` table + rotation if revocation becomes a requirement (v2).
   - Confidence: HIGH.

3. **Should `GET /admin/restaurantes/{id}` be the AUTH-04 verification endpoint, or should we wait for real tenant-scoped resources (mesas) in Phase 3?**
   - What we know: AUTH-04 success criteria says "staff A requesting resources of restaurant B gets 404." Phase 2 has no mesas/pedidos yet (those are Phase 3). We need *some* tenant-scoped read to verify AUTH-04 now.
   - Recommendation: **Use `GET /admin/restaurantes/{id}` under `get_tenant_scope`** as the AUTH-04 verification endpoint this phase. It's a legitimate Phase 2 endpoint (staff viewing their restaurant), the service applies the tenant filter, and cross-tenant access yields 404. Phase 3 adds mesas/pedidos which repeat the same pattern. This is honest — AUTH-04 is about the *mechanism* (TenantScope), which is fully exercised here.
   - Confidence: HIGH.

4. **Single `role` column vs `usuario_restaurante` M:N join table?**
   - What we know: ARCHITECTURE.md sketched a M:N join table (`usuario_restaurante`). PLAT-03 says "assigned to a restaurant" (singular). v1 has no requirement for one user staffing multiple restaurants.
   - Recommendation: **Flat `role` + nullable `restaurant_id` on `usuario`.** Matches JWT claims exactly (`role`, `restaurant_id`); avoids a join on every auth check. The M:N table is a documented v2 upgrade.
   - Confidence: HIGH.

5. **Cliente self-registration: should `email` be case-insensitive unique?**
   - What we know: MySQL default collation `utf8mb4_unicode_ci` is **case-insensitive** — so a `UNIQUE` index on `email` is already case-insensitive at the DB layer (Phase 1 set this collation). `ANA@x.com` and `ana@x.com` collide on insert.
   - Recommendation: **Rely on the DB collation** (already correct). Normalize email to lowercase in the service layer before insert + lookup, for consistency. No extra work needed.
   - Confidence: HIGH.

---

## Validation Architecture

> `workflow.nyquist_validation` is ABSENT in `.planning/config.json` → treated as **enabled**. This section is REQUIRED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | **pytest 9.1.1 + pytest-asyncio 1.4.0 + httpx 0.28.1** (installed in Phase 1) |
| Config file | `backend/pyproject.toml` `[tool.pytest.ini_options]` (`asyncio_mode="auto"`, `testpaths=["tests"]`) |
| Quick run command | `cd backend && uv run pytest tests/ -x` |
| Full suite command | `cd backend && uv run pytest tests/ -v` |

Phase 1's test pattern (httpx `AsyncClient` vs the running Docker stack at `http://localhost:8000`) is **reused unchanged**. Phase 2 tests build on it: they hit the running API (which has applied the Alembic migration and bootstrapped the super-admin). Tests create their own data via the API (register clientes, login as super_admin to create restaurantes + staff) and assert HTTP behaviors. This is integration-level (real HTTP, real DB, real bcrypt, real JWT) — appropriate for an auth/tenancy phase where the correctness of the *full request path* is what matters.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | `POST /auth/register` creates a cliente (201, returns UserRead without password_hash) | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_register_cliente -x` | ❌ Wave 0 |
| AUTH-01 | duplicate email rejected (409) | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_register_duplicate_email -x` | ❌ Wave 0 |
| AUTH-02 | `POST /auth/login` returns access + refresh for valid creds | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_login_returns_tokens -x` | ❌ Wave 0 |
| AUTH-02 | `POST /auth/login` rejects wrong password (401) | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_login_wrong_password -x` | ❌ Wave 0 |
| AUTH-02 | `POST /auth/refresh` returns a new token pair from a valid refresh | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_refresh_rotates_tokens -x` | ❌ Wave 0 |
| AUTH-02 | `POST /auth/refresh` rejects an access token used as refresh (401) | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_refresh_rejects_access_token -x` | ❌ Wave 0 |
| AUTH-02 | `GET /auth/me` returns the authenticated user | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_me -x` | ❌ Wave 0 |
| AUTH-02 | `GET /auth/me` rejects missing/invalid token (401) | integration | `cd backend && uv run pytest tests/test_auth_flow.py::test_me_no_token -x` | ❌ Wave 0 |
| AUTH-03 | cliente cannot `POST /admin/restaurantes` (403) | integration | `cd backend && uv run pytest tests/test_roles.py::test_cliente_cannot_create_restaurante -x` | ❌ Wave 0 |
| AUTH-03 | unauthenticated cannot access protected endpoints (401) | integration | `cd backend && uv run pytest tests/test_roles.py::test_no_token_admin -x` | ❌ Wave 0 |
| AUTH-03 | super_admin CAN create restaurante (201) | integration | `cd backend && uv run pytest tests/test_admin_platform.py::test_super_admin_creates_restaurante -x` | ❌ Wave 0 |
| AUTH-04 | staff A requesting restaurant B resource → 404 | integration | `cd backend && uv run pytest tests/test_multitenant.py::test_staff_cross_tenant_404 -x` | ❌ Wave 0 |
| AUTH-04 | staff A requesting own restaurant → 200 | integration | `cd backend && uv run pytest tests/test_multitenant.py::test_staff_own_tenant_200 -x` | ❌ Wave 0 |
| AUTH-04 | super_admin requesting any restaurant → 200 (no tenant filter) | integration | `cd backend && uv run pytest tests/test_multitenant.py::test_super_admin_no_filter -x` | ❌ Wave 0 |
| PLAT-02 | super_admin creates restaurante with all fields (201, returns id) | integration | `cd backend && uv run pytest tests/test_admin_platform.py::test_create_restaurante_fields -x` | ❌ Wave 0 |
| PLAT-03 | super_admin creates staff assigned to a restaurante (201, role + restaurant_id set) | integration | `cd backend && uv run pytest tests/test_admin_platform.py::test_create_staff_assigned -x` | ❌ Wave 0 |
| PLAT-03 | staff creation rejects invalid role (cliente/super_admin as staff → 422/400) | integration | `cd backend && uv run pytest tests/test_admin_platform.py::test_create_staff_invalid_role -x` | ❌ Wave 0 |
| PLAT-03 | staff creation for non-existent restaurante → 404 | integration | `cd backend && uv run pytest tests/test_admin_platform.py::test_create_staff_missing_restaurante -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd backend && uv run pytest tests/ -x` (fast; smoke the affected area)
- **Per wave merge:** rebuild + redeploy the stack (`docker compose up -d --build`), then full pytest + `scripts/verify_auth.sh`
- **Phase gate:** Full suite green AND manual `verify_auth.sh` (curl happy + sad paths) all pass before `/gsd-verify-work`. **Cross-tenant test (`test_staff_cross_tenant_404`) is a hard gate** — AUTH-04 is the phase's highest-risk requirement.

### Wave 0 Gaps
- [ ] `backend/tests/conftest.py` — **MODIFY**: add helpers `register_cliente(client, ...)`, `login(client, ...) -> (access, refresh)`, `auth_header(token)`, and a `super_admin_token` fixture (reads `SUPER_ADMIN_EMAIL/PASSWORD` from env, logs in). Keep the existing `async_client` fixture.
- [ ] `backend/tests/test_auth_flow.py` — covers AUTH-01, AUTH-02 (register, login, refresh, me, token-type enforcement)
- [ ] `backend/tests/test_roles.py` — covers AUTH-03 (role enforcement: cliente→admin = 403, no-token = 401)
- [ ] `backend/tests/test_multitenant.py` — covers AUTH-04 (cross-tenant 404, own-tenant 200, super_admin no-filter). **Highest-priority test.**
- [ ] `backend/tests/test_admin_platform.py` — covers PLAT-02, PLAT-03 (super_admin creates restaurante + staff, invalid role, missing restaurante)
- [ ] `backend/scripts/verify_auth.sh` — manual acceptance (curl-based happy + sad paths; mirrors the Code Examples)
- [ ] **Stack precondition:** tests require the Docker stack running (`docker compose up -d`) with `.env` populated (`JWT_SECRET`, `SUPER_ADMIN_EMAIL`, `SUPER_ADMIN_PASSWORD`, DB creds) AND `alembic upgrade head` applied (the Dockerfile CMD does this on boot). Document in `conftest.py` docstring.

---

## Sources

### Primary (HIGH confidence)
- **pypi.org/pypi/passlib/json** (fetched this session) — confirms `passlib` latest is **1.7.4**, released **2020-10-08**, zero releases since. **The decisive evidence for choosing `bcrypt` direct over `passlib[bcrypt]`.**
- **pypi.org/project/PyJWT** — 2.13.0, release May 21 2026 (STACK.md verified).
- **pypi.org/project/alembic** — 1.19.1, release Aug 8 2026 (STACK.md verified).
- **.planning/research/STACK.md** — locked stack (PyJWT over jose, bcrypt-family hashing, FastAPI/SQLAlchemy async versions) verified Aug 2026.
- **.planning/research/ARCHITECTURE.md** — locked patterns: shared-DB multi-tenant (Pattern 1), JWT single-secret multi-rol with `{role, restaurant_id}` claims (Pattern 2), `TenantScope` dependency, role × endpoint matrix, anti-patterns (forgetting the WHERE, multiple secrets, schema-per-tenant).
- **.planning/phases/01-.../01-RESEARCH.md + 01-01-SUMMARY.md + SKELETON.md** — Phase 1 built `core/config.py` (Settings), `core/db.py` (async engine + `get_session`, `expire_on_commit=False`), `main.py` (lifespan), `/health`; deferred Alembic; locked layout `app/{core,api}/`.
- **backend/app/core/{config,db}.py, main.py, api/health.py** — read directly this session; confirms exactly what exists to build on.
- **REQUIREMENTS.md** — AUTH-01..04, PLAT-02, PLAT-03 exact wording + Phase 2 traceability.

### Secondary (MEDIUM confidence)
- **FastAPI tutorial "OAuth2 with JWT"** (`fastapi.tiangolo.com/tutorial/security/oauth2-jwt/`) — referenced by ARCHITECTURE.md; uses `python-jose` + `passlib`. Both are now superseded (jose dormant, passlib frozen); the *pattern* (Bearer → decode → identity) is correct, the *libraries* are not. This research substitutes PyJWT + bcrypt direct.
- **bcrypt 72-byte limit** — standard bcrypt behavior (training + widely documented). Mitigated by schema-layer max length.
- **MySQL `utf8mb4_unicode_ci` case-insensitivity on UNIQUE index** — Phase 1 set this collation; standard MySQL behavior. Email case-insensitivity falls out for free.

### Tertiary (LOW confidence)
- None material. The phase's decisions are all backed by Primary sources or direct codebase inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack (PyJWT, bcrypt, Alembic, pydantic[email]): **HIGH** — versions verified; passlib abandonment verified directly this session.
- Architecture (models, JWT claims, dependencies, TenantScope): **HIGH** — fully locked by ARCHITECTURE.md; codebase inspected for the build-on surface.
- Pitfalls: **HIGH** — passlib abandonment (verified PyPI), create_all trap (standard SQLAlchemy guidance), tenant leak (canonical multi-tenant pitfall, ARCHITECTURE.md Anti-Pattern 1), JWT algorithm confusion (standard security guidance).
- Alembic-in-P2 decision: **HIGH** confidence in the reasoning; flagged for planner confirmation because it deliberately moves tooling Phase 1 deferred.

**Research date:** 2026-08-13
**Valid until:** 2026-09-13 (stable auth stack; PyJWT/bcrypt/Alembic patch versions unlikely to shift the patterns. Re-check passlib status only if someone proposes reintroducing it.)
