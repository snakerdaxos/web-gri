"""Model package — re-export Base + every model so Alembic's env.py (and any
`from app.models import ...`) sees the full metadata in one import.

Phase 3 extends the package with the 9 domain tables (mesa, categoria,
producto, pedido, pedido_item, reserva, sesion_mesa, pago, calificacion) and
their 5 estado enums.
"""

from app.models.base import Base
from app.models.calificacion import Calificacion
from app.models.mesa import EstadoMesa, Mesa
from app.models.menu import Categoria, Producto
from app.models.pago import EstadoPago, Pago
from app.models.pago_event import PagoEvent
from app.models.pedido import EstadoPedido, Pedido, PedidoItem
from app.models.reserva import EstadoReserva, Reserva
from app.models.restaurante import Restaurante
from app.models.sesion_mesa import EstadoSesion, SesionMesa
from app.models.usuario import RolUsuario, Usuario

__all__ = [
    # Phase 2
    "Base",
    "Restaurante",
    "RolUsuario",
    "Usuario",
    # Phase 3 — mesa
    "EstadoMesa",
    "Mesa",
    # Phase 3 — menu
    "Categoria",
    "Producto",
    # Phase 3 — pedido
    "EstadoPedido",
    "Pedido",
    "PedidoItem",
    # Phase 3 — reserva
    "EstadoReserva",
    "Reserva",
    # Phase 3 — sesion_mesa
    "EstadoSesion",
    "SesionMesa",
    # Phase 3 — pago
    "EstadoPago",
    "Pago",
    # Phase 9 — pago_event (dedup at-least-once del webhook)
    "PagoEvent",
    # Phase 3 — calificacion
    "Calificacion",
]
