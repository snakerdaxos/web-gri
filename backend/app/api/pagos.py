"""Pagos router — intención + estado del pago por sesión (PAGO-02, Phase 9).

El router de /cliente/pagos se monta SIEMPRE (auth-required, sin riesgo).
El sandbox (Task 3) es el que se monta condicionalmente según
``settings.SANDBOX_MODE`` — ver ``sandbox_router`` más abajo cuando aterrice.

Body de /intencion: VACÍO por diseño — el monto SIEMPRE se calcula
server-side (SUM de pedidos servido de la sesión activa).
"""

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.deps.auth import CurrentUser, require_roles
from app.models.usuario import RolUsuario
from app.schemas.pago import PagoEstadoRead, PagoIntencionRead
from app.services import pago_service

router = APIRouter(prefix="/cliente/pagos", tags=["pagos"])


@router.post("/intencion", response_model=PagoIntencionRead)
async def crear_intencion(
    response: Response,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """PAGO-02: crear (201) o reutilizar (200) la intención de pago de la
    sesión activa. Sin body — monto server-side siempre.

    404 sin sesión activa; 409 sin pedidos / pedidos en curso.
    """
    read, created = await pago_service.crear_intencion(session, user.id)
    response.status_code = (
        status.HTTP_201_CREATED if created else status.HTTP_200_OK
    )
    return read


@router.get("/{pago_id}", response_model=PagoEstadoRead)
async def get_estado(
    pago_id: int,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """Estado del pago para el polling post-checkout. Existence hiding:
    pago ajeno/inexistente → 404 idéntico."""
    return await pago_service.consultar_estado(session, user.id, pago_id)
