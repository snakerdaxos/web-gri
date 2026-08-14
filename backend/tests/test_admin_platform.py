"""PLAT-02 + PLAT-03 integration tests — super-admin platform management.

Precondition: the Docker stack is running (`docker compose up -d`), the Alembic
migration is applied (the Dockerfile CMD does this on boot), and the bootstrap
super-admin exists with the email/password configured in `.env`
(SUPER_ADMIN_EMAIL/PASSWORD). The `super_admin_token` fixture logs in via the
public API, so the email must pass EmailStr validation (a real/resolvable TLD,
not `.local`).

Covers:
  - PLAT-02: POST /admin/restaurantes (create with all fields)
  - PLAT-02: GET  /admin/restaurantes (list, at least the ones created here)
  - PLAT-03: POST /admin/restaurantes/{id}/staff (happy + invalid role + missing FK)
  - Regression: created staff can log in (hash stored correctly)
"""

from uuid import uuid4

import pytest
from sqlalchemy import delete

from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

from .conftest import auth_header, login, login_staff_demo, register_cliente

pytestmark = pytest.mark.asyncio


def _unique_suffix() -> str:
    """Random suffix so parallel runs / re-runs don't collide on unique fields."""
    return uuid4().hex[:8]


async def _create_restaurante(client, sa_token: str, nombre: str | None = None) -> dict:
    """Helper: POST /admin/restaurantes with the given name; return the JSON body."""
    if nombre is None:
        nombre = f"Rest-{_unique_suffix()}"
    body = {
        "nombre": nombre,
        "descripcion": "Pop-up de prueba",
        "tipo_cocina": "Fusion",
        "direccion": f"Calle Test {_unique_suffix()}",
    }
    resp = await client.post(
        "/admin/restaurantes", json=body, headers=auth_header(sa_token)
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


# --- PLAT-02 -----------------------------------------------------------------


async def test_super_admin_creates_restaurante(async_client, super_admin_token):
    """PLAT-02 happy path: 201 with .id and .activo=True."""
    body = await _create_restaurante(async_client, super_admin_token)
    assert body["activo"] is True
    assert isinstance(body["id"], int)
    assert body["id"] > 0


async def test_create_restaurante_fields(async_client, super_admin_token):
    """PLAT-02: all fields persisted (incl. created_at)."""
    nombre = f"Fields-{_unique_suffix()}"
    payload = {
        "nombre": nombre,
        "descripcion": "Una descripción",
        "tipo_cocina": "Italiana",
        "direccion": "Av. Siempre Viva 742",
    }
    resp = await client_post(async_client, "/admin/restaurantes", payload, super_admin_token)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["nombre"] == nombre
    assert data["descripcion"] == "Una descripción"
    assert data["tipo_cocina"] == "Italiana"
    assert data["direccion"] == "Av. Siempre Viva 742"
    assert data["activo"] is True
    # created_at is a server-side default — must be populated and non-empty.
    assert data.get("created_at")


async def test_list_restaurantes(async_client, super_admin_token):
    """PLAT-02 list: after creating 2, GET returns >= 2 active restaurantes."""
    await _create_restaurante(async_client, super_admin_token)
    await _create_restaurante(async_client, super_admin_token)
    resp = await async_client.get(
        "/admin/restaurantes", headers=auth_header(super_admin_token)
    )
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert isinstance(rows, list)
    assert len(rows) >= 2
    # list only returns active ones (decision: super_admin sees active for now).
    assert all(r["activo"] is True for r in rows)


# --- PLAT-03 -----------------------------------------------------------------


async def test_create_staff_assigned(async_client, super_admin_token):
    """PLAT-03 happy: 201 with role + restaurant_id set; NO password_hash."""
    rest = await _create_restaurante(async_client, super_admin_token)
    rid = rest["id"]
    email = f"mesero-{_unique_suffix()}@gri.dev"
    payload = {
        "nombre": "Juan Mesero",
        "email": email,
        "password": "S3cret0!1",
        "role": "mesero",
    }
    resp = await client_post(
        async_client, f"/admin/restaurantes/{rid}/staff", payload, super_admin_token
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["role"] == "mesero"
    assert data["restaurant_id"] == rid
    assert data["email"] == email
    assert "password_hash" not in data  # PITFALL 7


async def test_create_staff_invalid_role_cliente(async_client, super_admin_token):
    """PLAT-03: role='cliente' is rejected (422) — staff-only enum."""
    rest = await _create_restaurante(async_client, super_admin_token)
    rid = rest["id"]
    payload = {
        "nombre": "No Cliente",
        "email": f"cli-{_unique_suffix()}@gri.dev",
        "password": "S3cret0!1",
        "role": "cliente",
    }
    resp = await client_post(
        async_client, f"/admin/restaurantes/{rid}/staff", payload, super_admin_token
    )
    assert resp.status_code == 422, resp.text


async def test_create_staff_invalid_role_super_admin(async_client, super_admin_token):
    """PLAT-03: role='super_admin' rejected too — no privilege escalation via API."""
    rest = await _create_restaurante(async_client, super_admin_token)
    rid = rest["id"]
    payload = {
        "nombre": "No SA",
        "email": f"sa-{_unique_suffix()}@gri.dev",
        "password": "S3cret0!1",
        "role": "super_admin",
    }
    resp = await client_post(
        async_client, f"/admin/restaurantes/{rid}/staff", payload, super_admin_token
    )
    assert resp.status_code == 422, resp.text


async def test_create_staff_missing_restaurante(async_client, super_admin_token):
    """PLAT-03: staff for non-existent restaurante → 404 (not 400, not 422)."""
    payload = {
        "nombre": "Fantasma",
        "email": f"ghost-{_unique_suffix()}@gri.dev",
        "password": "S3cret0!1",
        "role": "mesero",
    }
    resp = await client_post(
        async_client, "/admin/restaurantes/999999/staff", payload, super_admin_token
    )
    assert resp.status_code == 404, resp.text


async def test_staff_login_works(async_client, super_admin_token):
    """Regression: the staff we just created can log in via /auth/login.

    Verifies the password was hashed and stored correctly (PITFALL 8 — the
    service must commit + the hash must round-trip through bcrypt).
    """
    rest = await _create_restaurante(async_client, super_admin_token)
    rid = rest["id"]
    email = f"login-{_unique_suffix()}@gri.dev"
    password = "S3cret0!1"
    payload = {
        "nombre": "Cocina Login",
        "email": email,
        "password": password,
        "role": "cocina",
    }
    resp = await client_post(
        async_client, f"/admin/restaurantes/{rid}/staff", payload, super_admin_token
    )
    assert resp.status_code == 201, resp.text

    access, refresh = await login(async_client, email, password)
    assert access
    assert refresh


async def test_create_staff_duplicate_email(async_client, super_admin_token):
    """PLAT-03: duplicate email (even across restaurante boundaries) → 409."""
    rest = await _create_restaurante(async_client, super_admin_token)
    rid = rest["id"]
    email = f"dup-{_unique_suffix()}@gri.dev"
    payload = {
        "nombre": "Primero",
        "email": email,
        "password": "S3cret0!1",
        "role": "mesero",
    }
    resp1 = await client_post(
        async_client, f"/admin/restaurantes/{rid}/staff", payload, super_admin_token
    )
    assert resp1.status_code == 201, resp1.text

    payload2 = {**payload, "nombre": "Segundo"}
    resp2 = await client_post(
        async_client, f"/admin/restaurantes/{rid}/staff", payload2, super_admin_token
    )
    assert resp2.status_code == 409, resp2.text


# --- PLAT-05: desactivar/reactivar restaurantes (08-02 Task 3) -------------------


async def _create_restaurante_con_staff_b(client, sa_token: str):
    """Restaurante B + su admin (vía /admin) → (rid, staff_email, password).

    El CALLER es dueño del cleanup (reactivar + delete user/restaurante)."""
    sa = auth_header(sa_token)
    r_rest = await client.post(
        "/admin/restaurantes",
        json={"nombre": f"Plat05 {uuid4().hex[:8]}"},
        headers=sa,
    )
    assert r_rest.status_code == 201, r_rest.text
    rid = r_rest.json()["id"]
    staff_email = f"plat05-{uuid4().hex[:8]}@gri.dev"
    password = "S3cret0!1"
    r_staff = await client.post(
        f"/admin/restaurantes/{rid}/staff",
        json={
            "nombre": "Admin Plat05",
            "email": staff_email,
            "password": password,
            "role": "admin_restaurante",
        },
        headers=sa,
    )
    assert r_staff.status_code == 201, r_staff.text
    return rid, staff_email, password


async def test_plat05_desactivar_oculta_y_reactivar(
    async_client, db_session, super_admin_token
):
    """Flujo completo PLAT-05: PATCH {activo: false} (super_admin) → 200;
    desaparece de /public (lista y detalle 404) y del listado activo del
    super-admin; ?incluir_inactivos=true lo revela; super_admin NO puede
    operarlo vía /staff (404 _resolve_rid); el staff B con token vigente
    SIGUE operando (alcance v1 — NO se bloquea; bloqueo operacional = PLT2
    futuro); PATCH {activo: true} reactiva. finally restaura SIEMPRE."""
    rid, staff_email, password = await _create_restaurante_con_staff_b(
        async_client, super_admin_token
    )
    sa = auth_header(super_admin_token)
    try:
        off = await async_client.patch(
            f"/admin/restaurantes/{rid}", json={"activo": False}, headers=sa
        )
        assert off.status_code == 200, off.text
        assert off.json()["activo"] is False
        assert off.json()["id"] == rid

        # Desaparece de /public (filtro activo ya existente — sin tocar
        # public_service).
        lista_pub = await async_client.get("/public/restaurantes")
        assert rid not in {r["id"] for r in lista_pub.json()}
        detalle = await async_client.get(f"/public/restaurantes/{rid}")
        assert detalle.status_code == 404, detalle.text

        # Listado activo del super-admin NO lo incluye; con flag SÍ.
        lista_admin = await async_client.get("/admin/restaurantes", headers=sa)
        assert rid not in {r["id"] for r in lista_admin.json()}
        lista_all = await async_client.get(
            "/admin/restaurantes", params={"incluir_inactivos": True}, headers=sa
        )
        assert rid in {r["id"] for r in lista_all.json()}
        row = next(r for r in lista_all.json() if r["id"] == rid)
        assert row["activo"] is False

        # super_admin NO puede operar el inactivo vía /staff (404 _resolve_rid
        # existente — comportamiento no tocado por este plan).
        mesas_sa = await async_client.get(
            "/staff/mesas", params={"restaurante_id": rid}, headers=sa
        )
        assert mesas_sa.status_code == 404, mesas_sa.text

        # Staff B con token vigente SIGUE operando (alcance v1 EXACTO).
        token_b, _ = await login(async_client, staff_email, password)
        mesas_b = await async_client.get(
            "/staff/mesas", headers=auth_header(token_b)
        )
        assert mesas_b.status_code == 200, (
            "decisión v1: el staff del restaurante inactivo NO se bloquea — "
            f"recibido {mesas_b.status_code}: {mesas_b.text}"
        )

        # Reactivar restaura visibilidad pública.
        on = await async_client.patch(
            f"/admin/restaurantes/{rid}", json={"activo": True}, headers=sa
        )
        assert on.status_code == 200, on.text
        assert on.json()["activo"] is True
        pub_after = await async_client.get(f"/public/restaurantes/{rid}")
        assert pub_after.status_code == 200, pub_after.text
    finally:
        # Invariant SIEMPRE (aunque el test falle a mitad): reactivar antes
        # del cleanup para no dejar un inactivo eterno en la BD.
        await async_client.patch(
            f"/admin/restaurantes/{rid}", json={"activo": True}, headers=sa
        )
        await db_session.rollback()
        await db_session.execute(delete(Usuario).where(Usuario.email == staff_email))
        await db_session.execute(delete(Restaurante).where(Restaurante.id == rid))
        await db_session.commit()


async def test_plat05_patch_guards_403_422_404(async_client, super_admin_token):
    """Matriz de errores del PATCH: admin_restaurante (staff, NO super_admin)
    → 403 (require_roles); body sin ``activo`` → 422; restaurante
    inexistente → 404 (existence hiding). Ningún efecto secundario."""
    sa = auth_header(super_admin_token)
    admin_demo = auth_header(
        await login_staff_demo(async_client, "admin@demo.gri.dev")
    )

    # staff (admin del demo, no super_admin) → 403 JAMÁS desactiva.
    forb = await async_client.patch(
        "/admin/restaurantes/1", json={"activo": False}, headers=admin_demo
    )
    assert forb.status_code == 403, (
        f"staff no super_admin debe ser 403; recibido {forb.status_code}"
    )

    # body sin activo → 422 (RestauranteActivoUpdate exige el campo).
    vacio = await async_client.patch(
        "/admin/restaurantes/1", json={}, headers=sa
    )
    assert vacio.status_code == 422, vacio.text

    # inexistente → 404 (mismo mensaje uniforme).
    ghost = await async_client.patch(
        "/admin/restaurantes/99999999", json={"activo": True}, headers=sa
    )
    assert ghost.status_code == 404, ghost.text


# --- helpers -----------------------------------------------------------------


async def client_post(client, path: str, payload: dict, token: str):
    """POST with Authorization header — keeps the tests concise."""
    return await client.post(path, json=payload, headers=auth_header(token))


# Silence the unused-import warning for `register_cliente` (kept for parity
# with the conftest public API; some future test will use it).
_ = register_cliente
