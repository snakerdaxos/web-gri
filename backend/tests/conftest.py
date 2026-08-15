"""Pytest fixtures + helpers for the GRI API test suite.

The async_client fixture assumes the Docker stack is already running
(`docker compose up -d`). It points at http://localhost:8000 (the published
API port from docker-compose.yml).

Phase 2 additions: auth helpers (register_cliente, login, auth_header) and a
super_admin_token fixture that reads SUPER_ADMIN_* from the environment. Tests
require the stack running with the Alembic migration applied (the Dockerfile
CMD does this on boot) AND SUPER_ADMIN_* set in .env.

Phase 3 additions:
- ``_read_env_var`` helper: shared manual .env parser (host-level), used by
  ``super_admin_token`` and the new ``db_session`` fixture.
- ``db_session`` fixture: asyncmy session DIRECTLY against the Docker MySQL
  (localhost:3306). Enables DB-direct tests of constraints/seed/state-machines
  without going through HTTP endpoints (which don't exist for domain entities
  until Phase 4-6).
"""

import os
from collections.abc import AsyncGenerator
from pathlib import Path
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

API_BASE = "http://localhost:8000"


# --- Phase 3: shared .env parser -----------------------------------------


def _read_env_var(key: str) -> str | None:
    """Read a single var from the host-level ``.env`` (project root).

    The test process does not auto-load ``.env``; this mirrors the same manual
    parse that ``super_admin_token`` used inline in Phase 2, now extracted so
    ``db_session`` can reuse it for DB credentials. Returns the raw value or
    None if absent.
    """
    cached = os.environ.get(key)
    if cached:
        return cached
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1]
    return None


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    """Yield an httpx AsyncClient pointing at the running API container."""
    async with httpx.AsyncClient(base_url=API_BASE) as client:
        yield client


# --- Phase 2: auth helpers ------------------------------------------------


async def register_cliente(
    client: httpx.AsyncClient,
    *,
    email: str | None = None,
    password: str = "S3cret0!",
    nombre: str = "Test User",
) -> dict:
    """POST /auth/register with a unique email by default; return the JSON body."""
    if email is None:
        email = f"test-{uuid4().hex[:8]}@x.com"
    resp = await client.post(
        "/auth/register",
        json={"nombre": nombre, "email": email, "password": password},
    )
    resp.raise_for_status()
    body = resp.json()
    body["_password"] = password  # carry back for subsequent login
    return body


async def login(
    client: httpx.AsyncClient, email: str, password: str
) -> tuple[str, str]:
    """POST /auth/login; return (access_token, refresh_token)."""
    resp = await client.post(
        "/auth/login", json={"email": email, "password": password}
    )
    resp.raise_for_status()
    data = resp.json()
    return data["access_token"], data["refresh_token"]


def auth_header(token: str) -> dict[str, str]:
    """Build the Authorization header dict for a Bearer token."""
    return {"Authorization": f"Bearer {token}"}


# --- Phase 6: sesión QR + staff demo helpers -------------------------------


async def abrir_sesion(
    client: httpx.AsyncClient, token: str, codigo_qr: str
) -> httpx.Response:
    """POST /cliente/sesiones with auth (MESA-05/06 helper).

    Deliberately NO raise_for_status: the caller asserts which status is
    expected (201 created / 200 idempotente propio / 404 QR inexistente /
    409 conflicto).
    """
    return await client.post(
        "/cliente/sesiones",
        json={"codigo_qr": codigo_qr},
        headers=auth_header(token),
    )


async def login_staff_demo(client: httpx.AsyncClient, email: str) -> str:
    """Access token for a seed-demo staff account (password Demo!1234).

    Seed staff (restaurant_id=1): admin@demo.gri.dev, mesero@demo.gri.dev,
    cocina@demo.gri.dev.
    """
    access, _ = await login(client, email, "Demo!1234")
    return access


# --- Phase 9: pago helpers ----------------------------------------------------


async def abrir_sesion_con_pedido_servido(
    client: httpx.AsyncClient,
    db_session,
    *,
    n_pedidos: int = 1,
    items_por_pedido: int = 1,
) -> dict:
    """Cadena completa reproducible para tests de pago (09-01 Task 2).

    (a) Mesa PROPIA por DB-direct INSERT (codigo_qr ``GRI-MESA-T``+uuid6,
    numero aleatorio 900+, capacidad 4, restaurante 1) — NO depende de las
    mesas del seed, que otros tests ocupan o dejan en estado sucio.
    (b) register_cliente + login + abrir sesión via POST /cliente/sesiones.
    (c) ``n_pedidos`` pedidos via POST /cliente/pedidos (``items_por_pedido``
    × "Bandeja Paisa" del seed del restaurante 1 — precio conocido).
    (d) Cada pedido avanzado enviado→aceptado→en_preparacion→servido con 3
    POST /staff/pedidos/{id}/estado (cocina@demo.gri.dev puede avanzar todo).

    Retorna dict: token, usuario, headers, mesa_id, codigo_qr, sesion_id,
    pedido_ids, precio_producto (Decimal), total_esperado (float).
    ``n_pedidos=0`` devuelve la cadena con la sesión abierta y sin pedidos.
    """
    from sqlalchemy import select as _select

    from app.models.mesa import Mesa as _Mesa
    from app.models.menu import Producto as _Producto

    await db_session.rollback()
    db_session.expire_all()
    # (a) mesa propia — numero aleatorio 900+ (no colisiona con seed 1-8).
    mesa = _Mesa(
        restaurant_id=1,
        numero=900 + abs(hash(uuid4().hex)) % 1000,
        capacidad=4,
        codigo_qr=f"GRI-MESA-T{uuid4().hex[:6]}",
    )
    db_session.add(mesa)
    await db_session.commit()  # expire_on_commit=False → mesa.id queda cargado

    # (b) cliente fresco + sesión sobre ESA mesa.
    usuario = await register_cliente(client, nombre="Pago Test")
    token, _ = await login(client, usuario["email"], usuario["_password"])
    resp = await abrir_sesion(client, token, mesa.codigo_qr)
    assert resp.status_code == 201, resp.text
    sesion_id = resp.json()["id"]

    # (c)+(d) pedidos → servidos (via API real de staff).
    prod = (
        await db_session.execute(
            _select(_Producto).where(
                _Producto.restaurant_id == 1,
                _Producto.nombre == "Bandeja Paisa",
            )
        )
    ).scalar_one()
    headers = auth_header(token)
    headers_staff = auth_header(await login_staff_demo(client, "cocina@demo.gri.dev"))
    pedido_ids: list[int] = []
    for _ in range(n_pedidos):
        r = await client.post(
            "/cliente/pedidos",
            json={
                "sesion_id": sesion_id,
                "items": [{"producto_id": prod.id, "cantidad": items_por_pedido}],
            },
            headers=headers,
        )
        assert r.status_code == 201, r.text
        pedido_id = r.json()["id"]
        for estado in ("aceptado", "en_preparacion", "servido"):
            rr = await client.post(
                f"/staff/pedidos/{pedido_id}/estado",
                json={"estado": estado},
                headers=headers_staff,
            )
            assert rr.status_code == 200, rr.text
        pedido_ids.append(pedido_id)

    await db_session.rollback()
    db_session.expire_all()
    return {
        "token": token,
        "usuario": usuario,
        "headers": headers,
        "mesa_id": mesa.id,
        "codigo_qr": mesa.codigo_qr,
        "sesion_id": sesion_id,
        "pedido_ids": pedido_ids,
        "precio_producto": prod.precio,
        "total_esperado": float(prod.precio) * n_pedidos * items_por_pedido,
    }


async def borrar_residuo_pago(db_session, ctx: dict) -> None:
    """Borra TODO el residuo de un test de pago en ORDEN FK INVERSO:
    calificacion → pago_event → pago → pedido_item → pedido → sesion_mesa →
    mesa. Cada paso en try/except+rollback para que un fallo parcial NO
    impida los demás (lección 06-01 — BD compartida, SIEMPRE limpiar).

    ``ctx`` es el dict de ``abrir_sesion_con_pedido_servido`` (usa
    usuario["id"], sesion_id, mesa_id).
    """
    from sqlalchemy import delete as _delete, select as _select

    from app.models.calificacion import Calificacion as _Cal
    from app.models.mesa import Mesa as _Mesa
    from app.models.pago import Pago as _Pago
    from app.models.pago_event import PagoEvent as _PagoEvent
    from app.models.pedido import Pedido as _Pedido, PedidoItem as _PedidoItem
    from app.models.sesion_mesa import SesionMesa as _Sesion

    usuario_id = ctx["usuario"]["id"]
    sesion_id = ctx["sesion_id"]
    mesa_id = ctx["mesa_id"]

    await db_session.rollback()
    db_session.expire_all()

    async def _paso(query) -> None:
        try:
            await db_session.execute(query)
            await db_session.commit()
        except Exception:
            await db_session.rollback()

    await _paso(_delete(_Cal).where(_Cal.usuario_id == usuario_id))
    await _paso(
        _delete(_PagoEvent).where(
            _PagoEvent.pago_id.in_(_select(_Pago.id).where(_Pago.sesion_id == sesion_id))
        )
    )
    await _paso(_delete(_Pago).where(_Pago.sesion_id == sesion_id))
    await _paso(
        _delete(_PedidoItem).where(
            _PedidoItem.pedido_id.in_(
                _select(_Pedido.id).where(_Pedido.usuario_id == usuario_id)
            )
        )
    )
    await _paso(_delete(_Pedido).where(_Pedido.usuario_id == usuario_id))
    await _paso(_delete(_Sesion).where(_Sesion.id == sesion_id))
    await _paso(_delete(_Mesa).where(_Mesa.id == mesa_id))
    await db_session.rollback()


@pytest_asyncio.fixture
async def super_admin_token(async_client: httpx.AsyncClient) -> str:
    """Login as the bootstrap super-admin; skip if SUPER_ADMIN_* unset."""
    email = _read_env_var("SUPER_ADMIN_EMAIL")
    password = _read_env_var("SUPER_ADMIN_PASSWORD")
    if not email or not password:
        pytest.skip("SUPER_ADMIN_* not configured")
    access, _ = await login(async_client, email, password)
    return access


# --- Phase 3: DB-direct fixture ------------------------------------------


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Sesión asyncmy DIRECTA a la BD del stack Docker.

    Para tests de dominio sin endpoints: constraints, seed, enums. Requiere el
    stack corriendo (igual que ``async_client``).

    Usa ``settings.database_url`` que resuelve el host correcto según el entorno
    (``mysql`` dentro del contenedor via DB_HOST, ``localhost`` en el host via
    puerto publicado). Hereda el patrón anti-MissingGreenlet de Phase 1 con
    ``expire_on_commit=False``.
    """
    from app.core.config import settings

    engine = create_async_engine(settings.database_url)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


# Keep pytest happy with the plugin import (silences unused-import on strict linters).
_ = pytest
