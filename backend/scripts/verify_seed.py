"""Verificación end-to-end del seed demo (Phase 3 Plan 02 — INFR-03/PLAT-04).

Invocado por ``scripts/verify_seed.sh`` DENTRO del contenedor api. Como el
container no tiene cliente mysql pero SÍ tiene SQLAlchemy + asyncmy, todos los
queries van por Python contra la misma BD del stack.

Estructura (8 secciones, imprimidas con echo para parseo humano):
1. Restaurante demo existe (1 fila).
2. 8 mesas con QR GRI-MESA-00X únicas.
3. 4 categorías.
4. 16 productos COP (>=15) + tabla de Platos Fuertes.
5. 3 staff + 2 clientes demo (5 filas @demo.gri.dev).
6. Captura counts PRE-restart.
7. Re-corre el seed (lo que el lifespan hace en cada docker restart).
8. Counts POST-restart idénticos (idempotencia INFR-03).

Exit code 0 + "ALL CHECKS PASSED" en stdout = éxito.
"""

import asyncio
import sys

from sqlalchemy import text

from app.core.db import async_session_maker
from app.services.seed_service import seed_if_demo_mode

BOLD = "\033[1m"
RESET = "\033[0m"


def section(n: int, title: str) -> None:
    print(f"== {n}. {title} ==")


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


async def scalar(session, sql: str) -> int:
    """Ejecuta un SELECT COUNT(*) y devuelve el entero."""
    return (await session.execute(text(sql))).scalar()


async def rows(session, sql: str) -> list:
    """Ejecuta un SELECT y devuelve las filas como lista de tuplas."""
    return [tuple(r) for r in (await session.execute(text(sql))).all()]


async def main() -> None:
    async with async_session_maker() as session:
        # ---- 1. Restaurante demo existe ----
        section(1, "Restaurante demo existe")
        rest_count = await scalar(
            session,
            "SELECT COUNT(*) FROM restaurante WHERE nombre='Restaurante Demo GRI'",
        )
        print(f"   restaurante demo filas: {rest_count}")
        if rest_count != 1:
            fail(f"esperaba 1 restaurante demo, encontre {rest_count}")
        for row in await rows(
            session,
            "SELECT id, nombre, tipo_cocina, activo FROM restaurante "
            "WHERE nombre='Restaurante Demo GRI'",
        ):
            print(f"   {row}")

        # ---- 2. 8 mesas con QR GRI-MESA-00X únicas ----
        section(2, "8 mesas con QR GRI-MESA-00X unicas")
        mesas_count = await scalar(
            session, "SELECT COUNT(*) FROM mesa WHERE codigo_qr LIKE 'GRI-MESA-%'"
        )
        print(f"   mesas demo filas: {mesas_count}")
        if mesas_count != 8:
            fail(f"esperaba 8 mesas demo, encontre {mesas_count}")
        for row in await rows(
            session,
            "SELECT codigo_qr, numero, capacidad, estado FROM mesa "
            "WHERE codigo_qr LIKE 'GRI-MESA-%' ORDER BY numero",
        ):
            print(f"   {row}")

        # ---- 3. 4 categorías ----
        section(3, "4 categorias")
        # Filtramos por nombre IN (demo) porque el stack Docker acumula
        # categorias cat-XXXXXX de test_domain_constraints.py que se adjuntan
        # al primer restaurante (que es el demo).
        cat_count = await scalar(
            session,
            "SELECT COUNT(*) FROM categoria c JOIN restaurante r "
            "ON c.restaurant_id=r.id WHERE r.nombre='Restaurante Demo GRI' "
            "AND c.nombre IN ('Entradas', 'Platos Fuertes', 'Bebidas', 'Postres')",
        )
        print(f"   categorias demo filas: {cat_count}")
        if cat_count != 4:
            fail(f"esperaba 4 categorias, encontre {cat_count}")

        # ---- 4. 16 productos COP (>=15) ----
        section(4, "16 productos COP (>=15)")
        # Filtramos por categoria nombre IN (demo) para excluir productos
        # prod-XXXXXX de test_domain_constraints.py.
        prod_count = await scalar(
            session,
            "SELECT COUNT(*) FROM producto p "
            "JOIN categoria c ON p.categoria_id=c.id "
            "JOIN restaurante r ON p.restaurant_id=r.id "
            "WHERE r.nombre='Restaurante Demo GRI' "
            "AND c.nombre IN ('Entradas', 'Platos Fuertes', 'Bebidas', 'Postres')",
        )
        print(f"   productos demo filas: {prod_count}")
        if prod_count < 15:
            fail(f"esperaba >= 15 productos, encontre {prod_count}")
        print("   Platos Fuertes del menu (precio DESC):")
        for row in await rows(
            session,
            "SELECT p.nombre, p.precio FROM producto p "
            "JOIN categoria c ON p.categoria_id=c.id "
            "JOIN restaurante r ON p.restaurant_id=r.id "
            "WHERE r.nombre='Restaurante Demo GRI' AND c.nombre='Platos Fuertes' "
            "ORDER BY p.precio DESC",
        ):
            print(f"   {row}")

        # ---- 5. 3 staff + 2 clientes demo (5 filas) ----
        section(5, "3 staff + 2 clientes demo (5 filas)")
        demo_users = await scalar(
            session, "SELECT COUNT(*) FROM usuario WHERE email LIKE '%@demo.gri.dev'"
        )
        print(f"   usuarios demo filas: {demo_users}")
        if demo_users != 5:
            fail(f"esperaba 5 usuarios demo, encontre {demo_users}")
        for row in await rows(
            session,
            "SELECT email, role FROM usuario "
            "WHERE email LIKE '%@demo.gri.dev' ORDER BY email",
        ):
            print(f"   {row}")

        # ---- 6. Captura counts PRE-restart ----
        section(6, "Captura counts PRE-restart (re-seed)")
        mesas_before = await scalar(
            session, "SELECT COUNT(*) FROM mesa WHERE codigo_qr LIKE 'GRI-MESA-%'"
        )
        productos_before = await scalar(
            session,
            "SELECT COUNT(*) FROM producto p JOIN restaurante r "
            "ON p.restaurant_id=r.id WHERE r.nombre='Restaurante Demo GRI'",
        )
        demo_users_before = await scalar(
            session, "SELECT COUNT(*) FROM usuario WHERE email LIKE '%@demo.gri.dev'"
        )
        print(
            f"   mesas={mesas_before} productos={productos_before} "
            f"demo_users={demo_users_before}"
        )

    # ---- 7. Re-corre el seed (lo que el lifespan hace en cada docker restart) ----
    # Sesión nueva — simula un boot fresco del contenedor.
    section(7, "Re-corre el seed (lo que el lifespan hace en cada docker restart)")
    async with async_session_maker() as session:
        await seed_if_demo_mode(session)
    print("   seed re-corrido sin errores")

    # ---- 8. Counts POST-restart idénticos (idempotencia INFR-03) ----
    section(8, "Counts POST-restart identicos (idempotencia INFR-03)")
    async with async_session_maker() as session:
        mesas_after = await scalar(
            session, "SELECT COUNT(*) FROM mesa WHERE codigo_qr LIKE 'GRI-MESA-%'"
        )
        productos_after = await scalar(
            session,
            "SELECT COUNT(*) FROM producto p JOIN restaurante r "
            "ON p.restaurant_id=r.id WHERE r.nombre='Restaurante Demo GRI'",
        )
        demo_users_after = await scalar(
            session,
            "SELECT COUNT(*) FROM usuario WHERE email LIKE '%@demo.gri.dev'",
        )
    print(
        f"   mesas={mesas_after} productos={productos_after} "
        f"demo_users={demo_users_after}"
    )

    if mesas_before != mesas_after:
        fail(f"mesas cambiaron {mesas_before} -> {mesas_after}")
    if productos_before != productos_after:
        fail(f"productos cambiaron {productos_before} -> {productos_after}")
    if demo_users_before != demo_users_after:
        fail(f"demo_users cambiaron {demo_users_before} -> {demo_users_after}")

    # Verificación adicional recomendada (desde el host, no dentro del contenedor):
    #   docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri \
    #     -e "SELECT COUNT(*) FROM mesa WHERE codigo_qr LIKE 'GRI-MESA-%';"  # capturar
    #   docker restart gri-api && sleep 12
    #   docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri \
    #     -e "SELECT COUNT(*) FROM mesa WHERE codigo_qr LIKE 'GRI-MESA-%';"  # comparar
    # Esta verificación con restart real la ejecuta el executor (ver SUMMARY.md).
    #
    # El marker "ALL CHECKS PASSED" lo emite verify_seed.sh (caller) al
    # confirmar que este script exits 0.


if __name__ == "__main__":
    asyncio.run(main())
