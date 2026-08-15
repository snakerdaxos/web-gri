"""Tests PAGO-03/04 — POST /webhooks/pago: firma, dedup, fraude, efectos.

Contrato (09-01 Task 3):

- Firma inválida/ausente → 401 con CERO efectos en BD (verificado con
  SELECT, no solo status).
- Dedup at-least-once: mismo evento APPROVED 2 veces → ambas 200,
  exactamente 1 fila pago_event, 1 set de efectos (pago_event.event_key
  UNIQUE + no-op terminal — NUNCA 500, Wompi reintenta ante 5xx).
- APPROVED con amount_in_cents != monto*100 → 200 SIN efectos (alerta de
  fraude en pago_event.estado).
- APPROVED con referencia desconocida → 200 (fila pago_event pago_id NULL).
- PENDING registra transaction_id sin efectos.
- DECLINED/ERROR → pago rechazado sin efectos de sesión/mesa (reintento con
  nueva intención).
- VOIDED post-aprobado → log sin revertir (reembolso manual, v1).

Los eventos se firman con wompi_gateway.firmar_evento y el MISMO
WOMPI_EVENTS_SECRET del stack (leído del .env host con fallback
"dev-events-secret" — el default del compose del Task 1).
"""

import asyncio
import time

import pytest
from sqlalchemy import func, select

from app.core.gateways.wompi_gateway import firmar_evento
from app.models.pago import EstadoPago, Pago
from app.models.pago_event import PagoEvent
from app.models.pedido import Pedido
from app.models.sesion_mesa import SesionMesa

from .conftest import (
    _read_env_var,
    abrir_sesion_con_pedido_servido,
    borrar_residuo_pago,
)


def _events_secret() -> str:
    """MISMO secret con el que firma el stack (compose Task 1)."""
    return _read_env_var("WOMPI_EVENTS_SECRET") or "dev-events-secret"


def _evento(transaccion: dict, secret: str | None = None) -> dict:
    """Evento transaction.updated firmado (pipeline del sandbox y Wompi)."""
    secret = secret or _events_secret()
    timestamp = int(time.time())
    return {
        "event": "transaction.updated",
        "data": {"transaction": transaccion},
        "sent_at": "2026-08-15T00:00:00.000Z",
        "timestamp": timestamp,
        "signature": firmar_evento(transaccion, timestamp, secret),
    }


def _txn(
    pago: Pago,
    status: str = "APPROVED",
    *,
    monto_cents: int | None = None,
    referencia: str | None = None,
    txn_id: str | None = None,
) -> dict:
    return {
        "id": txn_id or f"txn-{pago.referencia}",
        "status": status,
        "amount_in_cents": (
            monto_cents if monto_cents is not None else int(pago.monto * 100)
        ),
        "currency": "COP",
        "reference": referencia or pago.referencia,
    }


async def _pago_fresco(db_session, pago_id: int) -> Pago:
    await db_session.rollback()
    db_session.expire_all()
    return await db_session.get(Pago, pago_id)


async def _intencion(async_client, headers) -> dict:
    resp = await async_client.post("/cliente/pagos/intencion", headers=headers)
    assert resp.status_code == 201, resp.text
    return resp.json()


# --- Firma: primera y única barrera (T-09-01) ----------------------------------


@pytest.mark.asyncio
async def test_firma_invalida_401_cero_efectos(async_client, db_session):
    """Firma incorrecta y payload sin bloque signature → 401; el pago queda
    pendiente y NO se inserta NINGÚN pago_event (cero efectos)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        pago_id = intencion["pago_id"]
        pago = await _pago_fresco(db_session, pago_id)

        mal = _evento(_txn(pago), secret="secreto-equivocado")
        resp = await async_client.post("/webhooks/pago", json=mal)
        assert resp.status_code == 401, resp.text

        sin_firma = _evento(_txn(pago))
        sin_firma.pop("signature")
        resp2 = await async_client.post("/webhooks/pago", json=sin_firma)
        assert resp2.status_code == 401, resp2.text

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.pendiente
        n_eventos = (
            await db_session.execute(
                select(func.count())
                .select_from(PagoEvent)
                .where(
                    PagoEvent.pago_id.in_(
                        select(Pago.id).where(Pago.sesion_id == ctx["sesion_id"])
                    )
                )
            )
        ).scalar_one()
        assert n_eventos == 0, "401 debe dejar CERO filas pago_event"
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- Dedup at-least-once (PAGO-03) ----------------------------------------------


@pytest.mark.asyncio
async def test_dedup_mismo_evento_dos_veces(async_client, db_session):
    """Mismo evento APPROVED 2 veces → ambas 200; 1 sola fila pago_event;
    efectos exactamente 1 vez. Una 3a entrega con txn_id DISTINTO sobre el
    pago terminal → 200 ya-procesado (no-op terminal, NUNCA 500)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        pago_id = intencion["pago_id"]
        pago = await _pago_fresco(db_session, pago_id)
        evento = _evento(_txn(pago))

        primera = await async_client.post("/webhooks/pago", json=evento)
        assert primera.status_code == 200, primera.text
        assert primera.json()["status"] == "procesado"

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.aprobado
        updated_at_1 = pago.updated_at

        segunda = await async_client.post("/webhooks/pago", json=evento)
        assert segunda.status_code == 200, segunda.text
        assert segunda.json()["status"] == "ya-procesado"

        # 3a entrega con txn distinto (event_key nuevo) → terminal no-op 200.
        tercera = await async_client.post(
            "/webhooks/pago", json=_evento(_txn(pago, txn_id=f"otro-{pago.id}"))
        )
        assert tercera.status_code == 200, tercera.text
        assert tercera.json()["status"] == "ya-procesado"

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.aprobado
        assert pago.updated_at == updated_at_1, "re-entregas no tocan el pago"

        # 1 fila de dedup: la re-entrega exacta colisiona en el UNIQUE y la
        # 3a (txn distinto sobre pago terminal) se revierte con la
        # TransicionInvalidaError — ambas 200 no-op, ninguna deja fila.
        keys = list(
            (
                await db_session.execute(
                    select(PagoEvent.event_key).where(PagoEvent.pago_id == pago_id)
                )
            )
            .scalars()
            .all()
        )
        assert keys == [f"txn-{pago.referencia}:APPROVED"]

        # Efectos exactamente 1 vez: pedidos pagado, sesión cerrada.
        pedidos = (
            (
                await db_session.execute(
                    select(Pedido).where(Pedido.sesion_id == ctx["sesion_id"])
                )
            )
            .scalars()
            .all()
        )
        assert all(p.estado == "pagado" for p in pedidos)
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        assert sesion.estado == "cerrada"
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- Fraude: monto mismatch (Pitfall 5) ------------------------------------------


@pytest.mark.asyncio
async def test_aprobado_monto_mismatch_sin_efectos(async_client, db_session):
    """APPROVED firmado VÁLIDO pero con amount_in_cents distinto → 200 sin
    efectos; pago_event queda como alerta 'monto-mismatch'."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        pago_id = intencion["pago_id"]
        pago = await _pago_fresco(db_session, pago_id)

        evento = _evento(_txn(pago, monto_cents=int(pago.monto * 100) + 1))
        resp = await async_client.post("/webhooks/pago", json=evento)
        assert resp.status_code == 200, resp.text
        assert resp.json()["result"] == "monto-mismatch"

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.pendiente
        ev = (
            await db_session.execute(
                select(PagoEvent).where(PagoEvent.pago_id == pago_id)
            )
        ).scalar_one()
        assert ev.estado == "monto-mismatch"
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        assert sesion.estado == "activa"
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- Referencia desconocida -------------------------------------------------------


@pytest.mark.asyncio
async def test_aprobado_referencia_desconocida(async_client, db_session):
    """APPROVED válido con referencia inexistente → 200 con fila de
    auditoría pago_event (pago_id NULL), sin efectos."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        ref = "GRI-PAGO-noexiste"
        transaccion = {
            "id": "txn-fantasma",
            "status": "APPROVED",
            "amount_in_cents": 123456,
            "currency": "COP",
            "reference": ref,
        }
        evento = _evento(transaccion)
        resp = await async_client.post("/webhooks/pago", json=evento)
        assert resp.status_code == 200, resp.text
        assert resp.json()["status"] == "procesado"

        ev = (
            await db_session.execute(
                select(PagoEvent).where(PagoEvent.event_key == "txn-fantasma:APPROVED")
            )
        ).scalar_one()
        assert ev.pago_id is None

        # Cleanup manual de la fila de auditoría.
        await db_session.delete(ev)
        await db_session.commit()
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- PENDING: registra transaction_id sin efectos ----------------------------------


@pytest.mark.asyncio
async def test_pending_registra_txn_luego_aproba(async_client, db_session):
    """PENDING → guarda transaction_id, sin efectos. Luego APPROVED con el
    MISMO txn id (flujo Wompi real) → efectos completos."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        pago_id = intencion["pago_id"]
        pago = await _pago_fresco(db_session, pago_id)
        txn_id = f"txn-{pago.referencia}"

        pendiente = _evento(_txn(pago, status="PENDING"))
        resp = await async_client.post("/webhooks/pago", json=pendiente)
        assert resp.status_code == 200, resp.text

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.transaction_id == txn_id
        assert pago.estado == EstadoPago.pendiente
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        assert sesion.estado == "activa"
        pedido = await db_session.get(Pedido, ctx["pedido_ids"][0])
        assert pedido.estado == "servido"

        aprobado = _evento(_txn(pago, status="APPROVED"))
        resp2 = await async_client.post("/webhooks/pago", json=aprobado)
        assert resp2.status_code == 200, resp2.text

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.aprobado
        pedido = await db_session.get(Pedido, ctx["pedido_ids"][0])
        assert pedido.estado == "pagado"
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        assert sesion.estado == "cerrada" and sesion.cerrada_en is not None
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- DECLINED: rechazo sin efectos de sesión ----------------------------------------


@pytest.mark.asyncio
async def test_declined_rechaza_sin_efectos(async_client, db_session):
    """DECLINED → pago rechazado + transaction_id; sesión sigue activa, mesa
    ocupada, pedidos servido (el reintento es una nueva intención)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        pago_id = intencion["pago_id"]
        pago = await _pago_fresco(db_session, pago_id)

        resp = await async_client.post(
            "/webhooks/pago", json=_evento(_txn(pago, status="DECLINED"))
        )
        assert resp.status_code == 200, resp.text

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.rechazado
        assert pago.transaction_id == f"txn-{pago.referencia}"
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        assert sesion.estado == "activa"
        pedido = await db_session.get(Pedido, ctx["pedido_ids"][0])
        assert pedido.estado == "servido"

        # Nueva intención tras el rechazo → 201 nuevo pago pendiente.
        reintento = await async_client.post(
            "/cliente/pagos/intencion", headers=ctx["headers"]
        )
        assert reintento.status_code == 201, reintento.text
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- VOIDED post-aprobado: log sin revertir -----------------------------------------


@pytest.mark.asyncio
async def test_voided_post_aprobado_sin_revertir(async_client, db_session):
    """VOIDED llegando DESPUÉS del APPROVED → log 'voided-post-aprobado' en
    pago_event, efectos intactos (reembolso manual — fuera de scope v1)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        pago_id = intencion["pago_id"]
        pago = await _pago_fresco(db_session, pago_id)

        r1 = await async_client.post(
            "/webhooks/pago", json=_evento(_txn(pago, status="APPROVED"))
        )
        assert r1.status_code == 200, r1.text

        r2 = await async_client.post(
            "/webhooks/pago", json=_evento(_txn(pago, status="VOIDED"))
        )
        assert r2.status_code == 200, r2.text
        assert r2.json()["result"] == "voided-post-aprobado"

        pago = await _pago_fresco(db_session, pago_id)
        assert pago.estado == EstadoPago.aprobado
        pedido = await db_session.get(Pedido, ctx["pedido_ids"][0])
        assert pedido.estado == "pagado"
        sesion = await db_session.get(SesionMesa, ctx["sesion_id"])
        assert sesion.estado == "cerrada"
        ev = (
            await db_session.execute(
                select(PagoEvent).where(
                    PagoEvent.event_key == f"txn-{pago.referencia}:VOIDED"
                )
            )
        ).scalar_one()
        assert ev.estado == "voided-post-aprobado"
    finally:
        await borrar_residuo_pago(db_session, ctx)


# --- WS: eventos post-commit al dueño (PAGO-04) -------------------------------------


@pytest.mark.asyncio
async def test_ws_cliente_recibe_sesion_cerrada(async_client, db_session):
    """Al aprobar (pipeline completo), el user room del dueño recibe
    pedido.estado pagado → sesion.cerrada → pago.estado (post-commit)."""
    from httpx_ws import aconnect_ws

    from .conftest import API_BASE

    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    try:
        intencion = await _intencion(async_client, ctx["headers"])
        ref = intencion["referencia"]

        async with aconnect_ws(
            f"{API_BASE}/ws/cliente?token={ctx['token']}"
        ) as ws:
            await asyncio.sleep(0.2)  # join al room
            resp = await async_client.post(f"/pagos/sandbox/{ref}/aprobar")
            assert resp.status_code == 303, resp.text

            recibidos: dict[str, dict] = {}
            async with asyncio.timeout(4):
                while len(recibidos) < 3:
                    event = await ws.receive_json()
                    recibidos[event["type"]] = event["data"]

        assert recibidos["sesion.cerrada"]["sesion_id"] == ctx["sesion_id"]
        assert recibidos["pago.estado"]["estado"] == "aprobado"
        assert recibidos["pago.estado"]["pago_id"] == intencion["pago_id"]
        assert ctx["pedido_ids"][0] in recibidos["pago.estado"]["pedido_ids"]
        assert (
            recibidos["pedido.estado"]["estado"] == "pagado"
            and recibidos["pedido.estado"]["pedido_id"] == ctx["pedido_ids"][0]
        )
    finally:
        await borrar_residuo_pago(db_session, ctx)
