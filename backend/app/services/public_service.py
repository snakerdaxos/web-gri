"""Public read services — restaurante discovery + menú detalle (REST-01/02).

No auth, no tenant filter — these endpoints are open to the world (Phase 5
Open Question 4: rate-limiting deferred to Phase 9). They only expose the
``activo=True`` subset; inactive restaurantes are 404 (existence hiding, even
on public endpoints — a scraper cannot enumerate which IDs are inactive).

The menú detalle uses 3 separate queries (restaurante, categorias, productos)
grouped in Python — NO N+1, no eager-load gymnastics. With ~4 categorias and
~16 productos in the demo, this is the simplest correct shape.

Phase 9 (CALI-02): the aggregate de calificaciones (AVG round 1 decimal +
COUNT) se resuelve con UNA query extra ``GROUP BY restaurant_id`` para toda
la lista — sin N+1 por restaurante. /public expone SOLO avg y count; jamás
comentarios ni usuarios (T-09-04 — los comentarios son solo del restaurante).
"""

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.calificacion import Calificacion
from app.models.menu import Categoria, Producto
from app.models.restaurante import Restaurante
from app.schemas.menu import (
    CategoriaConProductos,
    ProductoRead,
    RestauranteDetalle,
    RestaurantePublico,
)

# (avg redondeado a 1 decimal | None, count) por restaurant_id.
Rating = tuple[float | None, int]


async def _ratings_por_restaurante(
    session: AsyncSession, ids: list[int]
) -> dict[int, Rating]:
    """UNA query GROUP BY para todos los ids (sin N+1). Restaurantes sin
    calificaciones quedan AUSENTES del dict → el caller aplica (None, 0)."""
    if not ids:
        return {}
    rows = (
        await session.execute(
            select(
                Calificacion.restaurant_id,
                func.avg(Calificacion.estrellas),
                func.count(Calificacion.id),
            )
            .where(Calificacion.restaurant_id.in_(ids))
            .group_by(Calificacion.restaurant_id)
        )
    ).all()
    return {
        restaurant_id: (round(float(avg), 1), int(count))
        for restaurant_id, avg, count in rows
    }


def _to_public(r: Restaurante, rating: Rating = (None, 0)) -> RestaurantePublico:
    avg, total = rating
    return RestaurantePublico(
        id=r.id,
        nombre=r.nombre,
        tipo_cocina=r.tipo_cocina,
        descripcion=r.descripcion,
        direccion=r.direccion,
        calificacion=avg,
        total_calificaciones=total,
    )


async def list_public_restaurantes(
    session: AsyncSession,
) -> list[RestaurantePublico]:
    """Active restaurantes, ordered by id (REST-01). No pagination — Phase 5
    ships with 1 demo restaurante; the handful max never justifies the
    pagination complexity."""
    stmt = (
        select(Restaurante)
        .where(Restaurante.activo.is_(True))
        .order_by(Restaurante.id)
    )
    rows = (await session.execute(stmt)).scalars().all()
    ratings = await _ratings_por_restaurante(session, [r.id for r in rows])
    return [_to_public(r, ratings.get(r.id, (None, 0))) for r in rows]


async def get_public_restaurante_detalle(
    session: AsyncSession, restaurante_id: int
) -> RestauranteDetalle:
    """Restaurante + nested menú (REST-02). 404 if unknown or inactive —
    existence hiding applies even on public endpoints (a scraper cannot tell
    'does not exist' from 'inactive')."""
    r = await session.get(Restaurante, restaurante_id)
    if r is None or not r.activo:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "Restaurante no encontrado"
        )

    # 3 queries total — no N+1.
    # Filtro ``activo`` (migración 0005): solo categorías/productos activos
    # llegan al cliente. ``disponible`` (agotado) NO se filtra — viaja como
    # flag (behavior F5; soft-delete ≠ agotado).
    cat_rows = (
        await session.execute(
            select(Categoria)
            .where(Categoria.restaurant_id == r.id, Categoria.activo.is_(True))
            .order_by(Categoria.orden, Categoria.id)
        )
    ).scalars().all()

    prod_rows = (
        await session.execute(
            select(Producto)
            .where(Producto.restaurant_id == r.id, Producto.activo.is_(True))
            .order_by(Producto.categoria_id, Producto.nombre)
        )
    ).scalars().all()

    # Group productos by categoria_id in Python.
    by_cat: dict[int, list[ProductoRead]] = {}
    for p in prod_rows:
        by_cat.setdefault(p.categoria_id, []).append(ProductoRead.model_validate(p))

    categorias = [
        CategoriaConProductos(
            id=c.id,
            nombre=c.nombre,
            orden=c.orden,
            productos=by_cat.get(c.id, []),
        )
        for c in cat_rows
    ]

    ratings = await _ratings_por_restaurante(session, [r.id])
    base = _to_public(r, ratings.get(r.id, (None, 0)))
    return RestauranteDetalle(**base.model_dump(), categorias=categorias)
