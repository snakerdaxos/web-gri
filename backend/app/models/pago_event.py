"""PagoEvent ORM model — dedup at-least-once + auditoría del webhook (Phase 9, PAGO-03).

La entrega de webhooks de Wompi es at-least-once y el payload NO trae un
``event.id`` único (verificado 09-RESEARCH §Contrato Wompi). La dedup usa
una clave DERIVADA: ``event_key = f"{transaction_id}:{status}"`` — única por
entrega lógica (una transacción cambia de status una vez; re-entregas del
mismo evento colisionan en el UNIQUE ``uq_pago_event_key`` → el handler
traduce ``IntegrityError`` a 200 no-op, JAMÁS 500: Wompi reintenta ante 5xx).

``pago_id`` es NULL-able: un webhook con referencia desconocida igual deja
fila de auditoría (pago_id NULL) antes de retornar sin efectos.

La tabla además es el log de qué eventos llegaron y cuándo (``payload`` crudo
en JSON + ``recibido_en``), y ``estado`` documenta el desenlace
(``procesado`` | ``monto-mismatch`` | ``voided-post-aprobado`` | ...).
"""

import datetime as dt

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PagoEvent(Base):
    __tablename__ = "pago_event"
    __table_args__ = (
        UniqueConstraint("event_key", name="uq_pago_event_key"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    # Clave derivada de dedup: f"{transaction_id}:{status}".
    event_key: Mapped[str] = mapped_column(String(150), nullable=False)
    # NULL = webhook con referencia desconocida (auditoría sin pago asociado).
    pago_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("pago.id"), nullable=True
    )
    payload: Mapped[str] = mapped_column(Text, nullable=False)
    recibido_en: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
    # procesado | monto-mismatch | voided-post-aprobado | ...
    estado: Mapped[str] = mapped_column(
        String(30), nullable=False, server_default="procesado"
    )
