"""CORS middleware integration tests (Phase 4, T-04-01 / research Pitfall 1).

The panel web (Plan 04-02) lives on http://localhost:5173 while the API is on
:8000 — different origins. Without CORSMiddleware every browser request dies
at preflight ("works in Bruno, blocked in Chrome"). These tests pin the
middleware contract:

  - preflight from the ALLOWED origin -> 200 + Access-Control-Allow-Origin echo
  - preflight from a BLOCKED origin -> 400, and the ACAO header never leaks
    the offending origin (Starlette "Disallowed CORS origin")
  - simple GET responses carry ACAO even when the handler itself answers 401
    (the middleware wraps the whole app, not just happy paths)
"""

ALLOWED = "http://localhost:5173"


async def test_cors_preflight_allowed_origin(async_client):
    """OPTIONS /staff/mesas desde :5173 -> 200 + ACAO echo exacto."""
    resp = await async_client.options(
        "/staff/mesas",
        headers={
            "Origin": ALLOWED,
            "Access-Control-Request-Method": "GET",
        },
    )
    assert resp.status_code == 200, resp.text
    assert resp.headers.get("access-control-allow-origin") == ALLOWED


async def test_cors_preflight_blocked_origin(async_client):
    """OPTIONS desde un origen no listado -> 400 (Disallowed CORS origin)
    y el ACAO header NO refleja jamás el origen ofensivo."""
    resp = await async_client.options(
        "/staff/mesas",
        headers={
            "Origin": "http://evil.example.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    # Starlette responde 400 "Disallowed CORS origin" (assert flexible por si
    # cambia a 403 en versiones futuras).
    assert resp.status_code in (400, 403), resp.text
    allow_origin = resp.headers.get("access-control-allow-origin")
    assert allow_origin != "http://evil.example.com"
    assert "evil.example.com" not in (allow_origin or "")


async def test_cors_get_has_allow_origin(async_client):
    """Un GET simple con Origin permitido lleva ACAO incluso en 401.

    Sin token el handler responde 401, pero el middleware ya inyectó los
    headers CORS — el navegador debe poder LEER el error 401 (si no, el
    usuario vería un opaco "network error" en vez de "no autenticado").
    """
    resp = await async_client.get("/staff/mesas", headers={"Origin": ALLOWED})
    assert resp.status_code == 401, resp.text
    assert resp.headers.get("access-control-allow-origin") == ALLOWED
