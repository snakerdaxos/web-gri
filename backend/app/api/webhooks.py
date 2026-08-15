"""Webhooks router — endpoints PÚBLICOS de pasarelas de pago (Phase 9, PAGO-03).

``POST /webhooks/pago`` recibe ``transaction.updated`` de Wompi (o del
sandbox local). El contrato es de Wompi (payload ``dict`` crudo — sin model
Pydantic). Orden inquebrantable (T-09-01):

1. FIRMA PRIMERO: ``verificar_firma_webhook`` (timing-safe,
   ``hmac.compare_digest``) con ``settings.WOMPI_EVENTS_SECRET`` — sin firma
   válida NO se ejecuta NI UNA línea de negocio (401, cero efectos).
2. ``procesar_webhook`` — dedup + efectos (ver pago_service).
3. ``IntegrityError`` (event_key duplicado) y ``TransicionInvalidaError``
   (estado terminal) → 200 ``ya-procesado``. JAMÁS 500: Wompi reintenta
   ante 5xx y un no-op convertido en 500 generaría re-entregas infinitas.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import get_session
from app.core.gateways.wompi_gateway import verificar_firma_webhook
from app.core.state_machines import TransicionInvalidaError
from app.services import pago_service

router = APIRouter(tags=["webhooks"])


@router.post("/webhooks/pago")
async def webhook_pago(
    payload: dict, session: AsyncSession = Depends(get_session)
) -> dict:
    """transaction.updated de Wompi/sandbox — firma primera, negocio después."""
    # 1. FIRMA PRIMERO — 401 antes de parsear cualquier dato de negocio.
    if not verificar_firma_webhook(payload, settings.WOMPI_EVENTS_SECRET):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Firma inválida")
    # 2. Pipeline (dedup → fraude → efectos atómicos → WS post-commit).
    try:
        resultado = await pago_service.procesar_webhook(session, payload)
        return {"status": "procesado", **resultado}
    except IntegrityError:
        # event_key UNIQUE — re-entrega exacta: no-op 200.
        await session.rollback()
        return {"status": "ya-procesado"}
    except TransicionInvalidaError:
        # Pago en estado terminal — re-entrega con event_key nuevo: no-op 200.
        await session.rollback()
        return {"status": "ya-procesado"}
