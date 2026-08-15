"""Tests RESV-05 (ver) — GET /staff/reservas (tenant-scoped, filtro fecha).

El endpoint lista las reservas del tenant del caller para una fecha dada
(default hoy DB-side via func.curdate(), Pitfall 6). Verifica:

- filtro por fecha exacta + joins display (restaurante_nombre, mesa_numero)
- default sin ?fecha= == ?fecha=hoy explícito
- aislamiento cross-tenant (staff del tenant 2 NO ve reservas del tenant 1)
- super_admin requiere ?restaurante_id= (400 si falta; 200 con param válido)

Aislamiento de la BD compartida (patrón test_reserva.py): num_personas=8 →
solo la mesa capacidad-8 del demo califica como candidata → determinismo +
cleanup simple. Cada test envuelve su cuerpo en try/finally.

Caveat TZ (Pitfall 6): el test usa date.today() del HOST (America/Bogota ==
TZ de la BD, -05:00). La validación de creación de reserva es API-side
(contenedor UTC), por lo que entre 19:00-24:00 Bogota (UTC ya en el día
siguiente) crear una reserva "para hoy" vía API puede recibir 400. Ejecutar
la suite en horario colombiano diurno evita la ventana; la divergencia es
un known issue documentado del v1 (misma asunción que test_reserva.py).
"""

import datetime as dt
from uuid import uuid4

import pytest
from sqlalchemy import delete

from app.models.mesa import EstadoMesa, Mesa
from app.models.reserva import Reserva
from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

from .conftest import auth_header, hoy_db, login, register_cliente

# Capacidad máxima del demo = 8 → único candidato → determinismo.
_NUM_PERSONAS_TEST = 8
_ADMIN_DEMO = ("admin@demo.gri.dev", "Demo!1234")


def _hora_unica() -> dt.time:
    """Hora :00 aleatoria 12..22 (slot horario §1) — minimiza colisiones de
    slot con residuo de runs previos fallidos en la BD compartida."""
    return dt.time(12 + (uuid4().int % 11), 0, 0)


async def _crear_cliente_logueado(client, *, nombre="Staff Reservas Test"):
    """Registra un cliente fresco y retorna sus auth headers (patrón 05-01)."""
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


async def _crear_reserva_api(async_client, headers, fecha, hora) -> dict:
    """POST /cliente/reservas como cliente; assert 201 y retorna el body."""
    resp = await async_client.post(
        "/cliente/reservas", json=_payload(fecha, hora), headers=headers
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


async def _cleanup_reserva(db_session, reserva_id: int | None):
    """Borra la reserva de test y revierte su mesa a 'disponible' vía la
    cadena de transiciones válidas (patrón test_reserva.py; idempotente)."""
    if reserva_id is None:
        return
    r = await db_session.get(Reserva, reserva_id)
    if r is None:
        return
    mesa = await db_session.get(Mesa, r.mesa_id)
    await db_session.delete(r)
    await db_session.flush()
    if mesa is not None:
        if mesa.estado == EstadoMesa.reservada:
            mesa.estado = EstadoMesa.disponible
        elif mesa.estado == EstadoMesa.ocupada:
            mesa.estado = EstadoMesa.limpieza
            await db_session.flush()
            mesa.estado = EstadoMesa.disponible
        elif mesa.estado == EstadoMesa.limpieza:
            mesa.estado = EstadoMesa.disponible
    await db_session.commit()


async def _cleanup_tenant_2(db_session, staff_email: str, r2_id: int):
    """Borra el restaurante del tenant 2 + su staff (orden FK: user primero)."""
    await db_session.execute(delete(Usuario).where(Usuario.email == staff_email))
    await db_session.execute(delete(Restaurante).where(Restaurante.id == r2_id))
    await db_session.commit()


# --- RESV-05 ver: filtro fecha + joins display --------------------------------


@pytest.mark.asyncio
async def test_list_by_fecha(async_client, db_session):
    """GET /staff/reservas?fecha=<hoy> → SOLO las de hoy (no las de mañana),
    con restaurante_nombre y mesa_numero poblados (joins display)."""
    headers_cliente, _ = await _crear_cliente_logueado(async_client)
    hoy = dt.date.today()
    manana = hoy + dt.timedelta(days=1)
    reserva_hoy_id = None
    reserva_manana_id = None
    try:
        body_hoy = await _crear_reserva_api(
            async_client, headers_cliente, hoy, _hora_unica()
        )
        reserva_hoy_id = body_hoy["id"]
        body_manana = await _crear_reserva_api(
            async_client, headers_cliente, manana, _hora_unica()
        )
        reserva_manana_id = body_manana["id"]

        access, _ = await login(async_client, *_ADMIN_DEMO)
        resp = await async_client.get(
            f"/staff/reservas?fecha={hoy.isoformat()}",
            headers=auth_header(access),
        )
        assert resp.status_code == 200, resp.text
        items = resp.json()
        ids = {it["id"] for it in items}
        assert reserva_hoy_id in ids, "la reserva de HOY debe aparecer"
        assert reserva_manana_id not in ids, "la reserva de mañana NO debe aparecer"

        ours = next(it for it in items if it["id"] == reserva_hoy_id)
        assert ours["restaurante_nombre"] == "Restaurante Demo GRI"
        assert isinstance(ours["mesa_numero"], int) and ours["mesa_numero"] > 0
        assert ours["fecha"] == hoy.isoformat()
        assert ours["estado"] == "confirmada"
    finally:
        await _cleanup_reserva(db_session, reserva_hoy_id)
        await _cleanup_reserva(db_session, reserva_manana_id)


@pytest.mark.asyncio
async def test_default_today(async_client, db_session):
    """GET /staff/reservas SIN ?fecha= ≡ ?fecha=hoy (func.curdate() DB-side,
    Pitfall 6 — nunca date.today() Python-side). ``hoy_db()`` alinea el
    arrange con el curdate() de la BD (el contenedor corre en UTC y diverge
    19:00-24:00 Bogotá)."""
    headers_cliente, _ = await _crear_cliente_logueado(async_client)
    hoy = hoy_db()
    reserva_id = None
    try:
        body = await _crear_reserva_api(
            async_client, headers_cliente, hoy, _hora_unica()
        )
        reserva_id = body["id"]

        access, _ = await login(async_client, *_ADMIN_DEMO)
        resp_default = await async_client.get(
            "/staff/reservas", headers=auth_header(access)
        )
        resp_hoy = await async_client.get(
            f"/staff/reservas?fecha={hoy.isoformat()}",
            headers=auth_header(access),
        )
        assert resp_default.status_code == 200, resp_default.text
        assert resp_hoy.status_code == 200, resp_hoy.text

        ids_default = {it["id"] for it in resp_default.json()}
        ids_hoy = {it["id"] for it in resp_hoy.json()}
        assert ids_default == ids_hoy, (
            "sin ?fecha= debe devolver exactamente lo mismo que ?fecha=hoy "
            f"(default DB-side); default={ids_default} vs hoy={ids_hoy}"
        )
        assert reserva_id in ids_default
    finally:
        await _cleanup_reserva(db_session, reserva_id)


# --- RESV-05 ver: tenant isolation --------------------------------------------


@pytest.mark.asyncio
async def test_cross_tenant(async_client, db_session, super_admin_token):
    """Staff del tenant 2 NO ve reservas del tenant 1: su lista (propia) no
    contiene la reserva creada en el tenant 1. Como el tenant 2 acaba de
    nacer, su lista debe ser [] (cero reservas propias)."""
    sa_headers = auth_header(super_admin_token)

    # Crear restaurante 2 + su admin vía /admin (super_admin).
    r_rest = await async_client.post(
        "/admin/restaurantes",
        json={"nombre": f"Cross Tenant {uuid4().hex[:6]}"},
        headers=sa_headers,
    )
    assert r_rest.status_code == 201, r_rest.text
    r2_id = r_rest.json()["id"]

    staff_email = f"admin2-{uuid4().hex[:8]}@x.com"
    staff_password = "S3cret0!"
    r_staff = await async_client.post(
        f"/admin/restaurantes/{r2_id}/staff",
        json={
            "nombre": "Admin Tenant 2",
            "email": staff_email,
            "password": staff_password,
            "role": "admin_restaurante",
        },
        headers=sa_headers,
    )
    assert r_staff.status_code == 201, r_staff.text

    # Reserva del tenant 1 (hoy) creada por un cliente.
    headers_cliente, _ = await _crear_cliente_logueado(async_client)
    reserva_id = None
    try:
        body = await _crear_reserva_api(
            async_client, headers_cliente, dt.date.today(), _hora_unica()
        )
        reserva_id = body["id"]

        # Staff del tenant 2 lista SUS reservas de hoy → vacía (y la del
        # tenant 1 JAMÁS aparece).
        access2, _ = await login(async_client, staff_email, staff_password)
        resp = await async_client.get(
            f"/staff/reservas?fecha={dt.date.today().isoformat()}",
            headers=auth_header(access2),
        )
        assert resp.status_code == 200, resp.text
        items = resp.json()
        ids = {it["id"] for it in items}
        assert reserva_id not in ids, (
            "reserva del tenant 1 NO debe ser visible para staff del tenant 2"
        )
        # Tenant 2 no tiene reservas propias → lista vacía estricta.
        assert items == [], (
            f"tenant 2 recién creado debe listar []; recibido: {items}"
        )

        # Sanity: staff del tenant 1 (admin demo) SÍ la ve.
        access1, _ = await login(async_client, *_ADMIN_DEMO)
        resp1 = await async_client.get(
            f"/staff/reservas?fecha={dt.date.today().isoformat()}",
            headers=auth_header(access1),
        )
        assert reserva_id in {it["id"] for it in resp1.json()}
    finally:
        await _cleanup_reserva(db_session, reserva_id)
        await _cleanup_tenant_2(db_session, staff_email, r2_id)


# --- RESV-05 ver: super_admin param contract ----------------------------------


@pytest.mark.asyncio
async def test_super_admin_requires_restaurante_id(async_client, super_admin_token):
    """super_admin SIN ?restaurante_id= → 400; CON param válido → 200."""
    headers = auth_header(super_admin_token)

    resp_sin = await async_client.get("/staff/reservas", headers=headers)
    assert resp_sin.status_code == 400, (
        f"super_admin sin restaurante_id debe ser 400; "
        f"recibido {resp_sin.status_code}: {resp_sin.text}"
    )

    resp_con = await async_client.get(
        "/staff/reservas?restaurante_id=1", headers=headers
    )
    assert resp_con.status_code == 200, resp_con.text
    assert isinstance(resp_con.json(), list)

    # Param inválido (restaurante inexistente) → 404 (existence hiding).
    resp_404 = await async_client.get(
        "/staff/reservas?restaurante_id=999999", headers=headers
    )
    assert resp_404.status_code == 404
