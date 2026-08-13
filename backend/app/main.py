"""FastAPI application entrypoint.

Uses the modern lifespan context manager (NOT the deprecated @app.on_event).
On shutdown the SQLAlchemy async engine pool is disposed cleanly.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import auth, health
from app.core.config import settings
from app.core.db import async_session_maker, engine
from app.services.bootstrap import ensure_super_admin


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # --- startup: bootstrap the platform super-admin if configured & absent ---
    async with async_session_maker() as session:
        await ensure_super_admin(session)
    yield
    # --- shutdown: close the pool cleanly ---
    await engine.dispose()


app = FastAPI(
    title="GRI API",
    version="0.1.0",
    lifespan=lifespan,
)
app.include_router(health.router)
app.include_router(auth.router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"app": "GRI API", "environment": settings.ENVIRONMENT}
