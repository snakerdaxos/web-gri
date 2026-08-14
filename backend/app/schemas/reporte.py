"""Reporte schemas for the panel admin (REPO-01/02, Phase 8).

Money on the wire: TODOS los campos money son ``float`` con
``@field_serializer`` (patrón schemas/pedido.py — Pitfall 1: MySQL SUM
devuelve ``Decimal`` y Pydantic v2 lo serializa como string, que rompe el
``double.parse`` del cliente Dart y el gráfico del panel).

``VentaDia.fecha`` es ``dt.date`` (agrupación ``func.date(created_at)``
DB-side) → viaja como "YYYY-MM-DD" en JSON.
"""

import datetime as dt
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, field_serializer


class VentaDia(BaseModel):
    """Una fila del agrupado por día: fecha + total + num_pedidos."""

    fecha: dt.date
    total: float
    num_pedidos: int

    @field_serializer("total")
    def _coerce_total(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 1 — SUM → Decimal → JSON number)."""
        return float(v)


class VentasReporte(BaseModel):
    """REPO-01: ventas del rango [desde, hasta] (inclusivo) — total y
    num_pedidos generales + desglose por día. venta = servido|pagado
    (decisión locked: JAMÁS solo pagado — los reportes no pueden salir
    vacíos hasta que F9 implemente el pago)."""

    desde: dt.date
    hasta: dt.date
    total: float
    num_pedidos: int
    por_dia: list[VentaDia]

    @field_serializer("total")
    def _coerce_total(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 1)."""
        return float(v)


class TopPlato(BaseModel):
    """REPO-02: una fila del ranking — producto + cantidad vendida + total.

    Nota (Open Question 3 del research, documentada): ``nombre`` es el
    nombre ACTUAL del producto (pedido_item no tiene snapshot de nombre;
    el PRECIO sí es exacto por snapshot — el total refleja lo cobrado)."""

    producto_id: int
    nombre: str
    cantidad: int
    total: float

    @field_serializer("total")
    def _coerce_total(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 1)."""
        return float(v)
