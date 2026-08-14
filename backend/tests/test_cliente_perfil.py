"""Tests AUTH-05 — /cliente/perfil (GET + PATCH).

Covers:
- PATCH cambia nombre.
- PATCH con password nueva → login con la nueva funciona.
- email immutable: PATCH con email en body → 422 (Pydantic extra="forbid").

Stack debe estar corriendo (docker compose up -d). Cada test registra un
cliente fresco vía ``register_cliente`` para aislar de la BD compartida.
"""

import pytest

from .conftest import auth_header, login, register_cliente


@pytest.mark.asyncio
async def test_get_perfil(async_client):
    """GET /cliente/perfil devuelve el usuario autenticado."""
    cliente = await register_cliente(async_client, nombre="Perfil Cliente")
    access, _ = await login(async_client, cliente["email"], cliente["_password"])
    resp = await async_client.get("/cliente/perfil", headers=auth_header(access))
    assert resp.status_code == 200
    body = resp.json()
    assert body["email"] == cliente["email"]
    assert body["role"] == "cliente"
    assert body["nombre"] == "Perfil Cliente"


@pytest.mark.asyncio
async def test_update_nombre(async_client):
    """PATCH /cliente/perfil cambia solo el nombre."""
    cliente = await register_cliente(async_client, nombre="Antes")
    access, _ = await login(async_client, cliente["email"], cliente["_password"])
    resp = await async_client.patch(
        "/cliente/perfil",
        json={"nombre": "Después"},
        headers=auth_header(access),
    )
    assert resp.status_code == 200
    assert resp.json()["nombre"] == "Después"
    # Idempotencia: otro GET refleja el cambio.
    resp = await async_client.get("/cliente/perfil", headers=auth_header(access))
    assert resp.json()["nombre"] == "Después"


@pytest.mark.asyncio
async def test_update_password(async_client):
    """PATCH con password nueva → relogin con la nueva password funciona;
    con la vieja falla (401)."""
    cliente = await register_cliente(
        async_client, password="S3cret0!", nombre="Cambio Pass"
    )
    access, _ = await login(async_client, cliente["email"], cliente["_password"])

    nueva = "NuevoS3cret0!XYZ"
    resp = await async_client.patch(
        "/cliente/perfil",
        json={"nombre": "Cambio Pass", "password": nueva},
        headers=auth_header(access),
    )
    assert resp.status_code == 200

    # Relogin con la nueva password.
    access2, _ = await login(async_client, cliente["email"], nueva)
    assert access2  # login exitoso

    # Login con la vieja falla.
    resp_old = await async_client.post(
        "/auth/login",
        json={"email": cliente["email"], "password": cliente["_password"]},
    )
    assert resp_old.status_code == 401


@pytest.mark.asyncio
async def test_email_immutable(async_client):
    """PATCH con email en body → 422 (PerfilUpdate tiene extra='forbid')."""
    cliente = await register_cliente(async_client, nombre="Email Block")
    access, _ = await login(async_client, cliente["email"], cliente["_password"])
    resp = await async_client.patch(
        "/cliente/perfil",
        json={"nombre": "Email Block", "email": "nuevo@x.com"},
        headers=auth_header(access),
    )
    assert resp.status_code == 422, (
        f"email debe ser rechazado (immutable); recibido {resp.status_code}: {resp.text}"
    )


@pytest.mark.asyncio
async def test_perfil_requires_cliente_role(async_client, super_admin_token):
    """Pitfall 2 inverso: /cliente/* rechaza staff con 403 (no es cliente)."""
    resp = await async_client.get(
        "/cliente/perfil", headers=auth_header(super_admin_token)
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_perfil_requires_auth(async_client):
    """Sin token → 401 (HTTPBearer auto_error)."""
    resp = await async_client.get("/cliente/perfil")
    assert resp.status_code in (401, 403)
