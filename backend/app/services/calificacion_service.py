"""Calificación post-pago service (CALI-01 — Phase 9).

La ÚNICA puerta a una calificación es ``pedido.estado == pagado`` (T-09-03):
un pedido servido/rechazado/borrador NO se califica (409). La validación de
ownership usa existence hiding — 404 con detalle IDÉNTICO para pedido ajeno
e inexistente (no filtrable por enumeración, patrón RESV-04).

``uq_calificacion_pedido`` es la autoridad de "exactamente UNA calificación
por pedido": el INSERT + ``IntegrityError`` → 409 deja que la BD gane la
carrera (patrón reserva 05-01) — jamás 500. ``restaurant_id`` y
``usuario_id`` se derivan del pedido; el body jamás los acepta.
"""

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.calificacion import Calificacion
from app.models.pedido import EstadoPedido, Pedido
from app.schemas.calificacion import CalificacionCreate, CalificacionRead

# Existence hiding: ajeno e inexistente comparten el MISMO detalle.
_NOT_FOUND = "Pedido no encontrado"


async def crear_calificacion(
    session: AsyncSession, usuario_id: int, body: CalificacionCreate
) -> CalificacionRead:
    """Califica (1-5 estrellas + comentario opcional) un pedido pagado propio.

    Flujo (el orden importa — ownership ANTES que estado):
    1. 404 si el pedido no existe.
    2. 404 (mismo detalle) si es de otro usuario — existence hiding.
    3. 409 si ``estado != pagado`` — la única puerta post-pago (T-09-03).
    4. INSERT + commit; ``IntegrityError`` de ``uq_calificacion_pedido`` →
       409 "ya fue calificado" (la BD gana la carrera, patrón 05-01).
    """
    pedido = await session.get(Pedido, body.pedido_id)
    if pedido is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, _NOT_FOUND)
    # Capturar en variables planas ANTES de tocar la sesión de nuevo (patrón
    # anti-MissingGreenlet del codebase — nada de lazy-load post-commit).
    pedido_usuario_id = pedido.usuario_id
    pedido_restaurant_id = pedido.restaurant_id
    pedido_estado = pedido.estado

    if pedido_usuario_id != usuario_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, _NOT_FOUND)
    if pedido_estado != EstadoPedido.pagado:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Solo puedes calificar pedidos pagados",
        )

    calificacion = Calificacion(
        restaurant_id=pedido_restaurant_id,
        usuario_id=usuario_id,
        pedido_id=body.pedido_id,
        estrellas=body.estrellas,
        comentario=body.comentario,
    )
    session.add(calificacion)
    try:
        await session.commit()
    except IntegrityError:
        # Doble-tap rápido o carrera con otra txn: uq_calificacion_pedido
        # rechazó el INSERT — traducir a 409, NUNCA 500 (patrón reserva).
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Este pedido ya fue calificado",
        )
    await session.refresh(calificacion)
    return CalificacionRead.model_validate(calificacion)
