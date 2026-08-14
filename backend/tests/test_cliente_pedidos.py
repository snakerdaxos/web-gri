"""Tests PEDI-01/02/04 — POST /cliente/pedidos + GET /cliente/pedidos/actual.

Contrato (06-01 Task 2):

- POST crea en estado=enviado con total calculado SERVER-SIDE (2*precioX +
  1*precioY) y snapshot de precio_unitario en pedido_item (Pitfall: NUNCA
  precios del body — el schema no tiene campos de precio).
- Sin sesión / sesión ajena (existence hiding) / producto cross-restaurante
  → 404. Sesión inactiva / producto agotado → 409. items vacío o cantidad≤0
  → 422 (Pydantic).
- GET /cliente/pedidos/actual: TODOS los pedidos de mi sesión activa,
  newest first (created_at DESC, id DESC).

Cleanup: borra los pedidos del usuario de test (items primero — FK), cierra
sesiones y restaura la mesa a disponible. Setup defensivo auto-repara
residuo (lección 05-02).
"""

from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, select, update

from app.models.menu import Categoria, Producto
from app.models.mesa import Mesa
from app.models.pedido import Pedido, PedidoItem
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa

from .conftest import abrir_sesion, auth_header, login, register_cliente

_MESA = 3  # mesas 5-8 las usan los tests de sesión (test_sesion_mesa.py)


# --- Helpers ---------------------------------------------------------------


async def _crear_cliente(client, *, nombre="Pedidos Test") -> tuple[dict, str, dict]:
    body = await register_cliente(client, nombre=nombre)
    access, _ = await login(client, body["email"], body["_password"])
    return body, access, auth_header(access)


async def _reset_mesas(db_session, numeros: list[int]) -> None:
    """Invariante de las mesas del seed: disponible + sin sesión activa."""
    await db_session.rollback()
    db_session.expire_all()
    for numero in numeros:
        mesa = (
            await db_session.execute(
                select(Mesa).where(Mesa.restaurant_id == 1, Mesa.numero == numero)
            )
        ).scalar_one()
        await db_session.execute(
            update(SesionMesa)
            .where(SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None))
            .values(estado=EstadoSesion.cerrada, cerrada_en=func.now())
        )
        mesa.estado = "disponible"
    await db_session.commit()


async def _cerrar_sesiones_usuario(db_session, usuario_id: int) -> None:
    await db_session.rollback()
    await db_session.execute(
        update(SesionMesa)
        .where(SesionMesa.usuario_id == usuario_id, SesionMesa.cerrada_en.is_(None))
        .values(estado=EstadoSesion.cerrada, cerrada_en=func.now())
    )
    await db_session.commit()


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


async def _productos_demo(db_session) -> dict[str, Producto]:
    """Productos del seed restaurante 1 con precio conocido (patrón subset
    seed — nunca counts absolutos sobre la BD compartida)."""
    await db_session.rollback()
    db_session.expire_all()
    rows = (
        await db_session.execute(
            select(Producto).where(
                Producto.restaurant_id == 1,
                Producto.nombre.in_(["Bandeja Paisa", "Limonada de Coco"]),
            )
        )
    ).scalars().all()
    assert len(rows) == 2
    return {p.nombre: p for p in rows}


async def _setup_sesion(async_client, db_session):
    """Mesa reseteada + cliente fresco + sesión abierta → (user, token,
    headers, sesion_id)."""
    await _reset_mesas(db_session, [_MESA])
    user, token, headers = await _crear_cliente(async_client)
    resp = await abrir_sesion(async_client, token, f"GRI-MESA-{_MESA:03d}")
    assert resp.status_code == 201, resp.text
    return user, token, headers, resp.json()["id"]


def _payload(sesion_id: int, items: list[dict], notas: str | None = None) -> dict:
    body: dict = {"sesion_id": sesion_id, "items": items}
    if notas is not None:
        body["notas"] = notas
    return body


# --- PEDI-01/02: crear pedido ------------------------------------------------


@pytest.mark.asyncio
async def test_crear_pedido_201_enviado_total_server_side(async_client, db_session):
    """201 con estado=enviado, total=2*32000+1*9000 server-side, items con
    nombre/cantidad/precios float, y pedido.sesion_id escrito en DB."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    prods = await _productos_demo(db_session)
    x, y = prods["Bandeja Paisa"], prods["Limonada de Coco"]
    esperado = float(2 * x.precio + 1 * y.precio)
    try:
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(
                sesion_id,
                [
                    {"producto_id": x.id, "cantidad": 2},
                    {"producto_id": y.id, "cantidad": 1},
                ],
                notas="Sin cebolla",
            ),
            headers=headers,
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["estado"] == "enviado"
        assert body["total"] == esperado
        assert isinstance(body["total"], float)
        assert body["mesa_numero"] == _MESA
        assert body["sesion_id"] == sesion_id
        assert body["notas"] == "Sin cebolla"
        assert len(body["items"]) == 2
        by_prod = {it["producto_id"]: it for it in body["items"]}
        assert by_prod[x.id]["nombre"] == "Bandeja Paisa"
        assert by_prod[x.id]["cantidad"] == 2
        assert by_prod[x.id]["precio_unitario"] == float(x.precio)
        assert isinstance(by_prod[x.id]["precio_unitario"], float)
        assert by_prod[x.id]["subtotal"] == float(2 * x.precio)
        assert isinstance(by_prod[x.id]["subtotal"], float)

        # DB: snapshot escrito + sesion_id SIEMPRE poblado (rollback +
        # expire_all + get — determinístico tras el commit del API).
        await db_session.rollback()
        db_session.expire_all()
        pedido = await db_session.get(Pedido, body["id"])
        assert pedido is not None
        assert pedido.sesion_id == sesion_id
        assert pedido.estado == "enviado"
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_snapshot_precio(async_client, db_session):
    """Tras crear el pedido, cambiar producto.precio NO muta el item:
    precio_unitario queda congelado (reportes F8 exactos)."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    prods = await _productos_demo(db_session)
    x = prods["Bandeja Paisa"]
    x_id, original = x.id, x.precio  # capturar ANTES de expire_all (PK de
    # objeto expirado dispara lazy-load síncrono → MissingGreenlet)
    try:
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": x_id, "cantidad": 1}]),
            headers=headers,
        )
        assert resp.status_code == 201, resp.text
        original_item = resp.json()["items"][0]

        # Mutar el precio del producto y commitear.
        await db_session.rollback()
        db_session.expire_all()
        prod_db = await db_session.get(Producto, x_id)
        prod_db.precio = Decimal("99999.00")
        await db_session.commit()

        actual = await async_client.get("/cliente/pedidos/actual", headers=headers)
        assert actual.status_code == 200, actual.text
        pedidos = actual.json()
        assert len(pedidos) == 1
        item = pedidos[0]["items"][0]
        assert item["precio_unitario"] == original_item["precio_unitario"]
        assert item["precio_unitario"] == float(original)
        assert pedidos[0]["total"] == float(original)
    finally:
        await db_session.rollback()
        db_session.expire_all()
        prod_db = await db_session.get(Producto, x_id)
        prod_db.precio = original
        await db_session.commit()
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


# --- PEDI-01: validaciones de error ------------------------------------------


@pytest.mark.asyncio
async def test_sin_sesion_404(async_client, db_session):
    """Usuario sin sesión activa y sin sesion_id en el body → 404."""
    await _reset_mesas(db_session, [_MESA])
    user, token, headers = await _crear_cliente(async_client)
    try:
        prods = await _productos_demo(db_session)
        x = prods["Bandeja Paisa"]
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(None, [{"producto_id": x.id, "cantidad": 1}]),
            headers=headers,
        )
        assert resp.status_code == 404, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_sesion_ajena_404(async_client, db_session):
    """Usuario B usa el sesion_id de A → 404 (existence hiding — sesión
    spoofing P6: indistinguible de una sesión inexistente)."""
    user_a, _, _, sesion_id_a = await _setup_sesion(async_client, db_session)
    user_b, token_b, headers_b = await _crear_cliente(async_client, nombre="Usuario B")
    try:
        prods = await _productos_demo(db_session)
        x = prods["Bandeja Paisa"]
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id_a, [{"producto_id": x.id, "cantidad": 1}]),
            headers=headers_b,
        )
        assert resp.status_code == 404, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user_a["id"])
        await _cerrar_sesiones_usuario(db_session, user_b["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_sesion_inactiva_409(async_client, db_session):
    """Sesión cerrada (cerrada_en seteado) → 409."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    try:
        await db_session.rollback()
        await db_session.execute(
            update(SesionMesa)
            .where(SesionMesa.id == sesion_id)
            .values(estado=EstadoSesion.cerrada, cerrada_en=func.now())
        )
        await db_session.commit()

        prods = await _productos_demo(db_session)
        x = prods["Bandeja Paisa"]
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": x.id, "cantidad": 1}]),
            headers=headers,
        )
        assert resp.status_code == 409, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_producto_agotado_409(async_client, db_session):
    """producto.disponible=False → 409 (no silencioso)."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    prods = await _productos_demo(db_session)
    x_id = prods["Bandeja Paisa"].id  # capturar ANTES de expire_all
    try:
        await db_session.rollback()
        db_session.expire_all()
        prod_db = await db_session.get(Producto, x_id)
        prod_db.disponible = False
        await db_session.commit()

        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": x_id, "cantidad": 1}]),
            headers=headers,
        )
        assert resp.status_code == 409, resp.text
    finally:
        await db_session.rollback()
        db_session.expire_all()
        prod_db = await db_session.get(Producto, x_id)
        prod_db.disponible = True
        await db_session.commit()
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_producto_cross_restaurante_404(async_client, db_session):
    """Producto de OTRO restaurante (GRI-TEST-*) en sesión del restaurante 1
    → 404 (el filtro restaurant_id del service lo cubre)."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    r2 = Restaurante(nombre=f"Cross Ped {uuid4().hex[:6]}")
    db_session.add(r2)
    await db_session.flush()
    cat2 = Categoria(restaurant_id=r2.id, nombre="Test", orden=1)
    db_session.add(cat2)
    await db_session.flush()
    p2 = Producto(
        restaurant_id=r2.id,
        categoria_id=cat2.id,
        nombre="Plato Ajeno",
        precio=Decimal("1000.00"),
    )
    db_session.add(p2)
    await db_session.commit()
    try:
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": p2.id, "cantidad": 1}]),
            headers=headers,
        )
        assert resp.status_code == 404, resp.text
    finally:
        await db_session.rollback()
        await db_session.delete(p2)
        await db_session.flush()
        await db_session.delete(cat2)
        await db_session.flush()
        await db_session.delete(r2)
        await db_session.commit()
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_items_vacio_422(async_client, db_session):
    """items=[] → 422 (min_length=1)."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    try:
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, []),
            headers=headers,
        )
        assert resp.status_code == 422, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_cantidad_cero_422(async_client, db_session):
    """cantidad=0 → 422 (gt=0)."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    try:
        prods = await _productos_demo(db_session)
        x = prods["Bandeja Paisa"]
        resp = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": x.id, "cantidad": 0}]),
            headers=headers,
        )
        assert resp.status_code == 422, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


# --- PEDI-04: pedidos de la sesión activa ------------------------------------


@pytest.mark.asyncio
async def test_pedidos_actual_lista_multiples(async_client, db_session):
    """2 pedidos (comer + postre) → GET /cliente/pedidos/actual devuelve 2,
    newest first, ambos con sesion_id correcto (cualquier estado)."""
    user, token, headers, sesion_id = await _setup_sesion(async_client, db_session)
    prods = await _productos_demo(db_session)
    x, y = prods["Bandeja Paisa"], prods["Limonada de Coco"]
    try:
        primero = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": x.id, "cantidad": 1}]),
            headers=headers,
        )
        assert primero.status_code == 201, primero.text
        segundo = await async_client.post(
            "/cliente/pedidos",
            json=_payload(sesion_id, [{"producto_id": y.id, "cantidad": 2}]),
            headers=headers,
        )
        assert segundo.status_code == 201, segundo.text

        resp = await async_client.get("/cliente/pedidos/actual", headers=headers)
        assert resp.status_code == 200, resp.text
        pedidos = resp.json()
        assert len(pedidos) == 2
        ids = [p["id"] for p in pedidos]
        assert ids == sorted(ids, reverse=True), "newest first (id DESC)"
        assert primero.json()["id"] in ids and segundo.json()["id"] in ids
        assert all(p["sesion_id"] == sesion_id for p in pedidos)
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_pedidos_actual_sin_sesion_404(async_client, db_session):
    """GET /cliente/pedidos/actual sin sesión activa → 404."""
    user, token, headers = await _crear_cliente(async_client)
    try:
        resp = await async_client.get("/cliente/pedidos/actual", headers=headers)
        assert resp.status_code == 404, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])
