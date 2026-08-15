"""Tests e2e del checkout sandbox (PAGO-02/03/04 — 09-01 Task 3).

El sandbox NO es un mock del handler: POST /pagos/sandbox/{ref}/aprobar
construye el evento transaction.updated COMPLETO firmado con
WOMPI_EVENTS_SECRET y pasa por el MISMO pipeline del webhook público.

- e2e aprobar: intención → checkout HTML → aprobar (303) → estado aprobado
  + efectos completos en BD (pedidos pagado, sesión cerrada_en, mesa
  limpieza, transaction_id sandbox-*).
- e2e rechazar: pago rechazado, mesa ocupada, sesión activa.
- SANDBOX_MODE=false (in-process, monkeypatch del guard por-request) →
  rutas sandbox 404 sin reiniciar el stack.
"""

import pytest
from sqlalchemy import select

import app.main as main_module
from app.core.config import settings
from app.models.mesa import Mesa
from app.models.pago import EstadoPago, Pago
from app.models.pedido import Pedido
from app.models.sesion_mesa import SesionMesa

from .conftest import abrir_sesion_con_pedido_servido, borrar_residuo_pago

_JOIN_SETTLE = 0.2  # no usado aquí, documentado para futuros asserts WS


def _monto_cop(monto) -> str:
    """Formato COP: $32.000 (punto de miles)."""
    return f"${int(monto):,}".replace(",", ".")


async def _intencion(async_client, headers) -> dict:
    resp = await async_client.post("/cliente/pagos/intencion", headers=headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


async def _refresco(db_session, ctx) -> tuple[Pago, SesionMesa, Mesa, list[Pedido]]:
    await db_session.rollback()
    db_session.expire_all()
    pago = (
        await db_session.execute(
            select(Pago).where(Pago.sesion_id == ctx["sesion_id"])
        )
    ).scalar_one()
    sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
    mesa = await db_session.get(Mesa, ctx["mesa_id"])
    pedidos = (
        (
            await db_session.execute(
                select(Pedido).where(Pedido.sesion_id == ctx["sesion_id"])
            )
        )
        .scalars()
        .all()
    )
    return pago, sesion, mesa, pedidos


# --- e2e aprobar: ciclo completo ------------------------------------------------


@pytest.mark.asyncio
async def test_e2e_sandbox_aprobar(async_client, db_session):
    """intención → checkout HTML (referencia + monto + forms) → aprobar →
    redirect → estado aprobado; BD: pedidos pagado, sesión cerrada con
    cerrada_en, mesa limpieza, transaction_id sandbox-*."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        ref = intencion["referencia"]

        # Checkout HTML: contiene referencia, monto formateado y los forms.
        html = await async_client.get(f"/pagos/sandbox/{ref}")
        assert html.status_code == 200, html.text
        assert "Pago sandbox GRI" in html.text
        assert ref in html.text
        assert _monto_cop(intencion["monto"]) in html.text
        assert f'action="/pagos/sandbox/{ref}/aprobar"' in html.text
        assert f'action="/pagos/sandbox/{ref}/rechazar"' in html.text

        # Aprobar → 303 redirect con resultado.
        post = await async_client.post(f"/pagos/sandbox/{ref}/aprobar")
        assert post.status_code == 303, post.text
        assert "resultado=aprobado" in post.headers["location"]

        # Banner del resultado en el GET de vuelta.
        vuelta = await async_client.get(f"/pagos/sandbox/{ref}?resultado=aprobado")
        assert vuelta.status_code == 200

        # Estado vía API (polling del cliente).
        estado = await async_client.get(
            f"/cliente/pagos/{intencion['pago_id']}", headers=ctx["headers"]
        )
        assert estado.status_code == 200, estado.text
        body = estado.json()
        assert body["estado"] == "aprobado"
        assert body["pedido_ids"] == ctx["pedido_ids"]

        # Efectos atómicos en BD.
        pago, sesion, mesa, pedidos = await _refresco(db_session, ctx)
        assert pago.estado == EstadoPago.aprobado
        assert pago.transaction_id == f"sandbox-{ref}"
        assert sesion.estado == "cerrada"
        assert sesion.cerrada_en is not None
        assert mesa.estado == "limpieza"
        assert all(p.estado == "pagado" for p in pedidos)
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_e2e_sandbox_rechazar(async_client, db_session):
    """Rechazar → redirect resultado=rechazado; pago rechazado, sesión
    activa, mesa ocupada, pedidos servido (sin efectos)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        ref = intencion["referencia"]

        post = await async_client.post(f"/pagos/sandbox/{ref}/rechazar")
        assert post.status_code == 303, post.text
        assert "resultado=rechazado" in post.headers["location"]

        estado = await async_client.get(
            f"/cliente/pagos/{intencion['pago_id']}", headers=ctx["headers"]
        )
        assert estado.status_code == 200, estado.text
        assert estado.json()["estado"] == "rechazado"

        pago, sesion, mesa, pedidos = await _refresco(db_session, ctx)
        assert pago.estado == EstadoPago.rechazado
        assert pago.transaction_id == f"sandbox-{ref}"
        assert sesion.estado == "activa" and sesion.cerrada_en is None
        assert mesa.estado == "ocupada"
        assert all(p.estado == "servido" for p in pedidos)
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_sandbox_post_sobre_no_pendiente_error(async_client, db_session):
    """POST aprobar sobre pago ya aprobado → redirect ?resultado=error (el
    lookup exige estado pendiente); re-POST del dedup NO re-aplica efectos."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        ref = intencion["referencia"]

        primero = await async_client.post(f"/pagos/sandbox/{ref}/aprobar")
        assert primero.status_code == 303
        segundo = await async_client.post(f"/pagos/sandbox/{ref}/aprobar")
        assert segundo.status_code == 303, segundo.text
        assert "resultado=error" in segundo.headers["location"]

        pago, _, _, _ = await _refresco(db_session, ctx)
        assert pago.estado == EstadoPago.aprobado
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_sandbox_checkout_ref_inexistente_404(async_client, db_session):
    """GET checkout de referencia inexistente → 404."""
    resp = await async_client.get("/pagos/sandbox/GRI-PAGO-fantasma")
    assert resp.status_code == 404, resp.text


# --- SANDBOX_MODE=false → 404 (guard por-request, in-process) ---------------------


@pytest.mark.asyncio
async def test_sandbox_mode_false_404(monkeypatch):
    """Con settings.SANDBOX_MODE=False el guard por-request responde 404 en
    TODAS las rutas sandbox — verificado in-process (ASGITransport) sin
    reiniciar el stack."""
    import httpx

    monkeypatch.setattr(settings, "SANDBOX_MODE", False)
    transport = httpx.ASGITransport(app=main_module.app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        r_get = await client.get("/pagos/sandbox/GRI-PAGO-x")
        assert r_get.status_code == 404, r_get.text
        r_post = await client.post("/pagos/sandbox/GRI-PAGO-x/aprobar")
        assert r_post.status_code == 404, r_post.text
        r_rech = await client.post("/pagos/sandbox/GRI-PAGO-x/rechazar")
        assert r_rech.status_code == 404, r_rech.text
