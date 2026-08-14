"""sesion_mesa.solicita_cuenta/solicitada_en + uq_sesion_mesa_usuario_activa
+ pedido.sesion_id FK (Phase 6 — sesión QR, pedidos y cuenta).

Revision ID: 0004
Revises: 0003
Create Date: 2026-08-14

Única migración de la fase (06-01 Task 1):

1. ``sesion_mesa.solicita_cuenta`` (BOOLEAN NOT NULL server_default FALSE) +
   ``solicitada_en`` (DATETIME NULL) — PAGO-01: el cliente pidió la cuenta;
   el staff lo ve como badge en la cola de pedidos.
2. ``UNIQUE (usuario_id, activo_flag)`` — una sesión activa por USUARIO,
   misma técnica de columna computada NULL-able que el UNIQUE por mesa de
   0002 (verificado 0002 + tests): MySQL ignora filas con NULL en cualquier
   columna del índice unique → las sesiones cerradas conviven.
3. ``pedido.sesion_id`` (BIGINT NULL FK → sesion_mesa.id) +
   ``ix_pedido_sesion`` — relación explícita pedido↔sesión. Nullable para no
   romper filas previas (en la práctica la tabla está vacía en dev); el
   service SIEMPRE la escribe.

Migration safety: la tabla pedido está vacía en la BD demo y las sesiones
existentes (ninguna en dev prístino) reciben solicita_cuenta=FALSE por el
server_default — el constraint UNIQUE aplica limpio.

Downgrade espejo exacto — orden crítico en MySQL: el FK de pedido.sesion_id
se dropea ANTES que el índice/columna (lección error 1553: un índice que
respalda un FK no se puede dropear primero).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "0004"
down_revision: Union[str, Sequence[str], None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. PAGO-01 — flag de cuenta solicitada.
    op.add_column(
        "sesion_mesa",
        sa.Column(
            "solicita_cuenta", sa.Boolean(), server_default=sa.text("0"), nullable=False
        ),
    )
    op.add_column(
        "sesion_mesa",
        sa.Column("solicitada_en", sa.DateTime(timezone=False), nullable=True),
    )
    # 2. Una sesión activa por usuario (columna computada de 0002).
    op.create_unique_constraint(
        "uq_sesion_mesa_usuario_activa", "sesion_mesa", ["usuario_id", "activo_flag"]
    )
    # 3. Relación explícita pedido↔sesión.
    op.add_column("pedido", sa.Column("sesion_id", sa.BigInteger(), nullable=True))
    op.create_foreign_key(
        "fk_pedido_sesion", "pedido", "sesion_mesa", ["sesion_id"], ["id"]
    )
    op.create_index("ix_pedido_sesion", "pedido", ["sesion_id"])


def downgrade() -> None:
    # Espejo exacto en orden inverso (FK antes que índice/columna).
    op.drop_index("ix_pedido_sesion", table_name="pedido")
    op.drop_constraint("fk_pedido_sesion", "pedido", type_="foreignkey")
    op.drop_column("pedido", "sesion_id")
    op.drop_constraint(
        "uq_sesion_mesa_usuario_activa", "sesion_mesa", type_="unique"
    )
    op.drop_column("sesion_mesa", "solicitada_en")
    op.drop_column("sesion_mesa", "solicita_cuenta")
