"""INFR-02 smoke test: GET /health returns 200 with database connected."""

import pytest


async def test_health_returns_connected(async_client):
    """GET /health -> 200 {"status":"ok","database":"connected"} when DB is up."""
    resp = await async_client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert "database" in body
    assert body["database"] == "connected"


_ = pytest  # silence unused-import when running ruff on tests dir
