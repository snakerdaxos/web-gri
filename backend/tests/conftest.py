"""Pytest fixtures + helpers for the GRI API test suite.

The async_client fixture assumes the Docker stack is already running
(`docker compose up -d`). It points at http://localhost:8000 (the published
API port from docker-compose.yml).

Phase 2 additions: auth helpers (register_cliente, login, auth_header) and a
super_admin_token fixture that reads SUPER_ADMIN_* from the environment. Tests
require the stack running with the Alembic migration applied (the Dockerfile
CMD does this on boot) AND SUPER_ADMIN_* set in .env.
"""

from collections.abc import AsyncGenerator
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio

API_BASE = "http://localhost:8000"


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
    import os

    email = os.environ.get("SUPER_ADMIN_EMAIL")
    password = os.environ.get("SUPER_ADMIN_PASSWORD")
    # .env on the host isn't auto-loaded into the test process; read it manually
    # so tests work whether or not the dev exported the vars.
    if not email or not password:
        from pathlib import Path

        env_path = Path(__file__).resolve().parents[2] / ".env"
        if env_path.exists():
            for line in env_path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line.startswith("SUPER_ADMIN_EMAIL="):
                    email = line.split("=", 1)[1]
                elif line.startswith("SUPER_ADMIN_PASSWORD="):
                    password = line.split("=", 1)[1]
    if not email or not password:
        pytest.skip("SUPER_ADMIN_* not configured")
    access, _ = await login(async_client, email, password)
    return access


# Keep pytest happy with the plugin import (silences unused-import on strict linters).
_ = pytest
