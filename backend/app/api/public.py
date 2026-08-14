"""Public router — restaurante discovery + menú detalle (REST-01/02).

NO auth dependency: anyone can discover active restaurantes and their menús.
This is the discovery surface the app_cliente consumes before login, plus the
menú shown after scanning a mesa QR (Phase 6). No tenant filter — the public
list is global (active restaurantes from any tenant).
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.schemas.menu import RestauranteDetalle, RestaurantePublico
from app.services import public_service

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/restaurantes", response_model=list[RestaurantePublico])
async def list_public_restaurantes(
    session: AsyncSession = Depends(get_session),
):
    """REST-01: active restaurantes (no auth). ``calificacion`` is always
    None in Phase 5."""
    return await public_service.list_public_restaurantes(session)


@router.get(
    "/restaurantes/{restaurante_id}", response_model=RestauranteDetalle
)
async def get_public_restaurante(
    restaurante_id: int, session: AsyncSession = Depends(get_session)
):
    """REST-02: restaurante + nested menú (no auth). 404 if unknown/inactive."""
    return await public_service.get_public_restaurante_detalle(
        session, restaurante_id
    )
