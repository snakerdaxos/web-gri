"""Menu ORM models: Categoria + Producto (Phase 3 domain).

Two tables live in this module because they form a single aggregate — a
`categoria` groups `producto` rows, and they are always queried together
(menú por categoría, REST-02 Phase 5). `producto.precio` is Numeric(10,2)
returning `decimal.Decimal` — exact COP, never Float (Pitfall 1 of the
research).
"""

import datetime as dt
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Categoria(Base):
    """Menu category (e.g. Entradas, Platos Fuertes).

    ``activo`` (migración 0005) es el soft-delete administrativo: la
    categoría desaparece del menú público PERO la fila vive (los FK de
    pedido_item siguen válidos). Distinto de ``producto.disponible``
    (agotado transitorio), que NO existe a nivel categoría.
    """

    __tablename__ = "categoria"
    __table_args__ = (
        UniqueConstraint("restaurant_id", "nombre", name="uq_categoria_restaurante_nombre"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    nombre: Mapped[str] = mapped_column(String(100), nullable=False)
    orden: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    activo: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=func.true()
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )


class Producto(Base):
    """A dish/drink sold by the restaurant. precio is exact COP (Decimal)."""

    __tablename__ = "producto"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    categoria_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("categoria.id"), nullable=False
    )
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(String(500), nullable=True)
    precio: Mapped[Decimal] = mapped_column(
        Numeric(10, 2, decimal_return_scale=2), nullable=False
    )
    imagen_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    disponible: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=func.true()
    )
    # Soft-delete administrativo (migración 0005): desaparece del menú
    # público, la historia de pedidos queda intacta. ≠ disponible (agotado
    # transitorio, SIGUE visible en /public con su flag — F5).
    activo: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=func.true()
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
