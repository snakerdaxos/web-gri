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

Wave 0 open question (rechazo pre-accept): OBSERVADO contra el stack vivo —
uvicorn 0.52.3 + websockets rechaza el handshake con HTTP 403 cuando el
server raise WebSocketException ANTES del accept; el close code 4401/4400 NO
viaja en ese caso. ``_assert_ws_rejected`` acepta esa forma (B) y la de close
frame post-accept (A) — para el WsClient de 07-02/07-03 son el MISMO caso
(refresh + retry). Detalle y racional en el helper.
"""

import asyncio
from decimal import Decimal
from uuid import uuid4

import pytest
from httpx_ws import aconnect_ws
from sqlalchemy import delete, select

from app.models.menu import Categoria, Producto
from app.models.mesa import EstadoMesa, Mesa
from app.models.pedido import Pedido, PedidoItem
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import SesionMesa

from .conftest import (
    API_BASE,
    abrir_sesion,
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
    con ``.response`` status 403 y SIN close code entregable.

    Forma OBSERVADA contra el stack vivo (uvicorn 0.52.3 + websockets, server
    raising WebSocketException ANTES del accept): **Forma B — handshake
    rechazado con HTTP 403**; el close code 4401/4400 NO viaja pre-accept.
    El diseño conserva los códigos app-defined (RFC 6455 §7.4.1) porque son
    el contrato del cliente (07-02/07-03 los trata igual: refresh + retry) y
    pasarían a Forma A si el raise fuese post-accept o cambiara la impl ASGI.
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


async def _cleanup_restaurante(db_session, restaurant_id: int) -> None:
    """Borra el restaurante de test 13 con su menú (orden por FKs)."""
    await db_session.rollback()
    await db_session.execute(
        delete(Producto).where(Producto.restaurant_id == restaurant_id)
    )
    await db_session.execute(
        delete(Categoria).where(Categoria.restaurant_id == restaurant_id)
    )
    await db_session.execute(delete(Restaurante).where(Restaurante.id == restaurant_id))
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


# --- Task 2: eventos end-to-end (RT-01/02) -------------------------------------
#
# Setup común: cliente DEDICADO por test (UNIQUE 0004), mesa propia
# GRI-TEST-WS-*+uuid (nunca mesas del seed), sesión por el flujo real
# (POST /cliente/sesiones) y cleanup en finally (gotcha: assert fallido antes
# del cleanup filtra filas).


async def test_staff_recibe_pedido_creado(async_client, db_session):
    """Test 8 (RT-01): POST /cliente/pedidos → staff conectado recibe
    pedido.creado con pedido_id/estado/mesa_id y seq int (<1s esperado)."""
    user, token, headers = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    producto_id = await _producto_demo(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text
        sesion_id = resp.json()["id"]

        async with aconnect_ws(f"{WS_BASE}/ws/staff?token={cocina}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)
            pedido = await async_client.post(
                "/cliente/pedidos",
                json={
                    "sesion_id": sesion_id,
                    "items": [{"producto_id": producto_id, "cantidad": 1}],
                },
                headers=headers,
            )
            assert pedido.status_code == 201, pedido.text
            async with asyncio.timeout(2):
                event = await ws.receive_json()

        assert event["type"] == "pedido.creado"
        assert event["restaurante_id"] == 1
        assert event["data"]["pedido_id"] == pedido.json()["id"]
        assert event["data"]["estado"] == "enviado"
        assert event["data"]["mesa_id"] == mesa_id
        assert isinstance(event["seq"], int)
        assert isinstance(event["ts"], str)
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)


async def test_cliente_recibe_pedido_estado(async_client, db_session):
    """Test 9 (RT-01): transición staff → el CLIENTE dueño recibe
    pedido.estado en su user room con restaurante_id=None (contrato)."""
    user, token, headers = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    producto_id = await _producto_demo(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text
        sesion_id = resp.json()["id"]
        pedido_id = await _crear_pedido(async_client, headers, sesion_id, producto_id)

        async with aconnect_ws(f"{WS_BASE}/ws/cliente?token={token}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)
            assert await _avanzar(async_client, cocina, pedido_id, "aceptado") == 200
            async with asyncio.timeout(2):
                event = await ws.receive_json()

        assert event["type"] == "pedido.estado"
        assert event["restaurante_id"] is None  # user room → null por contrato
        assert event["data"]["estado"] == "aceptado"
        assert event["data"]["pedido_id"] == pedido_id
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)


async def test_mesa_estado_eventos(async_client, db_session):
    """Test 10 (RT-02): mesa.estado al abrir sesión (QR → ocupada) y al
    transicionar desde el panel (ocupada → limpieza)."""
    user, token, _ = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        async with aconnect_ws(f"{WS_BASE}/ws/staff?token={cocina}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)

            resp = await abrir_sesion(async_client, token, qr)  # → ocupada
            assert resp.status_code == 201, resp.text
            async with asyncio.timeout(2):
                e1 = await ws.receive_json()
            assert e1["type"] == "mesa.estado"
            assert e1["data"]["estado"] == "ocupada"
            assert e1["data"]["mesa_id"] == mesa_id

            r = await async_client.post(
                f"/staff/mesas/{mesa_id}/estado",
                json={"estado": "limpieza"},
                headers=auth_header(cocina),
            )
            assert r.status_code == 200, r.text
            async with asyncio.timeout(2):
                e2 = await ws.receive_json()
            assert e2["type"] == "mesa.estado"
            assert e2["data"]["estado"] == "limpieza"
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)


async def test_sesion_cuenta_evento(async_client, db_session):
    """Test 11 (RT-01): POST cuenta → staff recibe sesion.cuenta (y el dueño
    su ACK en user room); segundo POST NO emite (idempotencia de emisión)."""
    user, token, headers = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text
        sesion_id = resp.json()["id"]

        async with (
            aconnect_ws(f"{WS_BASE}/ws/staff?token={cocina}") as ws_staff,
            aconnect_ws(f"{WS_BASE}/ws/cliente?token={token}") as ws_cliente,
        ):
            await asyncio.sleep(_JOIN_SETTLE)
            r1 = await async_client.post(
                "/cliente/sesiones/actual/cuenta", headers=headers
            )
            assert r1.status_code == 200, r1.text
            async with asyncio.timeout(2):
                e_staff = await ws_staff.receive_json()
                e_cliente = await ws_cliente.receive_json()
            assert e_staff["type"] == "sesion.cuenta"
            assert e_staff["data"]["sesion_id"] == sesion_id
            assert e_staff["data"]["mesa_id"] == mesa_id
            assert e_staff["restaurante_id"] == 1
            assert e_cliente["type"] == "sesion.cuenta"  # ACK al dueño

            # Idempotencia (PAGO-01): el segundo POST NO emite NADA.
            r2 = await async_client.post(
                "/cliente/sesiones/actual/cuenta", headers=headers
            )
            assert r2.status_code == 200, r2.text
            with pytest.raises(TimeoutError):
                async with asyncio.timeout(0.8):
                    await ws_staff.receive_json()
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)


async def test_sesion_cerrada_user_room(async_client, db_session):
    """Test 12 (RT-03): anti-zombi — mesa→limpieza cierra la sesión y el
    CLIENTE recibe sesion.cerrada en su user room."""
    user, token, _ = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text

        async with aconnect_ws(f"{WS_BASE}/ws/cliente?token={token}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)
            r = await async_client.post(
                f"/staff/mesas/{mesa_id}/estado",
                json={"estado": "limpieza"},
                headers=auth_header(cocina),
            )
            assert r.status_code == 200, r.text
            async with asyncio.timeout(2):
                event = await ws.receive_json()

        assert event["type"] == "sesion.cerrada"
        assert event["restaurante_id"] is None
        assert event["data"]["mesa_id"] == mesa_id
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)


async def test_cross_tenant_aislamiento(async_client, db_session):
    """Test 13 (RT-03): pedido del restaurante 2 → 201 con emisión a SUS
    rooms; staff del restaurante 1 (demo) NO recibe NADA (rooms aisladas)."""
    user, token, headers = await _crear_cliente(async_client)
    # Restaurante 2 completo propio (cleanup finally).
    r2 = Restaurante(nombre=f"WS Cross {uuid4().hex[:6]}")
    db_session.add(r2)
    await db_session.flush()
    cat2 = Categoria(restaurant_id=r2.id, nombre="Test WS", orden=1)
    db_session.add(cat2)
    await db_session.flush()
    p2 = Producto(
        restaurant_id=r2.id,
        categoria_id=cat2.id,
        nombre="Plato WS",
        precio=Decimal("1000.00"),
    )
    db_session.add(p2)
    await db_session.commit()
    r2_id, p2_id = r2.id, p2.id  # ints planos (lección MissingGreenlet)
    mesa_id, qr = await _crear_mesa_ws(db_session, restaurant_id=r2_id)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")  # rest. 1
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text
        sesion_id = resp.json()["id"]

        async with aconnect_ws(f"{WS_BASE}/ws/staff?token={cocina}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)
            pedido = await async_client.post(
                "/cliente/pedidos",
                json={
                    "sesion_id": sesion_id,
                    "items": [{"producto_id": p2_id, "cantidad": 1}],
                },
                headers=headers,
            )
            assert pedido.status_code == 201, pedido.text  # emitió a r2 + user
            # El staff del restaurante 1 NO recibe NADA: timeout = esperado.
            with pytest.raises(TimeoutError):
                async with asyncio.timeout(1):
                    await ws.receive_json()
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)
        await _cleanup_restaurante(db_session, r2_id)


async def test_seq_monotonico(async_client, db_session):
    """Test 14 (RT-03): dos transiciones consecutivas de un pedido → seq
    e1 < e2 en el MISMO room (dedup/orden client-side)."""
    user, token, headers = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    producto_id = await _producto_demo(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text
        sesion_id = resp.json()["id"]
        pedido_id = await _crear_pedido(async_client, headers, sesion_id, producto_id)

        async with aconnect_ws(f"{WS_BASE}/ws/staff?token={cocina}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)
            assert await _avanzar(async_client, cocina, pedido_id, "aceptado") == 200
            async with asyncio.timeout(2):
                e1 = await ws.receive_json()
            assert await _avanzar(async_client, cocina, pedido_id, "en_preparacion") == 200
            async with asyncio.timeout(2):
                e2 = await ws.receive_json()

        assert e1["type"] == "pedido.estado"
        assert e2["type"] == "pedido.estado"
        assert isinstance(e1["seq"], int) and isinstance(e2["seq"], int)
        assert e1["seq"] < e2["seq"]
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)


async def test_transicion_invalida_no_emite(async_client, db_session):
    """Test 15 (PITFALL 3): transición inválida (servido→aceptado) → 409 SIN
    ningún evento — la emisión es estrictamente post-commit."""
    user, token, headers = await _crear_cliente(async_client)
    mesa_id, qr = await _crear_mesa_ws(db_session)
    producto_id = await _producto_demo(db_session)
    cocina = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    try:
        resp = await abrir_sesion(async_client, token, qr)
        assert resp.status_code == 201, resp.text
        sesion_id = resp.json()["id"]
        pedido_id = await _crear_pedido(async_client, headers, sesion_id, producto_id)
        # Cadena completa PRE-conexión (esos eventos no llegan al socket).
        assert await _avanzar(async_client, cocina, pedido_id, "aceptado") == 200
        assert await _avanzar(async_client, cocina, pedido_id, "en_preparacion") == 200
        assert await _avanzar(async_client, cocina, pedido_id, "servido") == 200

        async with aconnect_ws(f"{WS_BASE}/ws/staff?token={cocina}") as ws:
            await asyncio.sleep(_JOIN_SETTLE)
            r = await async_client.post(
                f"/staff/pedidos/{pedido_id}/estado",
                json={"estado": "aceptado"},  # servido→aceptado inválido
                headers=auth_header(cocina),
            )
            assert r.status_code == 409, r.text
            with pytest.raises(TimeoutError):
                async with asyncio.timeout(1):
                    await ws.receive_json()
    finally:
        await _cleanup_cliente(db_session, user["id"], mesa_id)
