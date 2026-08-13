"""Health endpoint — proves the API <-> DB path end-to-end.

GET /health executes SELECT 1 against MySQL. Returns:
- 200 {"status":"ok","database":"connected"} when the DB answers
- 503 {"status":"error","database":"unreachable",...} when it does not

The 503 contract (rather than raising a 500) is correct for load balancers
and the docker-compose depends_on: service_healthy pattern.
"""

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(tags=["health"])


@router.get("/health")
async def health(session: AsyncSession = Depends(get_session)) -> JSONResponse:
    """Liveness + DB connectivity. Runs SELECT 1; 200 only if the DB answers."""
    try:
        result = await session.execute(text("SELECT 1"))
        result.scalar_one()
    except Exception as exc:  # noqa: BLE001 — surface any DB failure as 503
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "error",
                "database": "unreachable",
                "detail": str(exc),
            },
        )
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={"status": "ok", "database": "connected"},
    )
