"""SesionMesa ORM model + EstadoSesion enum (Phase 3 domain).

A `sesion_mesa` links an authenticated `usuario` to a `mesa` for the duration
of a dining session — the anti-spoofing anchor (PITFALLS P6 / MESA-06 in
Phase 6). Only the user who opened the session may place orders for that mesa.

The "one active session per mesa" invariant is enforced in the DATABASE (not
just the service layer) via Pattern 5 of the research: a generated column
`activo_flag` (1 while `cerrada_en IS NULL`, NULL otherwise) plus
`UNIQUE(mesa_id, activo_flag)`. MySQL excludes rows with NULL in any column of
a unique index, so any number of CLOSED sessions coexist, but only ONE active
session per mesa can ever exist — the database wins the race.
"""

import datetime as dt
import enum

from sqlalchemy import (
    BigInteger,
    Boolean,
    Computed,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EstadoSesion(str, enum.Enum):
    activa = "activa"
    cerrada = "cerrada"
    expirada = "expirada"


class SesionMesa(Base):
    __tablename__ = "sesion_mesa"
    __table_args__ = (
        UniqueConstraint("mesa_id", "activo_flag", name="uq_sesion_mesa_activa"),
        # Phase 6 (migración 0004): una sesión activa por USUARIO — misma
        # técnica de columna computada NULL-able. Un cliente no puede tener
        # sesión abierta en dos mesas a la vez.
        UniqueConstraint(
            "usuario_id", "activo_flag", name="uq_sesion_mesa_usuario_activa"
        ),
        Index("ix_sesion_mesa_usuario", "usuario_id"),
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
    estado: Mapped[EstadoSesion] = mapped_column(
        Enum(EstadoSesion, name="estado_sesion"),
        nullable=False,
        server_default="activa",
    )
    abierta_en: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
    cerrada_en: Mapped[dt.datetime | None] = mapped_column(
        DateTime(timezone=False), nullable=True
    )
    # Phase 6 (PAGO-01): el cliente pidió la cuenta. Idempotente en el
    # service (solicitar_cuenta NO re-escribe solicitada_en si ya es True).
    solicita_cuenta: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("0")
    )
    solicitada_en: Mapped[dt.datetime | None] = mapped_column(
        DateTime(timezone=False), nullable=True
    )
    # Generated column: 1 while session is open, NULL once closed.
    # MySQL excludes NULL rows from the unique index → only ONE active session
    # per mesa can ever exist (Pattern 5).
    activo_flag: Mapped[int | None] = mapped_column(
        Integer,
        Computed("CASE WHEN cerrada_en IS NULL THEN 1 ELSE NULL END"),
        nullable=True,
    )
