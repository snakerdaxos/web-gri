"""Pydantic schemas for the pedido contract (PEDI-01..06, Phase 6).

Money on the wire: ``total`` / ``precio_unitario`` / ``subtotal`` are declared
as ``float`` and coerced from the ORM ``Decimal`` via ``@field_serializer``
(patrón schemas/menu.py — Pitfall 3: Pydantic v2 serializa Decimal → string,
que rompe el cliente Dart).

ANTI-TAMPERING (PEDI-01): ``PedidoCreate`` NO tiene campos de precio — el
total SIEMPRE se calcula server-side desde ``producto.precio`` y el snapshot
vive en ``pedido_item.precio_unitario``.
"""

import datetime as dt
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, Field, field_serializer

from app.models.pedido import EstadoPedido


class PedidoItemCreate(BaseModel):
    """Una línea del pedido — solo producto_id + cantidad. El precio JAMÁS
    viene del cliente (calculated server-side)."""

    producto_id: int
    cantidad: int = Field(gt=0)


class PedidoCreate(BaseModel):
    """POST /cliente/pedidos body. ``sesion_id`` None = la sesión activa
    actual del usuario (la app manda el id explícito tras el scan)."""

    sesion_id: int | None = None
    items: list[PedidoItemCreate] = Field(min_length=1)
    notas: str | None = Field(default=None, max_length=500)


class PedidoItemRead(BaseModel):
    """Línea de pedido con el snapshot de precio (nombre = join display)."""

    producto_id: int
    nombre: str
    cantidad: int
    precio_unitario: float
    subtotal: float

    @field_serializer("precio_unitario", "subtotal")
    def _coerce_money(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 3 — Decimal → JSON number)."""
        return float(v)


class PedidoRead(BaseModel):
    """Pedido del cliente (PEDI-01/02/04) — construido por el service con
    joins display (mesa.numero, producto.nombre)."""

    id: int
    sesion_id: int | None
    mesa_numero: int
    estado: EstadoPedido
    total: float
    notas: str | None
    created_at: dt.datetime
    items: list[PedidoItemRead]

    @field_serializer("total")
    def _coerce_total(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 3)."""
        return float(v)


class PedidoEstadoUpdate(BaseModel):
    """POST /staff/pedidos/{id}/estado body — estado DESTINO validado contra
    el enum (422 si desconocido, patrón MesaEstadoUpdate); la validez de la
    transición la decide PEDIDO_TRANSITIONS en el service (409)."""

    estado: EstadoPedido
