"""Sesión de mesa business logic — abrir por QR + actual + cuenta (MESA-05/06, PAGO-01).

``abrir_sesion`` es concurrent-safe (defense-in-depth, patrón
``reserva_service.crear_reserva``):

1. ``SELECT ... FOR UPDATE`` sobre la mesa (por ``codigo_qr`` unique global)
   — serializa txns concurrentes sobre la misma fila.
2. Chequeos application-level: sesión activa existente de la mesa
   (idempotente propio → 200 / ajena → 409) y sesión activa del USUARIO en
   otra mesa (→ 409).
3. ``UNIQUE (mesa_id, activo_flag)`` + ``UNIQUE (usuario_id, activo_flag)``
   (columnas computadas, migraciones 0002/0004) — última línea de defensa;
   si dos txns colaran el FOR UPDATE, el INSERT levanta ``IntegrityError``
   → mapeado a 409. La BD gana la carrera.

La mesa pasa a ``ocupada`` AL ABRIR la sesión (decisión locked del research
— fiel al core value; disponible→ocupada y reservada→ocupada ambas válidas,
limpieza→ocupada la rechaza ``validar_transicion`` → 409 en el router).

``solicitar_cuenta`` (PAGO-01) es idempotente: si ``solicita_cuenta`` ya es
True, retorna SIN tocar ``solicitada_en`` (doble tap seguro).
"""

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.state_machines import validar_transicion
from app.models.mesa import EstadoMesa, Mesa
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import SesionMesa
from app.schemas.sesion import SesionRead


def _to_read(s: SesionMesa, restaurante: Restaurante, mesa: Mesa) -> SesionRead:
    """Build a SesionRead from the ORM row + display joins (no lazy loads)."""
    return SesionRead(
        id=s.id,
        restaurante_id=s.restaurant_id,
        restaurante_nombre=restaurante.nombre,
        mesa_id=s.mesa_id,
        mesa_numero=mesa.numero,
        abierta_en=s.abierta_en,
        solicita_cuenta=bool(s.solicita_cuenta),
        solicitada_en=s.solicitada_en,
    )


async def abrir_sesion(
    session: AsyncSession, usuario_id: int, codigo_qr: str
) -> tuple[SesionRead, bool]:
    """MESA-05/06: abrir (o re-escanear) la sesión de una mesa por su QR.

    Returns ``(SesionRead, created)`` — el router responde 201 si ``created``
    sino 200 (idempotencia propia).

    Raises HTTPException: 404 QR inexistente/restaurante inactivo;
    409 sesión ajena en la mesa / usuario con sesión activa en otra mesa /
    IntegrityError (la BD ganó la carrera). ``TransicionInvalidaError``
    (mesa limpieza) sube al router → 409.
    """
    # 1. Mesa por QR (unique global) con FOR UPDATE — lock hasta el commit.
    mesa = (
        await session.execute(
            select(Mesa).where(Mesa.codigo_qr == codigo_qr).with_for_update()
        )
    ).scalar_one_or_none()
    if mesa is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Mesa no encontrada")

    restaurante = await session.get(Restaurante, mesa.restaurant_id)
    if restaurante is None or not restaurante.activo:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "Restaurante no disponible"
        )

    # 2a. Sesión activa existente de la MESA → idempotente propio / 409 ajeno.
    activa = (
        await session.execute(
            select(SesionMesa).where(
                SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None)
            )
        )
    ).scalar_one_or_none()
    if activa is not None:
        if activa.usuario_id == usuario_id:
            return _to_read(activa, restaurante, mesa), False
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "La mesa ya tiene una sesión activa de otro usuario",
        )

    # 2b. Una sesión activa por USUARIO (UNIQUE 0004) — el mensaje nombra la
    # mesa de esa sesión para que el cliente entienda dónde está "sentado".
    mia = (
        await session.execute(
            select(SesionMesa, Mesa.numero)
            .join(Mesa, Mesa.id == SesionMesa.mesa_id)
            .where(
                SesionMesa.usuario_id == usuario_id,
                SesionMesa.cerrada_en.is_(None),
            )
        )
    ).first()
    if mia is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Ya tienes una sesión activa en la Mesa {mia.numero}",
        )

    # 3. Mesa disponible/reservada → ocupada (limpieza raises → 409 router).
    validar_transicion("mesa", mesa.estado, EstadoMesa.ocupada)

    mesa.estado = EstadoMesa.ocupada
    sesion = SesionMesa(
        restaurant_id=mesa.restaurant_id, mesa_id=mesa.id, usuario_id=usuario_id
    )
    session.add(sesion)
    try:
        await session.commit()
    except IntegrityError:
        # UNIQUE(mesa_id|usuario_id, activo_flag) — la BD gana la carrera.
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "La mesa acaba de ser ocupada por otro usuario",
        )
    await session.refresh(sesion)
    await session.refresh(mesa)
    return _to_read(sesion, restaurante, mesa), True


async def sesion_actual(
    session: AsyncSession, usuario_id: int
) -> SesionRead | None:
    """La sesión activa del usuario (joins display) o None → 404 en router."""
    row = (
        await session.execute(
            select(SesionMesa, Restaurante, Mesa)
            .join(Restaurante, Restaurante.id == SesionMesa.restaurant_id)
            .join(Mesa, Mesa.id == SesionMesa.mesa_id)
            .where(
                SesionMesa.usuario_id == usuario_id,
                SesionMesa.cerrada_en.is_(None),
            )
        )
    ).first()
    if row is None:
        return None
    sesion, restaurante, mesa = row
    return _to_read(sesion, restaurante, mesa)
