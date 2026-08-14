"""Integration tests for the /staff read endpoints (ADMN-01 + ADMN-02).

Black-box HTTP tests against the running Docker stack (Phase 2-3 convention:
no mocks, no DB patching — the stack must be up or these fail, by design).

Determinism note (deviation from the plan's literal counts): the Phase 3
constraint tests (test_domain_constraints.py) COMMIT uuid-tagged rows
(``GRI-TEST-*`` mesas, ``borrador`` pedidos) attached to the demo restaurante
and never clean up, so absolute row counts grow with every full-suite run.
These tests therefore assert, instead of ``total_mesas == 8``:

  - exact counts for the SEED subset (QR ``GRI-MESA-\\d{3}`` → 8, all
    ``disponible`` — the same convention test_seed.py already uses),
  - structural invariants (``total_mesas == suma de los 4 estados``),
  - tenant-scoped DB cross-checks: the API numbers must equal the DB reality
    filtered by the demo restaurante (proves the tenant filter + counts
    against live data, residue included).
"""

import re

from sqlalchemy import func, select

from app.models.mesa import EstadoMesa, Mesa
from app.models.pedido import EstadoPedido, Pedido
from app.models.reserva import EstadoReserva, Reserva
from app.models.restaurante import Restaurante
from tests.conftest import auth_header, login, register_cliente

DEMO_EMAIL = "admin@demo.gri.dev"
DEMO_PASSWORD = "Demo!1234"

SEED_QR = re.compile(r"^GRI-MESA-\d{3}$")
STATS_FIELDS = (
    "mesas_disponibles",
    "mesas_ocupadas",
    "mesas_reservadas",
    "mesas_limpieza",
    "total_mesas",
    "reservas_hoy",
    "pedidos_activos",
)
ESTADO_VALUES = {e.value for e in EstadoMesa}
PEDIDOS_ACTIVOS = [
    EstadoPedido.enviado,
    EstadoPedido.aceptado,
    EstadoPedido.en_preparacion,
    EstadoPedido.servido,
]


async def _demo_staff_token(async_client) -> str:
    """Login as the seeded demo admin (restaurant_id del demo)."""
    access, _ = await login(async_client, DEMO_EMAIL, DEMO_PASSWORD)
    return access


async def _demo_rid(db_session) -> int:
    """Resolve the demo restaurante's id by name (never hardcode the PK)."""
    rid = (
        await db_session.execute(
            select(Restaurante.id).where(
                Restaurante.nombre == "Restaurante Demo GRI"
            )
        )
    ).scalar_one()
    return rid


# --- GET /staff/mesas --------------------------------------------------------


async def test_mesas_own_tenant(async_client, db_session):
    """ADMN-02: staff del demo ve SOLO las mesas de SU restaurante.

    - 200 + lista no vacía (≥ 8)
    - cada item tiene exactamente los 5 campos de MesaRead
    - subset seed (GRI-MESA-\\d{3}) == 8, todas disponible, numeros 1..8
    - orden por numero ascendente
    - tenant isolation via DB cross-check: los ids devueltos == ids reales
      del restaurante demo (ninguna mesa de otro tenant se cuela)
    """
    token = await _demo_staff_token(async_client)
    resp = await async_client.get("/staff/mesas", headers=auth_header(token))
    assert resp.status_code == 200, resp.text
    body = resp.json()

    assert isinstance(body, list)
    assert len(body) >= 8

    for item in body:
        assert set(item.keys()) == {"id", "numero", "capacidad", "codigo_qr", "estado"}
        assert isinstance(item["id"], int)
        assert isinstance(item["numero"], int)
        assert isinstance(item["capacidad"], int)
        assert item["estado"] in ESTADO_VALUES

    numeros = [m["numero"] for m in body]
    assert numeros == sorted(numeros)

    seed = [m for m in body if SEED_QR.match(m["codigo_qr"])]
    assert len(seed) == 8
    assert all(m["estado"] == "disponible" for m in seed)
    assert sorted(m["numero"] for m in seed) == list(range(1, 9))

    rid = await _demo_rid(db_session)
    db_ids = set(
        (await db_session.execute(select(Mesa.id).where(Mesa.restaurant_id == rid)))
        .scalars()
        .all()
    )
    assert {m["id"] for m in body} == db_ids


async def test_mesas_ignores_query_param_for_staff(async_client):
    """T-04-02: el param ?restaurante_id= es IGNORADO para staff.

    Un staff del demo que envía ?restaurante_id=999 recibe EXACTAMENTE la
    misma respuesta que sin param (su propio tenant, forzado por el scope).
    """
    token = await _demo_staff_token(async_client)
    without_param = await async_client.get("/staff/mesas", headers=auth_header(token))
    with_param = await async_client.get(
        "/staff/mesas", headers=auth_header(token), params={"restaurante_id": 999}
    )
    assert without_param.status_code == 200
    assert with_param.status_code == 200
    assert with_param.json() == without_param.json()


async def test_mesas_requires_token(async_client):
    """Sin Authorization header -> 401 (get_current_user, AUTH-02)."""
    resp = await async_client.get("/staff/mesas")
    assert resp.status_code == 401, resp.text


async def test_mesas_cliente_forbidden(async_client):
    """get_tenant_scope: un cliente NUNCA obtiene tenant scope -> 403."""
    body = await register_cliente(async_client)
    access, _ = await login(async_client, body["email"], body["_password"])
    resp = await async_client.get("/staff/mesas", headers=auth_header(access))
    assert resp.status_code == 403, resp.text


async def test_mesas_super_admin_unknown_restaurante_404(
    async_client, super_admin_token
):
    """Existence hiding (AUTH-04 style): super_admin + rid inexistente -> 404
    (nunca 403 — la existencia de otros tenants no se revela)."""
    resp = await async_client.get(
        "/staff/mesas",
        headers=auth_header(super_admin_token),
        params={"restaurante_id": 999999},
    )
    assert resp.status_code == 404, resp.text


# --- GET /staff/stats --------------------------------------------------------


async def _db_expected_stats(db_session, rid: int) -> dict:
    """Compute the tenant-scoped truth directly from the DB (cross-check)."""
    rows = (
        await db_session.execute(
            select(Mesa.estado, func.count())
            .where(Mesa.restaurant_id == rid)
            .group_by(Mesa.estado)
        )
    ).all()
    by_estado = {estado.value: total for estado, total in rows}
    disp = by_estado.get("disponible", 0)
    ocup = by_estado.get("ocupada", 0)
    res = by_estado.get("reservada", 0)
    limp = by_estado.get("limpieza", 0)

    reservas_hoy = (
        await db_session.execute(
            select(func.count())
            .select_from(Reserva)
            .where(
                Reserva.restaurant_id == rid,
                # curdate() DB-side (America/Bogota) — Pitfall 6.
                Reserva.fecha == func.curdate(),
                Reserva.estado != EstadoReserva.cancelada,
            )
        )
    ).scalar_one()

    pedidos_activos = (
        await db_session.execute(
            select(func.count())
            .select_from(Pedido)
            .where(
                Pedido.restaurant_id == rid,
                Pedido.estado.in_(PEDIDOS_ACTIVOS),
            )
        )
    ).scalar_one()

    return {
        "mesas_disponibles": disp,
        "mesas_ocupadas": ocup,
        "mesas_reservadas": res,
        "mesas_limpieza": limp,
        "total_mesas": disp + ocup + res + limp,
        "reservas_hoy": reservas_hoy,
        "pedidos_activos": pedidos_activos,
    }


def _assert_stats_shape(body: dict) -> None:
    assert set(body.keys()) == set(STATS_FIELDS)
    for field in STATS_FIELDS:
        assert isinstance(body[field], int), f"{field} no es int: {body[field]!r}"
        assert body[field] >= 0
    # Invariante estructural: el total es la suma de los 4 estados.
    assert body["total_mesas"] == (
        body["mesas_disponibles"]
        + body["mesas_ocupadas"]
        + body["mesas_reservadas"]
        + body["mesas_limpieza"]
    )


async def test_stats_own_tenant(async_client, db_session):
    """ADMN-01: staff del demo -> DashboardStats con counts reales de BD.

    El cross-check contra la BD (mismos filtros tenant-scoped) prueba que los
    números de la API son la realidad del tenant — inmune al residuo GRI-TEST-*
    de los tests de constraints.
    """
    token = await _demo_staff_token(async_client)
    resp = await async_client.get("/staff/stats", headers=auth_header(token))
    assert resp.status_code == 200, resp.text
    body = resp.json()

    _assert_stats_shape(body)
    assert body["total_mesas"] >= 8  # 8 seed + residuo de constraints >= 0

    rid = await _demo_rid(db_session)
    expected = await _db_expected_stats(db_session, rid)
    assert body == expected


async def test_stats_super_admin_requires_param(async_client, super_admin_token):
    """Pitfall 4: super_admin SIN ?restaurante_id= -> 400 (no 500, no vacío)."""
    resp = await async_client.get(
        "/staff/stats", headers=auth_header(super_admin_token)
    )
    assert resp.status_code == 400, resp.text
    assert "restaurante_id" in resp.json()["detail"]


async def test_stats_super_admin_with_param(
    async_client, super_admin_token, db_session
):
    """super_admin + ?restaurante_id=<demo> -> mismo shape y números que staff."""
    rid = await _demo_rid(db_session)
    resp = await async_client.get(
        "/staff/stats",
        headers=auth_header(super_admin_token),
        params={"restaurante_id": rid},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()

    _assert_stats_shape(body)
    assert body["total_mesas"] >= 8
    expected = await _db_expected_stats(db_session, rid)
    assert body == expected
