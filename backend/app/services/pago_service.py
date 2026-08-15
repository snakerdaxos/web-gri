"""Pago business logic — intención por sesión + estado + webhook (PAGO-02/03/04).

La cuenta es de la SESIÓN (N pedidos — hallazgo estructural 09-RESEARCH):
``crear_intencion`` valida que TODOS los pedidos de la sesión estén en
``servido`` (409 si hay algo en curso; rechazado excluido) y calcula el
monto SERVER-SIDE con ``SELECT SUM(total)`` — el body JAMÁS trae montos
(T-09-01 anti-tampering).

``procesar_webhook`` + ``aplicar_pago_aprobado`` (Task 3) cierran el ciclo:
dedup por ``pago_event.event_key`` UNIQUE → efectos atómicos (pedidos→pagado,
sesión cerrada, mesa→limpieza) → emisiones WS post-commit.
"""

from decimal import Decimal
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.gateways import get_pago_gateway
from app.models.pago import EstadoPago, Pago
from app.models.pedido import EstadoPedido, Pedido
from app.models.sesion_mesa import SesionMesa
from app.schemas.pago import PagoEstadoRead, PagoIntencionRead

# Estados que bloquean el pago: la cocina todavía está trabajando.
_EN_CURSO = frozenset(
    {
        EstadoPedido.borrador,
        EstadoPedido.enviado,
        EstadoPedido.aceptado,
        EstadoPedido.en_preparacion,
    }
)


def _nueva_referencia() -> str:
    """GRI-PAGO-{uuid8} — ~20 chars, dentro del tope de reference."""
    return f"GRI-PAGO-{uuid4().hex[:8]}"


async def crear_intencion(
    session: AsyncSession, usuario_id: int
) -> tuple[PagoIntencionRead, bool]:
    """PAGO-02: crear (o reutilizar) la intención de pago de la sesión activa.

    Returns ``(PagoIntencionRead, created)`` — el router responde 201 si
    ``created`` sino 200 (idempotencia de intención: un pago pendiente por
    sesión; la 2a llamada retorna la MISMA referencia/monto).

    Raises HTTPException: 404 sin sesión activa; 409 sin pedidos / pedidos
    en curso.
    """
    # 1. Sesión activa del usuario.
    sesion = (
        await session.execute(
            select(SesionMesa).where(
                SesionMesa.usuario_id == usuario_id, SesionMesa.cerrada_en.is_(None)
            )
        )
    ).scalar_one_or_none()
    if sesion is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sin sesión activa")

    # 2. Política de estado previo: TODOS los pedidos de la sesión en
    #    servido (rechazado no bloquea — queda excluido del total).
    estados = (
        await session.execute(select(Pedido.estado).where(Pedido.sesion_id == sesion.id))
    ).scalars().all()
    if not estados:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "No hay nada que pagar en esta sesión"
        )
    if any(estado in _EN_CURSO for estado in estados):
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Aún hay pedidos en curso en la sesión"
        )

    # 3. Idempotencia de intención: pago pendiente existente → reutilizar.
    pendiente = (
        await session.execute(
            select(Pago).where(
                Pago.sesion_id == sesion.id, Pago.estado == EstadoPago.pendiente
            )
        )
    ).scalar_one_or_none()

    gateway = get_pago_gateway()
    if pendiente is not None:
        checkout_url = await gateway.crear_checkout(
            referencia=pendiente.referencia, monto=pendiente.monto
        )
        return (
            PagoIntencionRead(
                pago_id=pendiente.id,
                referencia=pendiente.referencia,
                monto=pendiente.monto,
                estado=pendiente.estado,
                checkout_url=checkout_url,
            ),
            False,
        )

    # 4. Monto server-side: SUM(total) de los pedidos servido.
    monto: Decimal | None = (
        await session.execute(
            select(func.sum(Pedido.total)).where(
                Pedido.sesion_id == sesion.id,
                Pedido.estado == EstadoPedido.servido,
            )
        )
    ).scalar_one()
    if monto is None or monto <= 0:
        # Solo pedidos rechazados/pagados — nada que pagar ahora.
        raise HTTPException(
            status.HTTP_409_CONFLICT, "No hay nada que pagar en esta sesión"
        )

    pago = Pago(
        restaurant_id=sesion.restaurant_id,
        sesion_id=sesion.id,
        pedido_id=None,  # legacy — ya no se escribe
        monto=monto,
        referencia=_nueva_referencia(),
        pasarela=gateway.nombre,
    )
    session.add(pago)
    await session.commit()
    # Cargar server defaults (estado/created_at) — patrón sesion_service.
    await session.refresh(pago)

    checkout_url = await gateway.crear_checkout(
        referencia=pago.referencia, monto=pago.monto
    )
    return (
        PagoIntencionRead(
            pago_id=pago.id,
            referencia=pago.referencia,
            monto=pago.monto,
            estado=pago.estado,
            checkout_url=checkout_url,
        ),
        True,
    )


async def consultar_estado(
    session: AsyncSession, usuario_id: int, pago_id: int
) -> PagoEstadoRead:
    """Polling post-checkout del estado del pago (existence hiding: 404 si
    ajeno/inexistente).

    Reconciliación lazy (limitación v1 documentada): solo aplica si el pago
    está pendiente Y ya tiene ``transaction_id`` Y la pasarela es wompi —
    sin webhook previo no hay transaction_id y no hay reconciliación
    posible; el sandbox entrega el webhook local de forma confiable. Se
    implementa junto a ``procesar_webhook`` (Task 3).
    """
    row = (
        await session.execute(
            select(Pago, SesionMesa)
            .join(SesionMesa, SesionMesa.id == Pago.sesion_id)
            .where(Pago.id == pago_id)
        )
    ).first()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Pago no encontrado")
    pago, sesion = row
    if sesion.usuario_id != usuario_id:
        # Existence hiding: idéntico a inexistente.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Pago no encontrado")

    # Pedidos cubiertos por el pago: pagado si aprobado; servido si aún
    # pendiente/rechazado (Pitfall 6 — calificación post-pago).
    estado_pedidos = (
        EstadoPedido.pagado if pago.estado == EstadoPago.aprobado else EstadoPedido.servido
    )
    pedido_ids = list(
        (
            await session.execute(
                select(Pedido.id)
                .where(Pedido.sesion_id == pago.sesion_id, Pedido.estado == estado_pedidos)
                .order_by(Pedido.id)
            )
        )
        .scalars()
        .all()
    )

    return PagoEstadoRead(
        pago_id=pago.id,
        estado=pago.estado,
        referencia=pago.referencia,
        monto=pago.monto,
        pedido_ids=pedido_ids,
    )
