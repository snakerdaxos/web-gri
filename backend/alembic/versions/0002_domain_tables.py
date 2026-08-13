"""domain tables: mesa, categoria, producto, pedido, pedido_item, reserva,
sesion_mesa, pago, calificacion (Phase 3).

Revision ID: 0002
Revises: 0001
Create Date: 2026-08-13

Creates the 9 domain tables of the GRI platform in one cohesive migration.
Written by hand (precedent: 0001_initial.py) so every constraint matches the
ORM model exactly — autogenerate would still need manual review of names and
checks, so we skip it.

Key invariants declared here (defensa permanente para fases 4-9):
- ``uq_mesa_codigo_qr`` — QR GLOBALMENTE único (MESA-02 / SC3).
- ``uq_sesion_mesa_activa`` — una sola sesión activa por mesa, via columna
  generada ``activo_flag`` + UNIQUE(mesa_id, activo_flag) que explota la
  semántica SQL de que NULL ≠ NULL en índices unique (PITFALLS P6, RESEARCH
  Pattern 5).
- ``uq_pago_referencia`` — idempotencia de pagos (PITFALLS P4).
- ``uq_calificacion_pedido`` — una calificación por pedido (CALI-01).
- CHECK constraints: cantidad > 0, num_personas >= 1, estrellas 1-5
  (MySQL 8.0.16+ los enforce).

Orden FK-dependiente (cada tabla solo referencia tablas ya existentes):
  mesa → categoria → producto → pedido → pedido_item → reserva →
  sesion_mesa → pago → calificacion
Downgrade: orden exactamente inverso. drop_table arrastra los índices (lección
Phase 2: error 1553 si se hace drop_index explícito de índices que respaldan
FK/unique constraints).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002"
down_revision: Union[str, Sequence[str], None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- mesa (FK restaurante) ---
    op.create_table(
        "mesa",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("numero", sa.Integer(), nullable=False),
        sa.Column("capacidad", sa.SmallInteger(), nullable=False),
        sa.Column("codigo_qr", sa.String(length=32), nullable=False),
        sa.Column(
            "estado",
            sa.Enum("disponible", "reservada", "ocupada", "limpieza", name="estado_mesa"),
            server_default="disponible",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("restaurant_id", "numero", name="uq_mesa_restaurante_numero"),
        sa.UniqueConstraint("codigo_qr", name="uq_mesa_codigo_qr"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )

    # --- categoria (FK restaurante) ---
    op.create_table(
        "categoria",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("nombre", sa.String(length=100), nullable=False),
        sa.Column("orden", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "restaurant_id", "nombre", name="uq_categoria_restaurante_nombre"
        ),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index(
        "ix_categoria_restaurante_orden", "categoria", ["restaurant_id", "orden"]
    )

    # --- producto (FK restaurante, categoria) ---
    op.create_table(
        "producto",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("categoria_id", sa.BigInteger(), nullable=False),
        sa.Column("nombre", sa.String(length=150), nullable=False),
        sa.Column("descripcion", sa.String(length=500), nullable=True),
        sa.Column("precio", sa.Numeric(10, 2), nullable=False),
        sa.Column("imagen_url", sa.String(length=500), nullable=True),
        sa.Column(
            "disponible",
            sa.Boolean(),
            server_default=sa.text("1"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["categoria_id"], ["categoria.id"]),
        sa.PrimaryKeyConstraint("id"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index(
        "ix_producto_restaurante_categoria",
        "producto",
        ["restaurant_id", "categoria_id"],
    )

    # --- pedido (FK restaurante, mesa, usuario) ---
    op.create_table(
        "pedido",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("mesa_id", sa.BigInteger(), nullable=False),
        sa.Column("usuario_id", sa.BigInteger(), nullable=False),
        sa.Column(
            "estado",
            sa.Enum(
                "borrador",
                "enviado",
                "aceptado",
                "en_preparacion",
                "servido",
                "pagado",
                "rechazado",
                name="estado_pedido",
            ),
            server_default="borrador",
            nullable=False,
        ),
        sa.Column("total", sa.Numeric(10, 2), nullable=False, server_default=sa.text("0")),
        sa.Column("notas", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["mesa_id"], ["mesa.id"]),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.PrimaryKeyConstraint("id"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index(
        "ix_pedido_restaurante_estado", "pedido", ["restaurant_id", "estado"]
    )
    op.create_index("ix_pedido_mesa", "pedido", ["mesa_id"])
    op.create_index("ix_pedido_usuario", "pedido", ["usuario_id"])

    # --- pedido_item (FK restaurante, pedido, producto) ---
    op.create_table(
        "pedido_item",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("pedido_id", sa.BigInteger(), nullable=False),
        sa.Column("producto_id", sa.BigInteger(), nullable=False),
        sa.Column("cantidad", sa.Integer(), nullable=False),
        sa.Column("precio_unitario", sa.Numeric(10, 2), nullable=False),
        sa.Column("subtotal", sa.Numeric(10, 2), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["pedido_id"], ["pedido.id"]),
        sa.ForeignKeyConstraint(["producto_id"], ["producto.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint("cantidad > 0", name="ck_pedido_item_cantidad_positiva"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index(
        "ix_pedido_item_restaurante_producto",
        "pedido_item",
        ["restaurant_id", "producto_id"],
    )

    # --- reserva (FK restaurante, usuario, mesa) ---
    op.create_table(
        "reserva",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("usuario_id", sa.BigInteger(), nullable=False),
        sa.Column("mesa_id", sa.BigInteger(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("hora_inicio", sa.Time(), nullable=False),
        sa.Column("num_personas", sa.SmallInteger(), nullable=False),
        sa.Column(
            "estado",
            sa.Enum("pendiente", "confirmada", "cancelada", name="estado_reserva"),
            server_default="pendiente",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["mesa_id"], ["mesa.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "num_personas >= 1", name="ck_reserva_num_personas_positiva"
        ),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index("ix_reserva_mesa_fecha", "reserva", ["mesa_id", "fecha"])
    op.create_index(
        "ix_reserva_restaurante_fecha_estado",
        "reserva",
        ["restaurant_id", "fecha", "estado"],
    )
    op.create_index("ix_reserva_usuario", "reserva", ["usuario_id"])

    # --- sesion_mesa (FK restaurante, mesa, usuario) ---
    # activo_flag = columna generada: 1 mientras cerrada_en IS NULL, NULL si no.
    # UNIQUE(mesa_id, activo_flag) explota que MySQL ignora filas con NULL en
    # cualquier columna del índice unique → múltiples cerradas conviven, solo
    # UNA activa por mesa.
    op.create_table(
        "sesion_mesa",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("mesa_id", sa.BigInteger(), nullable=False),
        sa.Column("usuario_id", sa.BigInteger(), nullable=False),
        sa.Column(
            "estado",
            sa.Enum("activa", "cerrada", "expirada", name="estado_sesion"),
            server_default="activa",
            nullable=False,
        ),
        sa.Column(
            "abierta_en",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("cerrada_en", sa.DateTime(timezone=False), nullable=True),
        sa.Column(
            "activo_flag",
            sa.Integer(),
            sa.Computed("CASE WHEN cerrada_en IS NULL THEN 1 ELSE NULL END"),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["mesa_id"], ["mesa.id"]),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("mesa_id", "activo_flag", name="uq_sesion_mesa_activa"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index("ix_sesion_mesa_usuario", "sesion_mesa", ["usuario_id"])

    # --- pago (FK restaurante, pedido) ---
    op.create_table(
        "pago",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("pedido_id", sa.BigInteger(), nullable=False),
        sa.Column("monto", sa.Numeric(10, 2), nullable=False),
        sa.Column("referencia", sa.String(length=100), nullable=False),
        sa.Column(
            "estado",
            sa.Enum("pendiente", "aprobado", "rechazado", name="estado_pago"),
            server_default="pendiente",
            nullable=False,
        ),
        sa.Column("pasarela", sa.String(length=50), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["pedido_id"], ["pedido.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("referencia", name="uq_pago_referencia"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index("ix_pago_pedido", "pago", ["pedido_id"])

    # --- calificacion (FK restaurante, usuario, pedido) ---
    op.create_table(
        "calificacion",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("usuario_id", sa.BigInteger(), nullable=False),
        sa.Column("pedido_id", sa.BigInteger(), nullable=False),
        sa.Column("estrellas", sa.SmallInteger(), nullable=False),
        sa.Column("comentario", sa.String(length=1000), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["pedido_id"], ["pedido.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "estrellas BETWEEN 1 AND 5", name="ck_calificacion_estrellas_rango"
        ),
        sa.UniqueConstraint("pedido_id", name="uq_calificacion_pedido"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    op.create_index(
        "ix_calificacion_restaurante", "calificacion", ["restaurant_id"]
    )


def downgrade() -> None:
    # Orden INVERSOS de FKs. NO drop_index explícito: drop_table arrastra los
    # índices (lección Phase 2: error 1553 si se hace drop_index de un índice
    # que respalda un FK/unique constraint mientras la tabla existe).
    op.drop_table("calificacion")
    op.drop_table("pago")
    op.drop_table("sesion_mesa")
    op.drop_table("reserva")
    op.drop_table("pedido_item")
    op.drop_table("pedido")
    op.drop_table("producto")
    op.drop_table("categoria")
    op.drop_table("mesa")
