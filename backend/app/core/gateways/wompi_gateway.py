"""WompiGateway — Web Checkout determinista + verificación de firmas.

Contrato VERIFICADO desde fuente mantenida (09-RESEARCH §Contrato Wompi,
paquete Laravel IGedeon/laravel-wompi mar-2026 con tests; docs oficiales
403). Todo lo que toque dinero real debe re-verificarse contra docs
oficiales al obtener credenciales (confianza MEDIUM-HIGH).

Tres algoritmos exactos (NO inventar otros — compatibilidad al conectar prod):

1. ``firma_integridad``: SHA256 de la concatenación PLANA
   ``referencia + amount_in_cents + currency [+ expiration_time] + secret``
   — sin separadores.
2. ``verificar_firma_webhook``: resolver ``signature.properties`` como
   dot-paths sobre ``data`` ("transaction.id" → data["transaction"]["id"],
   '' si falta), concatenar valores + str(timestamp) + events_secret, SHA256
   y comparar con ``signature.checksum`` vía ``hmac.compare_digest``
   (timing-safe — JAMÁS ``==``).
3. ``firmar_evento``: el inverso de (2) — construye el bloque ``signature``
   para un evento (lo usan el sandbox de la Task 3 y los tests). PÚBLICO.

El payload del webhook NO trae ``event.id`` (verificado): la dedup usa la
clave derivada ``f"{transaction.id}:{status}"`` (tabla pago_event).
"""

import hashlib
import hmac
import urllib.parse
from decimal import Decimal

import httpx

from app.core.config import settings

# URLs verificadas (09-RESEARCH §Endpoints y URLs base).
CHECKOUT_URL = "https://checkout.wompi.co/p/"
API_PRODUCTION = "https://production.wompi.co/v1"
# Propiedades que firma Wompi en transaction.updated (verificadas en los
# tests del SDK Laravel — el sandbox firma exactamente estas tres).
SIGNATURE_PROPERTIES = [
    "transaction.id",
    "transaction.status",
    "transaction.amount_in_cents",
]


# --- Algoritmos de firma (puros, testeados con vector conocido) ---------------


def firma_integridad(
    referencia: str,
    amount_in_cents: int,
    currency: str,
    integrity_secret: str,
    expiration_time: str | None = None,
) -> str:
    """SHA256(referencia + amount_in_cents + currency [+ expiration] + secret).

    Concatenación PLANA de strings — ``amount_in_cents`` entero sin formato.
    """
    payload = f"{referencia}{amount_in_cents}{currency}"
    if expiration_time is not None:
        payload += expiration_time
    payload += integrity_secret
    return hashlib.sha256(payload.encode()).hexdigest()


def _dig(data, path: str):
    """Dot-path resolver: 'transaction.id' → data['transaction']['id'].

    Retorna '' si cualquier tramo falta (el SDK PHP usa data_get con default
    '' — réplica exacta para que el checksum coincida).
    """
    for part in path.split("."):
        if not isinstance(data, dict):
            return ""
        data = data.get(part, "")
    return data


def verificar_firma_webhook(payload: dict, events_secret: str) -> bool:
    """Verifica signature{properties, checksum} + timestamp del webhook.

    Timing-safe (``hmac.compare_digest``). False si falta el bloque
    signature, las properties o el checksum (handler → 401).
    """
    signature = payload.get("signature") or {}
    props = signature.get("properties") or []
    checksum = signature.get("checksum") or ""
    timestamp = payload.get("timestamp", "")
    if not props or not checksum:
        return False
    values = "".join(str(_dig(payload.get("data", {}), p)) for p in props)
    values += str(timestamp) + events_secret
    computed = hashlib.sha256(values.encode()).hexdigest()
    return hmac.compare_digest(computed, checksum)


def firmar_evento(datos_transaccion: dict, timestamp: int, events_secret: str) -> dict:
    """Construye el bloque ``signature`` de un evento transaction.updated.

    Lo usan el sandbox (api/pagos.py Task 3) y los tests para producir
    eventos VÁLIDOS que pasan por el MISMO pipeline de verificación.
    """
    values = "".join(
        str(_dig({"transaction": datos_transaccion}, p)) for p in SIGNATURE_PROPERTIES
    )
    values += str(timestamp) + events_secret
    checksum = hashlib.sha256(values.encode()).hexdigest()
    return {"properties": list(SIGNATURE_PROPERTIES), "checksum": checksum}


# --- Gateway Wompi -------------------------------------------------------------


class WompiGateway:
    """Web Checkout URL determinista (form GET — no requiere llamada API para
    crear la intención) + consulta de transacciones (reconciliación)."""

    nombre = "wompi"

    async def crear_checkout(
        self,
        *,
        referencia: str,
        monto: Decimal,
        redirect_url: str | None = None,
    ) -> str:
        """URL determinista del Web Checkout (redirect-form verificado).

        ``signature:integrity`` viaja URL-encoded (``%3A`` — urlencode lo
        maneja); COP no tiene decimales en la práctica → Decimal*100 exacto.
        """
        amount_in_cents = int(monto * 100)
        params = {
            "public-key": settings.WOMPI_PUBLIC_KEY,
            "currency": "COP",
            "amount-in-cents": str(amount_in_cents),
            "reference": referencia,
            "signature:integrity": firma_integridad(
                referencia, amount_in_cents, "COP", settings.WOMPI_INTEGRITY_SECRET
            ),
        }
        if redirect_url is not None:
            params["redirect-url"] = redirect_url
        return f"{CHECKOUT_URL}?{urllib.parse.urlencode(params)}"

    async def consultar_transaccion(self, transaction_id: str) -> dict | None:
        """GET /transactions/{id} con public key (verificado: public=GET).

        Red de seguridad del webhook — JAMÁS raise: error de red / no-200 /
        formato inesperado → None (el flujo sigue su curso).
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    f"{API_PRODUCTION}/transactions/{transaction_id}",
                    headers={
                        "Authorization": f"Bearer {settings.WOMPI_PUBLIC_KEY}"
                    },
                )
        except httpx.HTTPError:
            return None
        if resp.status_code != 200:
            return None
        data = resp.json().get("data") or {}
        txn = data.get("transaction")
        return txn if isinstance(txn, dict) else None
