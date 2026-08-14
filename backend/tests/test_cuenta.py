"""Tests PAGO-01 — POST /cliente/sesiones/actual/cuenta.

Contrato (06-01 Task 2):

- 200 SesionRead con solicita_cuenta=true + solicitada_en not null
  (verificado en DB con rollback + expire_all + get — lección 05-01/05-02).
- IDEMPOTENTE: doble tap seguro — el segundo POST no cambia solicitada_en.
- Sin sesión activa → 404.

El flag es visible para el staff en la cola (test_cola_incluye_solicita_cuenta
de test_staff_pedidos.py, Task 3).
"""

import pytest
from sqlalchemy import func, select, update

from app.models.mesa import Mesa
from app.models.sesion_mesa import EstadoSesion, SesionMesa

from .conftest import abrir_sesion, auth_header, login, register_cliente

_MESA = 2  # mesas 3-8 las usan otros tests de la fase


# --- Helpers ---------------------------------------------------------------


async def _crear_cliente(client, *, nombre="Cuenta Test") -> tuple[dict, str, dict]:
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


# --- PAGO-01 -----------------------------------------------------------------


@pytest.mark.asyncio
async def test_pedir_cuenta_200(async_client, db_session):
    """POST cuenta → 200 con solicita_cuenta=true y solicitada_en seteado
    (flag + timestamp persistidos en DB)."""
    await _reset_mesas(db_session, [_MESA])
    user, token, headers = await _crear_cliente(async_client)
    opened = await abrir_sesion(async_client, token, f"GRI-MESA-{_MESA:03d}")
    assert opened.status_code == 201, opened.text
    sesion_id = opened.json()["id"]
    try:
        resp = await async_client.post(
            "/cliente/sesiones/actual/cuenta", headers=headers
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["id"] == sesion_id
        assert body["solicita_cuenta"] is True
        assert body["solicitada_en"] is not None

        # DB check determinístico (rollback + expire_all + get).
        await db_session.rollback()
        db_session.expire_all()
        sesion = await db_session.get(SesionMesa, sesion_id)
        assert sesion is not None
        assert sesion.solicita_cuenta is True
        assert sesion.solicitada_en is not None
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_cuenta_idempotente(async_client, db_session):
    """Doble tap: el segundo POST → 200 y solicitada_en NO cambia (mismo
    valor exacto que la primera respuesta)."""
    await _reset_mesas(db_session, [_MESA])
    user, token, headers = await _crear_cliente(async_client)
    opened = await abrir_sesion(async_client, token, f"GRI-MESA-{_MESA:03d}")
    assert opened.status_code == 201, opened.text
    try:
        first = await async_client.post(
            "/cliente/sesiones/actual/cuenta", headers=headers
        )
        assert first.status_code == 200, first.text
        second = await async_client.post(
            "/cliente/sesiones/actual/cuenta", headers=headers
        )
        assert second.status_code == 200, second.text
        assert second.json()["solicita_cuenta"] is True
        assert (
            second.json()["solicitada_en"] == first.json()["solicitada_en"]
        ), "doble tap no debe re-escribir solicitada_en"
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])


@pytest.mark.asyncio
async def test_cuenta_sin_sesion_404(async_client, db_session):
    """Sin sesión activa → 404."""
    await _reset_mesas(db_session, [_MESA])
    user, token, headers = await _crear_cliente(async_client)
    try:
        resp = await async_client.post(
            "/cliente/sesiones/actual/cuenta", headers=headers
        )
        assert resp.status_code == 404, resp.text
    finally:
        await _cerrar_sesiones_usuario(db_session, user["id"])
        await _reset_mesas(db_session, [_MESA])
