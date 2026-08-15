"""Gateways de pago — factory según settings.SANDBOX_MODE (Phase 9).

``get_pago_gateway()`` es la ÚNICA vía de selección (los services jamás
instancian un gateway directo): dev → SandboxGateway (pipeline real del
webhook firmado localmente), prod → WompiGateway (keys reales vía env).
"""

from app.core.config import settings
from app.core.gateways.base import PagoGateway
from app.core.gateways.sandbox_gateway import SandboxGateway
from app.core.gateways.wompi_gateway import WompiGateway

__all__ = ["PagoGateway", "SandboxGateway", "WompiGateway", "get_pago_gateway"]


def get_pago_gateway() -> PagoGateway:
    """SandboxGateway si settings.SANDBOX_MODE, sino WompiGateway."""
    if settings.SANDBOX_MODE:
        return SandboxGateway()
    return WompiGateway()
