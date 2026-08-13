"""initial: restaurante + usuario (Phase 2 auth + tenancy foundation)

Revision ID: 0001
Revises:
Create Date: 2026-08-13

First migration. Creates the two permanent tables of the platform:
- `restaurante`: the tenant root.
- `usuario`: global principals with a 5-value role enum and a nullable
  `restaurant_id` FK (NULL for super_admin & cliente).

Written by hand (not autogenerate) so the constraints match the ORM model
exactly. utf8mb4 charset + utf8mb4_unicode_ci collation on both tables to stay
consistent with the MySQL server collation set in docker-compose (Phase 1).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- restaurante (tenant root) ---
    op.create_table(
        "restaurante",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("nombre", sa.String(length=150), nullable=False),
        sa.Column("descripcion", sa.String(length=500), nullable=True),
        sa.Column("tipo_cocina", sa.String(length=100), nullable=True),
        sa.Column("direccion", sa.String(length=255), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )

    # --- usuario (global principals) ---
    op.create_table(
        "usuario",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("nombre", sa.String(length=150), nullable=False),
        sa.Column("email", sa.String(length=254), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "role",
            sa.Enum(
                "super_admin",
                "admin_restaurante",
                "mesero",
                "cocina",
                "cliente",
                name="rol_usuario",
            ),
            nullable=False,
        ),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email", name="uq_usuario_email"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index("ix_usuario_email", "usuario", ["email"])
    op.create_index("ix_usuario_role", "usuario", ["role"])
    op.create_index("ix_usuario_restaurant_id", "usuario", ["restaurant_id"])


def downgrade() -> None:
    # Reverse FK order: drop usuario first (it references restaurante).
    # NOTE: we do NOT drop_index explicitly — MySQL refuses to drop an index
    # that backs a FOREIGN KEY constraint (error 1553) while the table still
    # exists. Dropping the table cascades to its indexes automatically, which
    # is both correct and simpler.
    op.drop_table("usuario")
    op.drop_table("restaurante")
