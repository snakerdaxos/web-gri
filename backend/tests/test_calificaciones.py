"""Tests de calificaciones post-pago — CALI-01 (Phase 9, 09-02 Task 1).

Cubre los 5 bloques del behavior:
- Happy path: pedido pagado propio → 201 + fila con restaurant_id/usuario_id
  correctos (el service los llena desde el pedido, jamás del body).
- 404 ajeno (existence hiding — MISMO detalle que inexistente, no filtrable).
- 409 servido / 409 rechazado (única puerta: estado == pagado, T-09-03).
- 409 segunda calificación (uq_calificacion_pedido → IntegrityError → 409,
  patrón reserva 05-01 — la BD gana la carrera).
- 422 estrellas 0/6 + comentario 1001 chars (Pydantic ge/le + max_length;
  el CHECK de BD ck_calificacion_estrellas_rango es la segunda línea).

Arrange del "pagado": ``abrir_sesion_con_pedido_servido`` (09-01) + UPDATE
directo del estado — el API no expone transición a pagado fuera del pago
(consistente con test_domain_constraints). Cleanup con ``borrar_residuo_pago``
en finally (la calificación se borra PRIMERO — orden FK inverso).
"""

import pytest
from sqlalchemy import select, update

from app.models.calificacion import Calificacion
from app.models.pedido import EstadoPedido, Pedido

from .conftest import (
    abrir_sesion_con_pedido_servido,
    auth_header,
    borrar_residuo_pago,
    login,
    register_cliente,
)


async def _set_estado(db_session, pedido_id: int, estado: EstadoPedido) -> None:
    """Arrange: forzar el estado del pedido por DB-direct (la única vía real
    a pagado es el webhook de pago — 09-01). Rollback+expire_all después del
    commit (patrón anti-MissingGreenlet del conftest)."""
    await db_session.execute(
        update(Pedido).where(Pedido.id == pedido_id).values(estado=estado)
    )
    await db_session.commit()
    await db_session.rollback()
    db_session.expire_all()


async def _calificar(client, headers: dict, pedido_id: int, **overrides):
    """POST /cliente/calificaciones sin raise — el caller aserta el status."""
    body = {"pedido_id": pedido_id, "estrellas": 5}
    body.update(overrides)
    return await client.post(
        "/cliente/calificaciones", json=body, headers=headers
    )


async def _count_calificaciones(db_session, pedido_id: int) -> int:
    """Filas de calificacion de UN pedido — para asserts de cero residuo."""
    await db_session.rollback()
    db_session.expire_all()
    rows = (
        await db_session.execute(
            select(Calificacion).where(Calificacion.pedido_id == pedido_id)
        )
    ).scalars().all()
    return len(rows)


@pytest.mark.asyncio
async def test_calificar_pedido_pagado_201(async_client, db_session):
    """Happy path: pedido pagado propio → 201 con id/pedido_id/estrellas/
    comentario; fila en BD con restaurant_id y usuario_id correctos."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    pedido_id = ctx["pedido_ids"][0]
    try:
        pedido_db = await db_session.get(Pedido, pedido_id)
        restaurant_id_esperado = pedido_db.restaurant_id
        await _set_estado(db_session, pedido_id, EstadoPedido.pagado)

        resp = await _calificar(
            async_client,
            ctx["headers"],
            pedido_id,
            estrellas=5,
            comentario="Excelente",
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["pedido_id"] == pedido_id
        assert body["estrellas"] == 5
        assert body["comentario"] == "Excelente"
        assert isinstance(body["id"], int) and body["id"] > 0
        assert body["created_at"] is not None

        # Fila en BD con ownership + restaurante correctos (del pedido, no
        # del body — el body ni siquiera los acepta).
        filas = (
            await db_session.execute(
                select(Calificacion).where(Calificacion.pedido_id == pedido_id)
            )
        ).scalars().all()
        assert len(filas) == 1
        assert filas[0].usuario_id == ctx["usuario"]["id"]
        assert filas[0].restaurant_id == restaurant_id_esperado
        assert filas[0].estrellas == 5
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_calificar_ajeno_e_inexistente_404_igual(async_client, db_session):
    """Existence hiding: el 404 de un pedido AJENO (pagado, para probar que
    ownership se valida primero) y el de uno inexistente tienen detalle
    IDÉNTICO — un atacante no puede distinguirlos por enumeración."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    pedido_id = ctx["pedido_ids"][0]
    try:
        await _set_estado(db_session, pedido_id, EstadoPedido.pagado)
        ajeno = await register_cliente(async_client, nombre="Cliente Ajeno")
        token_b, _ = await login(async_client, ajeno["email"], ajeno["_password"])

        resp_ajeno = await _calificar(
            async_client, auth_header(token_b), pedido_id, estrellas=3
        )
        resp_inexistente = await _calificar(
            async_client, auth_header(token_b), 99999999, estrellas=3
        )
        assert resp_ajeno.status_code == 404, resp_ajeno.text
        assert resp_inexistente.status_code == 404
        assert (
            resp_ajeno.json()["detail"] == resp_inexistente.json()["detail"]
        ), "el 404 de ajeno e inexistente debe ser indistinguible"
        # Ninguna calificación se creó en el intento.
        assert await _count_calificaciones(db_session, pedido_id) == 0
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_calificar_no_pagado_409(async_client, db_session):
    """T-09-03: la única puerta es estado == pagado — servido → 409 y
    rechazado → 409 (terminal pero NO calificable)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session, n_pedidos=2)
    p_servido, p_rechazado = ctx["pedido_ids"]
    try:
        await _set_estado(db_session, p_rechazado, EstadoPedido.rechazado)

        for pedido_id in (p_servido, p_rechazado):
            resp = await _calificar(async_client, ctx["headers"], pedido_id, estrellas=4)
            assert resp.status_code == 409, resp.text
            assert "pagado" in resp.json()["detail"].lower()
            assert await _count_calificaciones(db_session, pedido_id) == 0
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_calificar_duplicado_409(async_client, db_session):
    """Segunda calificación del mismo pedido → 409 "ya calificado"; la fila
    de la primera NO se duplica (uq_calificacion_pedido manda)."""
    ctx = await abrir_sesion_con_pedido_servido(async_client, db_session)
    pedido_id = ctx["pedido_ids"][0]
    try:
        await _set_estado(db_session, pedido_id, EstadoPedido.pagado)
        primera = await _calificar(
            async_client, ctx["headers"], pedido_id, estrellas=5
        )
        assert primera.status_code == 201, primera.text

        segunda = await _calificar(
            async_client, ctx["headers"], pedido_id, estrellas=3
        )
        assert segunda.status_code == 409, segunda.text
        assert "ya fue calificado" in segunda.json()["detail"].lower()
        assert await _count_calificaciones(db_session, pedido_id) == 1
    finally:
        await borrar_residuo_pago(db_session, ctx)


@pytest.mark.asyncio
async def test_calificar_validacion_422(async_client):
    """Pydantic primera línea: estrellas 0/6 y comentario 1001 chars → 422
    (la validación ocurre ANTES de tocar la BD — no requiere cadena de
    pedidos ni deja residuo)."""
    usuario = await register_cliente(async_client, nombre="Validacion")
    token, _ = await login(async_client, usuario["email"], usuario["_password"])
    headers = auth_header(token)

    for estrellas in (0, 6):
        resp = await _calificar(async_client, headers, 1, estrellas=estrellas)
        assert resp.status_code == 422, f"estrellas={estrellas}: {resp.text}"

    resp = await _calificar(
        async_client, headers, 1, estrellas=5, comentario="x" * 1001
    )
    assert resp.status_code == 422, resp.text
