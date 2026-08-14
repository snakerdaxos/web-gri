"""Cliente business logic — perfil read/update (AUTH-05).

Thin layer over Usuario: load by id, mutate non-immutable fields, hash
password if provided. Email is NEVER mutated (immutable login key — changing
it breaks the unique login identity).
"""

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.usuario import Usuario
from app.schemas.auth import UserRead
from app.schemas.perfil import PerfilUpdate


async def get_perfil(session: AsyncSession, user_id: int) -> UserRead:
    """AUTH-05 ver: 404 si no existe (defensa; en práctica user_id viene del
    JWT así que siempre existe)."""
    user = await session.get(Usuario, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    return UserRead.model_validate(user)


async def update_perfil(
    session: AsyncSession, user_id: int, body: PerfilUpdate
) -> UserRead:
    """AUTH-05 editar: actualiza nombre; hashea password si viene; email NO
    se toca (immutable — y el schema ``extra="forbid"`` rechaza cualquier
    campo extra con 422 antes de llegar aquí)."""
    user = await session.get(Usuario, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")

    user.nombre = body.nombre
    if body.password is not None:
        user.password_hash = hash_password(body.password)

    await session.commit()
    await session.refresh(user)
    return UserRead.model_validate(user)
