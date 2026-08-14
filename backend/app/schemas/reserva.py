"""Pydantic schemas for the reserva HTTP contract (RESV-01..04).

ReservaCreate is the request body for ``POST /cliente/reservas``. The server
auto-assigns the mesa (Phase 5 Concurrency Design §3) so the body never
carries a ``mesa_id`` — the cliente only picks restaurante/fecha/hora/personas.

ReservaRead carries two display-only fields (``restaurante_nombre``,
``mesa_numero``) that the service populates via joins. They are NOT on the
ORM model; the service constructs ReservaRead explicitly.
"""

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field

from app.models.reserva import EstadoReserva


class ReservaCreate(BaseModel):
    """POST /cliente/reservas body. ``num_personas`` capped at 20 for sanity
    (DB CHECK is >=1; 20 is well above any realistic mesa capacity)."""

    restaurante_id: int
    fecha: dt.date
    hora_inicio: dt.time
    num_personas: int = Field(ge=1, le=20)


class ReservaRead(BaseModel):
    """Reserva with display joins. Built by the service from the Reserva row
    + Restaurante.nombre + Mesa.numero."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    restaurante_id: int
    restaurante_nombre: str
    mesa_id: int
    mesa_numero: int
    fecha: dt.date
    hora_inicio: dt.time
    num_personas: int
    estado: EstadoReserva
    created_at: dt.datetime
