"""Unitarios puros de las state machines de dominio (Phase 3).

NO tocan la BD ni levantan FastAPI — corren en milisegundos. Validan que las
transiciones declaradas en ``app.core.state_machines`` coinciden con
ARCHITECTURE.md Pattern 5 y que las transiciones inválidas/terminales se
rechazan con ``TransicionInvalidaError``.
"""

import pytest

from app.core.state_machines import (
    MESA_TRANSITIONS,
    PEDIDO_TRANSITIONS,
    PAGO_TRANSITIONS,
    RESERVA_TRANSITIONS,
    SESION_TRANSITIONS,
    TransicionInvalidaError,
    puede_transicionar,
    validar_transicion,
)
from app.models.mesa import EstadoMesa
from app.models.pago import EstadoPago
from app.models.pedido import EstadoPedido
from app.models.reserva import EstadoReserva
from app.models.sesion_mesa import EstadoSesion


# --- MESA -----------------------------------------------------------------


def test_mesas_transiciones_validas():
    """El ciclo completo disponible→ocupada→limpieza→disponible + reservas."""
    validar_transicion("mesa", EstadoMesa.disponible, EstadoMesa.ocupada)
    validar_transicion("mesa", EstadoMesa.ocupada, EstadoMesa.limpieza)
    validar_transicion("mesa", EstadoMesa.limpieza, EstadoMesa.disponible)
    validar_transicion("mesa", EstadoMesa.disponible, EstadoMesa.reservada)
    validar_transicion("mesa", EstadoMesa.reservada, EstadoMesa.ocupada)
    validar_transicion("mesa", EstadoMesa.reservada, EstadoMesa.disponible)


def test_mesa_transiciones_invalidas_rechazadas():
    """Saltos no declarados (limpieza→ocupada, disponible→limpieza,
    ocupada→disponible) son rechazados."""
    for actual, nueva in [
        (EstadoMesa.limpieza, EstadoMesa.ocupada),
        (EstadoMesa.disponible, EstadoMesa.limpieza),
        (EstadoMesa.ocupada, EstadoMesa.disponible),
    ]:
        with pytest.raises(TransicionInvalidaError) as exc:
            validar_transicion("mesa", actual, nueva)
        assert exc.value.maquina == "mesa"
        assert exc.value.actual == actual
        assert exc.value.nueva == nueva


# --- PEDIDO ---------------------------------------------------------------


def test_pedido_cadena_completa_valida():
    """borrador→enviado→aceptado→en_preparacion→servido→pagado pasa."""
    validar_transicion("pedido", EstadoPedido.borrador, EstadoPedido.enviado)
    validar_transicion("pedido", EstadoPedido.enviado, EstadoPedido.aceptado)
    validar_transicion("pedido", EstadoPedido.aceptado, EstadoPedido.en_preparacion)
    validar_transicion("pedido", EstadoPedido.en_preparacion, EstadoPedido.servido)
    validar_transicion("pedido", EstadoPedido.servido, EstadoPedido.pagado)


def test_pedido_enviado_puede_rechazarse():
    validar_transicion("pedido", EstadoPedido.enviado, EstadoPedido.rechazado)


def test_pedido_rechazado_y_pagado_son_terminales():
    """Desde un terminal, cualquier transición (incluso a sí mismo implícitamente
    via otros estados) levanta TransicionInvalidaError."""
    terminales = [EstadoPedido.rechazado, EstadoPedido.pagado]
    for terminal in terminales:
        for nuevo in EstadoPedido:
            if nuevo == terminal:
                continue
            with pytest.raises(TransicionInvalidaError):
                validar_transicion("pedido", terminal, nuevo)


def test_pedido_salto_invalido_rechazado():
    """borrador→pagado (saltarse la cadena) no permitido."""
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("pedido", EstadoPedido.borrador, EstadoPedido.pagado)
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("pedido", EstadoPedido.borrador, EstadoPedido.aceptado)


# --- COBERTURA Enums vs dicts --------------------------------------------


def test_cobertura_declarada():
    """Todo estado del Enum tiene entrada en el dict (evita estados huérfanos)."""
    assert set(MESA_TRANSITIONS) == set(EstadoMesa)
    assert set(PEDIDO_TRANSITIONS) == set(EstadoPedido)
    assert set(RESERVA_TRANSITIONS) == set(EstadoReserva)
    assert set(PAGO_TRANSITIONS) == set(EstadoPago)
    assert set(SESION_TRANSITIONS) == set(EstadoSesion)


# --- puede_transicionar (helper booleano) ---------------------------------


def test_puede_transicionar_retorna_bool_false_sin_levantar():
    assert puede_transicionar("mesa", EstadoMesa.limpieza, EstadoMesa.ocupada) is False
    assert puede_transicionar("mesa", EstadoMesa.disponible, EstadoMesa.ocupada) is True
    # Terminal: nunca puede transicionar
    assert puede_transicionar("pedido", EstadoPedido.pagado, EstadoPedido.borrador) is False


# --- RESERVA / PAGO / SESION (smoke de terminales) ------------------------


def test_reserva_cancelada_es_terminal():
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("reserva", EstadoReserva.cancelada, EstadoReserva.confirmada)


def test_pago_aprobado_es_terminal():
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("pago", EstadoPago.aprobado, EstadoPago.pendiente)


def test_sesion_cerrada_es_terminal():
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("sesion_mesa", EstadoSesion.cerrada, EstadoSesion.activa)
