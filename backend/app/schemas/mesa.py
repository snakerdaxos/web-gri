"""Mesa schemas for the panel admin (ADMN-02 mapa de mesas + MESA-04).

Deliberately narrow: the panel only needs identity + estado to render the
colored mesa map. `restaurant_id` is omitted — the caller already knows their
own tenant (it came from their token), and echoing it adds no value while
widening the response surface.

``MesaEstadoUpdate`` (05-02 / MESA-04) is the request body for
``POST /staff/mesas/{id}/estado``. The value is validated against the
``EstadoMesa`` enum (422 on unknown values) and then against
``MESA_TRANSITIONS`` in the service (409 on invalid transitions).

``MesaCreate`` / ``MesaUpdate`` (08-02 / MESA-01) are the bodies for
POST /staff/mesas and PATCH /staff/mesas/{id}. There is DELIBERATELY no
``codigo_qr`` field: the QR is derived deterministically server-side as
``GRI-MESA-R{rid}-{numero:03d}`` (Pattern 1 del research — locked) and
NEVER accepted from the client. ``estado`` doesn't come from the client
either: a new mesa always starts ``disponible`` and state changes go
through the MESA_TRANSITIONS endpoint.
"""

from pydantic import BaseModel, ConfigDict, Field

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


class MesaCreate(BaseModel):
    """POST /staff/mesas body (MESA-01). Solo numero + capacidad — el QR lo
    deriva el server (determinista) y el estado nace ``disponible``.

    capacidad tope 50: una mesa física de restaurante no razona en
    centenares; valores absurdos se rechazan en validación (422)."""

    numero: int = Field(gt=0)
    capacidad: int = Field(gt=0, le=50)


class MesaUpdate(BaseModel):
    """PATCH /staff/mesas/{id} body (MESA-01) — parcial. Si ``numero`` cambia,
    el service regenera el codigo_qr al nuevo número (Pitfall 6: el QR
    impreso anterior queda obsoleto — el form del panel lo advierte)."""

    numero: int | None = Field(default=None, gt=0)
    capacidad: int | None = Field(default=None, gt=0, le=50)
