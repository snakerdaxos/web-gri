"""add UNIQUE (mesa_id, fecha, hora_inicio) on reserva (Phase 5 — PITFALLS P1).

Revision ID: 0003
Revises: 0002
Create Date: 2026-08-14

The last-line defense anti doble-reserva. Combined with hourly slots
(``hora_inicio`` always at ``:00``, 60-min effective turn — Phase 5 Concurrency
Design §1), this UNIQUE constraint is *sufficient* to prevent overlap: two
reservas on the same mesa/fecha can only differ in ``hora_inicio``, and two
``:00`` values are either identical (caught here) or differ by at least one
hour (no overlap with a 60-min turn).

The service layer also runs ``SELECT ... FOR UPDATE`` on candidate mesas
(``reserva_service.crear_reserva``) as the primary serialization path. The
UNIQUE here catches the rare race where two txns picked different candidate
mesas but one was already reserved between their SELECT and INSERT in a third
aborted tx — belt and suspenders. The matching ``IntegrityError → 409`` lives
in the service.

References:
- research/PITFALLS.md P1 (race condition reservas)
- 05-RESEARCH.md §Concurrency Design §1/§2

Migration safety: the demo seed creates 0 reservas, so the constraint applies
cleanly on a fresh DB. No pre-check needed (Phase 5 first write path).
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "0003"
down_revision: Union[str, Sequence[str], None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_reserva_mesa_fecha_hora",
        "reserva",
        ["mesa_id", "fecha", "hora_inicio"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_reserva_mesa_fecha_hora", "reserva", type_="unique"
    )
