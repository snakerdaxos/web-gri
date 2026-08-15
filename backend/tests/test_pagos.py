"""Tests PAGO-02 — POST /cliente/pagos/intencion + GET /cliente/pagos/{id}.

Contrato (09-01 Task 2):

- 201 con {pago_id, referencia GRI-PAGO-*, monto (float), estado pendiente,
  checkout_url "/pagos/sandbox/..." en SANDBOX_MODE dev}. El monto SIEMPRE es
  SUM(total de pedidos servido) server-side — el body NO acepta montos.
- 404 sin sesión activa; 409 sesión sin pedidos; 409 pedidos en curso
  (enviado/en_preparacion); rechazado NO bloquea (excluido del total).
- Idempotencia de intención: 2a llamada con pago pendiente → 200 MISMA
  referencia/monto (no crea segundo pago).
- GET estado: propio → 200 con pedido_ids; ajeno → 404 (existence hiding);
  estado rechazado NO toca sesión ni mesa.

Incluye el test unitario del vector de firma de integridad (research
§Contrato Wompi — SHA256 de la concatenación PLANA).

Cleanup: borrar_residuo_pago en cada test (BD compartida — cero filas).
"""

import hashlib
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.core.gateways.wompi_gateway import firma_integridad
from app.models.mesa import Mesa
from app.models.pago import EstadoPago, Pago
from app.models.sesion_mesa import SesionMesa

from .conftest import (
    abrir_sesion_con_pedido_servido,
    auth_header,
    borrar_residuo_pago,
    login,
    login_staff_demo,
    register_cliente,
)

# --- Unit: firma de integridad (vector del research) --------------------------


def test_firma_integridad_vector_conocido():
    """SHA256 plano de referencia+amount_in_cents+currency+secret, sin
    separadores; expiration_time se concatena ANTES del secret."""
    esperado = hashlib.sha256(b"GRI-PAGO-x5000000COPtest-integrity").hexdigest()
    assert (
        firma_integridad("GRI-PAGO-x", 5000000, "COP", "test-integrity") == esperado
    )

    con_exp = hashlib.sha256(
        b"GRI-PAGO-x5000000COP2099-01-01T00:00:00test-integrity"
    ).hexdigest()
    assert (
        firma_integridad(
            "GRI-PAGO-x",
            5000000,
            "COP",
            "test-integrity",
            expiration_time="2099-01-01T00:00:00",
        )
        == con_exp
    )


# --- PAGO-02: intención de pago ------------------------------------------------


@pytest.mark.asyncio
async def test_intencion_201_monto_server_side(async_client, db_session):
    """Sesión con 1 pedido servido → 201; monto == total del pedido (float);
    referencia GRI-PAGO-*; checkout_url relativa /pagos/sandbox/ (dev)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        resp = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["estado"] == "pendiente"
        assert body["monto"] == ctx["total_esperado"]
        assert isinstance(body["monto"], float)
        assert body["referencia"].startswith("GRI-PAGO-")
        assert body["checkout_url"].startswith("/pagos/sandbox/")
        assert ctx["codigo_qr"]  # la cadena es reproducible
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_intencion_suma_todos_los_servidos(async_client, db_session):
    """2 pedidos servidos (2 items c/u) → monto == suma exacta de los 4
    items. El body con un monto maligno se IGNORA (server-side siempre)."""
    ctx = await abrir_sesion_con_pedido_servido(
        async_client, db_session, n_pedidos=2, items_por_pedido=2
    )
    try:
        resp = await async_client.post(
            "/cliente/pagos/intencion",
            json={"monto": 1},  # intento de tampering — debe ignorarse
            headers=ctx["headers"],
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["monto"] == ctx["total_esperado"]
        assert body["monto"] != 1
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_intencion_sin_sesion_404(async_client, db_session):
    """Usuario autenticado SIN sesión activa → 404."""
    usuario = await register_cliente(async_client, nombre="Sin Sesion")
    access, _ = await login(async_client, usuario["email"], usuario["_password"])
    try:
        resp = await async_client.post(
            "/cliente/pagos/intencion", headers=auth_header(access)
        )
        assert resp.status_code == 404, resp.text
    finally:
        await db_session.rollback()


@pytest.mark.asyncio
async def test_intencion_sesion_sin_pedidos_409(async_client, db_session):
    """Sesión abierta pero sin pedidos → 409 "no hay nada que pagar"."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session, n_pedidos=0)
    try:
        resp = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert resp.status_code == 409, resp.text
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_intencion_pedidos_en_curso_409(async_client, db_session):
    """Un pedido servido + otro en enviado/en_preparacion → 409 mientras
    haya pedidos en curso (cocina aún trabaja)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session, n_pedidos=1)
    headers_staff = auth_header(
        await login_staff_demo(async_client, "cocina@demo.gri.dev")
    )
    try:
        # 2o pedido: queda en enviado → 409.
        segundo = await async_client.post(
            "/cliente/pedidos",
            json={
                "sesion_id": ctx["sesion_id"],
                "items": [{"producto_id": ctx["producto_id"], "cantidad": 1}],
            },
            headers=ctx["headers"],
        )
        assert segundo.status_code == 201, segundo.text
        pid2 = segundo.json()["id"]

        resp = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert resp.status_code == 409, resp.text

        # Avanzado a en_preparacion → sigue en curso → 409.
        for estado in ("aceptado", "en_preparacion"):
            rr = await async_client.post(
                f"/staff/pedidos/{pid2}/estado",
                json={"estado": estado},
                headers=headers_staff,
            )
            assert rr.status_code == 200, rr.text
        resp = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert resp.status_code == 409, resp.text
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_intencion_rechazado_excluido(async_client, db_session):
    """1 servido + 1 rechazado → 201 con monto SOLO del servido (rechazado
    excluido del total y NO bloquea el pago)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session, n_pedidos=1)
    headers_staff = auth_header(
        await login_staff_demo(async_client, "cocina@demo.gri.dev")
    )
    try:
        segundo = await async_client.post(
            "/cliente/pedidos",
            json={
                "sesion_id": ctx["sesion_id"],
                "items": [{"producto_id": ctx["producto_id"], "cantidad": 1}],
            },
            headers=ctx["headers"],
        )
        assert segundo.status_code == 201, segundo.text
        pid2 = segundo.json()["id"]
        rr = await async_client.post(
            f"/staff/pedidos/{pid2}/estado",
            json={"estado": "rechazado"},
            headers=headers_staff,
        )
        assert rr.status_code == 200, rr.text

        resp = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert resp.status_code == 201, resp.text
        assert resp.json()["monto"] == ctx["total_esperado"]
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_intencion_idempotente_200(async_client, db_session):
    """2a llamada con pago pendiente existente → 200 con MISMA
    referencia/monto/pago_id; exactamente 1 fila pago en la sesión."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        primero = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert primero.status_code == 201, primero.text
        segundo = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert segundo.status_code == 200, segundo.text
        assert segundo.json() == primero.json()

        await db_session.rollback()
        db_session.expire_all()
        n = (
            await db_session.execute(
                select(func.count())
                .select_from(Pago)
                .where(Pago.sesion_id == ctx["sesion_id"])
            )
        ).scalar_one()
        assert n == 1
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- PAGO-02: estado del pago ---------------------------------------------------


@pytest.mark.asyncio
async def test_estado_propio_y_ajeno_404(async_client, db_session):
    """GET propio → estado pendiente + pedido_ids de la sesión; usuario B →
    404 (existence hiding — idéntico a inexistente)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert intencion.status_code == 201, intencion.text
        pago_id = intencion.json()["pago_id"]

        resp = await async_client.get(
            f"/cliente/pagos/{pago_id}", headers=ctx["headers"]
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["estado"] == "pendiente"
        assert body["pago_id"] == pago_id
        assert body["referencia"] == intencion.json()["referencia"]
        assert body["monto"] == ctx["total_esperado"]
        assert body["pedido_ids"] == ctx["pedido_ids"]

        otro = await register_cliente(async_client, nombre="Ajeno")
        access_b, _ = await login(async_client, otro["email"], otro["_password"])
        resp_b = await async_client.get(
            f"/cliente/pagos/{pago_id}", headers=auth_header(access_b)
        )
        assert resp_b.status_code == 404, resp_b.text
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_estado_rechazado_no_toca_sesion_ni_mesa(async_client, db_session):
    """Pago en estado rechazado (vía DB-direct): GET lo reporta; la sesión
    sigue activa y la mesa ocupada (el rechazo NO tiene efectos — se reintenta
    con una nueva intención)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        pago_id = intencion.json()["pago_id"]

        await db_session.rollback()
        db_session.expire_all()
        pago = await db_session.get(Pago, pago_id)
        pago.estado = EstadoPago.rechazado
        await db_session.commit()

        resp = await async_client.get(
            f"/cliente/pagos/{pago_id}", headers=ctx["headers"]
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["estado"] == "rechazado"

        await db_session.rollback()
        db_session.expire_all()
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        mesa = await db_session.get(Mesa, ctx["mesa_id"])
        assert sesion.estado == "activa"
        assert sesion.cerrada_en is None
        assert mesa.estado == "ocupada"
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- Referencia única de pago (regresión ligera, PAGO-03) ----------------------


@pytest.mark.asyncio
async def test_referencia_unica_por_pago(async_client, db_session):
    """Cada intención crea una referencia única (uq_pago_referencia): dos
    sesiones distintas → referencias distintas."""
    ctx_a = await abrir_sesion_con_pedido_servido(async_client, db_session)
    ctx_b = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        r_a = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx_a["headers"]
        )
        r_b = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx_b["headers"]
        )
        assert r_a.status_code == 201 and r_b.status_code == 201
        assert r_a.json()["referencia"] != r_b.json()["referencia"]
        assert uuid4().hex  # sanity del import
    finally:
        await borrar_residuo_pago(db_session, ctx_a)
        await borrar_residuo_pago(db_session, ctx_b)
