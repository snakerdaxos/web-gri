"""Mesa schemas for the panel admin (ADMN-02 mapa de mesas + MESA-04).

Deliberately narrow: the panel only needs identity + estado to render the
colored mesa map. `restaurant_id` is omitted — the caller already knows their
own tenant (it came from their token), and echoing it adds no value while
widening the response surface.

``MesaEstadoUpdate`` (05-02 / MESA-04) is the request body for
``POST /staff/mesas/{id}/estado``. The value is validated against the
``EstadoMesa`` enum (422 on unknown values) and then against
``MESA_TRANSITIONS`` in the service (409 on invalid transitions).
"""

from pydantic import BaseModel, ConfigDict

from app.models.mesa import EstadoMesa


class MesaRead(BaseModel):
    """Public mesa shape consumed by the panel's mesa grid + Plan 04-02."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    numero: int
    capacidad: int
    codigo_qr: str
    estado: EstadoMesa


class MesaEstadoUpdate(BaseModel):
    """POST /staff/mesas/{id}/estado body (RESV-05 marcar + MESA-04).

    ``estado`` es el estado DESTINO; el service valida la transición desde
    el estado actual vía ``validar_transicion("mesa", ...)`` — 409 si el
    salto no está en MESA_TRANSITIONS (ej. limpieza→ocupada)."""

    estado: EstadoMesa
