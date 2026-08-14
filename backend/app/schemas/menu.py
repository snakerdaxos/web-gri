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

from pydantic import BaseModel, ConfigDict, Field, field_serializer


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


# --- Phase 8 (MENU-01/02): staff-facing menú contract -------------------------


class ProductoStaff(BaseModel):
    """Producto para el panel admin: TODO lo que el staff ve, incluyendo los
    flags ``disponible`` (agotado transitorio) y ``activo`` (soft-delete)."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    categoria_id: int
    nombre: str
    descripcion: str | None
    precio: float
    imagen_url: str | None
    disponible: bool
    activo: bool

    @field_serializer("precio")
    def _coerce_precio(self, v: float | Decimal | Any) -> float:
        """Force float on the wire (Pitfall 3 — Decimal → JSON number)."""
        return float(v)


class CategoriaStaff(BaseModel):
    """Categoría con sus productos para GET /staff/menu — INCLUYE inactivos
    y agotados con sus flags (el staff ve TODO; /public es el que filtra)."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    orden: int
    activo: bool
    productos: list[ProductoStaff] = []


class CategoriaCreate(BaseModel):
    """POST /staff/categorias body."""

    nombre: str = Field(min_length=1, max_length=100)
    orden: int = 0


class CategoriaUpdate(BaseModel):
    """PATCH /staff/categorias/{id} body — parcial (exclude_unset en el
    service distingue "no viene" de None)."""

    nombre: str | None = Field(default=None, min_length=1, max_length=100)
    orden: int | None = None
    activo: bool | None = None


class ProductoCreate(BaseModel):
    """POST /staff/productos body. ``precio`` float > 0 (422 server-side);
    el service lo convierte con ``Decimal(str(precio))`` — exacto."""

    categoria_id: int
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = Field(default=None, max_length=500)
    precio: float = Field(gt=0)
    imagen_url: str | None = Field(default=None, max_length=500)


class ProductoUpdate(BaseModel):
    """PATCH /staff/productos/{id} body — parcial. ``disponible`` = agotado
    transitorio (SIGUE en /public); ``activo`` = soft-delete (DESAPARECE)."""

    nombre: str | None = Field(default=None, min_length=1, max_length=150)
    descripcion: str | None = Field(default=None, max_length=500)
    precio: float | None = Field(default=None, gt=0)
    imagen_url: str | None = Field(default=None, max_length=500)
    disponible: bool | None = None
    activo: bool | None = None
