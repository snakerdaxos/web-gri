"""Pydantic schemas for the cliente-management contract (ADMN-03, Phase 8).

``total_gastado`` is declared as ``float`` and coerced from the SQL ``SUM``
``Decimal`` via a ``@field_serializer`` — Pitfall 1 of the research: asyncmy
returns Decimal from ``Numeric(10,2)`` and Pydantic v2 would serialize it as
a JSON string, breaking the Dart client (same pattern as
``schemas/menu.py:ProductoRead._coerce_precio``).
"""

import datetime as dt
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, field_serializer


class ClienteResumen(BaseModel):
    """Un cliente del restaurante = usuario CON pedidos en el tenant (JOIN
    pedido→usuario; un usuario que solo reservó NO aparece — decisión v1
    documentada en el research)."""

    usuario_id: int
    nombre: str
    email: str
    num_pedidos: int
    total_gastado: float
    ultimo_pedido_at: dt.datetime | None = None

    @field_serializer("total_gastado")
    def _coerce_total(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (SUM devuelve Decimal — Pitfall 1)."""
        return float(v)
