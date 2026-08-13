"""State machines explícitas de dominio (ARCHITECTURE.md Pattern 5).

Módulo PURO: no importa ORM ni FastAPI — solo los enums de estado. Phase 5/6
importan ``validar_transicion()`` en sus services y traducen
``TransicionInvalidaError`` a 409 Conflict en el router (el dominio no decide
códigos HTTP). Los tests unitarios de este módulo corren en milisegundos sin
levantar la base ni el stack.

Cada ``*_TRANSITIONS`` dict mapea ``estado_origen -> {estados_destino}``.
Un ``set()`` vacío marca un estado TERMINAL (no admite más transiciones).
"""

from app.models.mesa import EstadoMesa
from app.models.pedido import EstadoPedido
from app.models.reserva import EstadoReserva
from app.models.sesion_mesa import EstadoSesion
from app.models.pago import EstadoPago


class TransicionInvalidaError(Exception):
    """Transición de estado no permitida por la máquina de estados del dominio.

    Atributos:
        maquina: nombre de la máquina ("mesa", "pedido", ...).
        actual: estado origen (Enum).
        nueva: estado destino rechazado (Enum).
    """

    def __init__(self, maquina: str, actual, nueva):
        self.maquina = maquina
        self.actual = actual
        self.nueva = nueva
        super().__init__(
            f"[{maquina}] transición {actual!r} → {nueva!r} no permitida"
        )


# ARCHITECTURE.md Pattern 5 — set vacío = terminal.
MESA_TRANSITIONS: dict[EstadoMesa, set[EstadoMesa]] = {
    EstadoMesa.disponible: {EstadoMesa.reservada, EstadoMesa.ocupada},
    EstadoMesa.reservada: {EstadoMesa.ocupada, EstadoMesa.disponible},
    EstadoMesa.ocupada: {EstadoMesa.limpieza},
    EstadoMesa.limpieza: {EstadoMesa.disponible},
}

PEDIDO_TRANSITIONS: dict[EstadoPedido, set[EstadoPedido]] = {
    EstadoPedido.borrador: {EstadoPedido.enviado},
    EstadoPedido.enviado: {EstadoPedido.aceptado, EstadoPedido.rechazado},
    EstadoPedido.aceptado: {EstadoPedido.en_preparacion},
    EstadoPedido.en_preparacion: {EstadoPedido.servido},
    EstadoPedido.servido: {EstadoPedido.pagado},
    EstadoPedido.rechazado: set(),  # terminal
    EstadoPedido.pagado: set(),  # terminal
}

RESERVA_TRANSITIONS: dict[EstadoReserva, set[EstadoReserva]] = {
    EstadoReserva.pendiente: {EstadoReserva.confirmada, EstadoReserva.cancelada},
    EstadoReserva.confirmada: {EstadoReserva.cancelada},
    EstadoReserva.cancelada: set(),  # terminal
}

PAGO_TRANSITIONS: dict[EstadoPago, set[EstadoPago]] = {
    EstadoPago.pendiente: {EstadoPago.aprobado, EstadoPago.rechazado},
    EstadoPago.aprobado: set(),  # terminal
    EstadoPago.rechazado: set(),  # terminal
}

SESION_TRANSITIONS: dict[EstadoSesion, set[EstadoSesion]] = {
    EstadoSesion.activa: {EstadoSesion.cerrada, EstadoSesion.expirada},
    EstadoSesion.cerrada: set(),  # terminal
    EstadoSesion.expirada: set(),  # terminal
}

_ALL: dict[str, dict] = {
    "mesa": MESA_TRANSITIONS,
    "pedido": PEDIDO_TRANSITIONS,
    "reserva": RESERVA_TRANSITIONS,
    "pago": PAGO_TRANSITIONS,
    "sesion_mesa": SESION_TRANSITIONS,
}


def validar_transicion(maquina: str, actual, nueva) -> None:
    """Raise ``TransicionInvalidaError`` si ``actual`` → ``nueva`` no está
    declarada en la máquina indicada.

    Args:
        maquina: clave en ``_ALL`` ("mesa", "pedido", "reserva", "pago",
            "sesion_mesa").
        actual: estado origen (Enum).
        nueva: estado destino (Enum).
    """
    transitions = _ALL[maquina]
    permitidas = transitions.get(actual, set())
    if nueva not in permitidas:
        raise TransicionInvalidaError(maquina, actual, nueva)


def puede_transicionar(maquina: str, actual, nueva) -> bool:
    """Versión booleana de :func:`validar_transicion` (sin raise)."""
    transitions = _ALL[maquina]
    return nueva in transitions.get(actual, set())
