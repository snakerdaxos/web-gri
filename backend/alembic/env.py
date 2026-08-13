"""Alembic environment — async (run_sync pattern).

Alembic itself is synchronous; we bridge to the async SQLAlchemy engine via
`async_engine_from_config` + `connection.run_sync(...)`. The DB URL is injected
from `app.core.config.settings.database_url` (the same .env that drives the app)
so migrations and app never drift apart.

RESEARCH Code Examples — "Alembic async env.py".
"""

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.core.config import settings
from app.models.base import Base
# IMPORTANT: import every model module so Base.metadata is fully populated.
# Without these imports Alembic autogenerate would see an empty metadata.
from app.models import restaurante, usuario  # noqa: F401

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Inject the async URL from settings (overrides alembic.ini sqlalchemy.url).
config.set_main_option("sqlalchemy.url", settings.database_url)
target_metadata = Base.metadata


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


run_migrations_online()
