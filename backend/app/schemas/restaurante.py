"""Pydantic schemas for the admin HTTP contract (restaurantes + staff).

`StaffRole` is a RESTRICTED enum (PLAT-03): only the 3 staff roles are
assignable via the API. `cliente` and `super_admin` are rejected at validation
time (422) — nobody can escalate privileges through the staff endpoint; the
only super_admin is the env-driven bootstrap.

`StaffRead` deliberately omits the stored secret column (PITFALL 7) — never use
the ORM model as a response_model. `StaffCreate.password` caps at 64 chars
(PITFALL 5 — bcrypt truncates at 72 bytes).
"""

import datetime as dt
import enum

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.usuario import RolUsuario


class RestauranteCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = Field(default=None, max_length=500)
    tipo_cocina: str | None = Field(default=None, max_length=100)
    direccion: str | None = Field(default=None, max_length=255)


class RestauranteRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    descripcion: str | None
    tipo_cocina: str | None
    direccion: str | None
    activo: bool
    created_at: dt.datetime


class RestauranteActivoUpdate(BaseModel):
    """PATCH /admin/restaurantes/{id} body (PLAT-05) — ``activo`` es requerido:
    el endpoint hace UNA cosa (toggle) y el body vacío es un error del caller
    (422), no un no-op silencioso."""

    activo: bool


class StaffRole(str, enum.Enum):
    """The ONLY roles assignable via POST /admin/restaurantes/{id}/staff.

    Excludes cliente (cross-tenant by design) and super_admin (bootstrap-only).
    """

    admin_restaurante = "admin_restaurante"
    mesero = "mesero"
    cocina = "cocina"


class StaffCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    email: EmailStr
    # max_length=64 mitigates bcrypt's 72-byte truncation (PITFALL 5).
    password: str = Field(min_length=8, max_length=64)
    role: StaffRole


class StaffRead(BaseModel):
    """Public staff shape. NEVER exposes the stored secret."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    email: EmailStr
    role: RolUsuario
    restaurant_id: int
