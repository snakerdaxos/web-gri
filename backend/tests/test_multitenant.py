"""AUTH-04 multi-tenant isolation integration tests — THE HARD GATE of Phase 2.

Architectural decision under test (research Pattern 3 + Pitfall 3):
cross-tenant access returns **404**, never 200 and never 403 — a staff member
of restaurant A must not even learn that restaurant B exists. The tenant filter
lives in admin_service.get_restaurante_for_staff:

    if not scope.is_super_admin:
        stmt = stmt.where(Restaurante.id == scope.restaurant_id)

A cross-tenant lookup returns None -> the router answers a uniform 404. If any
of these tests see a 403 instead, the filter leaked (or was answered as a
forbidden instead of a not-found) — that is a BUG, fix before advancing.

Precondition: Docker stack running, admin endpoints from Task 1 available.
"""

from dataclasses import dataclass
from uuid import uuid4

import pytest

from .conftest import auth_header, login

pytestmark = pytest.mark.asyncio


@dataclass
class TenantSetup:
    """Two restaurantes + a mesero bound to restaurante A."""

    id_a: int
    id_b: int
    mesero_a_token: str


def _suffix() -> str:
    return uuid4().hex[:8]


async def _setup_two_tenants(client, sa_token: str) -> TenantSetup:
    """Create restaurante A + B and a mesero for A; return ids + mesero token."""
    # Restaurante A (the mesero's own tenant)
    resp_a = await client.post(
        "/admin/restaurantes",
        json={
            "nombre": f"RestA-{_suffix()}",
            "descripcion": "Tenant A",
            "tipo_cocina": "Fusion",
            "direccion": f"Calle A {_suffix()}",
        },
        headers=auth_header(sa_token),
    )
    assert resp_a.status_code == 201, resp_a.text
    id_a = resp_a.json()["id"]

    # Restaurante B (the OTHER tenant)
    resp_b = await client.post(
        "/admin/restaurantes",
        json={
            "nombre": f"RestB-{_suffix()}",
            "descripcion": "Tenant B",
            "tipo_cocina": "Parrilla",
            "direccion": f"Calle B {_suffix()}",
        },
        headers=auth_header(sa_token),
    )
    assert resp_b.status_code == 201, resp_b.text
    id_b = resp_b.json()["id"]

    # Mesero "Juan" assigned to restaurante A only
    mesero_email = f"juan-{_suffix()}@gri.dev"
    mesero_password = "S3cret0!1"
    resp_staff = await client.post(
        f"/admin/restaurantes/{id_a}/staff",
        json={
            "nombre": "Juan",
            "email": mesero_email,
            "password": mesero_password,
            "role": "mesero",
        },
        headers=auth_header(sa_token),
    )
    assert resp_staff.status_code == 201, resp_staff.text

    mesero_token, _ = await login(client, mesero_email, mesero_password)
    return TenantSetup(id_a=id_a, id_b=id_b, mesero_a_token=mesero_token)


# --- THE HARD GATE ------------------------------------------------------------


async def test_staff_cross_tenant_404(async_client, super_admin_token):
    """HARD GATE (AUTH-04): mesero of A GETs restaurante B -> **404**.

    Cross-tenant returns 404 to avoid revealing resource existence (research
    Pattern 3 + Pitfall 3). NOT 200 (that would be a data leak) and NOT 403
    (that would confirm B exists). This is the single most important assertion
    of the phase.
    """
    setup = await _setup_two_tenants(async_client, super_admin_token)
    resp = await async_client.get(
        f"/admin/restaurantes/{setup.id_b}", headers=auth_header(setup.mesero_a_token)
    )
    assert resp.status_code == 404, resp.text


async def test_staff_own_tenant_200(async_client, super_admin_token):
    """AUTH-04 positive case: mesero of A GETs restaurante A -> 200."""
    setup = await _setup_two_tenants(async_client, super_admin_token)
    resp = await async_client.get(
        f"/admin/restaurantes/{setup.id_a}", headers=auth_header(setup.mesero_a_token)
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == setup.id_a


async def test_super_admin_no_filter(async_client, super_admin_token):
    """AUTH-04: super_admin carries no tenant filter — GETs restaurante B -> 200."""
    setup = await _setup_two_tenants(async_client, super_admin_token)
    resp = await async_client.get(
        f"/admin/restaurantes/{setup.id_b}", headers=auth_header(super_admin_token)
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == setup.id_b


async def test_staff_other_staff_restaurante(async_client, super_admin_token):
    """AUTH-04: restaurante B has its OWN staff; mesero of A still gets 404 on B.

    Two staffed tenants side by side — the isolation is symmetric: each staff
    member only ever resolves their own tenant's root.
    """
    setup = await _setup_two_tenants(async_client, super_admin_token)
    # Staff B exists and is functional...
    resp_pedro = await async_client.post(
        f"/admin/restaurantes/{setup.id_b}/staff",
        json={
            "nombre": "Pedro",
            "email": f"pedro-{_suffix()}@gri.dev",
            "password": "S3cret0!1",
            "role": "mesero",
        },
        headers=auth_header(super_admin_token),
    )
    assert resp_pedro.status_code == 201, resp_pedro.text
    # ...but mesero of A cannot see B.
    resp = await async_client.get(
        f"/admin/restaurantes/{setup.id_b}", headers=auth_header(setup.mesero_a_token)
    )
    assert resp.status_code == 404, resp.text


async def test_super_admin_sees_any_active(async_client, super_admin_token):
    """AUTH-04: the super_admin list contains every restaurante created here."""
    setup = await _setup_two_tenants(async_client, super_admin_token)
    resp = await async_client.get(
        "/admin/restaurantes", headers=auth_header(super_admin_token)
    )
    assert resp.status_code == 200, resp.text
    ids = {r["id"] for r in resp.json()}
    assert setup.id_a in ids
    assert setup.id_b in ids
