"""Declarative base for all ORM models.

Central Base so Alembic sees the full metadata in one place (env.py imports
every model module, then reads `Base.metadata`). Phase 2 introduces this;
Phase 3+ models inherit from the same Base.
"""

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
