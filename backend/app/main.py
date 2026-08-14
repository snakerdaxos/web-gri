"""FastAPI application entrypoint.

Uses the modern lifespan context manager (NOT the deprecated @app.on_event).
On shutdown the SQLAlchemy async engine pool is disposed cleanly.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import admin, auth, health, public, staff
from app.core.config import settings
from app.core.db import async_session_maker, engine
from app.services.bootstrap import ensure_super_admin
from app.services.seed_service import seed_if_demo_mode


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # --- startup: bootstrap the platform super-admin if configured & absent ---
    async with async_session_maker() as session:
        await ensure_super_admin(session)
        # Phase 3: seed demo restaurante (PLAT-04). Gate inside the service;
        # no-op when DEMO_MODE=false (PITFALL 4 — defense-in-depth).
        await seed_if_demo_mode(session)
    yield
    # --- shutdown: close the pool cleanly ---
    await engine.dispose()


app = FastAPI(
    title="GRI API",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS (Phase 4, T-04-01): the panel web (Plan 04-02) runs on a different
# origin (:5173) than the API (:8000) — without this middleware every browser
# request dies at preflight (research Pitfall 1). Origins are EXPLICIT, parsed
# from the comma-separated CORS_ORIGINS setting — never "*" (incompatible with
# allow_credentials=True).
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.CORS_ORIGINS.split(",") if o.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(staff.router)
app.include_router(public.router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"app": "GRI API", "environment": settings.ENVIRONMENT}
