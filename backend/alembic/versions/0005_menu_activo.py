"""categoria.activo + producto.activo — soft-delete del menú (Phase 8 — MENU-01/02).

Revision ID: 0005_menu_activo
Revises: 0004
Create Date: 2026-08-14

Única migración del plan 08-01 Task 1:

1. ``categoria.activo`` (BOOLEAN NOT NULL server_default TRUE).
2. ``producto.activo`` idéntico.

Semántica (decision locked del research — PROHIBIDO reutilizar ``disponible``
como soft-delete):

- ``activo`` = soft-delete administrativo: el ítem desaparece del menú
  público (``public_service`` filtra ``activo IS TRUE``) PERO la fila vive —
  los ``pedido_item`` FK siguen válidos y la historia de ventas queda
  intacta.
- ``disponible`` = agotado TRANSITORIO (vuelve solo): SIGUE visible en
  /public con su flag (behavior F5 intocado).

``server_default=sa.text("1")`` — NO ``sa.true_()`` (no existe top-level en
SA 2.0; gotcha STATE.md junto con el espejo de 0004 que usa ``sa.text("0")``
para FALSE). ``sa.text("1")`` backfilla las filas existentes del demo en el
mismo ALTER: el menú público no cambia tras el upgrade.

Downgrade espejo exacto (drop en orden inverso; sin FKs que dependan de
estas columnas, no hay orden crítico entre tablas).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "0005_menu_activo"
down_revision: Union[str, Sequence[str], None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # MENU-01 — soft-delete de categorías (desaparece de /public, historia viva).
    op.add_column(
        "categoria",
        sa.Column("activo", sa.Boolean(), server_default=sa.text("1"), nullable=False),
    )
    # MENU-02 — soft-delete de productos (≠ disponible/agotado).
    op.add_column(
        "producto",
        sa.Column("activo", sa.Boolean(), server_default=sa.text("1"), nullable=False),
    )


def downgrade() -> None:
    op.drop_column("producto", "activo")
    op.drop_column("categoria", "activo")
