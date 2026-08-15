"""Pydantic schemas para calificaciones post-pago (CALI-01 — Phase 9).

``estrellas`` se valida con ``Field(ge=1, le=5)`` como PRIMERA línea (422);
el CHECK de BD ``ck_calificacion_estrellas_rango`` es la autoridad final
(defensa en profundidad — una capa no puede quedar sola). El body NUNCA trae
``restaurant_id`` ni ``usuario_id``: el service los deriva del pedido.
"""

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field


class CalificacionCreate(BaseModel):
    """POST /cliente/calificaciones body."""

    pedido_id: int
    estrellas: int = Field(ge=1, le=5)
    comentario: str | None = Field(default=None, max_length=1000)


class CalificacionRead(BaseModel):
    """Respuesta 201 de la calificación creada."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    pedido_id: int
    estrellas: int
    comentario: str | None
    created_at: dt.datetime
