"""Tests for /public endpoints — REST-01, REST-02, Pitfall 3 (precio float).

Covers:
- REST-01: GET /public/restaurantes sin auth lista restaurantes activos.
- REST-01: restaurantes inactivos NO aparecen (existence hiding público).
- REST-02: GET /public/restaurantes/{id} trae menú anidado por categorías.
- Pitfall 3: precio serializado como float (NO string Decimal).
- 404 para restaurante inactivo o desconocido.
- CALI-02 (Phase 9, 09-02 Task 2): calificacion promedio (round 1 decimal)
  + total_calificaciones en lista Y detalle, con restaurante PROPIO por test
  (aislado del seed y del residuo de otros tests — cleanup total en finally).

Stack debe estar corriendo (docker compose up -d); el seed demo crea el
restaurante id=1 "Restaurante Demo GRI" con 4 categorias y 16 productos.
"""

from uuid import uuid4

import pytest
from sqlalchemy import delete, select

from app.models.calificacion import Calificacion
from app.models.mesa import Mesa
from app.models.pedido import EstadoPedido, Pedido
from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

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


# --- CALI-02 (Phase 9, 09-02 Task 2): promedio + count en /public ----------


async def _sembrar_restaurante_con_calificaciones(
    db_session, estrellas: list[int]
) -> int:
    """Restaurante PROPIO + mesa + un pedido borrador por estrella + sus
    calificaciones (calificacion exige FK pedido UNIQUE — un pedido por
    fila). Aislado del seed y de otros tests: nunca asertar sobre el demo
    sin limpiar SUS calificaciones (plan 09-02 Task 2).

    Retorna el ``restaurant_id`` como int PLANO (rollback+expire_all al
    final — devolver el objeto ORM provocaría lazy-load sync →
    MissingGreenlet, patrón anti del conftest). Cleanup con
    ``_limpiar_restaurante_test`` en finally del caller.
    """
    suffix = uuid4().hex[:8]
    restaurante = Restaurante(nombre=f"GRI-CALI-PUB-{suffix}")
    db_session.add(restaurante)
    await db_session.commit()  # expire_on_commit=False → id queda cargado
    r_id = restaurante.id

    mesa = Mesa(
        restaurant_id=r_id, numero=1, capacidad=4, codigo_qr=f"GRI-MESA-CALI-{suffix}"
    )
    db_session.add(mesa)
    await db_session.commit()
    mesa_id = mesa.id

    usuario_id = (
        await db_session.execute(select(Usuario.id).limit(1))
    ).scalar_one()

    for estrella in estrellas:
        pedido = Pedido(
            restaurant_id=r_id,
            mesa_id=mesa_id,
            usuario_id=usuario_id,
            estado=EstadoPedido.borrador,
            total=0,
        )
        db_session.add(pedido)
        await db_session.commit()
        db_session.add(
            Calificacion(
                restaurant_id=r_id,
                usuario_id=usuario_id,
                pedido_id=pedido.id,
                estrellas=estrella,
            )
        )
        await db_session.commit()
    await db_session.rollback()
    db_session.expire_all()
    return r_id


async def _limpiar_restaurante_test(db_session, restaurante_id: int) -> None:
    """Cleanup TOTAL en orden FK inverso: calificacion → pedido → mesa →
    restaurante. Cada paso tolerante a fallo parcial (patrón conftest)."""
    await db_session.rollback()
    db_session.expire_all()

    async def _paso(query) -> None:
        try:
            await db_session.execute(query)
            await db_session.commit()
        except Exception:
            await db_session.rollback()

    await _paso(delete(Calificacion).where(Calificacion.restaurant_id == restaurante_id))
    await _paso(delete(Pedido).where(Pedido.restaurant_id == restaurante_id))
    await _paso(delete(Mesa).where(Mesa.restaurant_id == restaurante_id))
    await _paso(delete(Restaurante).where(Restaurante.id == restaurante_id))
    await db_session.rollback()


@pytest.mark.asyncio
async def test_list_avg_y_count(async_client, db_session):
    """CALI-02: calificaciones 5 y 4 → lista devuelve calificacion 4.5 y
    total_calificaciones 2."""
    r_id = await _sembrar_restaurante_con_calificaciones(db_session, [5, 4])
    try:
        resp = await async_client.get("/public/restaurantes")
        assert resp.status_code == 200
        item = next(x for x in resp.json() if x["id"] == r_id)
        assert item["calificacion"] == 4.5
        assert item["total_calificaciones"] == 2
    finally:
        await _limpiar_restaurante_test(db_session, r_id)


@pytest.mark.asyncio
async def test_list_redondeo_1_decimal(async_client, db_session):
    """CALI-02: promedio con decimales largos (5+4+4)/3 = 4.333... → 4.3
    (round a 1 decimal, no truncamiento)."""
    r_id = await _sembrar_restaurante_con_calificaciones(db_session, [5, 4, 4])
    try:
        resp = await async_client.get("/public/restaurantes")
        assert resp.status_code == 200
        item = next(x for x in resp.json() if x["id"] == r_id)
        assert item["calificacion"] == 4.3
        assert item["total_calificaciones"] == 3
    finally:
        await _limpiar_restaurante_test(db_session, r_id)


@pytest.mark.asyncio
async def test_sin_calificaciones_null_y_cero(async_client, db_session):
    """CALI-02: restaurante propio sin calificaciones → calificacion null y
    total_calificaciones 0 en lista Y detalle."""
    r_id = await _sembrar_restaurante_con_calificaciones(db_session, [])
    try:
        lista = await async_client.get("/public/restaurantes")
        assert lista.status_code == 200
        item = next(x for x in lista.json() if x["id"] == r_id)
        assert item["calificacion"] is None
        assert item["total_calificaciones"] == 0

        detalle = await async_client.get(f"/public/restaurantes/{r_id}")
        assert detalle.status_code == 200
        body = detalle.json()
        assert body["calificacion"] is None
        assert body["total_calificaciones"] == 0
    finally:
        await _limpiar_restaurante_test(db_session, r_id)


@pytest.mark.asyncio
async def test_detalle_avg_y_count(async_client, db_session):
    """CALI-02: el DETALLE también devuelve el agregado poblado (5+3)/2 = 4.0
    + total 2 (hereda del RestaurantePublico base)."""
    r_id = await _sembrar_restaurante_con_calificaciones(db_session, [5, 3])
    try:
        resp = await async_client.get(f"/public/restaurantes/{r_id}")
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == r_id
        assert body["calificacion"] == 4.0
        assert body["total_calificaciones"] == 2
        assert isinstance(body["categorias"], list)  # el menú sigue intacto
    finally:
        await _limpiar_restaurante_test(db_session, r_id)
