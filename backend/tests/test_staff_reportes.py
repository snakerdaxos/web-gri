"""Tests REPO-01/02 — GET /staff/reportes/ventas + GET /staff/reportes/top-platos.

Contrato (decisión locked — reportes NO vacíos hasta F9):

- Venta = pedido en estado ``servido`` O ``pagado`` — JAMÁS solo pagado (en
  v1 casi ningún pedido llega a pagado; filtrar así dejaría los reportes
  vacíos). ``enviado`` NO cuenta (P2 del fixture queda excluido).
- Ventas por día: agrupación ``func.date(created_at)`` DB-side (America/
  Bogotá — Pitfall 3: NUNCA date.today() Python-side), rango inclusivo
  (desde 00:00:00 <= x < hasta+1d), defaults desde=hoy-6 hasta=hoy con
  ``func.curdate()`` DB-side. desde>hasta → 422.
- Top platos: SUM(cantidad) DESC, limit param (default 10, 1..50),
  tenant-scoped sobre ``PedidoItem.restaurant_id`` (denormalizado).
- Money como JSON number (field_serializer — Pitfall 1: SUM devuelve Decimal).
- Cross-tenant: el restaurante B ve CERO ventas del tenant 1 (cero fuga).
- super_admin sin ?restaurante_id= → 400; con param → 200.

Fixture: cliente dedicado + sesión GRI-MESA-003 + P1 (A×2 + B×1) avanzado a
``servido`` con cocina@demo (aceptado→en_preparacion→servido) y P2 (A×1)
dejado en ``enviado``. Cleanup finally: borra pedidos del usuario + mesa a
disponible VÍA API (ocupada→limpieza→disponible — cierra sesión anti-zombi).
"""

from uuid import uuid4

import datetime as dt
import pytest
from sqlalchemy import delete, func, select

from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

from .conftest import (
    abrir_sesion,
    auth_header,
    login,
    login_staff_demo,
    register_cliente,
)
from .test_staff_clientes import (
    _borrar_pedidos_usuario,
    _reset_mesa,
    _restaurar_mesa_via_api,
)
from .test_staff_menu import create_restaurante_con_staff

_MESA_NUM = 3  # GRI-MESA-003 (plan); mesas 2/5-8 las usan otras suites
_ADMIN_DEMO = "admin@demo.gri.dev"
_COCINA_DEMO = "cocina@demo.gri.dev"


async def _hoy_db(db_session) -> dt.date:
    """'Hoy' según la BD (func.curdate — la misma fuente que agrupa por_dia).
    Pitfall 3: el host y el contenedor pueden divergir por TZ."""
    return (await db_session.execute(select(func.curdate()))).scalar_one()


async def _avanzar_a_servido(async_client, headers_cocina, pedido_id: int) -> None:
    """P1: aceptado → en_preparacion → servido (3 POST, cocina@demo)."""
    for estado in ("aceptado", "en_preparacion", "servido"):
        resp = await async_client.post(
            f"/staff/pedidos/{pedido_id}/estado",
            json={"estado": estado},
            headers=headers_cocina,
        )
        assert resp.status_code == 200, (estado, resp.text)


async def _setup_pedidos_reporte(async_client, db_session):
    """Cliente dedicado + sesión en GRI-MESA-003 + P1 (A×2+B×1 → servido) y
    P2 (A×1 → queda enviado) → (usuario, total_p1, a, b, mesa_id)."""
    mesa_id = await _reset_mesa(db_session, _MESA_NUM)
    user = await register_cliente(async_client, nombre="Cliente Reportes")
    access, _ = await login(async_client, user["email"], user["_password"])
    headers = auth_header(access)
    sesion = await abrir_sesion(async_client, access, f"GRI-MESA-{_MESA_NUM:03d}")
    assert sesion.status_code == 201, sesion.text
    sesion_id = sesion.json()["id"]

    # Items del menú demo vía /public (API F6 — ids reales, no asumidos).
    pub = await async_client.get("/public/restaurantes/1")
    assert pub.status_code == 200, pub.text
    productos = [p for c in pub.json()["categorias"] for p in c["productos"]]
    assert len(productos) >= 2, "el demo tiene productos"
    a, b = productos[0], productos[1]

    # P1: A×2 + B×1 — avanzado a servido (VENTA).
    p1 = await async_client.post(
        "/cliente/pedidos",
        json={
            "sesion_id": sesion_id,
            "items": [
                {"producto_id": a["id"], "cantidad": 2},
                {"producto_id": b["id"], "cantidad": 1},
            ],
        },
        headers=headers,
    )
    assert p1.status_code == 201, p1.text

    # P2: A×1 — dejado en enviado (NO es venta).
    p2 = await async_client.post(
        "/cliente/pedidos",
        json={
            "sesion_id": sesion_id,
            "items": [{"producto_id": a["id"], "cantidad": 1}],
        },
        headers=headers,
    )
    assert p2.status_code == 201, p2.text

    await _avanzar_a_servido(
        async_client, auth_header(await login_staff_demo(async_client, _COCINA_DEMO)),
        p1.json()["id"],
    )
    return user, p1.json()["total"], a, b, mesa_id


# --- REPO-01: ventas por día/rango ------------------------------------------------


@pytest.mark.asyncio
async def test_ventas_default_rango_y_filtro_estados(async_client, db_session):
    """Sin params: total == P1 (approx), num_pedidos == 1 (P2 enviado NO
    cuenta — venta = servido|pagado), por_dia con entrada de HOY. Rango
    explícito hoy..hoy idéntico (inclusivo); 2020 → 0/vacío; desde>hasta →
    422. total viaja como JSON number."""
    user, total_p1, a, b, mesa_id = await _setup_pedidos_reporte(
        async_client, db_session
    )
    try:
        admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))
        hoy = await _hoy_db(db_session)

        resp = await async_client.get("/staff/reportes/ventas", headers=admin)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["total"] == pytest.approx(total_p1), (
            "venta = servido|pagado únicamente (P2 enviado excluido)"
        )
        assert body["num_pedidos"] == 1, "solo P1 cuenta como venta"
        assert isinstance(body["total"], float), (
            "total viaja como JSON number (Pitfall 1: SUM devuelve Decimal)"
        )
        assert body["desde"] == str(hoy - dt.timedelta(days=6)), (
            "default desde = hoy-6 (computado DB-side con curdate)"
        )
        assert body["hasta"] == str(hoy), "default hasta = hoy (curdate DB-side)"
        hoy_row = next(d for d in body["por_dia"] if d["fecha"] == str(hoy))
        assert hoy_row["num_pedidos"] == 1
        assert hoy_row["total"] == pytest.approx(total_p1)

        # Rango explícito hoy..hoy → idéntico (boundaries inclusivos).
        mismo = await async_client.get(
            "/staff/reportes/ventas",
            params={"desde": str(hoy), "hasta": str(hoy)},
            headers=admin,
        )
        assert mismo.status_code == 200, mismo.text
        assert mismo.json()["total"] == pytest.approx(total_p1)
        assert mismo.json()["num_pedidos"] == 1

        # Rango lejano → vacío, no error.
        viejo = await async_client.get(
            "/staff/reportes/ventas",
            params={"desde": "2020-01-01", "hasta": "2020-01-31"},
            headers=admin,
        )
        assert viejo.status_code == 200, viejo.text
        assert viejo.json()["total"] == 0.0
        assert viejo.json()["num_pedidos"] == 0
        assert viejo.json()["por_dia"] == []

        # desde > hasta → 422.
        invertido = await async_client.get(
            "/staff/reportes/ventas",
            params={"desde": "2099-01-01", "hasta": "2020-01-01"},
            headers=admin,
        )
        assert invertido.status_code == 422, (
            f"desde>hasta debe ser 422; recibido {invertido.status_code}"
        )
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)


# --- REPO-02: top platos -----------------------------------------------------------


@pytest.mark.asyncio
async def test_top_platos_cantidad_desc_y_filtro_estados(async_client, db_session):
    """A×2 y B×1 (SOLO items de P1 servido — el A×1 de P2 enviado NO suma),
    orden cantidad DESC, limit acota. Rango 2020 → vacío."""
    user, total_p1, a, b, mesa_id = await _setup_pedidos_reporte(
        async_client, db_session
    )
    try:
        admin = auth_header(await login_staff_demo(async_client, _ADMIN_DEMO))

        resp = await async_client.get("/staff/reportes/top-platos", headers=admin)
        assert resp.status_code == 200, resp.text
        filas = resp.json()
        assert len(filas) >= 2, "A y B deben aparecer"
        fila_a = next(f for f in filas if f["producto_id"] == a["id"])
        fila_b = next(f for f in filas if f["producto_id"] == b["id"])
        assert fila_a["nombre"] == a["nombre"]
        assert fila_a["cantidad"] == 2, (
            "A×2 de P1 (servido) + A×1 de P2 (enviado) → cantidad 2, NO 3: "
            "el filtro estado.in_(servido,pagado) aplica al JOIN del pedido"
        )
        assert fila_b["cantidad"] == 1
        assert fila_a["total"] == pytest.approx(2 * a["precio"])
        assert isinstance(fila_a["total"], float), "money como JSON number"
        # Orden cantidad DESC (A siempre antes que B; empates no importan).
        assert filas.index(fila_a) < filas.index(fila_b)
        cantidades = [f["cantidad"] for f in filas]
        assert cantidades == sorted(cantidades, reverse=True)

        # limit=1 → solo el top 1 (A).
        top1 = await async_client.get(
            "/staff/reportes/top-platos", params={"limit": 1}, headers=admin
        )
        assert top1.status_code == 200, top1.text
        assert len(top1.json()) == 1
        assert top1.json()[0]["producto_id"] == a["id"]

        # Rango lejano → lista vacía.
        viejo = await async_client.get(
            "/staff/reportes/top-platos",
            params={"desde": "2020-01-01", "hasta": "2020-01-31"},
            headers=admin,
        )
        assert viejo.status_code == 200, viejo.text
        assert viejo.json() == []
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)


# --- Cross-tenant + contrato super_admin ------------------------------------------


@pytest.mark.asyncio
async def test_reportes_cross_tenant_y_super_admin(
    async_client, db_session, super_admin_token
):
    """Staff del restaurante B: ventas total 0.0 / por_dia vacío y top-platos
    vacío (CERO fuga de P1). super_admin: sin ?restaurante_id= → 400 en
    ambos; con ?restaurante_id=1 → 200."""
    user, total_p1, a, b, mesa_id = await _setup_pedidos_reporte(
        async_client, db_session
    )
    rid_b, token_b, email_b = await create_restaurante_con_staff(
        async_client, super_admin_token, f"Cross Reportes {uuid4().hex[:6]}"
    )
    try:
        headers_b = auth_header(token_b)
        ventas_b = await async_client.get("/staff/reportes/ventas", headers=headers_b)
        assert ventas_b.status_code == 200, ventas_b.text
        assert ventas_b.json()["total"] == 0.0
        assert ventas_b.json()["por_dia"] == []

        top_b = await async_client.get(
            "/staff/reportes/top-platos", headers=headers_b
        )
        assert top_b.status_code == 200, top_b.text
        assert top_b.json() == []

        sa = auth_header(super_admin_token)
        sin_v = await async_client.get("/staff/reportes/ventas", headers=sa)
        assert sin_v.status_code == 400, sin_v.text
        sin_t = await async_client.get("/staff/reportes/top-platos", headers=sa)
        assert sin_t.status_code == 400, sin_t.text

        con_v = await async_client.get(
            "/staff/reportes/ventas", params={"restaurante_id": 1}, headers=sa
        )
        assert con_v.status_code == 200, con_v.text
        assert con_v.json()["total"] == pytest.approx(total_p1)

        con_t = await async_client.get(
            "/staff/reportes/top-platos", params={"restaurante_id": 1}, headers=sa
        )
        assert con_t.status_code == 200, con_t.text
        assert any(f["producto_id"] == a["id"] for f in con_t.json())
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _restaurar_mesa_via_api(async_client, mesa_id)
        await db_session.rollback()
        await db_session.execute(delete(Usuario).where(Usuario.email == email_b))
        await db_session.execute(
            delete(Restaurante).where(Restaurante.id == rid_b)
        )
        await db_session.commit()
