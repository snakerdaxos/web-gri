"""Tests PEDI-03/05/06 + PAGO-01 (badge) + anti-zombi — /staff/pedidos.

Contrato (06-01 Task 3):

- POST /staff/pedidos/{id}/estado: enviado→aceptado→en_preparacion→servido
  como cocina (3×200); rechazo desde enviado (200); transiciones inválidas
  → 409 (SALTOS y terminales).
- Matriz rol×transición: mesero NO acepta (403) pero SÍ marca servido (200).
  ORDEN de checks: 409 (transición inválida) ANTES que 403 (rol) — un mesero
  que pide un salto inválido recibe 409, no 403.
- GET /staff/pedidos?activos=true: cola tenant-scoped FIFO
  (FIELD(estado,'enviado','aceptado','en_preparacion','servido'),
  created_at ASC) con mesa_numero, items, total float, notas, usuario_nombre
  y solicita_cuenta (badge PAGO-01). Cross-tenant → ausente (existence
  hiding). super_admin sin ?restaurante_id= → 400; cliente → 403.
- Anti-zombi: mesa→limpieza cierra la sesión activa en la MISMA tx.

Staff del seed (restaurante 1): cocina@/mesero@/admin@demo.gri.dev
(password Demo!1234) vía login_staff_demo.
"""

from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, select, update

from app.models.mesa import Mesa
from app.models.pedido import Pedido, PedidoItem
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa
from app.models.usuario import RolUsuario, Usuario

from .conftest import (
    abrir_sesion,
    auth_header,
    login,
    login_staff_demo,
    register_cliente,
)

_MESA = 1  # mesas 2-8 las usan los otros tests de la fase
_COCINA = "cocina@demo.gri.dev"
_MESERO = "mesero@demo.gri.dev"
_ADMIN = "admin@demo.gri.dev"


# --- Helpers ---------------------------------------------------------------


async def _crear_cliente(client, *, nombre="Staff Pedidos Test"):
    body = await register_cliente(client, nombre=nombre)
    access, _ = await login(client, body["email"], body["_password"])
    return body, access, auth_header(access)


async def _reset_mesas(db_session, numeros: list[int]) -> None:
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


async def _setup_pedido(async_client, db_session, *, nombre="Staff Pedidos Test"):
    """Mesa 1 reseteada + cliente fresco + sesión + 1 pedido enviado.

    Retorna (user, token, headers, sesion_id, pedido_body).
    """
    await _reset_mesas(db_session, [_MESA])
    user, token, headers = await _crear_cliente(async_client, nombre=nombre)
    opened = await abrir_sesion(async_client, token, f"GRI-MESA-{_MESA:03d}")
    assert opened.status_code == 201, opened.text
    sesion_id = opened.json()["id"]

    from app.models.menu import Producto

    await db_session.rollback()
    db_session.expire_all()
    prod = (
        await db_session.execute(
            select(Producto).where(
                Producto.restaurant_id == 1,
                Producto.nombre == "Bandeja Paisa",
            )
        )
    ).scalar_one()
    prod_id = prod.id

    resp = await async_client.post(
        "/cliente/pedidos",
        json={
            "sesion_id": sesion_id,
            "items": [{"producto_id": prod_id, "cantidad": 1}],
            "notas": "Sin cebolla",
        },
        headers=headers,
    )
    assert resp.status_code == 201, resp.text
    return user, token, headers, sesion_id, resp.json()


async def _avanzar(async_client, token: str, pedido_id: int, estado: str):
    """POST /staff/pedidos/{id}/estado con token staff; retorna la response."""
    return await async_client.post(
        f"/staff/pedidos/{pedido_id}/estado",
        json={"estado": estado},
        headers=auth_header(token),
    )


# --- PEDI-03/05: transiciones + matriz ----------------------------------------


@pytest.mark.asyncio
async def test_secuencia_completa_cocina(async_client, db_session):
    """enviado→aceptado→en_preparacion→servido como cocina → 3×200 con el
    estado actualizado en cada body."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    pid = pedido["id"]
    try:
        for estado in ("aceptado", "en_preparacion", "servido"):
            resp = await _avanzar(async_client, cocina, pid, estado)
            assert resp.status_code == 200, f"{estado}: {resp.text}"
            assert resp.json()["estado"] == estado
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_rechazo_enviado_cocina(async_client, db_session):
    """enviado→rechazado como cocina → 200."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    try:
        resp = await _avanzar(async_client, cocina, pedido["id"], "rechazado")
        assert resp.status_code == 200, resp.text
        assert resp.json()["estado"] == "rechazado"
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_transicion_invalida_409(async_client, db_session):
    """Saltos (enviado→servido), retrocesos (servido→aceptado) y terminales
    (rechazado→aceptado) → 409."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    pid = pedido["id"]
    try:
        # Salto: enviado→servido.
        salto = await _avanzar(async_client, cocina, pid, "servido")
        assert salto.status_code == 409, salto.text

        # Ciclo completo hasta servido, luego retroceso servido→aceptado.
        for estado in ("aceptado", "en_preparacion", "servido"):
            resp = await _avanzar(async_client, cocina, pid, estado)
            assert resp.status_code == 200, resp.text
        retro = await _avanzar(async_client, cocina, pid, "aceptado")
        assert retro.status_code == 409, retro.text

        # Terminal: rechazado→aceptado (cleanup anidado: el finally externo
        # no conoce a `nuevo` si un assert falla antes).
        nuevo_user_id = None
        try:
            nuevo = await _setup_pedido(
                async_client, db_session, nombre="Terminal Test"
            )
            nuevo_user_id = nuevo[0]["id"]
            term = await _avanzar(async_client, cocina, nuevo[4]["id"], "rechazado")
            assert term.status_code == 200, term.text
            terminal = await _avanzar(async_client, cocina, nuevo[4]["id"], "aceptado")
            assert terminal.status_code == 409, terminal.text
        finally:
            if nuevo_user_id is not None:
                await _borrar_pedidos_usuario(db_session, nuevo_user_id)
                await _cerrar_sesiones_usuario(db_session, nuevo_user_id)
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_matriz_mesero_403_aceptar(async_client, db_session):
    """Mesero sobre pedido enviado con transición VÁLIDA (aceptar) pero rol
    NO autorizado → 403."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    mesero = await login_staff_demo(async_client, _MESERO)
    try:
        resp = await _avanzar(async_client, mesero, pedido["id"], "aceptado")
        assert resp.status_code == 403, resp.text
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_matriz_mesero_200_servido(async_client, db_session):
    """Mesero sobre pedido en_preparacion → servido (transición válida + rol
    autorizado) → 200."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    mesero = await login_staff_demo(async_client, _MESERO)
    pid = pedido["id"]
    try:
        for estado in ("aceptado", "en_preparacion"):
            resp = await _avanzar(async_client, cocina, pid, estado)
            assert resp.status_code == 200, resp.text
        servido = await _avanzar(async_client, mesero, pid, "servido")
        assert servido.status_code == 200, servido.text
        assert servido.json()["estado"] == "servido"
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_matriz_orden_409_antes_403(async_client, db_session):
    """Mesero pide enviado→servido (transición INVÁLIDA y rol no autorizado
    para servido desde... en realidad la transición es inválida primero) →
    409, NO 403: la validez de la transición NO se filtra por rol."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    mesero = await login_staff_demo(async_client, _MESERO)
    try:
        resp = await _avanzar(async_client, mesero, pedido["id"], "servido")
        assert resp.status_code == 409, (
            f"409 (transición inválida) debe evaluarse ANTES que 403 (rol); "
            f"recibido {resp.status_code}: {resp.text}"
        )
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


# --- PEDI-05/06: cola tenant-scoped -------------------------------------------


async def _crear_pedido_tenant_2(db_session):
    """Restaurante 2 + usuario + mesa + sesión + pedido (patrón GRI-TEST-*),
    todo directo por DB. El usuario es DEDICADO (el UNIQUE(usuario_id,
    activo_flag) de 0004 impide dos sesiones activas del mismo usuario).
    Retorna (r2, mesa2, user2, sesion2, pedido2)."""
    r2 = Restaurante(nombre=f"Cross Staff {uuid4().hex[:6]}")
    db_session.add(r2)
    await db_session.flush()
    user2 = Usuario(
        nombre="Cross Staff User",
        email=f"cross-staff-{uuid4().hex[:8]}@x.com",
        password_hash="not-a-real-hash",
        role=RolUsuario.cliente,
        restaurant_id=None,
    )
    db_session.add(user2)
    await db_session.flush()
    mesa2 = Mesa(
        restaurant_id=r2.id, numero=1, capacidad=2, codigo_qr="GRI-TEST-STF-01"
    )
    db_session.add(mesa2)
    await db_session.flush()
    sesion2 = SesionMesa(
        restaurant_id=r2.id, mesa_id=mesa2.id, usuario_id=user2.id
    )
    db_session.add(sesion2)
    await db_session.flush()
    pedido2 = Pedido(
        restaurant_id=r2.id,
        mesa_id=mesa2.id,
        usuario_id=user2.id,
        sesion_id=sesion2.id,
        estado="enviado",
        total=Decimal("1000.00"),
    )
    db_session.add(pedido2)
    await db_session.commit()
    return r2, mesa2, user2, sesion2, pedido2


async def _borrar_pedido_tenant_2(db_session, r2, mesa2, user2, sesion2, pedido2):
    """Borrado en orden FK inverso (pedido → sesión → mesa → usuario → r2)."""
    await db_session.rollback()
    await db_session.delete(pedido2)
    await db_session.flush()
    await db_session.delete(sesion2)
    await db_session.flush()
    await db_session.delete(mesa2)
    await db_session.flush()
    await db_session.delete(user2)
    await db_session.flush()
    await db_session.delete(r2)
    await db_session.commit()


@pytest.mark.asyncio
async def test_pedido_cross_tenant_404(async_client, db_session):
    """Pedido de OTRO tenant → 404 (existence hiding: idéntico a
    inexistente). Staff del restaurante 1 opera el pedido GRI-TEST del
    restaurante 2."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    r2, mesa2, user2, sesion2, pedido2 = await _crear_pedido_tenant_2(db_session)
    try:
        resp = await _avanzar(async_client, cocina, pedido2.id, "aceptado")
        assert resp.status_code == 404, resp.text
    finally:
        await _borrar_pedido_tenant_2(db_session, r2, mesa2, user2, sesion2, pedido2)
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_cola_tenant_scoped(async_client, db_session):
    """La cola del staff r1 NO incluye el pedido GRI-TEST del r2; SÍ incluye
    el de r1 con todos los campos display (mesa_numero, items[nombre,
    cantidad, precio float], total float, notas, usuario_nombre)."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    r2, mesa2, user2, sesion2, pedido2 = await _crear_pedido_tenant_2(db_session)
    try:
        resp = await async_client.get(
            "/staff/pedidos?activos=true", headers=auth_header(cocina)
        )
        assert resp.status_code == 200, resp.text
        cola = resp.json()
        ids = [p["id"] for p in cola]
        assert pedido2.id not in ids, "pedido cross-tenant JAMÁS en la cola"
        assert pedido["id"] in ids

        ours = next(p for p in cola if p["id"] == pedido["id"])
        assert ours["mesa_numero"] == _MESA
        assert ours["usuario_nombre"] == user["nombre"]
        assert ours["notas"] == "Sin cebolla"
        assert isinstance(ours["total"], float)
        assert ours["total"] == pedido["total"]
        item = ours["items"][0]
        assert item["nombre"] == "Bandeja Paisa"
        assert item["cantidad"] == 1
        assert isinstance(item["precio_unitario"], float)
        assert ours["solicita_cuenta"] is False
    finally:
        await _borrar_pedido_tenant_2(db_session, r2, mesa2, user2, sesion2, pedido2)
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_cola_super_admin_sin_param_400_con_param_200(
    async_client, super_admin_token
):
    """super_admin SIN ?restaurante_id= → 400; CON param válido → 200."""
    headers = auth_header(super_admin_token)
    sin = await async_client.get("/staff/pedidos?activos=true", headers=headers)
    assert sin.status_code == 400, sin.text
    con = await async_client.get(
        "/staff/pedidos?activos=true&restaurante_id=1", headers=headers
    )
    assert con.status_code == 200, con.text
    assert isinstance(con.json(), list)


@pytest.mark.asyncio
async def test_cola_cliente_403(async_client, db_session):
    """Token de cliente en GET /staff/pedidos → 403 (get_tenant_scope)."""
    user, token, headers = await _crear_cliente(async_client)
    try:
        resp = await async_client.get(
            "/staff/pedidos?activos=true", headers=headers
        )
        assert resp.status_code == 403, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])


@pytest.mark.asyncio
async def test_cola_orden_fifo(async_client, db_session):
    """2 pedidos; avanzar el PRIMERO a aceptado → la cola lista el enviado
    (2º) ANTES del aceptado (1º): FIELD(estado,...), created_at ASC."""
    user, token, headers, sesion_id, p1 = await _setup_pedido(
        async_client, db_session
    )
    from app.models.menu import Producto

    await db_session.rollback()
    db_session.expire_all()
    prod = (
        await db_session.execute(
            select(Producto).where(
                Producto.restaurant_id == 1,
                Producto.nombre == "Limonada de Coco",
            )
        )
    ).scalar_one()
    p2_resp = await async_client.post(
        "/cliente/pedidos",
        json={
            "sesion_id": sesion_id,
            "items": [{"producto_id": prod.id, "cantidad": 2}],
        },
        headers=headers,
    )
    assert p2_resp.status_code == 201, p2_resp.text
    p2 = p2_resp.json()

    cocina = await login_staff_demo(async_client, _COCINA)
    try:
        avance = await _avanzar(async_client, cocina, p1["id"], "aceptado")
        assert avance.status_code == 200, avance.text

        resp = await async_client.get(
            "/staff/pedidos?activos=true", headers=auth_header(cocina)
        )
        assert resp.status_code == 200, resp.text
        cola = resp.json()
        ids = [p["id"] for p in cola]
        assert p1["id"] in ids and p2["id"] in ids
        assert ids.index(p2["id"]) < ids.index(p1["id"]), (
            "el pedido enviado (2º) debe listar ANTES del aceptado (1º)"
        )
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_cola_incluye_solicita_cuenta(async_client, db_session):
    """POST cuenta del cliente → la cola muestra solicita_cuenta=true en el
    pedido de esa sesión (badge PAGO-01)."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    cocina = await login_staff_demo(async_client, _COCINA)
    try:
        cuenta = await async_client.post(
            "/cliente/sesiones/actual/cuenta", headers=headers
        )
        assert cuenta.status_code == 200, cuenta.text

        resp = await async_client.get(
            "/staff/pedidos?activos=true", headers=auth_header(cocina)
        )
        assert resp.status_code == 200, resp.text
        ours = next(p for p in resp.json() if p["id"] == pedido["id"])
        assert ours["solicita_cuenta"] is True
        assert ours["solicitada_en"] is not None
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


# --- Anti-zombi: limpieza cierra la sesión -------------------------------------


@pytest.mark.asyncio
async def test_anti_zombi_limpieza_cierra_sesion(async_client, db_session):
    """mesa→limpieza (staff) cierra la sesión activa de esa mesa EN LA MISMA
    tx: sesión cerrada_en NOT NULL + estado=cerrada en DB, y GET
    /cliente/sesiones/actual del cliente pasa a 404."""
    user, token, headers, sesion_id, pedido = await _setup_pedido(
        async_client, db_session
    )
    admin = await login_staff_demo(async_client, _ADMIN)

    mesa = (
        await db_session.execute(
            select(Mesa).where(Mesa.restaurant_id == 1, Mesa.numero == _MESA)
        )
    ).scalar_one()
    try:
        resp = await async_client.post(
            f"/staff/mesas/{mesa.id}/estado",
            json={"estado": "limpieza"},
            headers=auth_header(admin),
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["estado"] == "limpieza"

        # DB: sesión cerrada en la misma tx (rollback + expire_all + get).
        await db_session.rollback()
        db_session.expire_all()
        sesion = await db_session.get(SesionMesa, sesion_id)
        assert sesion is not None
        assert sesion.cerrada_en is not None
        assert sesion.estado == EstadoSesion.cerrada

        # El cliente ya no tiene sesión activa.
        actual = await async_client.get("/cliente/sesiones/actual", headers=headers)
        assert actual.status_code == 404, actual.text
    finally:
        await _borrar_pedidos_usuario(db_session, user["id"])
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])
