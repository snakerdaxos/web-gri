"""Pago ORM model + EstadoPago enum (Phase 3 domain).

A `pago` records a payment attempt for a `pedido`. `referencia` is GLOBALLY
unique so that a replayed webhook or a double-submit cannot create a second
payment row for the same logical transaction (PITFALLS P4 idempotency,
PAGO-03). The full pasarela flow (Wompi/PayU) lands in Phase 9; this table +
enum + unique reference is the data contract those integrations will write to.
"""

import datetime as dt
import enum
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EstadoPago(str, enum.Enum):
    pendiente = "pendiente"
    aprobado = "aprobado"
    rechazado = "rechazado"


class Pago(Base):
    __tablename__ = "pago"
    __table_args__ = (
        UniqueConstraint("referencia", name="uq_pago_referencia"),
        Index("ix_pago_pedido", "pedido_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    pedido_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("pedido.id"), nullable=False
    )
    monto: Mapped[Decimal] = mapped_column(
        Numeric(10, 2, decimal_return_scale=2), nullable=False
    )
    referencia: Mapped[str] = mapped_column(String(100), nullable=False)
    estado: Mapped[EstadoPago] = mapped_column(
        Enum(EstadoPago, name="estado_pago"),
        nullable=False,
        server_default="pendiente",
    )
    pasarela: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
