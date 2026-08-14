"""Tests MESA-04 + RESV-05 (marcar) — POST /staff/mesas/{id}/estado.

El endpoint aplica MESA_TRANSITIONS via ``validar_transicion("mesa", ...)``:
transición válida → 200 + MesaRead actualizada; inválida (ej. limpieza→ocupada)
→ 409; mesa ajena/inexistente → 404 (existence hiding cross-tenant — la mesa
del OTRO restaurante no existe para el staff).

Setup de estados: manipulación directa vía ``db_session`` (UPDATE mesa SET
estado=...), como indica el plan 05-02 Task 2. Verificación post-POST:
rollback + get fresco (lección REPEATABLE READ de 05-01 — la tx del test
mantiene el snapshot del primer read; NUNCA refresh tras un commit del API).

Cada test restaura el estado original de la mesa que tocó (try/finally).
"""

from uuid import uuid4

import pytest
from sqlalchemy import delete, select

from app.models.mesa import EstadoMesa, Mesa
from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

from .conftest import auth_header, login

_ADMIN_DEMO = ("admin@demo.gri.dev", "Demo!1234")


async def _mesa_demo(db_session) -> Mesa:
    """Primera mesa del restaurante demo (numero asc). Nunca hardcodear PK."""
    mesa = (
        await db_session.execute(
            select(Mesa)
            .join(Restaurante, Restaurante.id == Mesa.restaurant_id)
            .where(Restaurante.nombre == "Restaurante Demo GRI")
            .order_by(Mesa.numero)
            .limit(1)
        )
    ).scalar_one()
    return mesa


async def _set_estado(db_session, mesa_id: int, estado: EstadoMesa) -> None:
    """Fuerza el estado de la mesa vía BD (setup directo, sin pasar por el API)."""
    mesa = await db_session.get(Mesa, mesa_id)
    mesa.estado = estado
    await db_session.commit()


async def _estado_fresco(db_session, mesa_id: int) -> EstadoMesa:
    """Lee el estado post-commit-del-API: rollback cierra la tx REPEATABLE
    READ para que el get vea el commit hecho por la sesión del API."""
    await db_session.rollback()
    mesa = await db_session.get(Mesa, mesa_id)
    return mesa.estado


async def _restaurar_estado(db_session, mesa_id: int, original: EstadoMesa) -> None:
    """Restaura el estado original de la mesa vía cadena de transiciones
    válidas (limpieza→disponible, ocupada→limpieza→disponible, etc.) —
    buen ciudadano de la BD compartida."""
    await db_session.rollback()
    mesa = await db_session.get(Mesa, mesa_id)
    if mesa.estado == original:
        return
    # Llevar a disponible por el camino válido, luego al original si hace falta.
    if mesa.estado == EstadoMesa.ocupada:
        mesa.estado = EstadoMesa.limpieza
        await db_session.flush()
    if mesa.estado == EstadoMesa.limpieza:
        mesa.estado = EstadoMesa.disponible
        await db_session.flush()
    if mesa.estado == EstadoMesa.reservada and original != EstadoMesa.reservada:
        mesa.estado = EstadoMesa.disponible
        await db_session.flush()
    if mesa.estado != original:
        # disponible → original por transición directa (todas válidas desde
        # disponible: reservada/ocupada) o ya coincide.
        mesa.estado = original
    await db_session.commit()


async def _post_estado(async_client, headers, mesa_id: int, estado: str):
    """POST /staff/mesas/{id}/estado con body {estado}; retorna la response."""
    return await async_client.post(
        f"/staff/mesas/{mesa_id}/estado", json={"estado": estado}, headers=headers
    )


# --- MESA-04: transiciones válidas -------------------------------------------


@pytest.mark.asyncio
async def test_reservada_to_ocupada(async_client, db_session):
    """RESV-05 clave: cliente llega, admin marca la mesa ocupada.
    reservada→ocupada es válida en MESA_TRANSITIONS → 200 + estado ocupada."""
    mesa = await _mesa_demo(db_session)
    original = mesa.estado
    access, _ = await login(async_client, *_ADMIN_DEMO)
    headers = auth_header(access)
    try:
        await _set_estado(db_session, mesa.id, EstadoMesa.reservada)
        resp = await _post_estado(async_client, headers, mesa.id, "ocupada")
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["id"] == mesa.id
        assert body["estado"] == "ocupada"
        # Verificación DB directa (rollback + get fresco — REPEATABLE READ).
        assert await _estado_fresco(db_session, mesa.id) == EstadoMesa.ocupada
    finally:
        await _restaurar_estado(db_session, mesa.id, original)


@pytest.mark.asyncio
async def test_disponible_to_ocupada(async_client, db_session):
    """Walk-in válido: disponible→ocupada está en MESA_TRANSITIONS → 200."""
    mesa = await _mesa_demo(db_session)
    original = mesa.estado
    access, _ = await login(async_client, *_ADMIN_DEMO)
    headers = auth_header(access)
    try:
        await _set_estado(db_session, mesa.id, EstadoMesa.disponible)
        resp = await _post_estado(async_client, headers, mesa.id, "ocupada")
        assert resp.status_code == 200, resp.text
        assert resp.json()["estado"] == "ocupada"
        assert await _estado_fresco(db_session, mesa.id) == EstadoMesa.ocupada
    finally:
        await _restaurar_estado(db_session, mesa.id, original)


@pytest.mark.asyncio
async def test_ocupada_to_limpieza(async_client, db_session):
    """Ciclo válido del state machine: ocupada→limpieza (post-comida) → 200."""
    mesa = await _mesa_demo(db_session)
    original = mesa.estado
    access, _ = await login(async_client, *_ADMIN_DEMO)
    headers = auth_header(access)
    try:
        await _set_estado(db_session, mesa.id, EstadoMesa.ocupada)
        resp = await _post_estado(async_client, headers, mesa.id, "limpieza")
        assert resp.status_code == 200, resp.text
        assert resp.json()["estado"] == "limpieza"
        assert await _estado_fresco(db_session, mesa.id) == EstadoMesa.limpieza
    finally:
        await _restaurar_estado(db_session, mesa.id, original)


# --- MESA-04: transición inválida → 409 ---------------------------------------


@pytest.mark.asyncio
async def test_invalid_transition_409(async_client, db_session):
    """MESA-04 clave: limpieza→ocupada NO está en MESA_TRANSITIONS → 409.
    La mesa NO muta (sigue limpieza) — el rechazo no deja estado drift."""
    mesa = await _mesa_demo(db_session)
    original = mesa.estado
    access, _ = await login(async_client, *_ADMIN_DEMO)
    headers = auth_header(access)
    try:
        await _set_estado(db_session, mesa.id, EstadoMesa.limpieza)
        resp = await _post_estado(async_client, headers, mesa.id, "ocupada")
        assert resp.status_code == 409, (
            f"limpieza→ocupada debe ser 409 (transición inválida); "
            f"recibido {resp.status_code}: {resp.text}"
        )
        assert "transici" in resp.json()["detail"].lower()
        # La mesa SIGUE en limpieza (sin drift).
        assert await _estado_fresco(db_session, mesa.id) == EstadoMesa.limpieza
    finally:
        await _restaurar_estado(db_session, mesa.id, original)


# --- Existence hiding cross-tenant + unknown id -------------------------------


@pytest.mark.asyncio
async def test_cross_tenant_404(async_client, db_session, super_admin_token):
    """La mesa del OTRO restaurante no existe para el staff (existence hiding):
    POST del admin del tenant 2 sobre una mesa del tenant 1 → 404 (NO 403)."""
    sa_headers = auth_header(super_admin_token)

    # Crear restaurante 2 + su admin vía /admin (super_admin).
    r_rest = await async_client.post(
        "/admin/restaurantes",
        json={"nombre": f"Cross Mesa {uuid4().hex[:6]}"},
        headers=sa_headers,
    )
    assert r_rest.status_code == 201, r_rest.text
    r2_id = r_rest.json()["id"]

    staff_email = f"mesa-admin2-{uuid4().hex[:8]}@x.com"
    staff_password = "S3cret0!"
    r_staff = await async_client.post(
        f"/admin/restaurantes/{r2_id}/staff",
        json={
            "nombre": "Admin Tenant 2 Mesas",
            "email": staff_email,
            "password": staff_password,
            "role": "admin_restaurante",
        },
        headers=sa_headers,
    )
    assert r_staff.status_code == 201, r_staff.text

    mesa = await _mesa_demo(db_session)  # mesa del TENANT 1
    original = mesa.estado
    access2, _ = await login(async_client, staff_email, staff_password)
    try:
        resp = await _post_estado(
            async_client, auth_header(access2), mesa.id, "ocupada"
        )
        assert resp.status_code == 404, (
            f"mesa ajena debe ser 404 (existence hiding, nunca 403); "
            f"recibido {resp.status_code}: {resp.text}"
        )
        # La mesa del tenant 1 NO mutó (el staff ajeno no puede tocarla).
        assert await _estado_fresco(db_session, mesa.id) == original

        # Sanity: el admin del tenant 1 SÍ puede.
        access1, _ = await login(async_client, *_ADMIN_DEMO)
        resp1 = await _post_estado(
            async_client, auth_header(access1), mesa.id, "ocupada"
        )
        assert resp1.status_code == 200, resp1.text
    finally:
        await _restaurar_estado(db_session, mesa.id, original)
        await db_session.execute(
            delete(Usuario).where(Usuario.email == staff_email)
        )
        await db_session.execute(
            delete(Restaurante).where(Restaurante.id == r2_id)
        )
        await db_session.commit()


@pytest.mark.asyncio
async def test_unknown_mesa_404(async_client):
    """id inexistente (999999999) → 404."""
    access, _ = await login(async_client, *_ADMIN_DEMO)
    resp = await _post_estado(
        async_client, auth_header(access), 999999999, "ocupada"
    )
    assert resp.status_code == 404
