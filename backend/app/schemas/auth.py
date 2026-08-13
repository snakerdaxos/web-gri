"""Pydantic schemas for the auth HTTP contract.

UserRead deliberately omits the secret hash field (PITFALL 7) — never use the
ORM model as a response_model. UserCreate.password caps at 64 chars (PITFALL 5
— bcrypt truncates at 72 bytes; 64 chars is ample and safe).
"""

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.usuario import RolUsuario


class UserCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    email: EmailStr
    # max_length=64 mitigates bcrypt's 72-byte truncation (PITFALL 5).
    password: str = Field(min_length=8, max_length=64)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserRead(BaseModel):
    """Public user shape. NEVER exposes the stored secret."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    email: EmailStr
    role: RolUsuario
    restaurant_id: int | None


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    """Body for /auth/refresh — JSON {"refresh_token": "..."}.

    JSON body (not raw string) for consistency with /auth/login and ease of use
    from the Flutter/dio client.
    """

    refresh_token: str
