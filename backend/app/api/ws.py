"""Endpoints WebSocket — /ws/staff + /ws/cliente (Phase 7, RT-01..03).

Auth JWT por QUERY PARAM (``?token=``): el browser no permite headers custom
en el handshake WS — mismo patrón del ejemplo canónico de la doc de FastAPI.
``decode_token`` verifica firma HS256 + exp completos; adicionalmente se
exige ``type == "access"`` y usuario existente + activo. Cualquier fallo →
``WebSocketException(code=4401)`` ANTES de entrar al room (sin join).

CRÍTICO — PROHIBIDO inyectar la dependency de sesión (yield) de los routers
REST en este archivo (threat #3 del plan): esa sesión viviría hasta el
CIERRE de la conexión WS, sostendría el checkout del pool toda la vida del
socket y N conexiones agotarían el pool (Pitfall 1 del research). ``_ws_user``
abre ``async_session_maker()`` en un ``async with`` corto (1 SELECT por PK) y
la sesión se cierra en el acto.

Rooms (aislamiento cross-tenant — threat #2):
- staff → ``restaurant:{rid}`` donde rid sale SIEMPRE del TOKEN (nunca de un
  param). super_admin requiere ``?restaurante_id=`` explícito (4400 sin él —
  mirror de ``_resolve_rid``); para staff el param se IGNORA.
- cliente → ``user:{id}``. Un cliente NUNCA entra a rooms de restaurante
  (privacidad de otros comensales) → 4401 si lo intenta.

El receive loop descarta todo texto entrante (no hay client→server en v1);
solo mantiene viva la conexión. Heartbeat: protocol-level de uvicorn
(ping 20s / timeout 20s) — sin ping/pong app-level (Pattern 5 del research).
"""

import jwt
from fastapi import (
    APIRouter,
    Query,
    WebSocket,
    WebSocketDisconnect,
    WebSocketException,
)

from app.core.broadcaster import broadcaster
from app.core.db import async_session_maker
from app.core.security import decode_token
from app.models.usuario import RolUsuario, Usuario

router = APIRouter()

_WS_CLOSE_UNAUTHENTICATED = 4401  # app-defined (RFC 6455 §7.4.1: 4000-4999)
_WS_CLOSE_BAD_REQUEST = 4400


async def _ws_user(token: str) -> Usuario:
    """Auth del handshake. SIN la dependency de sesión de los routers REST
    (que vive tanto como la conexión WS y agotaría el pool): sesión corta y
    al cierre."""
    try:
        payload = decode_token(token)
    except jwt.PyJWTError:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED) from None
    if payload.get("type") != "access":  # refresh NO es access (PITFALL 6)
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    try:
        user_id = int(payload["sub"])
    except (KeyError, ValueError):
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED) from None
    async with async_session_maker() as session:  # abre → 1 get por PK → cierra
        user = await session.get(Usuario, user_id)
    if user is None or not user.activo:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    return user


async def _listen(websocket: WebSocket, room: str) -> None:
    """Receive loop compartido: descarta entrante, mantiene viva, leave al salir."""
    await broadcaster.connect(websocket, room)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await broadcaster.disconnect(websocket, room)


@router.websocket("/ws/staff")
async def ws_staff(
    websocket: WebSocket,
    token: str = Query(...),
    restaurante_id: int | None = Query(default=None),
):
    """Room ``restaurant:{rid}`` — cocina/mesero/admin (y super_admin con param).

    No se valida la existencia del restaurante: un rid inexistente
    simplemente no recibe eventos (decisión del research — sin 4404 en v1).
    """
    user = await _ws_user(token)
    if user.role == RolUsuario.cliente:  # jamás rooms de restaurante
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)

    # Para staff el rid sale del TOKEN (el param se IGNORA — mirror
    # _resolve_rid de staff.py). super_admin sin restaurant_id en el token →
    # param requerido (4400). Staff sin restaurante (cuenta mal configurada)
    # también cae en el 4400.
    rid = user.restaurant_id if user.role != RolUsuario.super_admin else restaurante_id
    if rid is None:
        raise WebSocketException(code=_WS_CLOSE_BAD_REQUEST)

    await _listen(websocket, f"restaurant:{rid}")


@router.websocket("/ws/cliente")
async def ws_cliente(websocket: WebSocket, token: str = Query(...)):
    """Room ``user:{id}`` — solo rol cliente (staff → 4401)."""
    user = await _ws_user(token)
    if user.role != RolUsuario.cliente:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    await _listen(websocket, f"user:{user.id}")
