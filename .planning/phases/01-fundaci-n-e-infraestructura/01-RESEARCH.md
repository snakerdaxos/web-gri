# Phase 1: Fundación e Infraestructura - Research

**Researched:** 2026-08-13
**Domain:** Docker infra (MySQL 8.4 + FastAPI/uvicorn), SQLAlchemy 2 async, pydantic-settings, env-driven config
**Confidence:** HIGH (Python layer verified Aug 2026; MySQL 8.4 auth-plugin removal = training-verified, flag for implementation check)

---

## Summary

Phase 1 is a pure infrastructure greenfield: stand up MySQL 8.4 LTS and a minimal FastAPI app in Docker Compose, wire the DB connection through environment variables, and prove it with a `/health` endpoint that runs `SELECT 1`. There is **no domain code, no models, no auth, no Alembic** in this phase — those land in Phases 2–3. The deliverable is "a reproducible `docker compose up` whose data survives restarts, speaks utf8mb4 + America/Bogota, and whose connection string comes entirely from `.env`."

The stack is fully decided (PROJECT.md + STACK.md), so this research does **not** re-evaluate alternatives. Instead it prescribes the **exact files and code patterns** the planner needs to write concrete tasks: a corrected `docker-compose.yml`, a slim `Dockerfile` using the modern uv-from-GHCR pattern, the minimal `app/` layout (`main.py`, `core/config.py`, `core/db.py`, `api/health.py`), and the SQLAlchemy 2 async engine/session recipe.

**Two corrections to STACK.md the planner MUST apply** (both verified this session):
1. **Drop `--default-authentication-plugin=caching_sha2_password` from the MySQL `command:`** — that system variable was deprecated in MySQL 8.0.27 and **removed in MySQL 8.4**. Passing it to `mysql:8.4-lts` makes the container fail to start with "unknown variable". `caching_sha2_password` is already the default in 8.4, so the flag is both broken and unnecessary.
2. **`build-essential default-libmysqlclient-dev pkg-config` are NOT needed in the Dockerfile** — asyncmy 0.2.14 ships prebuilt `manylinux cp312` wheels (verified on PyPI), as do bcrypt and greenlet. The slim image installs all deps from wheels with no compilation, so the C build toolchain can be omitted on the standard x86_64/aarch64 build (smaller image, faster builds).

**Primary recommendation:** Build a single `docker-compose.yml` (mysql + api with `depends_on: condition: service_healthy`), a uv-based Dockerfile, and a ~5-file FastAPI app whose only endpoint is `/health`. Verify INFR-01/INFR-02 with one SQL script (charset + TZ + round-trip an accented/emoji string) and one `curl` + restart cycle.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **INFR-01** | MySQL corre en Docker con volumen persistente, charset utf8mb4 y timezone America/Bogota | `docker-compose.yml` con named volume `gri_mysql_data`, `command:` con `--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci`, `TZ=America/Bogota` env + `--default-time-zone='-05:00'`; verificación vía `SELECT @@character_set_database, @@global.time_zone` y round-trip de acento/emoji (Architecture Patterns + Code Examples) |
| **INFR-02** | La API FastAPI corre en Docker (Ubuntu Server) y se conecta a MySQL por configuración de entorno | `Dockerfile` (uv from GHCR) + `core/config.py` (pydantic-settings: `DB_HOST/PORT/USER/PASSWORD/NAME`, `DEMO_MODE`) + `core/db.py` (SQLAlchemy 2 `create_async_engine` con `mysql+asyncmy://`); compose pasa `DB_HOST=mysql` al contenedor API; `/health` ejecuta `SELECT 1` para verificar la conexión |
</phase_requirements>

<user_constraints>
## User Constraints

**No CONTEXT.md exists for this phase** (verified: `has_context: false`). Constraints therefore come from project-level locked decisions in PROJECT.md / STACK.md, which are **not re-opened** here.

### Locked Decisions (from PROJECT.md — user decisions, immutable)
- **Tech stack: FastAPI (Python)** for the API — user decision.
- **Tech stack: MySQL** as the database — user decision (do NOT propose PostgreSQL/MariaDB).
- **Infrastructure: MySQL and API deploy in Docker on Ubuntu Server**; DB connection configured toward that server, not localhost, in production.
- **Real-time: WebSockets** for orders/table state — out of scope this phase, but the stack must not block it (uvicorn[standard] already bundles `websockets`).

### Claude's Discretion (no CONTEXT.md → researcher recommends)
- **Alembic:** recommend DEFERRING init to Phase 3 (no models exist yet; `alembic upgrade head` in the Dockerfile CMD would fail today). See "Don't Hand-Roll" / Open Questions.
- **Config shape:** recommend parts-based settings (`DB_HOST/PORT/USER/PASSWORD/NAME`) composed into a URL, over a single `DATABASE_URL` string — more granular, easier to verify INFR-02.
- **TZ mechanism:** recommend `TZ=America/Bogota` env + `--default-time-zone='-05:00'` (Bogota = UTC-5, no DST) to avoid loading tz tables; documented tradeoff below.
- **Test scope:** recommend lightweight smoke tests + a manual verification script; full pytest infra is Wave 0 but kept minimal for an infra phase.

### Deferred Ideas (OUT OF SCOPE for Phase 1)
- Domain models (mesa, pedido, reserva, producto, etc.) → **Phase 3**.
- Alembic migrations → **Phase 3** (INFR-03).
- Seed / DEMO_MODE data → **Phase 3** (PLAT-04). The `DEMO_MODE` setting can EXIST in config now (cheap, read by Phase 3) but must do nothing yet.
- Auth / JWT / multi-tenant → **Phase 2**.
- WebSockets → **Phase 7**.
- Nginx / TLS → **Phase 9** (prod hardening). Dev compose exposes ports directly.
</user_constraints>

---

## Standard Stack

Only the subset of STACK.md needed for Phase 1. Versions verified Aug 2026.

### Core
| Library / Image | Version | Purpose | Why Standard |
|-----------------|---------|---------|--------------|
| **Python** | 3.12 (`python:3.12-slim`) | Runtime | FastAPI 0.141 min Python 3.10; 3.12 is the stable sweet spot. **Confidence: HIGH** |
| **FastAPI** | 0.141.1 | Web framework | Verified pypi.org Jul 29 2026. Lifespan context manager is the modern startup/shutdown API (`@app.on_event` is deprecated). **Confidence: HIGH** |
| **uvicorn[standard]** | 0.52.2 | ASGI server | Official FastAPI recommendation. `[standard]` bundles uvloop + httptools + websockets + watchfiles. Verified Aug 13 2026. **Confidence: HIGH** |
| **SQLAlchemy** | 2.0.52 | ORM + async engine | `create_async_engine` + `async_sessionmaker` + `AsyncSession`. Verified docs.sqlalchemy.org Aug 11 2026. **Confidence: HIGH** |
| **asyncmy** | 0.2.14 | asyncio MySQL driver | Drop-in aiomysql API, Cython core. **Ships `manylinux cp312` wheels** → installs with NO compilation on `python:3.12-slim`. Verified pypi.org/project/asyncmy Aug 12 2026. **Confidence: HIGH** |
| **pydantic-settings** | 2.x | Typed config from `.env` | `BaseSettings` + `SettingsConfigDict`. Shipped as separate pkg from Pydantic 2.x. **Confidence: HIGH** |
| **MySQL** | 8.4-lts (`mysql:8.4-lts`) | Database | LTS until Apr 2032. **Note:** `--default-authentication-plugin` removed in 8.4 (use nothing — caching_sha2_password is default). **Confidence: HIGH** |
| **uv** | 0.12.x | Dependency mgmt | `COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/` is the current official Docker pattern. Docs updated Aug 7 2026. **Confidence: HIGH** |
| **Docker Compose** | v2 (bundled in Docker) | Orchestration | `depends_on: condition: service_healthy` is the modern startup-order primitive. **Confidence: HIGH** |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **greenlet** | (transitive via `sqlalchemy[asyncio]`) | C coroutine support for async ORM | Installed automatically by `sqlalchemy[asyncio]`; has manylinux wheels. **Always** |
| **ruff** | latest (dev) | Lint + format | Replaces flake8/isort/pyupgrade. Configure in `pyproject.toml`. **Dev only** |
| **pytest + pytest-asyncio + httpx** | 8.x / 0.24+ / 0.28+ | Tests | Smoke test `/health` against running stack. **Wave 0** |

### Alternatives Considered
| Instead of | Could Use | Tradeoff | Verdict |
|------------|-----------|----------|---------|
| Parts-based config (`DB_HOST`...) | Single `DATABASE_URL` string | URL is terser; parts are more granular + trivial to verify INFR-02 (change one part → connection changes) | **Use parts** (this phase) |
| `TZ` env + `--default-time-zone='-05:00'` | Load tz tables via `mysql_tzinfo_to_sql` + named `America/Bogota` zone | Named zone is "more correct" but needs an init step + tz table load in Docker | **Use offset for v1** (Bogota has no DST since 1993, so `-05:00` == America/Bogota permanently) |
| uv from GHCR (`COPY --from=...`) | `pip install uv` | GHCR copy is smaller, faster, official-recommended | **Use GHCR copy** |
| `mysqladmin ping` healthcheck | `mysql -e "SELECT 1"` healthcheck | Both work; `mysqladmin ping` is the Docker-standard idiom | **Use `mysqladmin ping`** |

### Installation
```bash
# Local dev (Windows host running Docker Desktop):
cd backend
uv init --python 3.12 --name gri-backend
uv add "fastapi[standard]" "uvicorn[standard]" "sqlalchemy[asyncio]" asyncmy pydantic-settings
uv add --dev ruff pytest pytest-asyncio httpx
# .venv auto-created by uv on Windows; deps install from wheels (asyncmy/bcrypt/greenlet all have cp312 wheels)
```

**`pyproject.toml` (Phase 1 minimal):**
```toml
[project]
name = "gri-backend"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi[standard]>=0.141.0",
    "uvicorn[standard]>=0.52.0",
    "sqlalchemy[asyncio]>=2.0.52",
    "asyncmy>=0.2.14",
    "pydantic-settings>=2.0",
]

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "ASYNC", "S", "T20"]
ignore = ["S101"]  # allow assert in tests

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

> **Note:** `alembic`, `pyjwt`, `bcrypt`, `httpx` (runtime), `passlib` are NOT added this phase — they belong to Phases 2–3. Adding them now would ship unused/dead code.

---

## Architecture Patterns

### Recommended Project Structure (Phase 1 minimal)
```
cel/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py            # FastAPI app + lifespan + include health router
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py      # pydantic-settings Settings
│   │   │   └── db.py          # async engine + sessionmaker + get_session dep
│   │   └── api/
│   │       ├── __init__.py
│   │       └── health.py      # GET /health -> SELECT 1
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py        # fixtures (Wave 0)
│   │   └── test_health.py     # smoke test
│   ├── pyproject.toml
│   ├── uv.lock                # commit this — needed by Dockerfile bind-mount sync
│   └── Dockerfile
├── docker-compose.yml         # root (orchestrates backend/ + mysql)
├── .env.example               # committed template
└── .env                       # gitignored, dev values
```

**Why root-level `docker-compose.yml`:** it references both `./backend` (build context for API) and the `mysql` image; keeping it at repo root matches how it will run on Ubuntu Server.

### Pattern 1: `docker-compose.yml` (corrected for MySQL 8.4)
**What:** The single orchestration file that satisfies INFR-01 (volume + charset + TZ) and INFR-02 (API depends on healthy MySQL, env-driven connection).
**Critical:** No `--default-authentication-plugin` (removed in 8.4).

```yaml
# docker-compose.yml
services:
  mysql:
    image: mysql:8.4-lts
    container_name: gri-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: gri          # DB 'gri' created on first boot
      MYSQL_USER: gri_app
      MYSQL_PASSWORD: ${MYSQL_APP_PASSWORD}
      TZ: America/Bogota           # container OS TZ (MySQL time_zone=SYSTEM resolves to this)
    ports:
      - "3306:3306"                # DEV ONLY — remove/omit in prod (Phase 9)
    volumes:
      - gri_mysql_data:/var/lib/mysql
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-time-zone=-05:00      # Bogota = UTC-5, no DST (DO NOT pass --default-authentication-plugin — removed in 8.4)
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -u root -p$$MYSQL_ROOT_PASSWORD --silent"]
      interval: 10s
      timeout: 5s
      retries: 10            # first boot of MySQL is slow; give it room
      start_period: 30s

  api:
    build: ./backend
    container_name: gri-api
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy   # API won't start until MySQL answers ping
    environment:
      DB_HOST: mysql                 # docker DNS name of the mysql service
      DB_PORT: "3306"
      DB_USER: gri_app
      DB_PASSWORD: ${MYSQL_APP_PASSWORD}
      DB_NAME: gri
      DEMO_MODE: ${DEMO_MODE:-false}
      ENVIRONMENT: development
    ports:
      - "8000:8000"

volumes:
  gri_mysql_data:                    # named volume → data survives `docker compose down`
```

**Why `$$MYSQL_ROOT_PASSWORD` in healthcheck:** Compose interpolates `$VAR` from the host/`.env`. `$$` escapes to a literal `$` so the running container reads its OWN `MYSQL_ROOT_PASSWORD` env var at healthcheck time.

**Why `start_period: 30s` + `retries: 10`:** MySQL 8.4 first-boot (initializing the data dir, creating users) takes 15–25s. A tight healthcheck makes the API `service_healthy` gate flap. Generous startup window prevents a false "unhealthy" during first boot.

**Why `condition: service_healthy` (not plain `depends_on`):** Plain `depends_on` only waits for container *start*, not MySQL *readiness*. The API would try to connect during MySQL's init and crash-loop. `service_healthy` blocks the API until `mysqladmin ping` succeeds.

### Pattern 2: `Dockerfile` (uv from GHCR, no build toolchain needed)
**What:** Build the API image. Uses the official uv Docker pattern; omits `build-essential` because asyncmy/bcrypt/greenlet ship manylinux cp312 wheels.

```dockerfile
# backend/Dockerfile
FROM python:3.12-slim

# uv binary from the official image (recommended over `pip install uv`)
COPY --from=ghcr.io/astral-sh/uv:0.12 /uv /uvx /bin/

# Compile bytecode (faster startup), link mode copy (silences cache-on-separate-fs warnings)
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

# Layer 1: install deps ONLY (cached unless uv.lock/pyproject change)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

# Layer 2: copy source + install the project itself
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

# Non-root user (security hygiene)
RUN useradd --create-home --uid 1000 appuser && chown -R appuser /app
USER appuser

# Put the venv on PATH so `uvicorn` resolves directly
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Key points:**
- **No `alembic upgrade head` in CMD** — Alembic is deferred to Phase 3 (no migrations exist yet; the DB `gri` is created by `MYSQL_DATABASE`). Adding it now would crash on startup.
- **`.dockerignore` is mandatory** (see Pitfall 3): exclude `.venv`, `__pycache__`, `.pytest_cache`, `.env`, `tests/` (optional — keeps image lean).
- **`--no-dev`** excludes pytest/ruff from the production image.
- If a future Phase builds on a platform without wheels (rare), re-add `build-essential default-libmysqlclient-dev pkg-config` in a builder stage.

### Pattern 3: `core/config.py` (pydantic-settings, parts-based)
**What:** All config comes from env vars. This is the INFR-02 contract — changing `.env` changes the connection with zero code edits.

```python
# backend/app/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database connection PARTS (INFR-02: change these via .env -> connection changes)
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "gri_app"
    DB_PASSWORD: str = ""
    DB_NAME: str = "gri"

    # App flags
    ENVIRONMENT: str = "development"   # development | production
    DEMO_MODE: bool = False            # read but inert this phase (Phase 3 seeds demo when True)

    @property
    def database_url(self) -> str:
        return (
            f"mysql+asyncmy://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}?charset=utf8mb4"
        )


settings = Settings()
```

**Why parts over a single `DATABASE_URL`:** INFR-02's success criterion ("changing `.env` changes the connection") is trivially demonstrable by flipping `DB_HOST` (e.g. `mysql` in compose → `localhost` for local non-Docker dev → the prod server IP in Phase 9). A single opaque URL string is harder to verify per-part.

### Pattern 4: `core/db.py` (SQLAlchemy 2 async engine + session)
**What:** The async engine and a FastAPI dependency that yields an `AsyncSession`. `pool_pre_ping=True` protects against stale connections ("MySQL server has gone away").

```python
# backend/app/core/db.py
from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    pool_pre_ping=True,     # validate connections before checkout (MySQL idle timeout safe)
    pool_size=10,
    max_overflow=20,
    pool_recycle=3600,      # recycle conns before MySQL's wait_timeout
    future=True,
)

async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # avoid lazy-load after commit in async context
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session
```

### Pattern 5: `main.py` (lifespan, not deprecated on_event) + `health.py`
**What:** Modern FastAPI startup/shutdown via `lifespan`. `/health` runs `SELECT 1` to prove the API↔DB path end-to-end.

```python
# backend/app/main.py
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import health
from app.core.config import settings
from app.core.db import engine


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # --- startup ---
    yield
    # --- shutdown ---
    await engine.dispose()   # close the pool cleanly


app = FastAPI(
    title="GRI API",
    version="0.1.0",
    lifespan=lifespan,
)
app.include_router(health.router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"app": "GRI API", "environment": settings.ENVIRONMENT}
```

```python
# backend/app/api/health.py
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(tags=["health"])


@router.get("/health")
async def health(session: AsyncSession = Depends(get_session)) -> JSONResponse:
    """Liveness + DB connectivity. Runs SELECT 1; 200 only if the DB answers."""
    try:
        result = await session.execute(text("SELECT 1"))
        result.scalar_one()
    except Exception as exc:  # noqa: BLE001 — surface any DB failure as 503
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "error", "database": "unreachable", "detail": str(exc)},
        )
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={"status": "ok", "database": "connected"},
    )
```

**Why the try/except in `/health`:** A `/health` that raises on DB failure returns a 500 with a stack trace. Returning 503 with `{status:"error"}` is the correct contract for load balancers / `depends_on`-style checks, and it makes the manual verification unambiguous (200 = good, 503 = bad).

### Anti-Patterns to Avoid
- **`--default-authentication-plugin=caching_sha2_password` on `mysql:8.4-lts`** → container won't start ("unknown variable"). The STACK.md example has this bug. **Drop it.**
- **Plain `depends_on: [mysql]` without `condition: service_healthy`** → API races MySQL's init and crash-loops on "Can't connect".
- **`@app.on_event("startup")`** → deprecated since FastAPI 0.93. Use `lifespan`.
- **`build-essential`/`default-libmysqlclient-dev` in the slim image when wheels exist** → bloats the image ~300MB and slows builds for no benefit on standard platforms.
- **`expire_on_commit=True` (default) with AsyncSession** → triggers implicit lazy I/O after commit → `MissingGreenlet` / `IO should be performed from a coroutine` errors. Always set `expire_on_commit=False`.
- **Exposing port 3306 in production** → dev convenience only. Phase 9 removes it; document now.
- **`CMD` running `alembic upgrade head` this phase** → no `alembic/` dir exists; container crash-loops. Defer to Phase 3.
- **Forgetting `.dockerignore` for `.venv`** → copies the host's (Windows/Python 3.12-specific) venv into the Linux image, breaking everything. uv docs explicitly call this out.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MySQL readiness gate | `sleep 10` in API entrypoint, or a retry loop | `depends_on: { mysql: { condition: service_healthy } }` + `mysqladmin ping` healthcheck | Sleep is a race; healthcheck is deterministic |
| Typed config | `os.getenv("DB_HOST")` calls scattered everywhere | pydantic-settings `BaseSettings` | Validation, defaults, `.env` loading, single source of truth (INFR-02) |
| DB connection string | Manual string concat in each module | `settings.database_url` property + SQLAlchemy `create_async_engine` | One place; URL-encoding of password handled by SQLAlchemy |
| Async DB sessions | Manual `engine.connect()` per request | `async_sessionmaker` + `get_session` FastAPI dependency | Proper pool reuse, scoped per-request lifecycle |
| Dependency installs in Docker | `pip install -r requirements.txt` + manual pinning | uv + `uv.lock` + `uv sync --locked` | Reproducible, 10–100x faster, lockfile committed |
| Charset / collation | Setting per-column after the fact | `--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci` at server boot | Server default flows to every new DB/table/column automatically |

**Key insight:** Every piece of Phase 1 is a solved problem with an off-the-shelf primitive (Compose healthcheck, pydantic-settings, SQLAlchemy async, uv Docker). There is nothing novel to invent. The phase's risk is in **getting the config details right** (the MySQL 8.4 auth-plugin trap, the `$$` escape, `expire_on_commit`), not in architecture.

---

## Common Pitfalls

### Pitfall 1: `--default-authentication-plugin` breaks MySQL 8.4 boot
**What goes wrong:** The STACK.md `docker-compose.yml` example passes `command: --default-authentication-plugin=caching_sha2_password ...`. On `mysql:8.4-lts` the container exits immediately: `unknown variable 'default-authentication-plugin=caching_sha2_password'`.
**Why it happens:** That system variable was deprecated in MySQL 8.0.27 and **removed in 8.4** (replaced by `authentication_policy`). The old STACK.md example was written against MySQL 8.0 conventions.
**How to avoid:** Drop the flag entirely. `caching_sha2_password` is already the default in 8.4. The `MYSQL_USER` created by the image gets `caching_sha2_password` automatically.
**Warning signs:** `docker compose up` → `gri-mysql` exits with code 1 within ~2s; `docker logs gri-mysql` shows the unknown-variable error.
**Confidence:** HIGH (training-verified MySQL 8.4 migration item). **Implementation task should confirm** with `docker compose up mysql` succeeding; can also verify `SELECT plugin FROM mysql.user WHERE user='gri_app'` returns `caching_sha2_password`.

### Pitfall 2: asyncmy "needs build tools" — actually it ships wheels
**What goes wrong:** Developers copy old Dockerfiles with `apt-get install build-essential default-libmysqlclient-dev pkg-config`, bloating the image ~300MB and slowing builds, believing asyncmy must compile Cython.
**Why it happens:** asyncmy historically lacked wheels; PyPI now publishes `manylinux2014/2_17/2_28` cp39–cp314 wheels for x86_64 + aarch64 (verified Aug 12 2026), plus musllinux + macOS + Windows wheels.
**How to avoid:** On the standard `python:3.12-slim` (Debian/glibc, x86_64) build, omit the C toolchain. asyncmy, bcrypt, and greenlet all install from wheels. Only re-add build deps if you target an exotic arch without wheels.
**Warning signs:** Image size > 600MB; `RUN uv sync` step takes > 60s on first build.

### Pitfall 3: `.venv` leaks into the Docker image
**What goes wrong:** `COPY . /app` without `.dockerignore` copies the host's `.venv` (built for Windows host Python) into the Linux container. `uvicorn` then resolves to a broken binary, or imports fail with ELF/ABI errors.
**Why it happens:** uv creates `.venv` locally; without an ignore rule Docker sends it as build context.
**How to avoid:** Create `backend/.dockerignore` with at minimum: `.venv/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.env`, `tests/`, `*.pyc`.
**Warning signs:** Build context size is huge; runtime `ModuleNotFoundError` or `bad ELF interpreter`.

### Pitfall 4: Password interpolation in Compose healthcheck
**What goes wrong:** Writing `-p$MYSQL_ROOT_PASSWORD` in a Compose `healthcheck.test` shell string: Compose tries to interpolate `$MYSQL_ROOT_PASSWORD` from the *host* env at parse time, or the container sees a literal that doesn't match.
**How to avoid:** Use `$$` to escape → `mysqladmin ping -h 127.0.0.1 -u root -p$$MYSQL_ROOT_PASSWORD --silent` so the running container resolves its own env var. Alternatively use `test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]` (ping often works pre-auth on localhost socket).
**Warning signs:** Healthcheck logs "Access denied for user 'root'@'localhost'"; `service_healthy` never becomes true → API never starts.

### Pitfall 5: Plain `depends_on` races MySQL startup
**What goes wrong:** `depends_on: [mysql]` (short form) only waits for the container to *start*, not for MySQL to *accept connections*. The API boots, tries `SELECT 1`, gets `Can't connect to MySQL server`, and exits; Compose restarts it; loop continues for ~15s until MySQL is ready.
**How to avoid:** Use the long form `depends_on: { mysql: { condition: service_healthy } }`. Combined with the `mysqladmin ping` healthcheck + generous `start_period`, the API starts exactly once.
**Warning signs:** `docker logs gri-api` shows repeated "Can't connect" then a sudden success; `restart` count > 0 in `docker compose ps`.

### Pitfall 6: `expire_on_commit=True` with AsyncSession
**What goes wrong:** After `await session.commit()`, accessing an ORM attribute triggers a lazy SQL load on a closed/no-loop greenlet → `MissingGreenlet: greenlet spawn has not been called` or `IO should be performed from a coroutine`.
**How to avoid:** Always construct `async_sessionmaker(..., expire_on_commit=False)`. Doesn't bite Phase 1 (no commits yet) but set it now so Phase 2+ doesn't inherit a broken default.
**Warning signs:** Phase 2 auth code crashes after commit when reading `user.id`.

### Pitfall 7: utf8mb4 only at table level (collation mismatch on JOINs)
**What goes wrong:** Server boots as `latin1`/`utf8` (3-byte), the `gri` DB inherits that, and 4-byte chars (emoji, some CJK) raise `Incorrect string value` on INSERT or silently corrupt.
**How to avoid:** Set at **server boot** (`--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci` in `command:`) so it flows to DB→table→column. Then verify with `SELECT @@character_set_database, @@collation_database` and a round-trip INSERT/SELECT of `'Açaí 🍜'`.
**Warning signs:** Emoji insert throws `1366 Incorrect string value`; accents look fine but emoji don't.

### Pitfall 8: Timezone ambiguity (naive vs aware, SYSTEM vs offset)
**What goes wrong:** MySQL `time_zone=SYSTEM` resolves via the container's `TZ` env; if `TZ` isn't set, the container is UTC and `NOW()` returns UTC. App code that assumes Bogota local time drifts by 5h. Worse: mixing naive Python `datetime` (no tzinfo) with MySQL `TIMESTAMP` (UTC-stored) produces phantom offsets.
**How to avoid:** Set BOTH `TZ=America/Bogota` (container) and `--default-time-zone=-05:00` (MySQL global, explicit). Verify `SELECT @@global.time_zone` = `-05:00` and `SELECT NOW()` matches a Bogota wall clock. For Phase 1 there are no `DATETIME`/`TIMESTAMP` columns yet, but the server-level config is correct from boot so Phase 3 models inherit it.
**Warning signs:** `SELECT NOW()` off by 5 hours from local Bogota time.

---

## Code Examples

### Verify INFR-01 + INFR-02 (the acceptance script)
Run after `docker compose up -d` waits for healthy. Put in `backend/scripts/verify_infra.sh` or run manually.

```bash
# 1. API health (INFR-02) — must be 200 with database: connected
curl -s http://localhost:8000/health | grep '"database":"connected"'

# 2. Charset + TZ + persistence + 4-byte round-trip (INFR-01) via mysql client in the container
docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri <<'SQL'
SELECT @@character_set_database AS charset, @@collation_database AS collation,
       @@global.time_zone AS tz_global, NOW() AS now_local;
CREATE TABLE IF NOT EXISTS infra_probe (v VARCHAR(50) CHARACTER SET utf8mb4);
TRUNCATE infra_probe;
INSERT INTO infra_probe VALUES ('Açaí 🍜 café Bogotá');
SELECT v FROM infra_probe;
SQL
# Expect: charset=utf8mb4, collation=utf8mb4_unicode_ci, tz_global=-05:00,
#         and the SELECT returns the accented+emoji string intact.

# 3. Persistence across restart (INFR-01)
docker compose restart mysql
sleep 15
docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri -e "SELECT v FROM infra_probe;"
# Expect: the row still there.

# 4. env-driven connection (INFR-02) — change DB_NAME to a non-existent DB, API /health -> 503
#    (document the test; do it by editing .env and `docker compose up -d api`, confirm 503, revert)
```

### Change `.env` → connection changes (INFR-02 proof)
```bash
# .env (committed as .env.example with placeholder values; real .env gitignored)
MYSQL_ROOT_PASSWORD=changeme-root
MYSQL_APP_PASSWORD=changeme-app
DEMO_MODE=false
```
Flip `DB_NAME` in compose (or point `DB_HOST` at a different host) → restart api → `/health` goes 503 (1045 Access denied / 1049 Unknown database). This is the direct demonstration of INFR-02.

### `.env.example` (committed)
```env
# Copy to .env and set real values. .env is gitignored.
MYSQL_ROOT_PASSWORD=replace-me-root
MYSQL_APP_PASSWORD=replace-me-app
DEMO_MODE=false
# DB_HOST etc. are set in docker-compose.yml for the container (DB_HOST=mysql).
# For local non-Docker dev against MySQL on host: DB_HOST=127.0.0.1
```

### Reference: Alembic async `env.py` (NOT built this phase — for Phase 3)
The planner should NOT create `alembic/` now. When Phase 3 adds models, the async env.py pattern is:
```python
# alembic/env.py (Phase 3) — async with run_sync(migration_context)
import asyncio
from alembic import context
from sqlalchemy.ext.asyncio import async_engine_from_config
from sqlalchemy.engine import Connection
# ... target_metadata = Base.metadata ...

def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations() -> None:
    connectable = async_engine_from_config(config.get_section(...), prefix="sqlalchemy.")
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()

def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())

run_migrations_online()
```
And the Dockerfile CMD becomes: `CMD ["sh","-c","alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]` — **only in Phase 3**.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `--default-authentication-plugin` server flag | (flag removed) caching_sha2_password is default; use `authentication_policy` for advanced rules | MySQL 8.4 (deprecated 8.0.27) | Drop the flag or MySQL 8.4 won't start |
| `pip install uv` in Dockerfile | `COPY --from=ghcr.io/astral-sh/uv:0.12 /uv /uvx /bin/` | uv 0.5+ official guide | Smaller image, no pip bootstrap |
| `requirements.txt` | `pyproject.toml` + `uv.lock` | 2024+ Python ecosystem | Reproducible lockfile, fast resolver |
| `@app.on_event("startup"/"shutdown")` | `lifespan` async context manager | FastAPI 0.93+ | on_event deprecated; lifespan is the supported API |
| `depends_on: [db]` (short form) | `depends_on: { db: { condition: service_healthy } }` | Compose v2 | Deterministic startup order via healthcheck |
| sync SQLAlchemy `session.query()` | `session.execute(select(...))` | SQLAlchemy 2.0 | Old Query API being removed; 2.0 is typed + async |
| `aiomysql` for async MySQL | `asyncmy` (wheels, 5x faster) | asyncmy stable 2024+ | aiomysql is `3 - Alpha` on PyPI; asyncmy is the production choice |

**Deprecated/outdated (do NOT use this phase):**
- `--default-authentication-plugin` (removed in MySQL 8.4)
- `@app.on_event` (deprecated in FastAPI)
- `aiomysql` (Alpha, slower)
- `mysql:8.0` / `mysql:8.4` without `-lts` tag (use the explicit LTS tag)
- plain `depends_on` list form (no health gate)

---

## Open Questions

1. **TZ: named zone vs fixed offset?**
   - What we know: Bogota is UTC-5 with no DST since 1993, so `-05:00` ≡ America/Bogota permanently. `--default-time-zone=-05:00` avoids loading tz tables.
   - What's unclear: future requirements (e.g. Phase 5 reservations) may want MySQL named-zone semantics for `CONVERT_TZ`.
   - Recommendation: **Use `-05:00` + `TZ=America/Bogota` for Phase 1.** Document the equivalence. Revisit in Phase 3 if domain logic needs named-zone functions. LOW risk.

2. **Alembic init now vs Phase 3?**
   - Recommendation: **Defer to Phase 3.** No models exist; an Alembic setup with empty migrations adds dead files and a `CMD alembic upgrade head` that crashes. Phase 1's DB is the empty `gri` DB created by `MYSQL_DATABASE`. Phase 3 will scaffold Alembic + the async env.py (pattern provided above) and edit the Dockerfile CMD. This matches ROADMAP (INFR-03 migrations is Phase 3).

3. **Single repo vs `backend/` subfolder for `docker-compose.yml`?**
   - Recommendation: **Root-level `docker-compose.yml`**, `Dockerfile` inside `backend/`. Root-level matches the Ubuntu Server deploy layout (Phase 9) and keeps the `mysql` + `api` pair visible together. Compose `build: ./backend`.

4. **Do we need `DEMO_MODE` now if it's inert?**
   - Recommendation: **Add it to `config.py` (cheap), wire it through compose env, but make it do nothing.** Phase 3 reads it to seed the demo restaurant. Defining it now means the `.env.example` and compose env are stable from day one — no Phase 3 env-shape changes.

---

## Validation Architecture

> `workflow.nyquist_validation` is absent in `.planning/config.json` → treated as **enabled**.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | **pytest 8.x + pytest-asyncio 0.24+ + httpx 0.28+** (Wave 0 install) |
| Config file | `backend/pyproject.toml` `[tool.pytest.ini_options]` (asyncio_mode="auto") |
| Quick run command | `cd backend && uv run pytest tests/ -x` |
| Full suite command | `cd backend && uv run pytest tests/ -v` |

Phase 1 is an **infrastructure** phase — its primary verification is operational (`docker compose up` → `/health` 200 → restart → data persists). Automated tests are lightweight smoke tests against a running stack, not pure unit tests. Manual verification script (`Code Examples`) is the acceptance gate.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFR-02 | `/health` returns 200 `{database: connected}` when API↔DB wired | smoke (httpx vs running API) | `cd backend && uv run pytest tests/test_health.py -x` | ❌ Wave 0 |
| INFR-01 | charset=utf8mb4, collation=utf8mb4_unicode_ci, tz=-05:00 via query | integration (mysql client vs running mysql) | `cd backend && uv run pytest tests/test_db_config.py -x` | ❌ Wave 0 |
| INFR-01 | accented + 4-byte (emoji) string round-trips intact | integration | covered by `test_db_config.py` | ❌ Wave 0 |
| INFR-01 | data survives container restart | **manual** (compose orchestration, slow, not <30s) | run `verify_infra.sh` step 3 manually | n/a — manual |
| INFR-02 | changing `.env` changes connection (DB_NAME mismatch → 503) | **manual** (requires compose re-up) | run `verify_infra.sh` step 4 manually | n/a — manual |

### Sampling Rate
- **Per task commit:** `cd backend && uv run pytest tests/ -x` (fast smoke once infra is up)
- **Per wave merge:** `docker compose up -d --build && sleep 30 && curl :8000/health` + full pytest
- **Phase gate:** Manual verification script (charset/TZ/persistence/env-swap) all green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/tests/conftest.py` — httpx `AsyncClient` fixture pointing at `http://localhost:8000` (assumes stack running); optional mysql fixture for `test_db_config.py`
- [ ] `backend/tests/test_health.py` — `GET /health` asserts 200 + `"database":"connected"` (covers INFR-02)
- [ ] `backend/tests/test_db_config.py` — connects via asyncmy, asserts `@@character_set_database='utf8mb4'`, `@@global.time_zone='-05:00'`, round-trips `'Açaí 🍜'` (covers INFR-01 charset/TZ)
- [ ] Framework install: `uv add --dev pytest pytest-asyncio httpx` (no test infra exists yet)
- [ ] `backend/scripts/verify_infra.sh` — the manual acceptance script (persistence + env-swap tests live here)

---

## Sources

### Primary (HIGH confidence)
- **pypi.org/project/asyncmy** — 0.2.14 released Aug 12 2026; **download files confirm `cp312 manylinux2014_x86_64 / 2_17 / 2_28` wheels exist** (no compilation needed on `python:3.12-slim`). Also musllinux, macOS, win wheels. Verified directly this session.
- **docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html** — confirms `create_async_engine`, `async_sessionmaker`, `AsyncSession`, `run_sync()`, greenlet requirement; release 2.0.52 dated Aug 11 2026.
- **docs.astral.sh/uv/guides/integration/docker/** — official uv Docker pattern: `COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/`, intermediate-layer `uv sync --locked --no-install-project`, `UV_COMPILE_BYTECODE`, cache mounts; updated Aug 7 2026 (uv 0.12.x current).
- **.planning/research/STACK.md** — versions verified against PyPI Aug 2026 (FastAPI 0.141.1, uvicorn 0.52.2, SQLAlchemy 2.0.52, asyncmy 0.2.14, MySQL 8.4 LTS, Python 3.12).
- **.planning/research/PITFALLS.md** — MySQL Docker volume/charset/TZ pitfalls, utf8mb4 vs utf8 (3-byte), `docker rm` data-loss risk.

### Secondary (MEDIUM confidence)
- **MySQL 8.4 `--default-authentication-plugin` removal** — training data (MySQL 8.0.27 deprecation → 8.4 removal; replaced by `authentication_policy`). dev.mysql.com returned HTTP 403 to the fetcher, so NOT re-verified against live docs this session. **Implementation task MUST confirm** by `docker compose up mysql` starting cleanly without the flag. Confidence in the claim itself: HIGH (widely documented migration item); confidence that live docs agree without re-check: MEDIUM.

### Tertiary (LOW confidence)
- TZ `-05:00` ≡ America/Bogota permanently — Bogota has observed no DST since 1993 (training data / IANA tzdata). Adequate for v1; revisit if Phase 5 reservation logic needs `CONVERT_TZ` with named zones.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — all versions verified against PyPI/docs Aug 2026.
- Architecture (compose, Dockerfile, FastAPI layout): **HIGH** — official patterns (uv Docker guide, SQLAlchemy asyncio docs, Compose healthcheck semantics).
- Pitfalls: **HIGH** for asyncmy-wheels (PyPI files verified), compose healthcheck/depends_on, expire_on_commit, `.dockerignore` (uv docs); **MEDIUM** for the MySQL 8.4 auth-plugin removal (training-verified, live-doc fetch blocked by 403 — flag for implementation check).

**Research date:** 2026-08-13
**Valid until:** 2026-09-13 (stable infra stack; re-check uv/FastAPI/asyncmy patch versions if Phase 1 starts later)
