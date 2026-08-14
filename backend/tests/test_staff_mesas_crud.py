"""Tests MESA-01 — POST /staff/mesas + PATCH /staff/mesas/{id} (plan 08-02 T1).

Contrato (QR determinista, Pattern 1 del research — locked):

- POST /staff/mesas {numero, capacidad} → 201 con ``codigo_qr`` derivado
  ``GRI-MESA-R{rid}-{numero:03d}`` (≈22 chars, cabe en String(32)) y estado
  ``disponible``. Cero intervención humana: el QR NUNCA viene del cliente.
- 409 numero duplicado en el tenant (pre-check amigable + IntegrityError
  safety net — la constraint uq_mesa_restaurante_numero es la autoridad).
- PATCH {capacidad} → 200 SIN tocar codigo_qr; PATCH {numero} → 200 con QR
  REGENERADO al nuevo número (Pitfall 6: el QR impreso anterior queda
  obsoleto — el form del panel advierte).
- PATCH a numero ya existente → 409; PATCH {} → 422; PATCH mesa ajena →
  404 (existence hiding cross-tenant, idéntico a inexistente).
- super_admin sin ?restaurante_id= → 400; con param → 201 (contrato
  _resolve_rid). mesero → 403 en ambos writes (require_roles).
- Cross-tenant: B puede crear SU mesa con el MISMO numero de A → QR con
  prefijo R{rid_b} distinto (collision-free por construcción).

Cleanup: delete de las mesas creadas vía db_session por id, en finally
(nested try/finally). N y M únicos por run (derivados de uuid4) para no
chocar con residuo de runs previos.
"""

from uuid import uuid4

import pytest
from sqlalchemy import delete

from app.models.mesa import Mesa
from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

from .conftest import auth_header, login_staff_demo
from .test_staff_menu import create_restaurante_con_staff

_ADMIN_DEMO = "admin@demo.gri.dev"
_MESERO_DEMO = "mesero@demo.gri.dev"


def _numeros_unicos() -> tuple[int, int]:
    """(N, M) únicos por run: N en [100, 8100), M = N + 4000 (separación
    amplia — nunca colisionan entre sí ni con el seed 1-8)."""
    n = 100 + (uuid4().int % 8_000)
    return n, n + 4_000


async def _delete_mesas(db_session, *mesa_ids: int | None) -> None:
    """Borra las mesas de test por id (sin pedidos → FK libre)."""
    await db_session.rollback()
    for mid in mesa_ids:
        if mid is not None:
            await db_session.execute(delete(Mesa).where(Mesa.id == mid))
    await db_session.commit()


async def _post_mesa(async_client, headers, numero: int, capacidad: int = 4, params: dict | None = None):
    return await async_client.post(
        "/staff/mesas",
        json={"numero": numero, "capacidad": capacidad},
        params=params,
        headers=headers,
    )


# --- POST: QR determinista + duplicado 409 --------------------------------------


@pytest.mark.asyncio
async def test_post_mesa_qr_determinista_y_dup_409(async_client, db_session):
    """201 con codigo_qr == GRI-MESA-R1-{N:03d} y estado disponible; POST
    duplicado del mismo numero → 409 SIN drift (la original sigue intacta)."""
    n, _ = _numeros_unicos()
    admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
    mesa_id: int | None = None
    try:
        resp = await _post_mesa(async_client, admin, n)
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["codigo_qr"] == f"GRI-MESA-R1-{n:03d}", (
            f"QR determinista esperado GRI-MESA-R1-{n:03d}; "
            f"recibido {body['codigo_qr']}"
        )
        assert body["estado"] == "disponible"
        assert body["numero"] == n
        assert body["capacidad"] == 4
        mesa_id = body["id"]

        dup = await _post_mesa(async_client, admin, n, capacidad=2)
        assert dup.status_code == 409, (
            f"numero duplicado debe ser 409; recibido {dup.status_code}: {dup.text}"
        )
        # Sin drift: la mesa original sigue con su QR y capacidad.
        orig = await async_client.get("/staff/mesas", headers=admin)
        row = next(m for m in orig.json() if m["id"] == mesa_id)
        assert row["codigo_qr"] == f"GRI-MESA-R1-{n:03d}"
        assert row["capacidad"] == 4
    finally:
        await _delete_mesas(db_session, mesa_id)


# --- PATCH: capacidad no toca QR; numero REGENERA QR -----------------------------


@pytest.mark.asyncio
async def test_patch_capacidad_mantiene_qr_y_numero_regenera(async_client, db_session):
    """Pitfall 6: PATCH {capacidad} → 200 SIN cambios en QR; PATCH {numero}
    → 200 con QR == GRI-MESA-R1-{M:03d} (regenerado — el impreso anterior
    queda obsoleto)."""
    n, m = _numeros_unicos()
    admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
    mesa_id: int | None = None
    try:
        created = await _post_mesa(async_client, admin, n)
        assert created.status_code == 201, created.text
        mesa_id = created.json()["id"]
        qr_original = created.json()["codigo_qr"]
        assert qr_original == f"GRI-MESA-R1-{n:03d}"

        # capacidad: QR intacto
        r_cap = await async_client.patch(
            f"/staff/mesas/{mesa_id}", json={"capacidad": 6}, headers=admin
        )
        assert r_cap.status_code == 200, r_cap.text
        assert r_cap.json()["capacidad"] == 6
        assert r_cap.json()["codigo_qr"] == qr_original, (
            "cambiar capacidad NO debe regenerar el QR"
        )
        assert r_cap.json()["numero"] == n

        # numero: QR regenerado al nuevo número
        r_num = await async_client.patch(
            f"/staff/mesas/{mesa_id}", json={"numero": m}, headers=admin
        )
        assert r_num.status_code == 200, r_num.text
        assert r_num.json()["codigo_qr"] == f"GRI-MESA-R1-{m:03d}", (
            f"PATCH numero debe regenerar el QR a GRI-MESA-R1-{m:03d}; "
            f"recibido {r_num.json()['codigo_qr']}"
        )
        assert r_num.json()["numero"] == m
        assert r_num.json()["capacidad"] == 6, "capacidad persiste entre PATCHes"
    finally:
        await _delete_mesas(db_session, mesa_id)


@pytest.mark.asyncio
async def test_patch_numero_duplicado_409(async_client, db_session):
    """PATCH a un numero que YA existe en el tenant → 409 (uq constraint);
    sin drift: la mesa queda con su numero original."""
    n, m = _numeros_unicos()
    admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
    id_a: int | None = None
    id_b: int | None = None
    try:
        ra = await _post_mesa(async_client, admin, n)
        rb = await _post_mesa(async_client, admin, m)
        assert ra.status_code == 201 and rb.status_code == 201, (ra.text, rb.text)
        id_a, id_b = ra.json()["id"], rb.json()["id"]

        clash = await async_client.patch(
            f"/staff/mesas/{id_b}", json={"numero": n}, headers=admin
        )
        assert clash.status_code == 409, (
            f"PATCH a numero existente debe ser 409; recibido {clash.status_code}"
        )
        # Sin drift: B sigue con su numero/QR originales.
        mesas = await async_client.get("/staff/mesas", headers=admin)
        row_b = next(x for x in mesas.json() if x["id"] == id_b)
        assert row_b["numero"] == m
        assert row_b["codigo_qr"] == f"GRI-MESA-R1-{m:03d}"
    finally:
        await _delete_mesas(db_session, id_a, id_b)


# --- PATCH: body vacío 422 + unknown id 404 -------------------------------------


@pytest.mark.asyncio
async def test_patch_body_vacio_422_y_unknown_404(async_client, db_session):
    """PATCH {} (sin campos) → 422 "Nada que actualizar"; PATCH a id
    inexistente → 404 (existence hiding)."""
    n, _ = _numeros_unicos()
    admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
    mesa_id: int | None = None
    try:
        created = await _post_mesa(async_client, admin, n)
        assert created.status_code == 201, created.text
        mesa_id = created.json()["id"]

        vacio = await async_client.patch(
            f"/staff/mesas/{mesa_id}", json={}, headers=admin
        )
        assert vacio.status_code == 422, (
            f"body vacío debe ser 422; recibido {vacio.status_code}: {vacio.text}"
        )

        unknown = await async_client.patch(
            "/staff/mesas/999999999", json={"capacidad": 2}, headers=admin
        )
        assert unknown.status_code == 404, unknown.text
    finally:
        await _delete_mesas(db_session, mesa_id)


# --- Cross-tenant: 404 existence hiding + QR collision-free ----------------------


@pytest.mark.asyncio
async def test_cross_tenant_patch_404_y_qr_collision_free(
    async_client, db_session, super_admin_token
):
    """Mesa del tenant 1 patcheada por staff B → 404 (idéntico a inexistente,
    NUNCA 403). B puede crear SU mesa con el MISMO numero → QR con prefijo
    R{rid_b} distinto (collision-free por construcción: uq_mesa_codigo_qr
    global jamás se viola porque rid distinto ⇒ prefijo distinto)."""
    n, _ = _numeros_unicos()
    admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
    rid_b, token_b, email_b = await create_restaurante_con_staff(
        async_client, super_admin_token, "Cross Mesas CRUD"
    )
    headers_b = auth_header(token_b)
    id_a: int | None = None
    id_b: int | None = None
    try:
        created = await _post_mesa(async_client, admin, n)
        assert created.status_code == 201, created.text
        id_a = created.json()["id"]

        # staff B NO puede patchear la mesa de A → 404 existence hiding.
        r_patch = await async_client.patch(
            f"/staff/mesas/{id_a}", json={"capacidad": 9}, headers=headers_b
        )
        assert r_patch.status_code == 404, (
            f"mesa ajena debe ser 404 (existence hiding, nunca 403); "
            f"recibido {r_patch.status_code}: {r_patch.text}"
        )

        # B crea SU mesa con el MISMO numero → 201 con QR del tenant B.
        r_post_b = await _post_mesa(async_client, headers_b, n)
        assert r_post_b.status_code == 201, r_post_b.text
        assert r_post_b.json()["codigo_qr"] == f"GRI-MESA-R{rid_b}-{n:03d}", (
            "el QR del tenant B lleva SU rid — mismo numero, QR distinto"
        )
        id_b = r_post_b.json()["id"]
    finally:
        await _delete_mesas(db_session, id_a, id_b)
        await db_session.rollback()
        await db_session.execute(delete(Usuario).where(Usuario.email == email_b))
        await db_session.execute(
            delete(Restaurante).where(Restaurante.id == rid_b)
        )
        await db_session.commit()


# --- Contrato super_admin + mesero 403 -------------------------------------------


@pytest.mark.asyncio
async def test_super_admin_contrato_post(async_client, db_session, super_admin_token):
    """super_admin: POST sin ?restaurante_id= → 400; con ?restaurante_id=1
    → 201 con QR del rid indicado (contrato _resolve_rid)."""
    n, _ = _numeros_unicos()
    sa = auth_header(super_admin_token)
    mesa_id: int | None = None
    try:
        sin = await _post_mesa(async_client, sa, n)
        assert sin.status_code == 400, (
            f"super_admin sin param debe ser 400; recibido {sin.status_code}"
        )

        con = await _post_mesa(async_client, sa, n, params={"restaurante_id": 1})
        assert con.status_code == 201, con.text
        assert con.json()["codigo_qr"] == f"GRI-MESA-R1-{n:03d}"
        mesa_id = con.json()["id"]
    finally:
        await _delete_mesas(db_session, mesa_id)


@pytest.mark.asyncio
async def test_mesero_403_post_y_patch(async_client):
    """require_roles(admin_restaurante, super_admin): mesero → 403 en POST y
    PATCH (la dependencia corre ANTES del service — 403 aunque la mesa no
    exista)."""
    mesero = auth_header(await login_staff_demo(async_client, _MESERO_DEMO))
    post = await _post_mesa(async_client, mesero, 4242)
    assert post.status_code == 403, (
        f"mesero debe recibir 403 en POST; recibido {post.status_code}"
    )
    patch = await async_client.patch(
        "/staff/mesas/1", json={"capacidad": 2}, headers=mesero
    )
    assert patch.status_code == 403, (
        f"mesero debe recibir 403 en PATCH; recibido {patch.status_code}"
    )
