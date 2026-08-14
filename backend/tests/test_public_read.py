"""Tests for /public endpoints — REST-01, REST-02, Pitfall 3 (precio float).

Covers:
- REST-01: GET /public/restaurantes sin auth lista restaurantes activos.
- REST-01: restaurantes inactivos NO aparecen (existence hiding público).
- REST-02: GET /public/restaurantes/{id} trae menú anidado por categorías.
- Pitfall 3: precio serializado como float (NO string Decimal).
- 404 para restaurante inactivo o desconocido.

Stack debe estar corriendo (docker compose up -d); el seed demo crea el
restaurante id=1 "Restaurante Demo GRI" con 4 categorias y 16 productos.
"""

from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models.restaurante import Restaurante

from .conftest import API_BASE  # noqa: F401  (silences unused-import lint)


@pytest.mark.asyncio
async def test_list_public_restaurantes(async_client):
    """REST-01: sin header de auth la lista responde 200 y trae el demo."""
    resp = await async_client.get("/public/restaurantes")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1, "demo restaurante debe existir"
    demo = next(
        (r for r in data if r["nombre"] == "Restaurante Demo GRI"), None
    )
    assert demo is not None, "Restaurante Demo GRI debe aparecer"
    # calificacion siempre None en Phase 5 (Phase 9 la llena con CALI-02).
    assert all(r["calificacion"] is None for r in data)


@pytest.mark.asyncio
async def test_excludes_inactive(async_client, db_session):
    """REST-01: un restaurante marcado inactivo NO aparece en la lista
    pública. Aislado con nombre único para no romper invariantes del seed
    (gotcha STATE.md sobre residuo GRI-TEST-* en la BD compartida)."""
    suffix = uuid4().hex[:8]
    inactive = Restaurante(
        nombre=f"GRI-INACTIVO-TEST-{suffix}",
        activo=False,
    )
    db_session.add(inactive)
    await db_session.commit()
    await db_session.refresh(inactive)
    try:
        resp = await async_client.get("/public/restaurantes")
        assert resp.status_code == 200
        nombres = {r["nombre"] for r in resp.json()}
        assert inactive.nombre not in nombres, (
            f"restaurante inactivo {inactive.nombre!r} no debe aparecer"
        )
        # Sanity: el demo SI aparece (control que el filtro funciona).
        assert "Restaurante Demo GRI" in nombres
    finally:
        # Cleanup: borrar el restaurante inactivo de prueba para que el
        # residuo GRI-TEST-* no se acumule en la BD compartida.
        stale = await db_session.get(Restaurante, inactive.id)
        if stale is not None:
            await db_session.delete(stale)
            await db_session.commit()


@pytest.mark.asyncio
async def test_detalle_con_menu(async_client):
    """REST-02: detalle del demo trae categorias con productos anidados."""
    resp = await async_client.get("/public/restaurantes/1")
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == 1
    assert body["nombre"] == "Restaurante Demo GRI"
    assert body["calificacion"] is None
    categorias = body["categorias"]
    assert isinstance(categorias, list)
    assert len(categorias) >= 1, "demo menú debe tener al menos una categoria"
    for cat in categorias:
        assert "id" in cat and "nombre" in cat and "orden" in cat
        assert isinstance(cat["productos"], list)
        assert len(cat["productos"]) >= 1, (
            f"categoria {cat['nombre']!r} debe tener productos"
        )


@pytest.mark.asyncio
async def test_precio_is_float(async_client):
    """Pitfall 3: precio DEBE ser numérico (float), nunca string Decimal.

    Si el @field_serializer de ProductoRead no se aplica, asyncmy devuelve
    Decimal y Pydantic v2 lo serializa como JSON string → rompe el cliente
    Dart (``type 'String' is not a subtype of type 'double'``)."""
    resp = await async_client.get("/public/restaurantes/1")
    assert resp.status_code == 200
    productos = resp.json()["categorias"][0]["productos"]
    assert len(productos) >= 1
    precio = productos[0]["precio"]
    assert isinstance(precio, (int, float)) and not isinstance(precio, bool), (
        f"precio debe ser numérico en JSON, recibido: {type(precio).__name__} ({precio!r})"
    )


@pytest.mark.asyncio
async def test_detalle_inactivo_404(async_client, db_session):
    """REST-02: restaurante inactivo → 404 (existence hiding público)."""
    suffix = uuid4().hex[:8]
    inactive = Restaurante(nombre=f"GRI-INACTIVO-DET-TEST-{suffix}", activo=False)
    db_session.add(inactive)
    await db_session.commit()
    await db_session.refresh(inactive)
    try:
        resp = await async_client.get(f"/public/restaurantes/{inactive.id}")
        assert resp.status_code == 404
    finally:
        stale = await db_session.get(Restaurante, inactive.id)
        if stale is not None:
            await db_session.delete(stale)
            await db_session.commit()


@pytest.mark.asyncio
async def test_detalle_unknown_404(async_client):
    """REST-02: id inexistente → 404 (no 500, no 200 con null)."""
    resp = await async_client.get("/public/restaurantes/999999")
    assert resp.status_code == 404
