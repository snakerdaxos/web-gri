"""PagoGateway — contrato abstracto de pasarela de pago (Phase 9, PAGO-02).

v1 tiene DOS implementaciones: ``SandboxGateway`` (default dev — checkout
local que ejercita el MISMO pipeline del webhook) y ``WompiGateway`` (Web
Checkout determinista + consulta de transacciones). La selección vive en
``app.core.gateways.get_pago_gateway()`` según ``settings.SANDBOX_MODE``.

``nombre`` se persiste en ``pago.pasarela`` — la reconciliación lazy y la
respuesta de estado lo usan para decidir si la pasarela puede consultarse.
"""

from decimal import Decimal
from typing import Protocol


class PagoGateway(Protocol):
    """Contrato de pasarela — v1: SandboxGateway | WompiGateway."""

    nombre: str

    async def crear_checkout(
        self,
        *,
        referencia: str,
        monto: Decimal,
        redirect_url: str | None = None,
    ) -> str:
        """Devuelve la URL de checkout (RELATIVA "/pagos/sandbox/..." si es
        el sandbox local — la app antepone Env.apiBaseUrl; absoluta si es
        Wompi Web Checkout)."""
        ...

    async def consultar_transaccion(self, transaction_id: str) -> dict | None:
        """Reconciliación (red de seguridad del webhook). Retorna el dict
        ``transaction`` de la pasarela o None si no aplica / error / no-200
        (JAMÁS raise — una falla de red no debe romper el flujo)."""
        ...
