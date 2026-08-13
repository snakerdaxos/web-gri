"""Calificacion ORM model (Phase 3 domain).

A `calificacion` is a cliente's review of a completed `pedido`. One review per
pedido (`uq_calificacion_pedido` — CALI-01). `estrellas` is constrained to 1-5
by a DB CHECK (MySQL 8.0.16+), the authoritative range invariant beyond any
Pydantic schema (CALI-02 Phase 9 reads these for restaurant averages).
"""

import datetime as dt

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    SmallInteger,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Calificacion(Base):
    __tablename__ = "calificacion"
    __table_args__ = (
        CheckConstraint("estrellas BETWEEN 1 AND 5", name="ck_calificacion_estrellas_rango"),
        UniqueConstraint("pedido_id", name="uq_calificacion_pedido"),
        Index("ix_calificacion_restaurante", "restaurant_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    usuario_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("usuario.id"), nullable=False
    )
    pedido_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("pedido.id"), nullable=False
    )
    estrellas: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    comentario: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
