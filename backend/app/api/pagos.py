"""Pagos router — intención + estado del pago por sesión + sandbox (PAGO-02/03/04).

Dos routers:

- ``router`` (/cliente/pagos) — SIEMPRE montado (auth-required, sin riesgo).
- ``sandbox_router`` (/pagos/sandbox) — montado SOLO si ``settings.SANDBOX_MODE``
  (main.py) + guard por-request 404 en CADA endpoint (defensa testeable sin
  reiniciar el stack — Pitfall 3 del research).

El sandbox NO es un mock del handler: POST aprobar/rechazar construye el
evento transaction.updated COMPLETO firmado con ``WOMPI_EVENTS_SECRET`` y
llama ``pago_service.procesar_webhook`` — la MISMA función del webhook
público. El pipeline de verificación queda ejercitado end-to-end en dev.

Body de /intencion: VACÍO por diseño — el monto SIEMPRE se calcula
server-side (SUM de pedidos servido de la sesión activa).
"""

import time

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import get_session
from app.core.gateways.wompi_gateway import firmar_evento
from app.core.state_machines import TransicionInvalidaError
from app.deps.auth import CurrentUser, require_roles
from app.models.pago import EstadoPago, Pago
from app.models.usuario import RolUsuario
from app.schemas.pago import PagoEstadoRead, PagoIntencionRead
from app.services import pago_service

router = APIRouter(prefix="/cliente/pagos", tags=["pagos"])


@router.post("/intencion", response_model=PagoIntencionRead)
async def crear_intencion(
    response: Response,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """PAGO-02: crear (201) o reutilizar (200) la intención de pago de la
    sesión activa. Sin body — monto server-side siempre.

    404 sin sesión activa; 409 sin pedidos / pedidos en curso.
    """
    read, created = await pago_service.crear_intencion(session, user.id)
    response.status_code = (
        status.HTTP_201_CREATED if created else status.HTTP_200_OK
    )
    return read


@router.get("/{pago_id}", response_model=PagoEstadoRead)
async def get_estado(
    pago_id: int,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """Estado del pago para el polling post-checkout. Existence hiding:
    pago ajeno/inexistente → 404 idéntico."""
    return await pago_service.consultar_estado(session, user.id, pago_id)


# --- Sandbox checkout (SOLO SANDBOX_MODE — guard por-request en cada endpoint) ---

sandbox_router = APIRouter(prefix="/pagos/sandbox", tags=["pagos-sandbox"])


def _sandbox_guard() -> None:
    """404 real si el sandbox está apagado (defensa testeable en caliente)."""
    if not settings.SANDBOX_MODE:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No encontrado")


def _monto_cop(monto) -> str:
    """Formato COP con punto de miles: $32.000."""
    return f"${int(monto):,}".replace(",", ".")


async def _pago_por_referencia(
    session: AsyncSession, referencia: str
) -> Pago | None:
    return (
        await session.execute(select(Pago).where(Pago.referencia == referencia))
    ).scalar_one_or_none()


def _construir_evento(pago: Pago, txn_status: str) -> dict:
    """Evento transaction.updated COMPLETO firmado con WOMPI_EVENTS_SECRET
    (el MISMO formato que entrega Wompi — pasa por verificar_firma_webhook
    en el pipeline público vía procesar_webhook)."""
    transaccion = {
        "id": f"sandbox-{pago.referencia}",
        "status": txn_status,
        "amount_in_cents": int(pago.monto * 100),
        "currency": "COP",
        "reference": pago.referencia,
    }
    timestamp = int(time.time())
    return {
        "event": "transaction.updated",
        "data": {"transaction": transaccion},
        "sent_at": "2026-08-15T00:00:00.000Z",
        "timestamp": timestamp,
        "signature": firmar_evento(transaccion, timestamp, settings.WOMPI_EVENTS_SECRET),
    }


@sandbox_router.get("/{referencia}", response_class=HTMLResponse)
async def sandbox_checkout(
    referencia: str,
    resultado: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> HTMLResponse:
    """Página de pago sandbox: total, referencia y los dos forms de acción."""
    _sandbox_guard()
    pago = await _pago_por_referencia(session, referencia)
    if pago is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Pago no encontrado")

    banners = {
        "aprobado": '<p id="banner" style="color:#1a7f37;font-weight:bold">'
        "✓ Pago aprobado</p>",
        "rechazado": '<p id="banner" style="color:#b3261e;font-weight:bold">'
        "✗ Pago rechazado</p>",
        "error": '<p id="banner" style="color:#b3261e;font-weight:bold">'
        "Error: el pago no está pendiente</p>",
    }
    banner = banners.get(resultado or "", "")
    estado_color = (
        "#1a7f37" if pago.estado == EstadoPago.aprobado
        else "#b3261e" if pago.estado == EstadoPago.rechazado
        else "#8a6d00"
    )
    html = f"""<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>Pago sandbox GRI</title></head>
<body style="font-family:sans-serif;max-width:480px;margin:48px auto;text-align:center">
  <h1>Pago sandbox GRI</h1>
  {banner}
  <p>Referencia: <strong>{pago.referencia}</strong></p>
  <p>Total: <strong style="font-size:1.6em">{_monto_cop(pago.monto)}</strong></p>
  <p>Estado: <strong style="color:{estado_color}">{pago.estado.value}</strong></p>
  <form method="POST" action="/pagos/sandbox/{referencia}/aprobar">
    <button type="submit" style="background:#1a7f37;color:#fff;padding:12px 32px;
      font-size:1.1em;border:none;border-radius:8px;cursor:pointer">Aprobar</button>
  </form>
  <form method="POST" action="/pagos/sandbox/{referencia}/rechazar" style="margin-top:12px">
    <button type="submit" style="background:#b3261e;color:#fff;padding:12px 32px;
      font-size:1.1em;border:none;border-radius:8px;cursor:pointer">Rechazar</button>
  </form>
  <p style="color:#666;font-size:0.85em;margin-top:32px">
    SANDBOX — sin dinero real. Cada botón construye un evento firmado y pasa
    por el MISMO pipeline del webhook público.</p>
</body>
</html>"""
    return HTMLResponse(html)


async def _sandbox_resolver(
    session: AsyncSession, referencia: str, txn_status: str, resultado_ok: str
) -> RedirectResponse:
    """Lookup + evento firmado + MISMO pipeline del webhook + redirect."""
    _sandbox_guard()
    pago = await _pago_por_referencia(session, referencia)
    if pago is None or pago.estado != EstadoPago.pendiente:
        return RedirectResponse(
            f"/pagos/sandbox/{referencia}?resultado=error", status_code=303
        )
    evento = _construir_evento(pago, txn_status)
    try:
        await pago_service.procesar_webhook(session, evento)
    except (IntegrityError, TransicionInvalidaError):
        # Re-entrega (doble click que ganó la carrera al guard) — no-op.
        await session.rollback()
    return RedirectResponse(
        f"/pagos/sandbox/{referencia}?resultado={resultado_ok}", status_code=303
    )


@sandbox_router.post("/{referencia}/aprobar")
async def sandbox_aprobar(
    referencia: str, session: AsyncSession = Depends(get_session)
) -> RedirectResponse:
    """Aprobar → evento APPROVED firmado → procesar_webhook → redirect."""
    return await _sandbox_resolver(session, referencia, "APPROVED", "aprobado")


@sandbox_router.post("/{referencia}/rechazar")
async def sandbox_rechazar(
    referencia: str, session: AsyncSession = Depends(get_session)
) -> RedirectResponse:
    """Rechazar → evento DECLINED firmado → procesar_webhook → redirect."""
    return await _sandbox_resolver(session, referencia, "DECLINED", "rechazado")
