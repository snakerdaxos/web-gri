"""Tests RESV-01/03/04 — /cliente/reservas (POST/GET/cancel).

Aislamiento de la BD compartida: cada test usa ``num_personas=8`` para que
SOLO la mesa capacidad-8 del demo (mesas [2,2,4,4,4,6,6,8]) califique como
candidata → el comportamiento es determinista (1 mesa por slot) y el cleanup
se simplifica. ``_futura_fecha_hora()`` genera (fecha, hora) únicas.

Cada test envuelve su cuerpo en ``try/finally`` para garantizar cleanup
incluso si el assert falla (evita residuo acumulado en la BD compartida —
gotcha STATE.md).

Stack debe estar corriendo; seed demo:
- restaurante id=1 "Restaurante Demo GRI"
- 8 mesas capacidades [2,2,4,4,4,6,6,8] → num_personas=8 califica solo mesa #8
- carlos@demo.gri.dev / Demo!1234 (cliente)
"""

import datetime as dt
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.mesa import EstadoMesa, Mesa
from app.models.reserva import EstadoReserva, Reserva

from .conftest import auth_header, hoy_db, login, register_cliente

# Capacidad máxima del demo = 8 (la única mesa con capacidad >= 8). Usarla
# en todos los tests de reserva garantiza UN solo candidato → determinismo.
_NUM_PERSONAS_TEST = 8


def _futura_fecha_hora() -> tuple[dt.date, dt.time]:
    """(fecha, hora) única futura para aislar reservas de test entre sí.

    Fecha = 2099-12-DD (D aleatorio 1-28). Hora = :00 aleatoria entre
    12:00 y 22:00. Slot horario (Phase 5 §1) → hora siempre :00."""
    dia = (uuid4().int % 28) + 1
    hora = 12 + (uuid4().int % 11)  # 12..22
    return dt.date(2099, 12, dia), dt.time(hora, 0, 0)


async def _crear_cliente_logueado(client, *, nombre="Reserva Test"):
    """Helper: registra un cliente fresco y retorna (headers, body)."""
    body = await register_cliente(client, nombre=nombre)
    access, _ = await login(client, body["email"], body["_password"])
    return auth_header(access), body


def _payload(fecha: dt.date, hora: dt.time) -> dict:
    return {
        "restaurante_id": 1,
        "fecha": fecha.isoformat(),
        "hora_inicio": hora.isoformat(),
        "num_personas": _NUM_PERSONAS_TEST,
    }


async def _cleanup_reserva(db_session, reserva_id: int | None):
    """Borra una reserva de test y revertir su mesa a 'disponible' si estaba
    'reservada'. Idempotente (None → no-op). Acepta mesa en cualquier estado
    (si el test la dejó ocupada/limpieza, la revertimos vía las transiciones
    válidas para volver a 'disponible')."""
    if reserva_id is None:
        return
    r = await db_session.get(Reserva, reserva_id)
    if r is None:
        # La reserva fue cancelada pero el row sigue — buscar por estado.
        return
    mesa = await db_session.get(Mesa, r.mesa_id)
    await db_session.delete(r)
    await db_session.flush()
    if mesa is not None:
        # Revertir la mesa a 'disponible' vía transiciones válidas.
        # Solo reservada→disponible es directa; ocupada/limpieza requieren cadena.
        if mesa.estado == EstadoMesa.reservada:
            mesa.estado = EstadoMesa.disponible
        elif mesa.estado == EstadoMesa.ocupada:
            mesa.estado = EstadoMesa.limpieza
            await db_session.flush()
            mesa.estado = EstadoMesa.disponible
        elif mesa.estado == EstadoMesa.limpieza:
            mesa.estado = EstadoMesa.disponible
    await db_session.commit()


# --- RESV-01 crear ---------------------------------------------------------


@pytest.mark.asyncio
async def test_crear_reserva_ok(async_client, db_session):
    """POST /cliente/reservas → 201; reserva nace confirmada; mesa asignada
    con capacidad suficiente queda en 'reservada'."""
    headers, _ = await _crear_cliente_logueado(async_client)
    fecha, hora = _futura_fecha_hora()
    reserva_id = None
    try:
        resp = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        reserva_id = body["id"]
        assert body["estado"] == "confirmada"
        assert body["restaurante_id"] == 1
        assert body["mesa_id"] is not None
        assert body["restaurante_nombre"] == "Restaurante Demo GRI"
        assert body["fecha"] == fecha.isoformat()
        assert body["num_personas"] == _NUM_PERSONAS_TEST

        # La mesa elegida debe estar reservada (efecto secundario correcto).
        mesa = await db_session.get(Mesa, body["mesa_id"])
        assert mesa.estado == EstadoMesa.reservada
    finally:
        await _cleanup_reserva(db_session, reserva_id)


@pytest.mark.asyncio
async def test_past_date_400(async_client):
    """fecha en pasado → 400. No se crea nada; sin cleanup.

    ``hoy_db()`` (no ``date.today()``): el service valida contra curdate()
    (Bogotá) y el contenedor corre en UTC — divergen 19:00-24:00 Bogotá."""
    headers, _ = await _crear_cliente_logueado(async_client)
    ayer = hoy_db() - dt.timedelta(days=1)
    resp = await async_client.post(
        "/cliente/reservas",
        json={
            "restaurante_id": 1,
            "fecha": ayer.isoformat(),
            "hora_inicio": "19:00:00",
            "num_personas": _NUM_PERSONAS_TEST,
        },
        headers=headers,
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_capacity_exceeded(async_client):
    """num_personas > capacidad máxima (9 > 8) → 409 'No hay mesas con
    capacidad suficiente'. Sin cleanup (no se crea nada)."""
    headers, _ = await _crear_cliente_logueado(async_client)
    fecha, hora = _futura_fecha_hora()
    resp = await async_client.post(
        "/cliente/reservas",
        json={
            "restaurante_id": 1,
            "fecha": fecha.isoformat(),
            "hora_inicio": hora.isoformat(),
            "num_personas": 9,  # max capacidad demo = 8
        },
        headers=headers,
    )
    assert resp.status_code == 409
    assert "capacidad" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_slot_taken_409(async_client, db_session):
    """RESV-02 (serial): dos POSTs mismos (fecha, hora) → primero 201,
    segundo 409. Con num_personas=8 SOLO la mesa capacidad-8 califica → la
    segunda POST encuentra el slot tomado → IntegrityError → 409."""
    headers, _ = await _crear_cliente_logueado(async_client)
    fecha, hora = _futura_fecha_hora()
    reserva_id = None
    try:
        r1 = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert r1.status_code == 201, r1.text
        reserva_id = r1.json()["id"]

        r2 = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert r2.status_code == 409, (
            f"segundo POST mismo slot debe ser 409 (mesa ya reservada); "
            f"recibido {r2.status_code}: {r2.text}"
        )
    finally:
        await _cleanup_reserva(db_session, reserva_id)


# --- RESV-03 listar --------------------------------------------------------


@pytest.mark.asyncio
async def test_list_propias_only(async_client, db_session):
    """GET /cliente/reservas lista SOLO las propias; cliente B no ve las
    reservas de cliente A."""
    headers_a, body_a = await _crear_cliente_logueado(async_client, nombre="Cliente A")
    headers_b, _ = await _crear_cliente_logueado(async_client, nombre="Cliente B")
    fecha, hora = _futura_fecha_hora()
    reserva_a_id = None
    try:
        # A crea una reserva.
        r = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers_a
        )
        assert r.status_code == 201, r.text
        reserva_a_id = r.json()["id"]

        # B lista sus reservas → no debe ver la de A.
        resp_b = await async_client.get("/cliente/reservas", headers=headers_b)
        assert resp_b.status_code == 200
        ids_b = {item["id"] for item in resp_b.json()}
        assert reserva_a_id not in ids_b

        # A lista las suyas → SÍ debe ver su reserva.
        resp_a = await async_client.get("/cliente/reservas", headers=headers_a)
        ids_a = {item["id"] for item in resp_a.json()}
        assert reserva_a_id in ids_a
    finally:
        await _cleanup_reserva(db_session, reserva_a_id)


@pytest.mark.asyncio
async def test_list_ordered(async_client, db_session):
    """GET /cliente/reservas → ordenadas por fecha DESC, hora DESC."""
    headers, _ = await _crear_cliente_logueado(async_client, nombre="Orden Test")
    reservas_creadas = []
    # Cada reserva usa (fecha, hora) DISTINTA para no chocar (UNIQUE slot).
    slots = [(dt.date(2099, 12, 5), dt.time(20, 0, 0)),
             (dt.date(2099, 12, 10), dt.time(18, 0, 0)),
             (dt.date(2099, 12, 10), dt.time(21, 0, 0))]
    try:
        for fecha, hora in slots:
            r = await async_client.post(
                "/cliente/reservas", json=_payload(fecha, hora), headers=headers
            )
            assert r.status_code == 201, r.text
            reservas_creadas.append(r.json()["id"])

        resp = await async_client.get("/cliente/reservas", headers=headers)
        assert resp.status_code == 200
        items = resp.json()
        ours = [it for it in items if it["id"] in reservas_creadas]
        assert len(ours) == 3

        # Orden DESC por (fecha, hora).
        pares = [(it["fecha"], it["hora_inicio"]) for it in ours]
        assert pares == sorted(pares, reverse=True), (
            f"debe estar DESC por (fecha, hora); recibido: {pares}"
        )
    finally:
        for rid in reservas_creadas:
            await _cleanup_reserva(db_session, rid)


# --- RESV-04 cancelar ------------------------------------------------------


@pytest.mark.asyncio
async def test_cancel_ok(async_client, db_session):
    """POST /cliente/reservas/{id}/cancelar → 200, estado=cancelada, mesa
    revertida a disponible."""
    headers, _ = await _crear_cliente_logueado(async_client, nombre="Cancel Ok")
    fecha, hora = _futura_fecha_hora()
    reserva_id = None
    try:
        r = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert r.status_code == 201, r.text
        reserva_id = r.json()["id"]
        mesa_id = r.json()["mesa_id"]

        cancel = await async_client.post(
            f"/cliente/reservas/{reserva_id}/cancelar", headers=headers
        )
        assert cancel.status_code == 200
        assert cancel.json()["estado"] == "cancelada"

        # La mesa debe estar disponible (reservada → disponible es válida).
        mesa = await db_session.get(Mesa, mesa_id)
        assert mesa.estado == EstadoMesa.disponible
    finally:
        await _cleanup_reserva(db_session, reserva_id)


@pytest.mark.asyncio
async def test_cancel_ajena_404(async_client, db_session):
    """Existence hiding: cancelar reserva de OTRO cliente → 404 (NO 403)."""
    headers_a, _ = await _crear_cliente_logueado(async_client, nombre="Otra A")
    headers_b, _ = await _crear_cliente_logueado(async_client, nombre="Otra B")
    fecha, hora = _futura_fecha_hora()
    reserva_a_id = None
    try:
        r = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers_a
        )
        assert r.status_code == 201, r.text
        reserva_a_id = r.json()["id"]

        # B intenta cancelar la de A → 404 (existence hiding).
        cancel = await async_client.post(
            f"/cliente/reservas/{reserva_a_id}/cancelar", headers=headers_b
        )
        assert cancel.status_code == 404

        # Sanity: A SÍ puede cancelar su propia reserva.
        cancel_a = await async_client.post(
            f"/cliente/reservas/{reserva_a_id}/cancelar", headers=headers_a
        )
        assert cancel_a.status_code == 200
    finally:
        await _cleanup_reserva(db_session, reserva_a_id)


@pytest.mark.asyncio
async def test_cancel_past_400(async_client, db_session):
    """Cancelar reserva con fecha pasada → 400 (no se cancela lo ya pasado)."""
    headers, body = await _crear_cliente_logueado(async_client, nombre="Past Cancel")
    # Crear una reserva "pasada" directamente en BD (la API rechazaría crearla).
    mesa = (
        await db_session.execute(
            select(Mesa)
            .where(Mesa.restaurant_id == 1, Mesa.capacidad >= _NUM_PERSONAS_TEST)
            .order_by(Mesa.numero)
            .limit(1)
        )
    ).scalar_one()
    ayer = hoy_db() - dt.timedelta(days=1)
    r_past = Reserva(
        restaurant_id=1,
        usuario_id=body["id"],
        mesa_id=mesa.id,
        fecha=ayer,
        hora_inicio=dt.time(19, 0, 0),
        num_personas=_NUM_PERSONAS_TEST,
        estado=EstadoReserva.confirmada,
    )
    db_session.add(r_past)
    await db_session.commit()
    await db_session.refresh(r_past)

    try:
        cancel = await async_client.post(
            f"/cliente/reservas/{r_past.id}/cancelar", headers=headers
        )
        assert cancel.status_code == 400
    finally:
        stale = await db_session.get(Reserva, r_past.id)
        if stale is not None:
            await db_session.delete(stale)
            await db_session.commit()


@pytest.mark.asyncio
async def test_cancel_reverts_mesa(async_client, db_session):
    """Cancelar reverte mesa reservada → disponible (comprobación DB directa
    del efecto secundario — Pitfall 4 inverso)."""
    headers, _ = await _crear_cliente_logueado(async_client, nombre="Revert Mesa")
    fecha, hora = _futura_fecha_hora()
    reserva_id = None
    try:
        r = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert r.status_code == 201, r.text
        reserva_id = r.json()["id"]
        mesa_id = r.json()["mesa_id"]

        # Pre: mesa reservada.
        mesa_pre = await db_session.get(Mesa, mesa_id)
        assert mesa_pre.estado == EstadoMesa.reservada

        await async_client.post(
            f"/cliente/reservas/{reserva_id}/cancelar", headers=headers
        )

        # Post: mesa disponible. MySQL REPEATABLE READ: la tx del test mantiene
        # el snapshot del primer read; rollback la cierra para que el get vea
        # el commit hecho por la sesion del API.
        await db_session.rollback()
        mesa_post = await db_session.get(Mesa, mesa_id)
        assert mesa_post.estado == EstadoMesa.disponible
    finally:
        await _cleanup_reserva(db_session, reserva_id)


@pytest.mark.asyncio
async def test_cancel_keeps_ocupada(async_client, db_session):
    """Pitfall 4: si la mesa fue promovida a 'ocupada' (cliente llegó, RESV-05),
    cancelar la reserva NO la reverte — sigue ocupada. MESA_TRANSITIONS solo
    permite ocupada→{limpieza}, no ocupada→disponible."""
    headers, _ = await _crear_cliente_logueado(async_client, nombre="Keep Ocupada")
    fecha, hora = _futura_fecha_hora()
    reserva_id = None
    try:
        r = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert r.status_code == 201, r.text
        reserva_id = r.json()["id"]
        mesa_id = r.json()["mesa_id"]

        # Simular RESV-05: el admin marcó la mesa como ocupada (cliente llegó).
        mesa = await db_session.get(Mesa, mesa_id)
        mesa.estado = EstadoMesa.ocupada  # reservada -> ocupada (válido)
        await db_session.commit()

        cancel = await async_client.post(
            f"/cliente/reservas/{reserva_id}/cancelar", headers=headers
        )
        assert cancel.status_code == 200
        assert cancel.json()["estado"] == "cancelada"

        # La mesa SIGUE ocupada (Pitfall 4 — NO se reverta).
        mesa_post = await db_session.get(Mesa, mesa_id)
        assert mesa_post.estado == EstadoMesa.ocupada, (
            f"Pitfall 4: mesa debe seguir ocupada tras cancelar reserva con mesa "
            f"ocupada; estado actual: {mesa_post.estado}"
        )
    finally:
        await _cleanup_reserva(db_session, reserva_id)


@pytest.mark.asyncio
async def test_cancel_idempotencia_invalida(async_client, db_session):
    """Cancelar una reserva YA cancelada → 409 (transición inválida:
    cancelada → cancelada no existe)."""
    headers, _ = await _crear_cliente_logueado(async_client, nombre="Cancel Twice")
    fecha, hora = _futura_fecha_hora()
    reserva_id = None
    try:
        r = await async_client.post(
            "/cliente/reservas", json=_payload(fecha, hora), headers=headers
        )
        assert r.status_code == 201, r.text
        reserva_id = r.json()["id"]

        c1 = await async_client.post(
            f"/cliente/reservas/{reserva_id}/cancelar", headers=headers
        )
        assert c1.status_code == 200

        c2 = await async_client.post(
            f"/cliente/reservas/{reserva_id}/cancelar", headers=headers
        )
        assert c2.status_code == 409, (
            f"segundo cancel debe ser 409 (estado terminal); recibido {c2.status_code}"
        )
    finally:
        await _cleanup_reserva(db_session, reserva_id)
