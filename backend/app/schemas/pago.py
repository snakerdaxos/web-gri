"""Pydantic schemas del contrato de pago (PAGO-02, Phase 9).

Money on the wire: ``monto`` declarado ``float`` + ``@field_serializer`` que
retorna ``float(v)`` (patrón schemas/pedido.py — Pitfall 3: Pydantic v2
serializa Decimal → string, que rompe el cliente Dart).

ANTI-TAMPERING (T-09-01): NO existe schema de create con monto — la
intención no acepta body; el monto SIEMPRE es server-side (SUM de pedidos
servido de la sesión).
"""

from decimal import Decimal
from typing import Any

from pydantic import BaseModel, field_serializer

from app.models.pago import EstadoPago


class PagoIntencionRead(BaseModel):
    """Respuesta de POST /cliente/pagos/intencion (201 nueva / 200 reutilizada)."""

    pago_id: int
    referencia: str
    monto: float
    estado: EstadoPago
    checkout_url: str

    @field_serializer("monto")
    def _coerce_monto(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 3 — Decimal → JSON number)."""
        return float(v)


class PagoEstadoRead(BaseModel):
    """Respuesta de GET /cliente/pagos/{id} — polling post-checkout.

    ``pedido_ids``: los pedidos cubiertos por el pago (pagado si ya aprobado;
    servido si aún pendiente) — la app los usa para el sheet de calificación
    post-pago (Pitfall 6: la sesión ya está cerrada, GET /sesiones/actual
    daría 404).
    """

    pago_id: int
    estado: EstadoPago
    referencia: str
    monto: float
    pedido_ids: list[int]

    @field_serializer("monto")
    def _coerce_monto(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 3)."""
        return float(v)
