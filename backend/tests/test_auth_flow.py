"""AUTH-01 + AUTH-02 integration tests (register / login / refresh / me).

Requiere stack Docker corriendo con la migración Alembic aplicada (el CMD del
Dockerfile hace `alembic upgrade head`) y SUPER_ADMIN_* en .env (solo para la
fixture super_admin_token; los tests de cliente no la necesitan).

Cobertura del bloque <behavior> de 02-01-PLAN.md.
"""

import httpx
import pytest

from .conftest import auth_header, login, register_cliente

# --- AUTH-01: register ----------------------------------------------------


async def test_register_cliente(async_client: httpx.AsyncClient):
    """POST /auth/register -> 201, role=cliente, restaurant_id=null, no hash."""
    user = await register_cliente(async_client, nombre="Ana")
    assert user["role"] == "cliente"
    assert user["restaurant_id"] is None
    assert user["nombre"] == "Ana"
    assert "email" in user and "@" in user["email"]
    assert "id" in user
    # PITFALL 7: password_hash MUST NOT leak into the response.
    assert "password_hash" not in user
    assert "password" not in user


async def test_register_duplicate_email(async_client: httpx.AsyncClient):
    """Second register with an existing email -> 409."""
    user = await register_cliente(async_client)
    resp = await async_client.post(
        "/auth/register",
        json={
            "nombre": "Otro",
            "email": user["email"],
            "password": "S3cret0!",
        },
    )
    assert resp.status_code == 409


async def test_register_invalid_email(async_client: httpx.AsyncClient):
    """Malformed email -> 422 (Pydantic EmailStr rejection)."""
    resp = await async_client.post(
        "/auth/register",
        json={"nombre": "X", "email": "no-es-un-email", "password": "S3cret0!"},
    )
    assert resp.status_code == 422


async def test_register_short_password(async_client: httpx.AsyncClient):
    """Password shorter than 8 chars -> 422 (PITFALL 5 max_length=64 boundary)."""
    resp = await async_client.post(
        "/auth/register",
        json={"nombre": "X", "email": "u@x.com", "password": "short"},
    )
    assert resp.status_code == 422


# --- AUTH-02: login -------------------------------------------------------


async def test_login_returns_tokens(async_client: httpx.AsyncClient):
    """Valid creds -> 200 with access + refresh + token_type bearer."""
    user = await register_cliente(async_client)
    access, refresh = await login(
        async_client, user["email"], user["_password"]
    )
    assert access and refresh
    assert access != refresh
    resp = await async_client.post(
        "/auth/login",
        json={"email": user["email"], "password": user["_password"]},
    )
    body = resp.json()
    assert body["token_type"] == "bearer"


async def test_login_wrong_password(async_client: httpx.AsyncClient):
    """Wrong password -> 401."""
    user = await register_cliente(async_client)
    resp = await async_client.post(
        "/auth/login",
        json={"email": user["email"], "password": "wrong-password"},
    )
    assert resp.status_code == 401


async def test_login_unknown_user(async_client: httpx.AsyncClient):
    """Non-existent email -> 401 (same shape as wrong password; no enumeration)."""
    resp = await async_client.post(
        "/auth/login",
        json={"email": "does-not-exist-xyz@nowhere.com", "password": "whatever"},
    )
    assert resp.status_code == 401


# --- AUTH-02: refresh -----------------------------------------------------


async def test_refresh_rotates_tokens(async_client: httpx.AsyncClient):
    """Refresh with a valid refresh token -> 200, new pair (different iat)."""
    user = await register_cliente(async_client)
    access, refresh = await login(
        async_client, user["email"], user["_password"]
    )
    resp = await async_client.post(
        "/auth/refresh", json={"refresh_token": refresh}
    )
    assert resp.status_code == 200
    new = resp.json()
    assert new["access_token"] and new["refresh_token"]
    assert new["token_type"] == "bearer"
    # Rotation: the new tokens differ from the originals (different iat/exp).
    assert new["access_token"] != access
    assert new["refresh_token"] != refresh


async def test_refresh_rejects_access_token(async_client: httpx.AsyncClient):
    """PITFALL 6: using an access token as refresh -> 401 (wrong claim type)."""
    user = await register_cliente(async_client)
    access, _ = await login(async_client, user["email"], user["_password"])
    resp = await async_client.post(
        "/auth/refresh", json={"refresh_token": access}
    )
    assert resp.status_code == 401


# --- AUTH-02: /auth/me ----------------------------------------------------


async def test_me_authenticated(async_client: httpx.AsyncClient):
    """GET /auth/me with a valid access token -> 200 with the profile."""
    user = await register_cliente(async_client)
    access, _ = await login(async_client, user["email"], user["_password"])
    resp = await async_client.get("/auth/me", headers=auth_header(access))
    assert resp.status_code == 200
    body = resp.json()
    assert body["email"] == user["email"]
    assert body["role"] == "cliente"
    assert "password_hash" not in body


async def test_me_no_token(async_client: httpx.AsyncClient):
    """GET /auth/me with no Authorization header -> 401."""
    resp = await async_client.get("/auth/me")
    assert resp.status_code == 401


async def test_me_invalid_token(async_client: httpx.AsyncClient):
    """GET /auth/me with a forged/garbage token -> 401."""
    resp = await async_client.get(
        "/auth/me", headers=auth_header("not.a.real.token")
    )
    assert resp.status_code == 401


# Ensure pytest collects this module even if all imports look unused to linters.
_ = pytest
