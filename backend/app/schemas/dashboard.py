"""Dashboard stats DTO (ADMN-01).

A computed DTO, NOT an ORM projection — hence no from_attributes. All seven
fields are ints (counts), which sidesteps the Decimal/COP serialization trap
entirely (research Pitfall 5: money totals are deferred to Phase 6/8).
"""

from pydantic import BaseModel


class DashboardStats(BaseModel):
    """The 7 numbers the panel dashboard renders as stat cards."""

    mesas_disponibles: int
    mesas_ocupadas: int
    mesas_reservadas: int
    mesas_limpieza: int
    total_mesas: int
    # Reservas where fecha == CURDATE() and estado != cancelada (DB-side
    # "today" — America/Bogota, research Pitfall 6).
    reservas_hoy: int
    # Pedidos in the active (non-terminal, post-envio) states.
    pedidos_activos: int
