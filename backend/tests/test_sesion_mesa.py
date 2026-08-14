"""Tests MESA-05/06 — sesión de mesa por QR (POST /cliente/sesiones).

Contrato (06-01 Task 1):

- QR válido de mesa disponible/reservada → 201 SesionRead + mesa pasa a
  ocupada (verificado en DB con rollback+expire_all+get — lección 05-01/05-02).
- QR inexistente o restaurante inactivo → 404 (existence hiding).
- Re-escanear MI sesión activa → 200 idempotente (mismo id, no crea segunda).
- Sesión activa de OTRO usuario en la mesa → 409.
- Mi sesión activa en OTRA mesa → 409 (mensaje menciona la sesión activa).
- Mesa en limpieza → 409 (validar_transicion raises → router mapea).
- GET /cliente/sesiones/actual: 200 con sesión / 404 sin sesión.
- HARD GATE concurrencia: 2 usuarios abren sesión en la MISMA mesa
  simultáneamente → exactamente 1×201 + 1×409 (FOR UPDATE +
  UNIQUE(mesa_id, activo_flag) + UNIQUE(usuario_id, activo_flag) +
  IntegrityError→409 — la BD gana la carrera).

Cleanup (regla de residuo STATE.md): cada test cierra las sesiones que creó
(UPDATE cerrada_en=NOW()) y restaura las mesas del seed a 'disponible' vía
db_session. Setup defensivo: _reset_mesa auto-repara residuo de runs fallidos
previos (invariante disponible + sin sesión activa) — NUNCA asertar counts
absolutos sobre la BD compartida.
"""

import asyncio
from uuid import uuid4

import pytest
from sqlalchemy import func, select, update

from app.models.mesa import EstadoMesa, Mesa
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa

from .conftest import abrir_sesion, auth_header, login, register_cliente

# Mesas del seed (restaurante 1) usadas por estos tests — números fijos para
# que el cleanup restaure exactamente lo que el test tocó.
_M5, _M6, _M7, _M8 = 5, 6, 7, 8


# --- Helpers ---------------------------------------------------------------


async def _crear_cliente(client, *, nombre="Sesion QR Test") -> tuple[dict, str, dict]:
    """Registra un cliente fresco; retorna (body, access_token, auth_headers)."""
    body = await register_cliente(client, nombre=nombre)
    access, _ = await login(client, body["email"], body["_password"])
    return body, access, auth_header(access)


async def _reset_mesas(db_session, numeros: list[int]) -> None:
    """Restaura las mesas del seed a su invariante: disponible + sin sesión
    activa. Auto-repara residuo de runs previos fallidos (lección 05-02:
    restaurar SIEMPRE al invariante, no al estado de entrada)."""
    await db_session.rollback()
    db_session.expire_all()
    for numero in numeros:
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
        mesa.estado = EstadoMesa.disponible
    await db_session.commit()


async def _cerrar_sesiones_usuario(db_session, usuario_id: int) -> None:
    """Cierra TODAS las sesiones activas del usuario de este test."""
    await db_session.rollback()
    await db_session.execute(
        update(SesionMesa)
        .where(SesionMesa.usuario_id == usuario_id, SesionMesa.cerrada_en.is_(None))
        .values(estado=EstadoSesion.cerrada, cerrada_en=func.now())
    )
    await db_session.commit()


async def _get_mesa_fresca(db_session, numero: int) -> Mesa:
    """Mesa del seed leída en tx NUEVA (rollback + expire_all + get —
    determinístico tras commits del API; gotcha identity map 05-02)."""
    await db_session.rollback()
    db_session.expire_all()
    return (
        await db_session.execute(
            select(Mesa).where(Mesa.restaurant_id == 1, Mesa.numero == numero)
        )
    ).scalar_one()


# --- MESA-06: abrir sesión --------------------------------------------------


@pytest.mark.asyncio
async def test_qr_valido_abre_sesion_y_ocupa_mesa(async_client, db_session):
    """QR válido de mesa disponible → 201 SesionRead + mesa ocupada en DB."""
    await _reset_mesas(db_session, [_M5])
    user, token, headers = await _crear_cliente(async_client)
    try:
        resp = await abrir_sesion(async_client, token, "GRI-MESA-005")
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert isinstance(body["id"], int)
        assert body["mesa_numero"] == _M5
        assert body["restaurante_nombre"] == "Restaurante Demo GRI"
        assert body["solicita_cuenta"] is False
        assert body["solicitada_en"] is None

        # DB: mesa ocupada + sesión activa (rollback + expire_all + get).
        mesa = await _get_mesa_fresca(db_session, _M5)
        assert mesa.estado == EstadoMesa.ocupada
        sesion = await db_session.get(SesionMesa, body["id"])
        assert sesion is not None
        assert sesion.cerrada_en is None
        assert sesion.usuario_id == user["id"]
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_M5])


@pytest.mark.asyncio
async def test_qr_invalido_404(async_client):
    """QR inexistente → 404."""
    _, token, headers = await _crear_cliente(async_client)
    resp = await abrir_sesion(async_client, token, "GRI-MESA-999")
    assert resp.status_code == 404, resp.text


@pytest.mark.asyncio
async def test_restaurante_inactivo_404(async_client, db_session):
    """QR de mesa de restaurante inactivo → 404 (existence hiding público)."""
    r = Restaurante(nombre=f"Inactivo Sess {uuid4().hex[:6]}", activo=False)
    db_session.add(r)
    await db_session.flush()
    mesa = Mesa(
        restaurant_id=r.id, numero=1, capacidad=2, codigo_qr="GRI-TEST-SESS-01"
    )
    db_session.add(mesa)
    await db_session.commit()
    try:
        _, token, headers = await _crear_cliente(async_client)
        resp = await abrir_sesion(async_client, token, "GRI-TEST-SESS-01")
        assert resp.status_code == 404, resp.text
    finally:
        await db_session.rollback()
        await db_session.delete(mesa)
        await db_session.flush()
        await db_session.delete(r)
        await db_session.commit()


# --- MESA-05/06: idempotencia y conflictos -----------------------------------


@pytest.mark.asyncio
async def test_idempotencia_propia_200(async_client, db_session):
    """Re-escanear MI sesión activa → 200 con el MISMO id (no crea segunda)."""
    await _reset_mesas(db_session, [_M5])
    user, token, headers = await _crear_cliente(async_client)
    try:
        first = await abrir_sesion(async_client, token, "GRI-MESA-005")
        assert first.status_code == 201, first.text
        second = await abrir_sesion(async_client, token, "GRI-MESA-005")
        assert second.status_code == 200, second.text
        assert second.json()["id"] == first.json()["id"]
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_M5])


@pytest.mark.asyncio
async def test_sesion_ajena_409(async_client, db_session):
    """Usuario B escanea la mesa con sesión activa de A → 409."""
    await _reset_mesas(db_session, [_M5])
    user_a, token_a, headers_a = await _crear_cliente(async_client, nombre="Usuario A")
    user_b, token_b, headers_b = await _crear_cliente(async_client, nombre="Usuario B")
    try:
        resp_a = await abrir_sesion(async_client, token_a, "GRI-MESA-005")
        assert resp_a.status_code == 201, resp_a.text
        resp_b = await abrir_sesion(async_client, token_b, "GRI-MESA-005")
        assert resp_b.status_code == 409, resp_b.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user_a["id"])
        await _cerrar_sesiones_usuario(db_session, user_b["id"])
        await _reset_mesas(db_session, [_M5])


@pytest.mark.asyncio
async def test_usuario_con_sesion_en_otra_mesa_409(async_client, db_session):
    """A con sesión activa en mesa 5 escanea mesa 6 → 409 (una sesión activa
    por USUARIO — UNIQUE(usuario_id, activo_flag) de la migración 0004)."""
    await _reset_mesas(db_session, [_M5, _M6])
    user, token, headers = await _crear_cliente(async_client)
    try:
        first = await abrir_sesion(async_client, token, "GRI-MESA-005")
        assert first.status_code == 201, first.text
        second = await abrir_sesion(async_client, token, "GRI-MESA-006")
        assert second.status_code == 409, second.text
        assert "sesión activa" in second.json()["detail"]
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_M5, _M6])


@pytest.mark.asyncio
async def test_mesa_limpieza_409(async_client, db_session):
    """Mesa en limpieza → 409 (validar_transicion 'limpieza→ocupada' raises)."""
    # Bypass directo de la state machine para el fixture (set DB puro).
    await _reset_mesas(db_session, [_M7])
    mesa = await _get_mesa_fresca(db_session, _M7)
    mesa.estado = EstadoMesa.limpieza
    await db_session.commit()
    _, token, headers = await _crear_cliente(async_client)
    try:
        resp = await abrir_sesion(async_client, token, "GRI-MESA-007")
        assert resp.status_code == 409, resp.text
    finally:
        await _reset_mesas(db_session, [_M7])


# --- GET /cliente/sesiones/actual -------------------------------------------


@pytest.mark.asyncio
async def test_get_sesion_actual(async_client, db_session):
    """Con sesión abierta → 200 SesionRead completo; sin sesión → 404."""
    await _reset_mesas(db_session, [_M5])
    user, token, headers = await _crear_cliente(async_client)

    # Sin sesión → 404.
    empty = await async_client.get("/cliente/sesiones/actual", headers=headers)
    assert empty.status_code == 404, empty.text

    try:
        created = await abrir_sesion(async_client, token, "GRI-MESA-005")
        assert created.status_code == 201, created.text
        actual = await async_client.get("/cliente/sesiones/actual", headers=headers)
        assert actual.status_code == 200, actual.text
        body = actual.json()
        assert body["id"] == created.json()["id"]
        assert body["mesa_numero"] == _M5
        assert body["restaurante_nombre"] == "Restaurante Demo GRI"
        assert body["solicita_cuenta"] is False
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_M5])


# --- HARD GATE: concurrencia -------------------------------------------------


@pytest.mark.asyncio
async def test_concurrencia_misma_mesa(async_client, db_session):
    """HARD GATE: 2 usuarios abren sesión en la MISMA mesa simultáneamente
    (asyncio.gather) → EXACTAMENTE 1×201 + 1×409. FOR UPDATE serializa, el
    perdedor ve la sesión del ganador (409 ajeno); si ambos colaran, el
    UNIQUE(mesa_id, activo_flag) gana → IntegrityError → 409."""
    await _reset_mesas(db_session, [_M8])
    user_a, token_a, headers_a = await _crear_cliente(async_client, nombre="Concurrencia A")
    user_b, token_b, headers_b = await _crear_cliente(async_client, nombre="Concurrencia B")
    try:
        responses = await asyncio.gather(
            abrir_sesion(async_client, token_a, "GRI-MESA-008"),
            abrir_sesion(async_client, token_b, "GRI-MESA-008"),
        )
        codes = sorted(r.status_code for r in responses)
        assert codes == [201, 409], (
            f"HARD GATE VIOLADO: se esperaba exactamente 1×201 + 1×409, "
            f"recibido {codes} — {[r.text for r in responses]}"
        )

        # DB: exactamente UNA sesión activa en la mesa (refuerzo del gate).
        await db_session.rollback()
        db_session.expire_all()
        mesa = await _get_mesa_fresca(db_session, _M8)
        assert mesa.estado == EstadoMesa.ocupada
        activas = (
            await db_session.execute(
                select(func.count())
                .select_from(SesionMesa)
                .where(SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None))
            )
        ).scalar_one()
        assert activas == 1
    finally:
        await _cerrar_sesiones_usuario(db_session, user_a["id"])
        await _cerrar_sesiones_usuario(db_session, user_b["id"])
        await _reset_mesas(db_session, [_M8])
