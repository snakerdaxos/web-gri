"""Auth router — /auth/{register, login, refresh, me}.

Thin layer: parse → call auth_service → return. No business logic here.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.deps.auth import CurrentUser, get_current_user
from app.schemas.auth import RefreshRequest, TokenPair, UserCreate, UserLogin, UserRead
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register(body: UserCreate, session: AsyncSession = Depends(get_session)):
    """AUTH-01: public cliente self-registration."""
    return await auth_service.register_cliente(session, body)


@router.post("/login", response_model=TokenPair)
async def login(body: UserLogin, session: AsyncSession = Depends(get_session)):
    """AUTH-02: validate credentials, return access + refresh tokens."""
    return await auth_service.login(session, body)


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    body: RefreshRequest, session: AsyncSession = Depends(get_session)
):
    """AUTH-02: rotate tokens from a valid refresh token (JSON body)."""
    return await auth_service.refresh(session, body.refresh_token)


@router.get("/me", response_model=UserRead)
async def me(
    user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Return the authenticated user's profile."""
    return await auth_service.get_user(session, user.id)
