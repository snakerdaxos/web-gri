"""Pydantic schemas for the sesión-mesa QR contract (MESA-05/06, PAGO-01).

``SesionRead`` spans 3 tablas (sesión + restaurante.nombre + mesa.numero),
so it is built by ``sesion_service._to_read`` — NO ``from_attributes``
directo (patrón ``reserva_service._to_read``).

El menú NO va embebido: la app reusa ``GET /public/restaurantes/{id}``
(decisión del research — contrato angosto).
"""

import datetime as dt

from pydantic import BaseModel, Field


class SesionCreate(BaseModel):
    """POST /cliente/sesiones body — el código impreso en el QR de la mesa
    (formato ``GRI-MESA-XXX``, globalmente único)."""

    codigo_qr: str = Field(min_length=1, max_length=50)


class SesionRead(BaseModel):
    """Sesión activa del cliente con joins display (restaurante, mesa)."""

    id: int
    restaurante_id: int
    restaurante_nombre: str
    mesa_id: int
    mesa_numero: int
    abierta_en: dt.datetime
    solicita_cuenta: bool
    solicitada_en: dt.datetime | None
