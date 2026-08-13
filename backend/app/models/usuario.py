"""Usuario ORM model + the 5-value role enum.

A single global `usuario` table holds every principal in the system. The `role`
enum enforces exactly 5 values (AUTH-03); `restaurant_id` is a nullable FK so
that `super_admin` and `cliente` (cross-tenant) are legitimately NULL, while
staff roles (admin_restaurante/mesero/cocina) are required to carry a tenant.
The staff-must-have-tenant rule is enforced in the service layer (TenantScope,
Plan 02-02), not as a DB NOT NULL — because the column legitimately holds NULLs.
"""

import datetime as dt
import enum

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class RolUsuario(str, enum.Enum):
    """The 5 roles of the GRI platform (ARCHITECTURE.md Pattern 2, AUTH-03)."""

    super_admin = "super_admin"
    admin_restaurante = "admin_restaurante"
    mesero = "mesero"
    cocina = "cocina"
    cliente = "cliente"


class Usuario(Base):
    __tablename__ = "usuario"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    # String(254) is the RFC 5321 max. utf8mb4_unicode_ci collation (Phase 1)
    # makes the UNIQUE index case-insensitive for free.
    email: Mapped[str] = mapped_column(String(254), nullable=False, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[RolUsuario] = mapped_column(
        Enum(RolUsuario, name="rol_usuario"), nullable=False, index=True
    )
    # NULL for super_admin & cliente (cross-tenant); required for staff.
    restaurant_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=True, index=True
    )
    activo: Mapped[bool] = mapped_column(default=True, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
