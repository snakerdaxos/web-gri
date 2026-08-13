"""Model package — re-export Base + every model so Alembic's env.py (and any
`from app.models import ...`) sees the full metadata in one import.
"""

from app.models.base import Base
from app.models.restaurante import Restaurante
from app.models.usuario import RolUsuario, Usuario

__all__ = ["Base", "Restaurante", "RolUsuario", "Usuario"]
