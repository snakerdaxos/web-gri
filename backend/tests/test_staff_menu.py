"""Tests MENU-01/02 + filtro público tras migración 0005 (plan 08-01).

Task 1 — migración 0005 (soft-delete ``activo``) + menú público:

- ``categoria.activo`` / ``producto.activo`` existen con default True (todas
  las filas del demo quedan activas tras el upgrade — la historia
  ``pedido_item`` FK queda intacta, no se borra nada).
- GET /public/restaurantes/{id} EXCLUYE categorías y productos con
  ``activo=False``, PERO un producto agotado (``disponible=False``) SIGUE
  apareciendo con su flag — semántica desactivar ≠ agotado (F5 intacta).

Task 2 (mismo archivo, más abajo): CRUD staff /staff/menu + categorías +
productos con aislamiento tenant.

Stack corriendo + migración aplicada (el CMD del contenedor corre
``alembic upgrade head`` en cada boot). Aislamiento de la BD compartida:
los toggles se restauran SIEMPRE en finally (nested try/finally — gotcha
residuo STATE.md).
"""

import pytest
from sqlalchemy import select

from app.models.menu import Categoria, Producto


async def _demo_categoria(db_session) -> Categoria:
    """Primera categoría del demo (rid=1), determinista por id.

    rollback + expire_all antes del SELECT — patrón anti identity-map-stale
    (lección 05-02): el objeto que retorna siempre refleja la BD."""
    await db_session.rollback()
    db_session.expire_all()
    return (
        await db_session.execute(
            select(Categoria)
            .where(Categoria.restaurant_id == 1)
            .order_by(Categoria.id)
            .limit(1)
        )
    ).scalar_one()


async def _demo_producto(db_session) -> Producto:
    """Primer producto del demo (rid=1), determinista por id."""
    await db_session.rollback()
    db_session.expire_all()
    return (
        await db_session.execute(
            select(Producto)
            .where(Producto.restaurant_id == 1)
            .order_by(Producto.id)
            .limit(1)
        )
    ).scalar_one()


def _flatten_product_ids(body: dict) -> set[int]:
    """Todos los producto ids del menú anidado de /public/restaurantes/{id}."""
    return {
        p["id"] for cat in body["categorias"] for p in cat["productos"]
    }


# --- Migración 0005: columna activo default True ------------------------------


@pytest.mark.asyncio
async def test_migracion_activo_default_true(async_client, db_session):
    """Tras 0005, TODAS las categorías y productos del demo (rid=1) tienen
    activo=True — el server_default backfilla las filas existentes y las
    nuevas nacen activas (el menú público no cambia para el demo)."""
    await db_session.rollback()
    db_session.expire_all()
    categorias = (
        await db_session.execute(
            select(Categoria).where(Categoria.restaurant_id == 1)
        )
    ).scalars().all()
    productos = (
        await db_session.execute(
            select(Producto).where(Producto.restaurant_id == 1)
        )
    ).scalars().all()
    assert len(categorias) >= 1, "el demo tiene categorías"
    assert len(productos) >= 1, "el demo tiene productos"
    assert all(c.activo is True for c in categorias), (
        "toda categoría del demo debe quedar activa tras la migración"
    )
    assert all(p.activo is True for p in productos), (
        "todo producto del demo debe quedar activo tras la migración"
    )


# --- Filtro público: activo=False desaparece, disponible=False queda -----------


@pytest.mark.asyncio
async def test_public_detalle_excluye_categoria_y_producto_inactivos(
    async_client, db_session
):
    """activo=False saca del detalle público a la categoría y al producto;
    disponible=False (agotado) NO lo saca — llega con su flag."""
    # --- 1. Categoría inactiva desaparece del menú público -------------------
    cat = await _demo_categoria(db_session)
    cat_id = cat.id  # capturar ANTES de mutar/expire (PK plano — gotcha
    # MissingGreenlet: attr de objeto expirado dispara lazy-load síncrono)
    cat.activo = False
    await db_session.commit()
    db_session.expire_all()
    try:
        resp = await async_client.get("/public/restaurantes/1")
        assert resp.status_code == 200, resp.text
        ids = {c["id"] for c in resp.json()["categorias"]}
        assert cat_id not in ids, "categoría inactiva NO debe listarse en /public"
    finally:
        await db_session.rollback()
        db_session.expire_all()
        cat_db = await db_session.get(Categoria, cat_id)
        cat_db.activo = True
        await db_session.commit()

    # --- 2. Producto inactivo desaparece (de TODA categoría) ------------------
    prod = await _demo_producto(db_session)
    prod_id = prod.id
    prod.activo = False
    await db_session.commit()
    db_session.expire_all()
    try:
        resp = await async_client.get("/public/restaurantes/1")
        assert resp.status_code == 200, resp.text
        assert prod_id not in _flatten_product_ids(resp.json()), (
            "producto inactivo NO debe aparecer en /public"
        )
    finally:
        await db_session.rollback()
        db_session.expire_all()
        prod_db = await db_session.get(Producto, prod_id)
        prod_db.activo = True
        await db_session.commit()

    # --- 3. Producto AGOTADO (disponible=False) SIGUE con su flag -------------
    # Semántica distinta (F5): agotado es transitorio y visible; activo es
    # soft-delete. PROHIBIDO reutilizar disponible como soft-delete.
    await db_session.rollback()
    db_session.expire_all()
    prod = await db_session.get(Producto, prod_id)
    prod.disponible = False
    await db_session.commit()
    db_session.expire_all()
    try:
        resp = await async_client.get("/public/restaurantes/1")
        assert resp.status_code == 200, resp.text
        todos = {
            p["id"]: p for cat in resp.json()["categorias"] for p in cat["productos"]
        }
        assert prod_id in todos, "producto agotado SIGUE visible en /public"
        assert todos[prod_id]["disponible"] is False, (
            "el flag disponible=False viaja en el menú público"
        )
    finally:
        await db_session.rollback()
        db_session.expire_all()
        prod_db = await db_session.get(Producto, prod_id)
        prod_db.disponible = True
        await db_session.commit()
