"""Pago ORM model + EstadoPago enum (Phase 3 domain, re-shape Phase 9).

A `pago` records a payment attempt for a SESIÓN de mesa (migración 0006):
the bill covers N pedidos, so `sesion_id` is the anchor and `pedido_id` is
nullable legacy (no longer written by the payment flow). `referencia` is
GLOBALLY unique so that a replayed webhook or a double-submit cannot create
a second payment row for the same logical transaction, and `transaction_id`
(the pasarela's external txn id, filled by the webhook) is unique too — one
pasarela transaction maps to at most one pago.
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
        # Phase 9 (0006): una transacción de pasarela mapea a lo sumo un pago.
        UniqueConstraint("transaction_id", name="uq_pago_transaction"),
        Index("ix_pago_pedido", "pedido_id"),
        Index("ix_pago_sesion", "sesion_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    # Phase 9 (0006): la cuenta es de la SESIÓN (N pedidos).
    sesion_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("sesion_mesa.id"), nullable=False
    )
    # Legacy Phase 3 — nullable retrocompatible; el flujo de pago NO lo escribe.
    pedido_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("pedido.id"), nullable=True
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
    # Id externo de la transacción (sandbox-{referencia} o txn id Wompi);
    # se llena al llegar el primer webhook firmado.
    transaction_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
