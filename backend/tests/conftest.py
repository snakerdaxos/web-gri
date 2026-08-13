"""Pytest fixtures + helpers for the GRI API test suite.

The async_client fixture assumes the Docker stack is already running
(`docker compose up -d`). It points at http://localhost:8000 (the published
API port from docker-compose.yml).

Phase 2 additions: auth helpers (register_cliente, login, auth_header) and a
super_admin_token fixture that reads SUPER_ADMIN_* from the environment. Tests
require the stack running with the Alembic migration applied (the Dockerfile
CMD does this on boot) AND SUPER_ADMIN_* set in .env.

Phase 3 additions:
- ``_read_env_var`` helper: shared manual .env parser (host-level), used by
  ``super_admin_token`` and the new ``db_session`` fixture.
- ``db_session`` fixture: asyncmy session DIRECTLY against the Docker MySQL
  (localhost:3306). Enables DB-direct tests of constraints/seed/state-machines
  without going through HTTP endpoints (which don't exist for domain entities
  until Phase 4-6).
"""

import os
from collections.abc import AsyncGenerator
from pathlib import Path
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

API_BASE = "http://localhost:8000"


# --- Phase 3: shared .env parser -----------------------------------------


def _read_env_var(key: str) -> str | None:
    """Read a single var from the host-level ``.env`` (project root).

    The test process does not auto-load ``.env``; this mirrors the same manual
    parse that ``super_admin_token`` used inline in Phase 2, now extracted so
    ``db_session`` can reuse it for DB credentials. Returns the raw value or
    None if absent.
    """
    cached = os.environ.get(key)
    if cached:
        return cached
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1]
    return None


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    """Yield an httpx AsyncClient pointing at the running API container."""
    async with httpx.AsyncClient(base_url=API_BASE) as client:
        yield client


# --- Phase 2: auth helpers ------------------------------------------------


async def register_cliente(
    client: httpx.AsyncClient,
    *,
    email: str | None = None,
    password: str = "S3cret0!",
    nombre: str = "Test User",
) -> dict:
    """POST /auth/register with a unique email by default; return the JSON body."""
    if email is None:
        email = f"test-{uuid4().hex[:8]}@x.com"
    resp = await client.post(
        "/auth/register",
        json={"nombre": nombre, "email": email, "password": password},
    )
    resp.raise_for_status()
    body = resp.json()
    body["_password"] = password  # carry back for subsequent login
    return body


async def login(
    client: httpx.AsyncClient, email: str, password: str
) -> tuple[str, str]:
    """POST /auth/login; return (access_token, refresh_token)."""
    resp = await client.post(
        "/auth/login", json={"email": email, "password": password}
    )
    resp.raise_for_status()
    data = resp.json()
    return data["access_token"], data["refresh_token"]


def auth_header(token: str) -> dict[str, str]:
    """Build the Authorization header dict for a Bearer token."""
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def super_admin_token(async_client: httpx.AsyncClient) -> str:
    """Login as the bootstrap super-admin; skip if SUPER_ADMIN_* unset."""
    email = _read_env_var("SUPER_ADMIN_EMAIL")
    password = _read_env_var("SUPER_ADMIN_PASSWORD")
    if not email or not password:
        pytest.skip("SUPER_ADMIN_* not configured")
    access, _ = await login(async_client, email, password)
    return access


# --- Phase 3: DB-direct fixture ------------------------------------------


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Sesión asyncmy DIRECTA a la BD del stack Docker.

    Para tests de dominio sin endpoints: constraints, seed, enums. Requiere el
    stack corriendo (igual que ``async_client``).

    Usa ``settings.database_url`` que resuelve el host correcto según el entorno
    (``mysql`` dentro del contenedor via DB_HOST, ``localhost`` en el host via
    puerto publicado). Hereda el patrón anti-MissingGreenlet de Phase 1 con
    ``expire_on_commit=False``.
    """
    from app.core.config import settings

    engine = create_async_engine(settings.database_url)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


# Keep pytest happy with the plugin import (silences unused-import on strict linters).
_ = pytest
