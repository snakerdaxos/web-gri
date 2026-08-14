"""Pedido ORM models: Pedido + PedidoItem + EstadoPedido (Phase 3 domain).

A `pedido` is the order placed by a cliente for a specific mesa.
`pedido_item` snapshots `precio_unitario` at order time so that a later price
change on the `producto` does not mutate historical orders (locked decision —
REPO-01 Phase 8 reports must be exact at transaction time). `restaurant_id` is
denormalized onto pedido_item to simplify tenant-scoped aggregations (REPO-02).

`cantidad > 0` is enforced by a DB-level CHECK constraint (MySQL 8.0.16+),
the last line of defense beyond any service-layer validation.

EstadoPedido drives the kitchen-flow state machine; transitions live in
`app.core.state_machines.PEDIDO_TRANSITIONS` (rechazado & pagado are terminal).
"""

import datetime as dt
import enum
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EstadoPedido(str, enum.Enum):
    """Pedido lifecycle (PEDI-03 / ARCHITECTURE.md Pattern 5).

    borrador → enviado → aceptado → en_preparacion → servido → pagado
                                └→ rechazado (terminal)
    """

    borrador = "borrador"
    enviado = "enviado"
    aceptado = "aceptado"
    en_preparacion = "en_preparacion"
    servido = "servido"
    pagado = "pagado"
    rechazado = "rechazado"


class Pedido(Base):
    __tablename__ = "pedido"
    __table_args__ = (
        Index("ix_pedido_restaurante_estado", "restaurant_id", "estado"),
        Index("ix_pedido_mesa", "mesa_id"),
        Index("ix_pedido_usuario", "usuario_id"),
        # Phase 6 (migración 0004): relación explícita pedido↔sesión — el
        # service SIEMPRE la escribe (inferir por mesa+usuario+timestamps
        # sería frágil). Nullable para no romper filas previas.
        Index("ix_pedido_sesion", "sesion_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    mesa_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("mesa.id"), nullable=False
    )
    usuario_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("usuario.id"), nullable=False
    )
    sesion_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("sesion_mesa.id"), nullable=True
    )
    estado: Mapped[EstadoPedido] = mapped_column(
        Enum(EstadoPedido, name="estado_pedido"),
        nullable=False,
        server_default="borrador",
    )
    total: Mapped[Decimal] = mapped_column(
        Numeric(10, 2, decimal_return_scale=2), nullable=False, server_default="0"
    )
    notas: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class PedidoItem(Base):
    """One line of a pedido. precio_unitario is a snapshot (locked decision)."""

    __tablename__ = "pedido_item"
    __table_args__ = (
        CheckConstraint("cantidad > 0", name="ck_pedido_item_cantidad_positiva"),
        Index("ix_pedido_item_restaurante_producto", "restaurant_id", "producto_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    pedido_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("pedido.id"), nullable=False
    )
    producto_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("producto.id"), nullable=False
    )
    cantidad: Mapped[int] = mapped_column(Integer, nullable=False)
    precio_unitario: Mapped[Decimal] = mapped_column(
        Numeric(10, 2, decimal_return_scale=2), nullable=False
    )
    subtotal: Mapped[Decimal] = mapped_column(
        Numeric(10, 2, decimal_return_scale=2), nullable=False
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
