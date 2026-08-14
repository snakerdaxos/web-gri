"""Cliente router — perfil + reservas (AUTH-05, RESV-01..04).

Pitfall 2: todos los endpoints usan ``require_roles(RolUsuario.cliente)``
internamente ``get_current_user`` — NUNCA ``get_tenant_scope`` (que 403-s
clientes en deps/auth.py línea 122). El "tenant" de un cliente se deriva del
recurso (reserva.usuario_id), no del token.

Existence hiding (RESV-04): cancelar reserva ajena → 404 (no 403, no 200).
TransicionInvalidaError → 409 (estado terminal o transición inválida).
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.state_machines import TransicionInvalidaError
from app.deps.auth import CurrentUser, require_roles
from app.models.usuario import RolUsuario
from app.schemas.auth import UserRead
from app.schemas.perfil import PerfilUpdate
from app.schemas.reserva import ReservaCreate, ReservaRead
from app.services import cliente_service, reserva_service

router = APIRouter(prefix="/cliente", tags=["cliente"])


# --- AUTH-05: perfil ------------------------------------------------------


@router.get("/perfil", response_model=UserRead)
async def get_perfil(
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """AUTH-05 ver: perfil del cliente autenticado."""
    return await cliente_service.get_perfil(session, user.id)


@router.patch("/perfil", response_model=UserRead)
async def update_perfil(
    body: PerfilUpdate,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """AUTH-05 editar: nombre required; password opcional; email immutable
    (rechazado con 422 por ``PerfilUpdate.extra="forbid"``)."""
    return await cliente_service.update_perfil(session, user.id, body)


# --- RESV-01..04: reservas ------------------------------------------------


@router.get("/reservas", response_model=list[ReservaRead])
async def list_reservas(
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """RESV-03: reservas del cliente, ordenadas DESC por fecha/hora."""
    return await reserva_service.list_reservas_usuario(session, user.id)


@router.post(
    "/reservas", response_model=ReservaRead, status_code=status.HTTP_201_CREATED
)
async def crear_reserva(
    body: ReservaCreate,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """RESV-01 + RESV-02: crear reserva (concurrent-safe). El servidor
    asigna la mesa automáticamente (Phase 5 §3)."""
    try:
        return await reserva_service.crear_reserva(session, user.id, body)
    except TransicionInvalidaError:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Conflicto de estado de mesa"
        )


@router.post(
    "/reservas/{reserva_id}/cancelar", response_model=ReservaRead
)
async def cancelar_reserva(
    reserva_id: int,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """RESV-04: cancelar reserva futura propia. Existence hiding: 404 si es
    ajena. Pitfall 4: mesa revertida a disponible solo si estaba reservada."""
    try:
        return await reserva_service.cancelar_reserva(session, user.id, reserva_id)
    except TransicionInvalidaError:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "La reserva no puede cancelarse"
        )
