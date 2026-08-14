"""Tests WebSocket Phase 7 (07-01) — conexión/auth (Task 1) + eventos (Task 2).

Corren contra el stack Docker VIVO (filosofía del proyecto) con httpx-ws
(``aconnect_ws`` sobre http://localhost:8000). El contenedor api NO tiene
volume mount: reconstruir con ``docker compose up -d --build api`` antes de
cada corrida tras cambiar código del server.

Task 1 (auth del handshake — RT-03):

- Staff demo conecta a /ws/staff?token=... → OK (room restaurant:{id}).
- Cliente registrado conecta a /ws/cliente?token=... → OK (room user:{id}).
- token=basura / refresh token / rol cliente en /ws/staff → rechazo 4401.
- super_admin SIN ?restaurante_id= en /ws/staff → rechazo 4400.

Wave 0 open question (rechazo pre-accept): el rechazo puede llegar como close
frame con el code (post-accept) o como handshake HTTP rechazado (pre-accept;
httpx-ws lo envuelve en ``WebSocketUpgradeError``). ``_assert_ws_rejected``
acepta ambas formas — para el WsClient de 07-02/07-03 son el MISMO caso
(refresh + retry). La forma observada está documentada en el helper.
"""

import asyncio
from uuid import uuid4

from httpx_ws import aconnect_ws
from sqlalchemy import delete, select

from app.models.menu import Producto
from app.models.mesa import EstadoMesa, Mesa
from app.models.pedido import Pedido, PedidoItem
from app.models.sesion_mesa import SesionMesa

from .conftest import (
    API_BASE,
    auth_header,
    login,
    login_staff_demo,
    register_cliente,
)

WS_BASE = API_BASE  # http://localhost:8000 — httpx-ws hace el upgrade WS

# Holgura tras el handshake: el server hace accept() y luego agrega el socket
# al set del room; el sleep elimina la (ínfima) carrera join-vs-publish.
_JOIN_SETTLE = 0.2


def _assert_ws_rejected(exc: BaseException, expected_code: int) -> None:
    """Assert del rechazo del handshake/close, aceptando ambas formas (Wave 0).

    Forma A: close frame post-accept → ``WebSocketDisconnect`` con ``.code``
    == expected_code (4401/4400 según el caso).
    Forma B: handshake HTTP rechazado pre-accept → ``WebSocketUpgradeError``
    con ``.response`` status 400/403 y SIN close code entregable.

    Forma OBSERVADA contra el stack vivo (uvicorn 0.52.3 + websockets):
    [actualizado tras el primer run GREEN — ver comentario abajo].
    """
    code = getattr(exc, "code", None)
    if code is not None:  # Forma A: close frame con código
        assert code == expected_code, (
            f"close code {code} != esperado {expected_code}: {exc!r}"
        )
        return
    response = getattr(exc, "response", None)  # Forma B: handshake rechazado
    assert response is not None and response.status_code in (400, 403), (
        f"forma de rechazo inesperada (esperaba close {expected_code} o "
        f"handshake 400/403): {exc!r}"
    )


async def _expect_ws_rejected(url: str, expected_code: int) -> None:
    """Conecta esperando el rechazo; falla si la conexión fuese aceptada."""
    rejected = False
    try:
        async with aconnect_ws(url) as ws:
            # Si el server aceptó y luego cerró, el receive entrega el close.
            await asyncio.wait_for(ws.receive_json(), timeout=2)
    except Exception as exc:  # ambas formas de rechazo llegan como excepción
        rejected = True
        _assert_ws_rejected(exc, expected_code)
    assert rejected, "el server debió rechazar la conexión WS"


async def _crear_cliente(client, *, nombre="WS Test") -> tuple[dict, str, dict]:
    """Cliente dedicado por test (gotcha UNIQUE 0004 — una sesión activa por
    usuario) → (body, access_token, headers)."""
    body = await register_cliente(client, nombre=nombre)
    access, _ = await login(client, body["email"], body["_password"])
    return body, access, auth_header(access)


# --- Task 2: helpers de datos (mesa propia por test — NUNCA mesas del seed) ---


async def _crear_mesa_ws(db_session, *, restaurant_id: int = 1) -> tuple[int, str]:
    """Mesa propia con QR único (uuid — re-runs seguros sobre BD compartida).

    Estado inicial ``disponible`` para que abrir sesión la transicione a
    ocupada por el flujo real (POST /cliente/sesiones).
    """
    qr = f"GRI-TEST-WS-{uuid4().hex[:10]}"
    mesa = Mesa(
        restaurant_id=restaurant_id,
        numero=int(uuid4().hex[:5], 16) % 90_000 + 9_000,
        capacidad=2,
        codigo_qr=qr,
        estado=EstadoMesa.disponible,
    )
    db_session.add(mesa)
    await db_session.commit()
    mesa_id = mesa.id  # int plano ANTES de cualquier expire (MissingGreenlet)
    return mesa_id, qr


async def _producto_demo(db_session) -> int:
    """id (int plano) del 'Bandeja Paisa' del seed (restaurante 1)."""
    await db_session.rollback()
    db_session.expire_all()
    return (
        await db_session.execute(
            select(Producto.id).where(
                Producto.restaurant_id == 1,
                Producto.nombre == "Bandeja Paisa",
            )
        )
    ).scalar_one()


async def _crear_pedido(client, headers, sesion_id: int, producto_id: int) -> int:
    """POST /cliente/pedidos → 201 → pedido_id (flujo real del core value)."""
    resp = await client.post(
        "/cliente/pedidos",
        json={
            "sesion_id": sesion_id,
            "items": [{"producto_id": producto_id, "cantidad": 1}],
        },
        headers=headers,
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


async def _avanzar(client, token: str, pedido_id: int, estado: str) -> int:
    """POST /staff/pedidos/{id}/estado (token cocina) → status code."""
    resp = await client.post(
        f"/staff/pedidos/{pedido_id}/estado",
        json={"estado": estado},
        headers=auth_header(token),
    )
    return resp.status_code


async def _cleanup_cliente(db_session, user_id: int, mesa_id: int | None = None) -> None:
    """Cleanup total del flujo de un test: pedidos → sesión → mesa propia.

    Borra (no cierra) las filas creadas por el test para dejar CERO residuo
    en la BD compartida (re-runs seguros). Orden por FKs.
    """
    await db_session.rollback()
    await db_session.execute(
        delete(PedidoItem).where(
            PedidoItem.pedido_id.in_(
                select(Pedido.id).where(Pedido.usuario_id == user_id)
            )
        )
    )
    await db_session.execute(delete(Pedido).where(Pedido.usuario_id == user_id))
    await db_session.execute(delete(SesionMesa).where(SesionMesa.usuario_id == user_id))
    if mesa_id is not None:
        await db_session.execute(delete(Mesa).where(Mesa.id == mesa_id))
    await db_session.commit()


# --- Task 1: conexión OK ------------------------------------------------------


async def test_staff_conecta_ok(async_client):
    """Test 1: cocina@demo.gri.dev conecta a /ws/staff → handshake OK."""
    token = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    async with aconnect_ws(f"{WS_BASE}/ws/staff?token={token}"):
        await asyncio.sleep(_JOIN_SETTLE)  # join al room completado


async def test_cliente_conecta_ok(async_client):
    """Test 2: cliente registrado conecta a /ws/cliente → OK."""
    _, token, _ = await _crear_cliente(async_client)
    async with aconnect_ws(f"{WS_BASE}/ws/cliente?token={token}"):
        await asyncio.sleep(_JOIN_SETTLE)


# --- Task 1: rechazos del handshake (RT-03) ------------------------------------


async def test_token_basura_4401(async_client):
    """Test 3: token inválido → rechazo 4401 ANTES de entrar al room."""
    await _expect_ws_rejected(f"{WS_BASE}/ws/staff?token=basura", 4401)


async def test_refresh_token_4401(async_client):
    """Test 4: refresh token (type incorrecto) en /ws/staff → 4401."""
    _, refresh = await login(async_client, "cocina@demo.gri.dev", "Demo!1234")
    await _expect_ws_rejected(f"{WS_BASE}/ws/staff?token={refresh}", 4401)


async def test_rol_cliente_en_ws_staff_4401(async_client):
    """Test 5: rol cliente en /ws/staff → 4401 (jamás entra a rooms de
    restaurante — privacidad de otros comensales, threat #2)."""
    _, token, _ = await _crear_cliente(async_client, nombre="Cliente Intruso")
    await _expect_ws_rejected(f"{WS_BASE}/ws/staff?token={token}", 4401)


async def test_super_admin_sin_restaurante_4400(async_client, super_admin_token):
    """Test 6: super_admin SIN ?restaurante_id= en /ws/staff → 4400 (param
    explícito requerido — mirror de _resolve_rid)."""
    await _expect_ws_rejected(f"{WS_BASE}/ws/staff?token={super_admin_token}", 4400)
