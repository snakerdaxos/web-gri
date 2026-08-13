"""Mesa read schema for the panel admin (ADMN-02 mapa de mesas).

Deliberately narrow: the panel only needs identity + estado to render the
colored mesa map. `restaurant_id` is omitted — the caller already knows their
own tenant (it came from their token), and echoing it adds no value while
widening the response surface.
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
