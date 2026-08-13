"""SQLAlchemy 2.0 async engine + session factory + FastAPI dependency.

Key invariants (set ONCE so Phase 2+ doesn't inherit broken defaults):
- pool_pre_ping=True  -> stale connections (MySQL "server has gone away") are detected
- expire_on_commit=False -> avoid lazy-load after commit in async context
                         (prevents MissingGreenlet / "IO should be performed from a coroutine")
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    pool_pre_ping=True,  # validate connections before checkout
    pool_size=10,
    max_overflow=20,
    pool_recycle=3600,  # recycle conns before MySQL's wait_timeout
    future=True,
)

async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # CRITICAL: prevent lazy I/O after commit in async context
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that yields a scoped AsyncSession per request."""
    async with async_session_maker() as session:
        yield session
