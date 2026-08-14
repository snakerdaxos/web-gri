"""Tests ADMN-03 — GET /staff/clientes + GET /staff/clientes/{id}/historial.

Contrato (plan 08-01 Task 3):

- ``GET /staff/clientes`` lista SOLO los usuarios con pedidos EN el tenant del
  caller (JOIN pedido→usuario, GROUP BY usuario; count + SUM(total) sobre
  TODOS los estados — decisión documentada), ordenado por total_gastado DESC.
  ``total_gastado`` viaja como JSON number (field_serializer — Pitfall 1:
  SUM devuelve Decimal).
- ``GET /staff/clientes/{usuario_id}/historial``: pedidos del usuario EN el
  tenant reusando PedidoStaffRead (items con nombre, mesa_numero,
  usuario_nombre). Usuario SIN pedidos en el tenant → 404 (existence hiding
  relacional: no revela que el usuario_id existe globalmente).
- Cross-tenant: el cliente del tenant 1 JAMÁS aparece para staff del tenant B.
- super_admin sin ?restaurante_id= → 400 (contrato uniforme _resolve_rid).

Fixture: usuario DEDICADO por test (UNIQUE sesión activa por usuario —
gotcha 0004) + sesión en GRI-MESA-002 + pedido real vía POST /cliente/pedidos
con items del menú demo (API F6). Cleanup en finally: borra los pedidos del
usuario y restaura la mesa a disponible VÍA API (ocupada→limpieza→disponible
— cierra la sesión anti-zombi, restaura el invariante del seed).
"""

from uuid import uuid4

import pytest
from sqlalchemy import delete, func, select, update

from app.models.mesa import Mesa
from app.models.pedido import Pedido, PedidoItem
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa
from app.models.usuario import Usuario

from .conftest import (
    abrir_sesion,
    auth_header,
    login,
    login_staff_demo,
    register_cliente,
)
from .test_staff_menu import create_restaurante_con_staff

_MESA_NUM = 2  # GRI-MESA-002 (plan); mesas 3/5-8 las usan otras suites
_ADMIN_DEMO = "admin@demo.gri.dev"


# --- Helpers -------------------------------------------------------------------


async def _reset_mesa(db_session, numero: int) -> int:
    """Invariante de la mesa del seed: disponible + sin sesión activa
    (auto-repara residuo — lección 05-02). Retorna el mesa_id."""
    await db_session.rollback()
    db_session.expire_all()
    mesa = (
        await db_session.execute(
            select(Mesa).where(
                Mesa.restaurant_id == 1, Mesa.numero == numero
            )
        )
    ).scalar_one()
    await db_session.execute(
        update(SesionMesa)
        .where(SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None))
        .values(estado=EstadoSesion.cerrada, cerrada_en=func.now())
    )
    mesa.estado = "disponible"
    await db_session.commit()
    return mesa.id


async def _borrar_pedidos_usuario(db_session, usuario_id: int) -> None:
    """Borra los pedidos del usuario de test (items primero — FK)."""
    await db_session.rollback()
    await db_session.execute(
        delete(PedidoItem).where(
            PedidoItem.pedido_id.in_(
                select(Pedido.id).where(Pedido.usuario_id == usuario_id)
            )
        )
    )
    await db_session.execute(delete(Pedido).where(Pedido.usuario_id == usuario_id))
    await db_session.commit()


async def _restaurar_mesa_via_api(async_client, mesa_id: int) -> None:
    """Mesa a disponible VÍA API (ocupada→limpieza→disponible) — el paso por
    limpieza cierra la sesión activa (anti-zombi 06-01) y restaura el
    invariante. Tolerante al estado actual (setup fallido a mitad)."""
    admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
    mesas = await async_client.get("/staff/mesas", headers=admin)
    estado = next((m["estado"] for m in mesas.json() if m["id"] == mesa_id), None)
    if estado == "ocupada":
        r1 = await async_client.post(
            f"/staff/mesas/{mesa_id}/estado", json={"estado": "limpieza"}, headers=admin
        )
        assert r1.status_code == 200, r1.text
        estado = "limpieza"
    if estado == "limpieza":
        r2 = await async_client.post(
            f"/staff/mesas/{mesa_id}/estado",
            json={"estado": "disponible"},
            headers=admin,
        )
        assert r2.status_code == 200, r2.text


async def _setup_cliente_con_pedido(async_client, db_session):
    """Cliente dedicado + sesión en GRI-MESA-002 + 1 pedido real (2×A + 1×B
    del menú demo) → (usuario_body, headers, pedido_body, total_esperado,
    mesa_id)."""
    mesa_id = await _reset_mesa(db_session, _MESA_NUM)
    user = await register_cliente(async_client, nombre="Cliente Staff Test")
    access, _ = await login(async_client, user["email"], user["_password"])
    headers = auth_header(access)
    sesion = await abrir_sesion(async_client, access, f"GRI-MESA-{_MESA_NUM:03d}")
    assert sesion.status_code == 201, sesion.text

    # Items del menú demo vía /public (API F6 — ids reales, no asumidos).
    pub = await async_client.get("/public/restaurantes/1")
    assert pub.status_code == 200, pub.text
    productos = [p for c in pub.json()["categorias"] for p in c["productos"]]
    assert len(productos) >= 2, "el demo tiene productos"
    a, b = productos[0], productos[1]
    pedido = await async_client.post(
        "/cliente/pedidos",
        json={
            "sesion_id": sesion.json()["id"],
            "items": [
                {"producto_id": a["id"], "cantidad": 2},
                {"producto_id": b["id"], "cantidad": 1},
            ],
        },
        headers=headers,
    )
    assert pedido.status_code == 201, pedido.text
    esperado = 2 * a["precio"] + 1 * b["precio"]
    return user, headers, pedido.json(), esperado, mesa_id


# --- ADMN-03: listado JOIN-por-pedidos ------------------------------------------


@pytest.mark.asyncio
async def test_list_clientes_con_pedido_y_orden(async_client, db_session):
    """El cliente con pedido aparece con num_pedidos=1, total_gastado ==
    total del pedido (approx), ultimo_pedido_at no nulo; lista ordenada por
    total_gastado DESC; total_gastado es JSON number (float)."""
    user, headers, pedido, esperado, mesa_id = await _setup_cliente_con_pedido(
        async_client, db_session
    )
    try:
        admin = await login_staff_demo(async_client, _ADMIN_DEMO)
        resp = await async_client.get(
            "/staff/clientes", headers=auth_header(admin)
        )
        assert resp.status_code == 200, resp.text
        clientes = resp.json()
        entry = next(
            (c for c in clientes if c["usuario_id"] == user["id"]), None
        )
        assert entry is not None, "el cliente con pedido debe aparecer"
        assert entry["num_pedidos"] == 1
        assert entry["total_gastado"] == pytest.approx(esperado)
        assert isinstance(entry["total_gastado"], float), (
            "total_gastado viaja como JSON number (Pitfall 1: SUM → Decimal)"
        )
        assert entry["ultimo_pedido_at"] is not None
        assert entry["nombre"] == "Cliente Staff Test"
        assert entry["email"] == user["email"]

        totals = [c["total_gastado"] for c in clientes]
        assert totals == sorted(totals, reverse=True), (
            "orden por total_gastado DESC"
        )
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)


# --- ADMN-03: historial del cliente ---------------------------------------------


@pytest.mark.asyncio
async def test_historial_cliente(async_client, db_session):
    """GET /staff/clientes/{id}/historial devuelve el pedido con items
    (nombre/cantidad), mesa_numero correcta y usuario_nombre (PedidoStaffRead
    reusado sin modificación)."""
    user, headers, pedido, esperado, mesa_id = await _setup_cliente_con_pedido(
        async_client, db_session
    )
    try:
        admin = await login_staff_demo(async_client, _ADMIN_DEMO)
        resp = await async_client.get(
            f"/staff/clientes/{user['id']}/historial", headers=auth_header(admin)
        )
        assert resp.status_code == 200, resp.text
        pedidos = resp.json()
        assert len(pedidos) == 1
        body = pedidos[0]
        assert body["id"] == pedido["id"]
        assert body["mesa_numero"] == _MESA_NUM
        assert body["estado"] == "enviado"
        assert body["total"] == pytest.approx(esperado)
        assert body["usuario_nombre"] == "Cliente Staff Test"
        assert len(body["items"]) == 2
        for item in body["items"]:
            assert item["nombre"], "item con nombre (join Producto)"
            assert isinstance(item["cantidad"], int) and item["cantidad"] >= 1
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)


@pytest.mark.asyncio
async def test_historial_sin_pedidos_en_tenant_404(async_client, db_session):
    """Usuario recién registrado (sin pedidos en NINGÚN tenant) → historial
    404 — existence hiding relacional: el endpoint no revela que el
    usuario_id existe en la tabla global."""
    user = await register_cliente(async_client, nombre="Sin Pedidos")
    admin = await login_staff_demo(async_client, _ADMIN_DEMO)
    resp = await async_client.get(
        f"/staff/clientes/{user['id']}/historial", headers=auth_header(admin)
    )
    assert resp.status_code == 404, resp.text


# --- ADMN-03: aislamiento cross-tenant ------------------------------------------


@pytest.mark.asyncio
async def test_cross_tenant_clientes(async_client, db_session, super_admin_token):
    """Staff del restaurante B NO ve al cliente del tenant 1: ni en su lista
    ni en su historial (404)."""
    rid_b, token_b, email_b = await create_restaurante_con_staff(
        async_client, super_admin_token, "Cross Clientes"
    )
    user, headers, pedido, esperado, mesa_id = await _setup_cliente_con_pedido(
        async_client, db_session
    )
    try:
        headers_b = auth_header(token_b)
        lista = await async_client.get("/staff/clientes", headers=headers_b)
        assert lista.status_code == 200, lista.text
        ids_b = {c["usuario_id"] for c in lista.json()}
        assert user["id"] not in ids_b, (
            "el cliente del tenant 1 JAMÁS aparece para staff del tenant B"
        )

        hist = await async_client.get(
            f"/staff/clientes/{user['id']}/historial", headers=headers_b
        )
        assert hist.status_code == 404, hist.text
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)
        await db_session.rollback()
        await db_session.execute(
            delete(Usuario).where(Usuario.email == email_b)
        )
        await db_session.execute(
            delete(Restaurante).where(Restaurante.id == rid_b)
        )
        await db_session.commit()


# --- ADMN-03: contrato super_admin + reads abiertos ------------------------------


@pytest.mark.asyncio
async def test_super_admin_contract_y_mesero_read(
    async_client, db_session, super_admin_token
):
    """super_admin: sin ?restaurante_id= → 400 (ambos endpoints); con param →
    200. Mesero (read abierto a todo el staff) → 200 en la lista."""
    user, headers, pedido, esperado, mesa_id = await _setup_cliente_con_pedido(
        async_client, db_session
    )
    try:
        sa = auth_header(super_admin_token)
        sin_lista = await async_client.get("/staff/clientes", headers=sa)
        assert sin_lista.status_code == 400, sin_lista.text
        sin_hist = await async_client.get(
            f"/staff/clientes/{user['id']}/historial", headers=sa
        )
        assert sin_hist.status_code == 400, sin_hist.text

        con_lista = await async_client.get(
            "/staff/clientes", params={"restaurante_id": 1}, headers=sa
        )
        assert con_lista.status_code == 200, con_lista.text
        assert user["id"] in {c["usuario_id"] for c in con_lista.json()}

        con_hist = await async_client.get(
            f"/staff/clientes/{user['id']}/historial",
            params={"restaurante_id": 1},
            headers=sa,
        )
        assert con_hist.status_code == 200, con_hist.text

        mesero = await login_staff_demo(async_client, "mesero@demo.gri.dev")
        as_mesero = await async_client.get(
            "/staff/clientes", headers=auth_header(mesero)
        )
        assert as_mesero.status_code == 200, as_mesero.text
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)
