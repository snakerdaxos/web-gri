"""Tests DB-directos de los constraints de dominio (Phase 3).

Validan que la BD (MySQL 8.4) enforce los invariants declarados en la
migración 0002: QR globalmente único, sesión activa única por mesa, CHECKs de
rango (cantidad, estrellas, num_personas), unique de referencia de pago y
unique de calificación por pedido.

Estos tests NO van por HTTP (no hay endpoints de dominio hasta Phase 4-6):
usan la fixture ``db_session`` (asyncmy directo) + helpers que crean la cadena
de FKs necesaria para cada constraint.

Patrones clave:
- Tras ``rollback()`` SQLAlchemy expira TODOS los objetos de la sesión (incluso
  con ``expire_on_commit=False``). Acceder a atributos ORM post-rollback
  dispara lazy-load → ``MissingGreenlet`` en async. Por eso capturamos los IDs
  en variables locales ANTES de cualquier rollback.
- MySQL 8.4 + asyncmy: UNIQUE/FK viol. → ``IntegrityError``; CHECK viol.
  (error 3819) → ``OperationalError``. Los tests de CHECK capturan ambos.
"""

import datetime as dt
import re
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError, OperationalError

from app.models.calificacion import Calificacion
from app.models.mesa import Mesa
from app.models.menu import Categoria, Producto
from app.models.pago import EstadoPago, Pago
from app.models.pago_event import PagoEvent
from app.models.pedido import EstadoPedido, Pedido, PedidoItem
from app.models.reserva import Reserva
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa
from app.models.usuario import RolUsuario, Usuario

# MySQL 8.4 + asyncmy raises OperationalError (not IntegrityError) for CHECK
# constraint violations (error 3819 ER_CHECK_CONSTRAINT_VIOLATED).
CHECK_VIOLATION = (IntegrityError, OperationalError)


# --- helpers --------------------------------------------------------------


async def _demo_restaurante(session) -> Restaurante:
    """Get-or-create a Restaurante for constraint tests."""
    r = (await session.execute(select(Restaurante).limit(1))).scalar_one_or_none()
    if r is None:
        r = Restaurante(nombre=f"constraint-test-{uuid4().hex[:6]}")
        session.add(r)
        await session.flush()
    return r


async def _new_restaurante(session) -> Restaurante:
    r = Restaurante(nombre=f"r-{uuid4().hex[:8]}")
    session.add(r)
    await session.flush()
    return r


async def _new_usuario(session) -> Usuario:
    u = Usuario(
        nombre="Constraint Test",
        email=f"u-{uuid4().hex[:8]}@test.dev",
        password_hash="x" * 60,
        role=RolUsuario.cliente,
        restaurant_id=None,
    )
    session.add(u)
    await session.flush()
    return u


async def _seed_chain(session):
    """Crea la cadena completa de FKs (restaurante, usuario, mesa, categoria,
    producto, pedido). Retorna los 6 objetos ORM."""
    r = await _demo_restaurante(session)
    u = await _new_usuario(session)
    mesa = Mesa(
        restaurant_id=r.id,
        numero=abs(hash(uuid4().hex)) % 9000 + 1000,
        capacidad=4,
        codigo_qr=f"GRI-TEST-{uuid4().hex[:8]}",
    )
    session.add(mesa)
    await session.flush()
    cat = Categoria(restaurant_id=r.id, nombre=f"cat-{uuid4().hex[:6]}", orden=1)
    session.add(cat)
    await session.flush()
    prod = Producto(
        restaurant_id=r.id,
        categoria_id=cat.id,
        nombre=f"prod-{uuid4().hex[:6]}",
        precio=Decimal("10000.00"),
    )
    session.add(prod)
    await session.flush()
    pedido = Pedido(
        restaurant_id=r.id,
        mesa_id=mesa.id,
        usuario_id=u.id,
        estado=EstadoPedido.borrador,
        total=Decimal("0"),
    )
    session.add(pedido)
    await session.flush()
    return r, u, mesa, cat, prod, pedido


# --- MESA-02: QR globalmente único ---------------------------------------


async def test_qr_duplicado_rechazado(db_session):
    """MESA-02/SC3: dos mesas NO pueden compartir codigo_qr (unique GLOBAL)."""
    r1 = await _new_restaurante(db_session)
    r2 = await _new_restaurante(db_session)
    r1_id, r2_id = r1.id, r2.id
    qr = f"GRI-DUP-{uuid4().hex[:6]}"

    db_session.add(Mesa(restaurant_id=r1_id, numero=1, capacidad=2, codigo_qr=qr))
    await db_session.flush()

    db_session.add(Mesa(restaurant_id=r2_id, numero=1, capacidad=2, codigo_qr=qr))
    with pytest.raises(IntegrityError):
        await db_session.flush()
    await db_session.rollback()


async def test_qr_formato_demo(db_session):
    """Los códigos QR formato GRI-MESA-\\d{3} cumplen el patrón (MESA-02)."""
    r = await _demo_restaurante(db_session)
    patron = re.compile(r"^GRI-MESA-\d{3}$")
    for i in (1, 8, 42, 100, 999):
        assert patron.match(f"GRI-MESA-{i:03d}")
    assert patron.match("GRI-MESA-9999") is None
    assert patron.match("gri-mesa-001") is None
    db_session.add(
        Mesa(
            restaurant_id=r.id,
            numero=abs(hash(uuid4().hex)) % 9000 + 1000,
            capacidad=4,
            codigo_qr=f"GRI-MESA-{uuid4().hex[:3]}",
        )
    )
    await db_session.flush()


# --- PITFALLS P6: una sesión activa por mesa ------------------------------


async def test_una_sesion_activa_por_mesa(db_session):
    """El unique (mesa_id, activo_flag) rechaza la 2a sesión activa; cerrar
    la primera libera el slot (semántica NULL del índice unique)."""
    r, u, mesa, *_ = await _seed_chain(db_session)
    # Capturar IDs antes de cualquier rollback (rollback expira los objetos).
    r_id, u_id, mesa_id = r.id, u.id, mesa.id

    # 1. Primera sesión activa — OK
    s1 = SesionMesa(
        restaurant_id=r_id, mesa_id=mesa_id, usuario_id=u_id, estado=EstadoSesion.activa
    )
    db_session.add(s1)
    await db_session.flush()
    s1_id = s1.id
    await db_session.commit()

    # 2. Segunda sesión activa — IntegrityError
    s2 = SesionMesa(
        restaurant_id=r_id, mesa_id=mesa_id, usuario_id=u_id, estado=EstadoSesion.activa
    )
    db_session.add(s2)
    with pytest.raises(IntegrityError):
        await db_session.flush()
    await db_session.rollback()

    # 3. Cerrar la primera (cerrada_en → activo_flag=NULL)
    s1_fresh = (
        await db_session.execute(select(SesionMesa).where(SesionMesa.id == s1_id))
    ).scalar_one()
    s1_fresh.cerrada_en = dt.datetime.now()
    s1_fresh.estado = EstadoSesion.cerrada
    await db_session.flush()
    await db_session.commit()

    # 4. Nueva sesión activa — OK (la única activa fue cerrada)
    s3 = SesionMesa(
        restaurant_id=r_id, mesa_id=mesa_id, usuario_id=u_id, estado=EstadoSesion.activa
    )
    db_session.add(s3)
    await db_session.flush()


# --- CHECK constraints (MySQL 8.0.16+ enforce) ---------------------------


async def test_check_cantidad_positiva(db_session):
    """ck_pedido_item_cantidad_positiva: cantidad > 0."""
    r, _, _, _, prod, pedido = await _seed_chain(db_session)
    r_id, pedido_id, prod_id = r.id, pedido.id, prod.id
    await db_session.commit()

    for cantidad_invalida in (0, -1):
        db_session.add(
            PedidoItem(
                restaurant_id=r_id,
                pedido_id=pedido_id,
                producto_id=prod_id,
                cantidad=cantidad_invalida,
                precio_unitario=Decimal("10000.00"),
                subtotal=Decimal("10000.00"),
            )
        )
        with pytest.raises(CHECK_VIOLATION):
            await db_session.flush()
        await db_session.rollback()

    # Cantidad válida — OK
    db_session.add(
        PedidoItem(
            restaurant_id=r_id,
            pedido_id=pedido_id,
            producto_id=prod_id,
            cantidad=2,
            precio_unitario=Decimal("10000.00"),
            subtotal=Decimal("20000.00"),
        )
    )
    await db_session.flush()


async def test_check_estrellas_rango(db_session):
    """ck_calificacion_estrellas_rango: estrellas BETWEEN 1 AND 5."""
    r, u, mesa, _, _, _ = await _seed_chain(db_session)
    r_id, u_id, mesa_id = r.id, u.id, mesa.id
    await db_session.commit()

    # Valores inválidos — crean su propio pedido para evitar conflictos de unique
    for estrellas_invalidas in (0, 6):
        ped = Pedido(
            restaurant_id=r_id,
            mesa_id=mesa_id,
            usuario_id=u_id,
            estado=EstadoPedido.borrador,
            total=Decimal("0"),
        )
        db_session.add(ped)
        await db_session.flush()
        ped_id = ped.id
        db_session.add(
            Calificacion(
                restaurant_id=r_id, usuario_id=u_id, pedido_id=ped_id,
                estrellas=estrellas_invalidas,
            )
        )
        with pytest.raises(CHECK_VIOLATION):
            await db_session.flush()
        await db_session.rollback()

    # Valores válidos (1 y 5) — OK. Cleanup OBLIGATORIO en finally: las filas
    # van al restaurante DEMO (compartido) y desde 09-02 el agregado público
    # (/public/restaurantes) las LEE — dejarlas contaminaría el promedio y
    # rompería test_public_read (residuo verificado en la BD compartida).
    creados: list[tuple[int, int]] = []  # (pedido_id, calificacion_id)
    try:
        for estrellas_validas in (1, 5):
            ped = Pedido(
                restaurant_id=r_id,
                mesa_id=mesa_id,
                usuario_id=u_id,
                estado=EstadoPedido.borrador,
                total=Decimal("0"),
            )
            db_session.add(ped)
            await db_session.flush()
            ped_id = ped.id
            cal = Calificacion(
                restaurant_id=r_id, usuario_id=u_id, pedido_id=ped_id,
                estrellas=estrellas_validas,
            )
            db_session.add(cal)
            await db_session.flush()
            creados.append((ped_id, cal.id))
        await db_session.commit()
    finally:
        # IDs capturados antes del rollback (patrón del docstring del módulo:
        # rollback expira TODO → jamás tocar atributos ORM post-rollback).
        await db_session.rollback()
        try:
            await db_session.execute(
                delete(Calificacion).where(
                    Calificacion.id.in_(c for _, c in creados)
                )
            )
            await db_session.execute(
                delete(Pedido).where(Pedido.id.in_(p for p, _ in creados))
            )
            await db_session.commit()
        except Exception:
            await db_session.rollback()


async def test_check_reserva_num_personas(db_session):
    """ck_reserva_num_personas_positiva: num_personas >= 1."""
    r, u, mesa, *_ = await _seed_chain(db_session)
    r_id, u_id, mesa_id = r.id, u.id, mesa.id
    await db_session.commit()

    db_session.add(
        Reserva(
            restaurant_id=r_id,
            usuario_id=u_id,
            mesa_id=mesa_id,
            fecha=dt.date.today(),
            hora_inicio=dt.time(12, 0),
            num_personas=0,
        )
    )
    with pytest.raises(CHECK_VIOLATION):
        await db_session.flush()
    await db_session.rollback()

    # Valor válido — OK
    db_session.add(
        Reserva(
            restaurant_id=r_id,
            usuario_id=u_id,
            mesa_id=mesa_id,
            fecha=dt.date.today(),
            hora_inicio=dt.time(13, 0),
            num_personas=1,
        )
    )
    await db_session.flush()


# --- Unique de referencia de pago (PITFALLS P4 idempotencia) --------------


async def test_pago_referencia_unique(db_session):
    """uq_pago_referencia: dos pagos con la misma referencia → IntegrityError.

    Phase 9 (migración 0006): el pago es por SESIÓN — el test construye la
    cadena mesa→sesión→pedido del seed y pasa ``sesion_id`` (``pedido_id``
    quedó nullable retrocompatible y ya no se escribe en el flujo nuevo)."""
    r, u, mesa, _, _, pedido = await _seed_chain(db_session)
    r_id, u_id, mesa_id, pedido_id = r.id, u.id, mesa.id, pedido.id
    sesion = SesionMesa(
        restaurant_id=r_id, mesa_id=mesa_id, usuario_id=u_id,
        estado=EstadoSesion.activa,
    )
    db_session.add(sesion)
    await db_session.flush()
    sesion_id = sesion.id
    pedido.sesion_id = sesion_id
    await db_session.commit()

    ref = f"PAY-{uuid4().hex[:8]}"
    db_session.add(
        Pago(
            restaurant_id=r_id, pedido_id=pedido_id, sesion_id=sesion_id,
            monto=Decimal("10000.00"),
            referencia=ref, estado=EstadoPago.pendiente,
        )
    )
    await db_session.flush()

    db_session.add(
        Pago(
            restaurant_id=r_id, pedido_id=pedido_id, sesion_id=sesion_id,
            monto=Decimal("20000.00"),
            referencia=ref, estado=EstadoPago.pendiente,
        )
    )
    with pytest.raises(IntegrityError):
        await db_session.flush()
    await db_session.rollback()


# --- Dedup at-least-once del webhook (PAGO-03, migración 0006) --------------


async def test_pago_event_event_key_unique(db_session):
    """uq_pago_event_key: el mismo ``transaction_id:status`` dos veces →
    IntegrityError (dedup at-least-once; el payload Wompi NO trae event.id —
    clave derivada, verificado 09-RESEARCH). ``pago_id`` NULL es válido
    (webhook con referencia desconocida → fila de auditoría)."""
    payload = '{"event": "transaction.updated"}'
    db_session.add(PagoEvent(event_key="txn-001:APPROVED", payload=payload))
    await db_session.flush()

    db_session.add(PagoEvent(event_key="txn-001:APPROVED", payload=payload))
    with pytest.raises(IntegrityError):
        await db_session.flush()
    await db_session.rollback()

    # pago_id NULL + segundo evento distinto — ambos válidos.
    db_session.add(
        PagoEvent(event_key="txn-002:DECLINED", payload=payload, pago_id=None)
    )
    await db_session.flush()


# --- Unique de calificación por pedido (CALI-01) -------------------------


async def test_calificacion_una_por_pedido(db_session):
    """uq_calificacion_pedido: una sola calificación por pedido."""
    r, u, _, _, _, pedido = await _seed_chain(db_session)
    r_id, u_id, pedido_id = r.id, u.id, pedido.id
    await db_session.commit()

    db_session.add(
        Calificacion(restaurant_id=r_id, usuario_id=u_id, pedido_id=pedido_id, estrellas=5)
    )
    await db_session.flush()

    db_session.add(
        Calificacion(restaurant_id=r_id, usuario_id=u_id, pedido_id=pedido_id, estrellas=3)
    )
    with pytest.raises(IntegrityError):
        await db_session.flush()
    await db_session.rollback()
