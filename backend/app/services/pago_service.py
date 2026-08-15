"""Pago business logic — intención por sesión + estado + webhook (PAGO-02/03/04).

La cuenta es de la SESIÓN (N pedidos — hallazgo estructural 09-RESEARCH):
``crear_intencion`` valida que TODOS los pedidos de la sesión estén en
``servido`` (409 si hay algo en curso; rechazado excluido) y calcula el
monto SERVER-SIDE con ``SELECT SUM(total)`` — el body JAMÁS trae montos
(T-09-01 anti-tampering).

``procesar_webhook`` (Task 3) cierra el ciclo: dedup por
``pago_event.event_key`` UNIQUE → mapeo de estados Wompi → efectos atómicos
en UNA transacción (``aplicar_pago_aprobado``: pedidos servido→pagado,
sesión cerrada, mesa ocupada→limpieza) → emisiones WS post-commit.

Reglas de oro (09-RESEARCH Patrón 2): el webhook responde 200 rápido, sin
llamadas externas bloqueantes; JAMÁS 500 (Wompi reintenta ante 5xx —
re-entregas y estados terminales son no-op 200 vía IntegrityError /
TransicionInvalidaError capturadas en el ROUTER).
"""

import json
from decimal import Decimal
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.broadcaster import emit_event
from app.core.gateways import get_pago_gateway
from app.core.state_machines import validar_transicion
from app.models.mesa import EstadoMesa, Mesa
from app.models.pago import EstadoPago, Pago
from app.models.pago_event import PagoEvent
from app.models.pedido import EstadoPedido, Pedido
from app.models.sesion_mesa import EstadoSesion, SesionMesa
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


# --- Task 3: webhook público + efectos atómicos ------------------------------


def _extraer_transaccion(payload: dict) -> dict:
    """data.transaction del payload Wompi ({} si la estructura falta)."""
    data = payload.get("data")
    if not isinstance(data, dict):
        return {}
    txn = data.get("transaction")
    return txn if isinstance(txn, dict) else {}


async def procesar_webhook(session: AsyncSession, payload: dict) -> dict:
    """Pipeline COMPLETO del webhook (público y sandbox — MISMA función).

    La FIRMA ya fue verificada por el router ANTES de esta llamada (T-09-01:
    firma primero, negocio después). Aquí: dedup → fraude → mapeo de estados.

    Returns ``{"result": <outcome>}`` con outcome ∈ referenciadesconocida |
    monto-mismatch | pendiente | aprobado | rechazado | voided-post-aprobado.

    Raises (el router las traduce a 200, NUNCA 500 — Wompi reintenta ante
    5xx): ``IntegrityError`` (event_key duplicado = re-entrega) y
    ``TransicionInvalidaError`` (pago en estado terminal = re-entrega).
    """
    txn = _extraer_transaccion(payload)
    txn_id = str(txn.get("id") or "")
    txn_status = str(txn.get("status") or "")
    referencia = str(txn.get("reference") or "")
    if not txn_id or not txn_status:
        return {"result": "payload-invalido"}

    # 1. Localizar el pago por referencia ANTES de insertar el evento (para
    #    poblar pago_id en el INSERT; referencia desconocida → pago_id NULL).
    #    FOR UPDATE: serializa webhooks concurrentes sobre el MISMO pago (dos
    #    APPROVED con txn ids distintos no pueden aplicar efectos 2 veces —
    #    el segundo lee estado post-commit y valida terminal → no-op).
    pago = None
    if referencia:
        pago = (
            await session.execute(
                select(Pago).where(Pago.referencia == referencia).with_for_update()
            )
        ).scalar_one_or_none()

    # 2. Dedup at-least-once: INSERT con event_key UNIQUE — la re-entrega
    #    levanta IntegrityError EN EL COMMIT de cada rama (el router → 200).
    evento = PagoEvent(
        event_key=f"{txn_id}:{txn_status}",
        pago_id=pago.id if pago is not None else None,
        payload=json.dumps(payload, ensure_ascii=False, default=str),
    )
    session.add(evento)

    if pago is None:
        await session.commit()  # persiste la fila de auditoría (pago_id NULL)
        return {"result": "referencia-desconocida"}

    # 3. Fraude (Pitfall 5): APPROVED con monto/moneda que no calzan →
    #    alerta en pago_event + 200 SIN efectos.
    if txn_status == "APPROVED" and (
        txn.get("amount_in_cents") != int(pago.monto * 100)
        or str(txn.get("currency") or "") != "COP"
    ):
        evento.estado = "monto-mismatch"
        await session.commit()
        return {"result": "monto-mismatch"}

    # 4. Mapeo de estados Wompi (verificado — TransactionStatus del SDK).
    if txn_status == "PENDING":
        # No final: solo registrar transaction_id si es nuevo.
        if pago.transaction_id is None:
            pago.transaction_id = txn_id
        await session.commit()
        return {"result": "pendiente"}

    if txn_status == "APPROVED":
        contexto = await aplicar_pago_aprobado(session, pago, txn_id, evento)
        return {"result": "aprobado", **contexto}

    if txn_status in ("DECLINED", "ERROR"):
        # Final: pendiente → rechazado (terminal si ya lo estaba → raise).
        validar_transicion("pago", pago.estado, EstadoPago.rechazado)
        pago.estado = EstadoPago.rechazado
        if pago.transaction_id is None:
            pago.transaction_id = txn_id
        await session.commit()
        await session.refresh(pago)
        # Sin emisión WS: el rechazo no toca sesión/mesa/pedidos (sin
        # efectos que sincronizar); el cliente lo descubre por polling de
        # GET /cliente/pagos/{id} o al reintentar la intención.
        return {"result": "rechazado"}

    if txn_status == "VOIDED":
        if pago.estado == EstadoPago.pendiente:
            validar_transicion("pago", EstadoPago.pendiente, EstadoPago.rechazado)
            pago.estado = EstadoPago.rechazado
            if pago.transaction_id is None:
                pago.transaction_id = txn_id
            await session.commit()
            return {"result": "rechazado"}
        # VOIDED post-aprobado: anulación — efectos intactos, reembolso
        # MANUAL fuera de scope v1 (docstring). Solo auditoría.
        evento.estado = "voided-post-aprobado"
        await session.commit()
        return {"result": "voided-post-aprobado"}

    evento.estado = f"status-desconocido:{txn_status}"
    await session.commit()
    return {"result": "desconocido"}


async def aplicar_pago_aprobado(
    session: AsyncSession, pago: Pago, txn_id: str, evento: PagoEvent
) -> dict:
    """Efectos del pago aprobado en UNA transacción BD + WS post-commit.

    UN solo commit cubre: pago_event (dedup/auditoría) + pago (aprobado +
    transaction_id) + pedidos servido→pagado + sesión cerrada (cerrada_en) +
    mesa ocupada→limpieza. Si cualquier paso falla, el rollback deja TODO
    como estaba (atomicidad — PAGO-04).

    ``TransicionInvalidaError`` sobre el pago (estado terminal) es la señal
    de re-entrega: sube al router que responde 200 ya-procesado.

    Emisiones POST-COMMIT (patrón 07-01 — jamás dentro de la tx):
    pedido.estado (por pedido) → sesion.cerrada → mesa.estado → pago.estado.
    """
    # Validación PRIMERO (re-entrega sobre terminal raise ANTES de mutar).
    validar_transicion("pago", pago.estado, EstadoPago.aprobado)

    sesion = await session.get(SesionMesa, pago.sesion_id)
    pedidos = list(
        (
            await session.execute(
                select(Pedido).where(
                    Pedido.sesion_id == pago.sesion_id,
                    Pedido.estado == EstadoPedido.servido,
                )
            )
        )
        .scalars()
        .all()
    )
    mesa = await session.get(Mesa, sesion.mesa_id)

    # --- UNA transacción: todo o nada ---
    pago.estado = EstadoPago.aprobado
    if txn_id and pago.transaction_id is None:
        pago.transaction_id = txn_id
    for pedido in pedidos:
        validar_transicion("pedido", pedido.estado, EstadoPedido.pagado)
        pedido.estado = EstadoPedido.pagado
    validar_transicion("sesion_mesa", sesion.estado, EstadoSesion.cerrada)
    sesion.estado = EstadoSesion.cerrada
    sesion.cerrada_en = func.now()
    validar_transicion("mesa", mesa.estado, EstadoMesa.limpieza)
    mesa.estado = EstadoMesa.limpieza
    await session.commit()

    # Contexto en variables PLANAS post-commit (gotcha MySQL sin RETURNING +
    # anti-expire: capturar ANTES de cualquier otra operación de sesión).
    restaurante_id = pago.restaurant_id
    usuario_id = sesion.usuario_id
    pago_id = pago.id
    sesion_id = sesion.id
    mesa_id = sesion.mesa_id
    pedido_ids = [p.id for p in pedidos]

    # --- Emisiones post-commit (awaits directos, orden del flujo) ---
    for pedido_id in pedido_ids:
        await emit_event(
            "pedido.estado",
            restaurante_id,
            usuario_id,
            data={"pedido_id": pedido_id, "estado": EstadoPedido.pagado.value},
        )
    await emit_event(
        "sesion.cerrada",
        restaurante_id,
        usuario_id,
        data={"sesion_id": sesion_id, "mesa_id": mesa_id},
    )
    await emit_event(
        "mesa.estado",
        restaurante_id,
        None,  # room staff — el mapa del panel
        data={"mesa_id": mesa_id, "estado": EstadoMesa.limpieza.value},
    )
    await emit_event(
        "pago.estado",
        restaurante_id,
        usuario_id,
        data={
            "pago_id": pago_id,
            "estado": EstadoPago.aprobado.value,
            "pedido_ids": pedido_ids,
        },
    )
    return {"pago_id": pago_id, "sesion_id": sesion_id, "mesa_id": mesa_id}
