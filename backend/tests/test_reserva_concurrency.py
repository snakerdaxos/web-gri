"""HARD GATE — RESV-02 PITFALLS P1 verification: 10 POSTs CONCURRENTES al
mismo slot → exactamente 1×201 + 9×409. Sin doble reserva.

Si este test falla, RESV-02 NO está cubierto y la Fase 5 no puede cerrar.

Stack debe estar corriendo. La serialización vive en el DB (FOR UPDATE +
UNIQUE constraint + IntegrityError→409), no en app-locks. ``asyncio.gather``
+ httpx AsyncClient dispara requests verdaderamente concurrentes; el GIL no
serializa I/O, así que esto atrapa la race que los tests seriales no ven.

Aislamiento: ``num_personas=8`` fuerza que SOLO la mesa capacidad-8 del demo
califique como candidata (mesas [2,2,4,4,4,6,6,8] — solo una con capacidad
>= 8). Así las 10 requests compiten por EXACTAMENTE una mesa y la aserción
canónica 1×201 + 9×409 es determinista.
"""

import asyncio
import datetime as dt
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, select

from app.models.mesa import EstadoMesa, Mesa
from app.models.reserva import Reserva

from .conftest import auth_header, login, register_cliente


@pytest.mark.asyncio
async def test_concurrent_reservas_same_slot_only_one_wins(
    async_client, db_session
):
    """PITFALLS P1: 10 POSTs concurrentes mismo (restaurante, fecha, hora,
    num_personas=8) → EXACTAMENTE 1×201 + 9×409. No double-booking.

    ``num_personas=8`` reduce las candidatas a 1 sola mesa (capacidad 8),
    garantizando que las 10 requests compitan por la misma fila → FOR UPDATE
    serializa → solo la primera INSERTA → UNIQUE atrapa cualquier race
    remanente → IntegrityError → 409.
    """
    # Registro + login del cliente que dispara las 10 requests.
    cliente = await register_cliente(async_client, nombre="Concurrency Test")
    access, _ = await login(async_client, cliente["email"], cliente["_password"])
    headers = auth_header(access)

    # Dia aleatorio en 2099-12 para no chocar con residuo de la BD compartida.
    # num_personas=8 → solo la mesa capacidad-8 califica como candidata.
    dia = (uuid4().int % 28) + 1
    fecha = f"2099-12-{dia:02d}"
    payload = {
        "restaurante_id": 1,
        "fecha": fecha,
        "hora_inicio": "19:00:00",
        "num_personas": 8,
    }

    # 10 requests concurrentes. asyncio.gather dispara todas a la vez.
    tasks = [
        async_client.post("/cliente/reservas", json=payload, headers=headers)
        for _ in range(10)
    ]
    responses = await asyncio.gather(*tasks)
    status_codes = [r.status_code for r in responses]

    successes = status_codes.count(201)
    conflicts = status_codes.count(409)

    # Invariante CANÓNICA del PITFALLS P1 (plan acceptance criteria):
    # exactamente 1×201 + 9×409. Cualquier otra cuenta = doble reserva o bug.
    assert successes == 1, (
        f"Expected exactly 1 success, got {successes}: {sorted(status_codes)}"
    )
    assert conflicts == 9, (
        f"Expected exactly 9 conflicts, got {conflicts}: {sorted(status_codes)}"
    )

    # Verificación DB-level: ninguna (mesa_id, fecha, hora) tiene >1 reserva
    # activa. Refuerzo del HARD GATE — la cuenta HTTP ya es definitiva, pero
    # el check DB confirma que la constraint UNIQUE realmente impidió el
    # doble INSERT (no fue solo suerte del scheduling).
    duplicados = (
        await db_session.execute(
            select(Reserva.mesa_id, func.count())
            .where(
                Reserva.fecha == fecha,
                Reserva.hora_inicio == dt.time(19, 0, 0),
                Reserva.estado != "cancelada",
            )
            .group_by(Reserva.mesa_id)
            .having(func.count() > 1)
        )
    ).all()
    assert duplicados == [], (
        f"PITFALLS P1 VIOLADO: doble reserva detectada en {duplicados}; "
        f"status codes: {sorted(status_codes)}"
    )

    # --- Cleanup: borrar la reserva creada y revertir la mesa a disponible ---
    await db_session.execute(
        delete(Reserva).where(
            Reserva.fecha == fecha,
            Reserva.usuario_id == cliente["id"],
        )
    )
    # Revertir las mesas reservadas por este test a disponible.
    mesas_reservadas = (
        await db_session.execute(
            select(Mesa).where(
                Mesa.restaurant_id == 1, Mesa.estado == EstadoMesa.reservada
            )
        )
    ).scalars().all()
    for m in mesas_reservadas:
        m.estado = EstadoMesa.disponible
    await db_session.commit()
