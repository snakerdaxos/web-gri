"""Reserva business logic — concurrent-safe create + cancel + list (RESV-01..04).

THE critical service of Phase 5. ``crear_reserva`` is the only write path on
the domain layer so far; it MUST be race-safe under concurrent requests
(PITFALLS P1). Defense in depth:

1. ``SELECT ... FOR UPDATE`` on candidate mesas — serializes concurrent txns
   that touch the same rows.
2. Application-level existence check (skip mesas with an active reserva on
   the requested slot).
3. ``UNIQUE (mesa_id, fecha, hora_inicio)`` constraint (migration 0003) —
   the last-line defense; if two txns slip past the FOR UPDATE check, the
   INSERT raises ``IntegrityError`` → mapped to 409.

Auto-confirm locked decision: reservas are created directly in
``estado=confirmada`` (no ``pendiente`` approval step). The state machine has
``pendiente`` but it's unused in v1.

Mesa assignment is automatic: the service picks the FIRST candidate mesa
(ordered by ``numero``) with capacity >= ``num_personas`` and no active
reserva on the requested slot. Phase 5 Concurrency Design §3.
"""

import datetime as dt

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password  # noqa: F401  (re-exported for clarity)
from app.core.state_machines import validar_transicion
from app.models.mesa import EstadoMesa, Mesa
from app.models.reserva import EstadoReserva, Reserva
from app.models.restaurante import Restaurante
from app.schemas.reserva import ReservaCreate, ReservaRead


def _validate_slot(fecha: dt.date, hora_inicio: dt.time) -> None:
    """400 on past date or non-hourly slot (Phase 5 Concurrency Design §1 —
    hourly slots, 60-min turn). ``hora_inicio`` MUST be at ``:00`` (minute=0,
    second=0) so the UNIQUE constraint alone prevents overlap."""
    if fecha < dt.date.today():
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "No se puede reservar en una fecha pasada",
        )
    if hora_inicio.minute != 0 or hora_inicio.second != 0:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "La hora de inicio debe ser un slot horario exacto (HH:00:00)",
        )


def _to_read(r: Reserva, restaurante_nombre: str, mesa_numero: int) -> ReservaRead:
    """Build a ReservaRead from the ORM row + display joins. Avoids relying
    on lazy relationships (which would trigger I/O after commit in async)."""
    return ReservaRead(
        id=r.id,
        restaurante_id=r.restaurant_id,
        restaurante_nombre=restaurante_nombre,
        mesa_id=r.mesa_id,
        mesa_numero=mesa_numero,
        fecha=r.fecha,
        hora_inicio=r.hora_inicio,
        num_personas=r.num_personas,
        estado=r.estado,
        created_at=r.created_at,
    )


async def crear_reserva(
    session: AsyncSession, usuario_id: int, body: ReservaCreate
) -> ReservaRead:
    """RESV-01 + RESV-02: concurrent-safe reserva creation.

    1. Validate restaurante (404 if unknown/inactive).
    2. Validate slot (400 if past / non-hourly).
    3. FOR UPDATE candidate mesas (capacity >= num_personas).
    4. Pick first candidate with no active reserva on the slot.
    5. Mutate mesa: disponible → reservada (validar_transicion raises → 409).
    6. Insert reserva (estado=confirmada — auto-confirm).
    7. Commit; IntegrityError → 409 (race lost to the UNIQUE constraint).
    """
    # 1. Restaurante (existence hiding público — 404 si no existe/inactivo).
    restaurante = await session.get(Restaurante, body.restaurante_id)
    if restaurante is None or not restaurante.activo:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "Restaurante no encontrado"
        )

    # 2. Slot validation (past date / non-hourly).
    _validate_slot(body.fecha, body.hora_inicio)

    # 3. FOR UPDATE candidate mesas — locks rows until commit.
    cand_stmt = (
        select(Mesa)
        .where(
            Mesa.restaurant_id == body.restaurante_id,
            Mesa.capacidad >= body.num_personas,
        )
        .order_by(Mesa.numero)
        .with_for_update()
    )
    candidates = (await session.execute(cand_stmt)).scalars().all()
    if not candidates:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "No hay mesas con capacidad suficiente",
        )

    # 4. Find first candidate with no active reserva on this slot.
    chosen: Mesa | None = None
    for mesa in candidates:
        existing = (
            await session.execute(
                select(Reserva).where(
                    Reserva.mesa_id == mesa.id,
                    Reserva.fecha == body.fecha,
                    Reserva.hora_inicio == body.hora_inicio,
                    Reserva.estado != EstadoReserva.cancelada,
                )
            )
        ).scalar_one_or_none()
        if existing is None:
            chosen = mesa
            break

    if chosen is None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "No hay mesas disponibles en ese horario",
        )

    # 5. Mesa state mutation. Phase 5 §2 / Pattern 3: idempotent if the mesa
    # is ALREADY 'reservada' (a mesa can hold multiple reservas for distinct
    # slots — the physical state is "reserved for some upcoming slot", not
    # "reserved for THIS slot"). ``disponible → reservada`` applies
    # ``validar_transicion``; any other non-disponible/non-reservada state
    # (ocupada/limpieza) raises → 409.
    if chosen.estado == EstadoMesa.disponible:
        validar_transicion("mesa", EstadoMesa.disponible, EstadoMesa.reservada)
        chosen.estado = EstadoMesa.reservada
    elif chosen.estado == EstadoMesa.reservada:
        # Idempotente: la mesa ya está reservada (para otro slot, o para este
        # mismo slot en una tx que ya commiteó — poco probable gracias al
        # FOR UPDATE). No tocar el estado.
        pass
    else:
        # ocupada / limpieza → no se puede reservar; 409.
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"La mesa {chosen.numero} no está disponible para reserva "
            f"(estado actual: {chosen.estado.value})",
        )

    # 6. Insert reserva (auto-confirm).
    reserva = Reserva(
        restaurant_id=body.restaurante_id,
        usuario_id=usuario_id,
        mesa_id=chosen.id,
        fecha=body.fecha,
        hora_inicio=body.hora_inicio,
        num_personas=body.num_personas,
        estado=EstadoReserva.confirmada,
    )
    session.add(reserva)

    # 7. Commit with IntegrityError handler (belt-and-suspenders: if two txns
    # somehow slipped past the FOR UPDATE check, the UNIQUE catches them).
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "La mesa acaba de ser reservada — intenta otro horario",
        )
    await session.refresh(reserva)
    await session.refresh(chosen)
    return _to_read(reserva, restaurante.nombre, chosen.numero)


async def list_reservas_usuario(
    session: AsyncSession, usuario_id: int
) -> list[ReservaRead]:
    """RESV-03: reservas del usuario, ordenadas por fecha DESC, hora DESC.
    Ownership enforced by WHERE usuario_id — nunca retorna ajenas."""
    stmt = (
        select(Reserva, Restaurante.nombre, Mesa.numero)
        .join(Restaurante, Restaurante.id == Reserva.restaurant_id)
        .join(Mesa, Mesa.id == Reserva.mesa_id)
        .where(Reserva.usuario_id == usuario_id)
        .order_by(Reserva.fecha.desc(), Reserva.hora_inicio.desc(), Reserva.id.desc())
    )
    rows = (await session.execute(stmt)).all()
    return [
        _to_read(reserva, restaurante_nombre, mesa_numero)
        for reserva, restaurante_nombre, mesa_numero in rows
    ]


async def cancelar_reserva(
    session: AsyncSession, usuario_id: int, reserva_id: int
) -> ReservaRead:
    """RESV-04: cancelar reserva futura propia.

    Existence hiding: 404 (NOT 403) si ``reserva.usuario_id != usuario_id``.
    400 si fecha pasada. validar_transicion → 409 si ya cancelada (terminal).
    Pitfall 4: revertir mesa a disponible SOLO si estaba reservada (nunca
    ocupada/limpieza — eso es transición inválida y rompería el state machine).
    """
    reserva = await session.get(Reserva, reserva_id)
    if reserva is None or reserva.usuario_id != usuario_id:
        # Existence hiding: nunca revelar que la reserva existe (404, no 403).
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reserva no encontrada")

    if reserva.fecha < dt.date.today():
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "No se puede cancelar una reserva pasada",
        )

    # Reserva state transition (confirmada → cancelada). Raises on invalid.
    validar_transicion("reserva", reserva.estado, EstadoReserva.cancelada)

    # Pitfall 4: revertir mesa SOLO si estaba reservada. Si ya fue promovida
    # a ocupada (cliente llegó, RESV-05) o limpieza, NO tocarla.
    mesa = await session.get(Mesa, reserva.mesa_id)
    if mesa is not None and mesa.estado == EstadoMesa.reservada:
        validar_transicion("mesa", EstadoMesa.reservada, EstadoMesa.disponible)
        mesa.estado = EstadoMesa.disponible

    reserva.estado = EstadoReserva.cancelada
    await session.commit()
    await session.refresh(reserva)
    if mesa is not None:
        await session.refresh(mesa)

    restaurante = await session.get(Restaurante, reserva.restaurant_id)
    restaurante_nombre = restaurante.nombre if restaurante else ""
    return _to_read(reserva, restaurante_nombre, mesa.numero if mesa else 0)
