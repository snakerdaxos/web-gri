"""Pydantic schema for PATCH /cliente/perfil (AUTH-05).

``email`` is DELIBERATELY absent — it is the login key and changing it breaks
the unique login identity. If a client posts ``email`` in the body, Pydantic
rejects it with 422 (we do NOT silence it with ``extra="ignore"``) so the
immutability surfaces to the client. ``password`` is optional: when present
the service hashes + stores it; when absent the stored hash is untouched.
"""

from pydantic import BaseModel, Field


class PerfilUpdate(BaseModel):
    """PATCH /cliente/perfil body. ``nombre`` required; ``password`` optional.
    Email immutable (not in this schema)."""

    nombre: str = Field(min_length=1, max_length=150)
    password: str | None = Field(default=None, min_length=8, max_length=64)
