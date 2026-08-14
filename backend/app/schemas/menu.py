"""Pydantic schemas for the public-facing menú contract (REST-01, REST-02).

``precio`` is declared as ``float`` and coerced from the ORM ``Decimal`` via a
``@field_serializer`` — Pitfall 3 of the research. asyncmy returns ``Decimal``
from ``Numeric(10,2)``; Pydantic v2's default Decimal → JSON serialization is a
string (the JSON spec has no Decimal type), which would break the Dart client
(``double.parse`` rejects strings). Coercing server-side keeps the contract
clean: the wire type is always a JSON number, never a string.
"""

from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, field_serializer


class ProductoRead(BaseModel):
    """A single dish/drink, public-facing shape."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    descripcion: str | None
    precio: float
    imagen_url: str | None
    disponible: bool

    @field_serializer("precio")
    def _coerce_precio(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 3). Accepts Decimal from the ORM
        (asyncmy returns Decimal from Numeric) or already-float values."""
        return float(v)


class CategoriaConProductos(BaseModel):
    """A menú category with its products pre-grouped (REST-02 nested shape)."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    orden: int
    productos: list[ProductoRead]


class RestaurantePublico(BaseModel):
    """Restaurante list item (REST-01). ``calificacion`` is always None in
    Phase 5 (Phase 9 fills it with CALI-02 aggregate)."""

    id: int
    nombre: str
    tipo_cocina: str | None
    descripcion: str | None
    direccion: str | None
    calificacion: float | None = None


class RestauranteDetalle(RestaurantePublico):
    """Restaurante detail with nested menú (REST-02)."""

    categorias: list[CategoriaConProductos]
