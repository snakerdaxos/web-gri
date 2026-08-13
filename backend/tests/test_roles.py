"""AUTH-03 role-enforcement integration tests.

The 5 roles are distinguishable and every admin endpoint rejects unauthorized
callers: a cliente gets 403, a missing token gets 401, a garbage token gets 401.

Precondition: the Docker stack is running with the admin endpoints from Task 1
(POST /admin/restaurantes etc. exist). These tests assume that infrastructure —
they validate the ENFORCEMENT semantics, not the endpoints' happy paths (those
live in test_admin_platform.py).
"""

import pytest

from .conftest import auth_header, login, register_cliente

pytestmark = pytest.mark.asyncio

INVALID_TOKEN = "not.a.real.token"


async def _cliente_token(client) -> str:
    """Register a fresh cliente and return its access token."""
    body = await register_cliente(client)
    access, _ = await login(client, body["email"], body["_password"])
    return access


# --- cliente is rejected on every admin endpoint (403) ------------------------


async def test_cliente_cannot_create_restaurante(async_client):
    """AUTH-03: cliente token on POST /admin/restaurantes -> 403 (not 401, not 201)."""
    token = await _cliente_token(async_client)
    resp = await async_client.post(
        "/admin/restaurantes",
        json={"nombre": "Restaurante de Ana"},
        headers=auth_header(token),
    )
    assert resp.status_code == 403, resp.text


async def test_cliente_cannot_list_restaurantes(async_client):
    """AUTH-03: cliente token on GET /admin/restaurantes -> 403."""
    token = await _cliente_token(async_client)
    resp = await async_client.get("/admin/restaurantes", headers=auth_header(token))
    assert resp.status_code == 403, resp.text


async def test_cliente_cannot_create_staff(async_client):
    """AUTH-03: cliente token on POST /admin/restaurantes/{id}/staff -> 403.

    Uses a non-existent restaurante id on purpose: the require_roles dependency
    resolves BEFORE the handler runs, so the 403 must win regardless of whether
    the FK target exists (role checks never leak resource existence).
    """
    token = await _cliente_token(async_client)
    resp = await async_client.post(
        "/admin/restaurantes/999999/staff",
        json={
            "nombre": "Infiltrado",
            "email": "infiltrado-x@x.com",
            "password": "S3cret0!1",
            "role": "mesero",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 403, resp.text


# --- no token / garbage token -> 401 -------------------------------------------


async def test_no_token_admin(async_client):
    """No Authorization header on POST /admin/restaurantes -> 401."""
    resp = await async_client.post("/admin/restaurantes", json={"nombre": "X"})
    assert resp.status_code == 401, resp.text


async def test_no_token_get_restaurante(async_client):
    """No Authorization header on GET /admin/restaurantes/{id} -> 401."""
    resp = await async_client.get("/admin/restaurantes/1")
    assert resp.status_code == 401, resp.text


async def test_invalid_token_admin(async_client):
    """A syntactically-garbage Bearer token -> 401 (signature check fails)."""
    resp = await async_client.post(
        "/admin/restaurantes",
        json={"nombre": "X"},
        headers=auth_header(INVALID_TOKEN),
    )
    assert resp.status_code == 401, resp.text
