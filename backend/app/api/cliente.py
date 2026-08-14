"""Cliente router — perfil + reservas (AUTH-05, RESV-01..04).

Pitfall 2: todos los endpoints usan ``require_roles(RolUsuario.cliente)``
internamente ``get_current_user`` — NUNCA ``get_tenant_scope`` (que 403-s
clientes en deps/auth.py línea 122). El "tenant" de un cliente se deriva del
recurso (reserva.usuario_id), no del token.

Existence hiding (RESV-04): cancelar reserva ajena → 404 (no 403, no 200).
TransicionInvalidaError → 409 (estado terminal o transición inválida).
"""

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.state_machines import TransicionInvalidaError
from app.deps.auth import CurrentUser, require_roles
from app.models.usuario import RolUsuario
from app.schemas.auth import UserRead
from app.schemas.perfil import PerfilUpdate
from app.schemas.pedido import PedidoCreate, PedidoRead
from app.schemas.reserva import ReservaCreate, ReservaRead
from app.schemas.sesion import SesionCreate, SesionRead
from app.services import (
    cliente_service,
    pedido_service,
    reserva_service,
    sesion_service,
)

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


# --- MESA-05/06: sesión de mesa por QR --------------------------------------


@router.post("/sesiones", response_model=SesionRead)
async def abrir_sesion(
    response: Response,
    body: SesionCreate,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """MESA-05/06: abrir la sesión de la mesa escaneada (o re-escanear la
    propia). La mesa pasa a ocupada AL ABRIR (decisión locked).

    - 201 SesionRead (sesión nueva; mesa disponible/reservada → ocupada).
    - 200 SesionRead (idempotencia: re-escaneo de MI sesión activa).
    - 404 QR inexistente / restaurante inactivo.
    - 409 sesión ajena en la mesa / ya tengo sesión activa en otra mesa /
      mesa en limpieza (TransicionInvalidaError → aquí).
    """
    try:
        read, created = await sesion_service.abrir_sesion(
            session, user.id, body.codigo_qr
        )
    except TransicionInvalidaError as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"La mesa no puede ocuparse en su estado actual: {exc}",
        ) from exc
    response.status_code = (
        status.HTTP_201_CREATED if created else status.HTTP_200_OK
    )
    return read


@router.get("/sesiones/actual", response_model=SesionRead)
async def get_sesion_actual(
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """La sesión activa del cliente (joins display) o 404 si no tiene."""
    read = await sesion_service.sesion_actual(session, user.id)
    if read is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "No tienes una sesión activa"
        )
    return read


@router.post("/sesiones/actual/cuenta", response_model=SesionRead)
async def pedir_cuenta(
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """PAGO-01: solicitar la cuenta — marca solicita_cuenta=true +
    solicitada_en (idempotente: doble tap seguro). El staff lo ve como badge
    en la cola de pedidos."""
    return await sesion_service.solicitar_cuenta(session, user.id)


# --- PEDI-01/02/04: pedidos del cliente --------------------------------------


@router.post(
    "/pedidos", response_model=PedidoRead, status_code=status.HTTP_201_CREATED
)
async def crear_pedido(
    body: PedidoCreate,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """PEDI-01/02: crear pedido en estado=enviado. Total SIEMPRE server-side
    (precio del producto al POST, snapshot en pedido_item); el body NO
    acepta precios. 404 sesión inexistente/ajena/producto cross-restaurante;
    409 sesión inactiva/producto agotado; 422 items vacío/cantidad≤0."""
    return await pedido_service.crear_pedido(session, user.id, body)


@router.get("/pedidos/actual", response_model=list[PedidoRead])
async def list_pedidos_actual(
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    """PEDI-04: TODOS los pedidos de mi sesión activa (cualquier estado),
    newest first — el cliente hace polling 10s (WS llega en Phase 7)."""
    return await pedido_service.pedidos_de_sesion(session, user.id)
