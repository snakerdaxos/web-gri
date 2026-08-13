"""Reserva ORM model + EstadoReserva enum (Phase 3 domain).

A `reserva` books a mesa for a future date/time. The unique-slot constraint
(PITFALLS P1) is DEFERRED to Phase 5 because the exact slot semantics (fixed
turn length vs exact-time) is a SPEC decision; an incorrect constraint today
is worse than a trivial additive migration later. We ship only the
`ix_reserva_mesa_fecha` index now so the Phase 5 lookup is already indexed.

`num_personas >= 1` is enforced by a DB CHECK (MySQL 8.0.16+).
"""

import datetime as dt
import enum

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    SmallInteger,
    Time,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EstadoReserva(str, enum.Enum):
    pendiente = "pendiente"
    confirmada = "confirmada"
    cancelada = "cancelada"


class Reserva(Base):
    __tablename__ = "reserva"
    __table_args__ = (
        CheckConstraint("num_personas >= 1", name="ck_reserva_num_personas_positiva"),
        Index("ix_reserva_mesa_fecha", "mesa_id", "fecha"),
        Index("ix_reserva_restaurante_fecha_estado", "restaurant_id", "fecha", "estado"),
        Index("ix_reserva_usuario", "usuario_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    usuario_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("usuario.id"), nullable=False
    )
    mesa_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("mesa.id"), nullable=False
    )
    fecha: Mapped[dt.date] = mapped_column(Date, nullable=False)
    hora_inicio: Mapped[dt.time] = mapped_column(Time, nullable=False)
    num_personas: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    estado: Mapped[EstadoReserva] = mapped_column(
        Enum(EstadoReserva, name="estado_reserva"),
        nullable=False,
        server_default="pendiente",
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
