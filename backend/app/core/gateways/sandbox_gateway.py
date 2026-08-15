"""SandboxGateway — checkout local que ejercita el pipeline REAL del webhook.

v1 corre sin credenciales de pasarela (KYC pendiente). El sandbox NO es un
mock del handler: ``/pagos/sandbox/{referencia}/aprobar|rechazar`` (api/pagos,
Task 3) construye el evento transaction.updated COMPLETO firmado con
``WOMPI_EVENTS_SECRET`` y llama a ``pago_service.procesar_webhook`` — la
MISMA función del webhook público. El pipeline de verificación queda
ejercitado end-to-end en dev/tests (09-RESEARCH Patrón 1).

El checkout URL es RELATIVO (``/pagos/sandbox/{referencia}``): la app cliente
antepone ``Env.apiBaseUrl`` (funciona igual en web-dev :5174 y en móvil).
"""

from decimal import Decimal


class SandboxGateway:
    """Pasarela local — cero llamadas externas, cero credenciales."""

    nombre = "sandbox"

    async def crear_checkout(
        self,
        *,
        referencia: str,
        monto: Decimal,
        redirect_url: str | None = None,
    ) -> str:
        """URL relativa del checkout sandbox (página HTML con botones
        Aprobar/Rechazar — la Task 3 la monta condicionalmente)."""
        return f"/pagos/sandbox/{referencia}"

    async def consultar_transaccion(self, transaction_id: str) -> dict | None:
        """Siempre None — el sandbox entrega el webhook local de forma
        confiable; no hay nada que reconciliar."""
        return None
