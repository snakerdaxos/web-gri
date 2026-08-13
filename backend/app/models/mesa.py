"""Mesa ORM model + EstadoMesa enum (Phase 3 domain).

A `mesa` is a physical table inside a restaurant. The `codigo_qr` column is
GLOBALLY unique (MESA-02 + Phase 3 SC3): two tables in different restaurants
cannot share a QR code, because the scanned QR must unambiguously resolve to
exactly one mesa. The composite unique (restaurant_id, numero) keeps the
human-facing label unique within a tenant.

EstadoMesa drives the mesa state machine (ARCHITECTURE.md Pattern 5); the
allowed transitions live in `app.core.state_machines.MESA_TRANSITIONS`.
"""

import datetime as dt
import enum

from sqlalchemy import (
    BigInteger,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EstadoMesa(str, enum.Enum):
    """Mesa lifecycle states (ARCHITECTURE.md Pattern 5)."""

    disponible = "disponible"
    reservada = "reservada"
    ocupada = "ocupada"
    limpieza = "limpieza"


class Mesa(Base):
    __tablename__ = "mesa"
    __table_args__ = (
        # Human label unique within a tenant.
        UniqueConstraint("restaurant_id", "numero", name="uq_mesa_restaurante_numero"),
        # GLOBAL unique — the scanned QR resolves to exactly one mesa across
        # the whole platform (MESA-02 / Phase 3 SC3).
        UniqueConstraint("codigo_qr", name="uq_mesa_codigo_qr"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    numero: Mapped[int] = mapped_column(Integer, nullable=False)
    capacidad: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    codigo_qr: Mapped[str] = mapped_column(String(32), nullable=False)
    estado: Mapped[EstadoMesa] = mapped_column(
        Enum(EstadoMesa, name="estado_mesa"),
        nullable=False,
        server_default="disponible",
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
