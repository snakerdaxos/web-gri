"""pago.sesion_id NOT NULL + pedido_id nullable + transaction_id UNIQUE + tabla pago_event (Phase 9 — PAGO-02/03/04).

Revision ID: 0006
Revises: 0005_menu_activo
Create Date: 2026-08-15

Única migración del plan 09-01 Task 1:

1. ``pago.sesion_id`` BIGINT NULL → backfill → NOT NULL, FK ``sesion_mesa.id``
   + ``ix_pago_sesion`` — LA CUENTA ES DE LA SESIÓN (N pedidos), no de un
   pedido individual (hallazgo estructural del research: ``pago.pedido_id``
   NOT NULL de Phase 3 no modelaba "el total de mi consumo").
2. ``pago.pedido_id`` → NULLABLE (retrocompatible con tests existentes; el
   flujo nuevo de pago ya NO lo escribe).
3. ``pago.transaction_id`` VARCHAR(100) NULL UNIQUE ``uq_pago_transaction`` —
   id externo de la transacción Wompi; se llena al llegar el primer webhook.
4. ``pago_event`` — dedup at-least-once del webhook (PAGO-03): NO existe
   ``event.id`` en el payload Wompi (verificado 09-RESEARCH) → clave derivada
   ``event_key = f"{transaction_id}:{status}"`` UNIQUE. Además auditoría de
   qué eventos llegaron y cuándo (``payload`` + ``recibido_en``).

``DELETE FROM pago WHERE sesion_id IS NULL``: el backfill solo puede dejar
NULL los pagos cuyo pedido NO tenga sesión (residuo de tests pre-0004). La
tabla ``pago`` NO tiene datos de producción (el flujo de pago real nace en
esta fase) — el DELETE es la única salida limpia antes del NOT NULL.

Notas MySQL/SA 2.0 (lecciones STATE.md): booleanos server_default van con
``sa.text("0"|"1")`` — ``sa.true_()``/``sa.false_()`` no existen top-level.
Esta migración no crea booleanos; los ALTER de nullability en MySQL exigen
``existing_type`` explícito.

Downgrade espejo inverso — orden crítico (lección error 1553 de 0004): el FK
se dropea ANTES que el índice/columna que respalda.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "0006"
down_revision: Union[str, Sequence[str], None] = "0005_menu_activo"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Pago por SESIÓN — columna nueva NULLable primero (ninguna fila
    #    incumple así el ADD), luego backfill desde pedido.sesion_id (0004).
    op.add_column("pago", sa.Column("sesion_id", sa.BigInteger(), nullable=True))
    op.create_foreign_key(
        "fk_pago_sesion", "pago", "sesion_mesa", ["sesion_id"], ["id"]
    )
    op.create_index("ix_pago_sesion", "pago", ["sesion_id"])
    op.execute(
        "UPDATE pago JOIN pedido ON pago.pedido_id = pedido.id "
        "SET pago.sesion_id = pedido.sesion_id"
    )
    # Residuo pre-0004 (pagos cuyo pedido nunca tuvo sesión). Sin datos de
    # producción en pago — DELETE documentado arriba en el docstring.
    op.execute("DELETE FROM pago WHERE sesion_id IS NULL")
    op.alter_column(
        "pago", "sesion_id", existing_type=sa.BigInteger(), nullable=False
    )
    # 2. Retrocompatible: pedido_id nullable (ya no se escribe en el flujo).
    op.alter_column(
        "pago", "pedido_id", existing_type=sa.BigInteger(), nullable=True
    )
    # 3. Id externo de la transacción (se llena en el webhook; UNIQUE = una
    #    transacción de pasarela mapea a lo sumo un pago).
    op.add_column(
        "pago", sa.Column("transaction_id", sa.String(length=100), nullable=True)
    )
    op.create_unique_constraint("uq_pago_transaction", "pago", ["transaction_id"])
    # 4. Dedup at-least-once + auditoría del webhook (PAGO-03).
    op.create_table(
        "pago_event",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("event_key", sa.String(length=150), nullable=False),
        sa.Column("pago_id", sa.BigInteger(), nullable=True),
        sa.Column("payload", sa.Text(), nullable=False),
        sa.Column(
            "recibido_en",
            sa.DateTime(timezone=False),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "estado",
            sa.String(length=30),
            server_default="procesado",
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["pago_id"], ["pago.id"], name="fk_pago_event_pago"),
        sa.UniqueConstraint("event_key", name="uq_pago_event_key"),
    )


def downgrade() -> None:
    # Espejo inverso — FK antes que índice/columna (lección 1553 de 0004).
    op.drop_table("pago_event")
    op.drop_constraint("uq_pago_transaction", "pago", type_="unique")
    op.drop_column("pago", "transaction_id")
    # pedido_id vuelve a NOT NULL: el ORM nuevo no lo escribe, así que en
    # downgrade los pagos sin pedido se borran (sin datos de producción).
    op.execute("DELETE FROM pago WHERE pedido_id IS NULL")
    op.alter_column(
        "pago", "pedido_id", existing_type=sa.BigInteger(), nullable=False
    )
    op.drop_index("ix_pago_sesion", table_name="pago")
    op.drop_constraint("fk_pago_sesion", "pago", type_="foreignkey")
    op.drop_column("pago", "sesion_id")
