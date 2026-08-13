"""Tests DB-directos del seed demo (Phase 3 Plan 02 — PLAT-04 + INFR-03).

Validan:
- Contenido sembrado: restaurante + 3 staff + 8 mesas + 4 categorías + ~16
  productos COP + 2 clientes.
- Idempotencia: correr ``seed_demo`` 2 (o N) veces deja el mismo estado.
- Gate ``DEMO_MODE`` dentro del service (no solo en el caller del lifespan):
  False → no crea filas nuevas; True → siembra.

Estos tests NO van por HTTP (no hay endpoints para disparar el seed desde la
API): usan ``db_session`` directo + ``monkeypatch`` para alternar
``settings.DEMO_MODE`` sin tocar ``.env``.
"""

import re
from decimal import Decimal

from sqlalchemy import func, select

from app.core.config import settings
from app.models.mesa import Mesa
from app.models.menu import Categoria, Producto
from app.models.restaurante import Restaurante
from app.models.usuario import RolUsuario, Usuario
from app.services.seed_service import seed_demo, seed_if_demo_mode


# --- Contenido sembrado (PLAT-04) ----------------------------------------


async def test_seed_crea_demo(db_session):
    """seed_demo siembra restaurante + 3 staff + 8 mesas + 4 categorías + ≥15
    productos + 2 clientes. Las 8 mesas cumplen el patrón GRI-MESA-\\d{3}."""
    resumen = await seed_demo(db_session)

    assert resumen["restaurante"] == 1
    assert resumen["staff"] == 3
    assert resumen["mesas"] == 8
    assert resumen["categorias"] == 4
    assert resumen["productos"] >= 15
    assert resumen["clientes"] == 2

    # Restaurante demo existe.
    restaurante = (
        await db_session.execute(
            select(Restaurante).where(Restaurante.nombre == "Restaurante Demo GRI")
        )
    ).scalar_one()
    assert restaurante.activo is True
    restaurante_id = restaurante.id

    # Las 8 mesas cumplen el patrón GRI-MESA-\d{3}$. Filtramos por codigo_qr
    # (no solo restaurant_id) porque test_domain_constraints.py crea mesas de
    # prueba GRI-TEST-* que se adjuntan al primer restaurante (que es el demo).
    mesas = (
        await db_session.execute(
            select(Mesa)
            .where(
                Mesa.restaurant_id == restaurante_id,
                Mesa.codigo_qr.like("GRI-MESA-%"),
            )
            .order_by(Mesa.numero)
        )
    ).scalars().all()
    assert len(mesas) == 8
    patron = re.compile(r"^GRI-MESA-\d{3}$")
    for m in mesas:
        assert patron.match(m.codigo_qr), f"QR fuera de patrón: {m.codigo_qr}"

    # Admin demo existe, role admin_restaurante, atado al restaurante demo.
    admin = (
        await db_session.execute(
            select(Usuario).where(Usuario.email == "admin@demo.gri.dev")
        )
    ).scalar_one()
    assert admin.role == RolUsuario.admin_restaurante
    assert admin.restaurant_id == restaurante_id


async def test_seed_crea_menu_cop(db_session):
    """El menú COP prescrito en el research: Bandeja Paisa $32.000, la
    categoría Platos Fuertes existe, y cada categoría tiene ≥1 producto."""
    await seed_demo(db_session)

    # Snapshot de precio exacto (Decimal, no float — asyncmy devuelve Decimal).
    bandeja = (
        await db_session.execute(
            select(Producto).where(Producto.nombre == "Bandeja Paisa")
        )
    ).scalar_one()
    assert bandeja.precio == Decimal("32000.00")

    # Restaurante demo (para acotar los counts al tenant demo).
    restaurante = (
        await db_session.execute(
            select(Restaurante).where(Restaurante.nombre == "Restaurante Demo GRI")
        )
    ).scalar_one()

    # Categoría Platos Fuertes existe.
    fuerte = (
        await db_session.execute(
            select(Categoria).where(
                Categoria.restaurant_id == restaurante.id,
                Categoria.nombre == "Platos Fuertes",
            )
        )
    ).scalar_one()
    assert fuerte.orden == 2

    # Las 4 categorías del demo existen, acotadas por (restaurant_id, nombre IN
    # demo) — el BD del stack Docker acumula datos de tests anteriores
    # (test_domain_constraints.py crea categorias cat-XXXXXX en el primer
    # restaurante, que es el demo).
    demo_nombres = {"Entradas", "Platos Fuertes", "Bebidas", "Postres"}
    categorias = (
        await db_session.execute(
            select(Categoria).where(
                Categoria.restaurant_id == restaurante.id,
                Categoria.nombre.in_(demo_nombres),
            )
        )
    ).scalars().all()
    assert len(categorias) == 4
    for cat in categorias:
        n = (
            await db_session.execute(
                select(func.count())
                .select_from(Producto)
                .where(Producto.categoria_id == cat.id)
            )
        ).scalar_one()
        assert n >= 1, f"categoría '{cat.nombre}' sin productos"


# --- Idempotencia (PITFALL 3 + INFR-03) ----------------------------------


async def test_seed_idempotente(db_session):
    """Correr seed_demo 2 veces deja el mismo estado (restart-safe).

    El test que garantiza INFR-03: reiniciar el contenedor N veces no
    duplica filas ni rompe el boot con IntegrityError.
    """
    await seed_demo(db_session)

    mesas_1 = (
        await db_session.execute(select(func.count()).select_from(Mesa))
    ).scalar_one()
    productos_1 = (
        await db_session.execute(select(func.count()).select_from(Producto))
    ).scalar_one()
    demo_users_1 = (
        await db_session.execute(
            select(func.count())
            .select_from(Usuario)
            .where(Usuario.email.like("%@demo.gri.dev"))
        )
    ).scalar_one()

    # Segunda pasada — no duplica.
    await seed_demo(db_session)

    mesas_2 = (
        await db_session.execute(select(func.count()).select_from(Mesa))
    ).scalar_one()
    productos_2 = (
        await db_session.execute(select(func.count()).select_from(Producto))
    ).scalar_one()
    demo_users_2 = (
        await db_session.execute(
            select(func.count())
            .select_from(Usuario)
            .where(Usuario.email.like("%@demo.gri.dev"))
        )
    ).scalar_one()

    assert mesas_1 == mesas_2, f"mesas cambiaron {mesas_1} -> {mesas_2}"
    assert productos_1 == productos_2
    assert demo_users_1 == demo_users_2


async def test_seed_idempotente_tras_usuarios_ya_existentes(db_session):
    """Edge case: si los usuarios admin/mesero/cocina/cliente ya existen
    (sembrados por un test anterior), seed_demo no falla y retorna los
    mismos counts — caso real en restart del contenedor."""
    # Primera pasada — siembra todo.
    resumen_1 = await seed_demo(db_session)
    # Segunda pasada — usuarios ya existen.
    resumen_2 = await seed_demo(db_session)

    assert resumen_1 == resumen_2


# --- Gate DEMO_MODE (SC2 — PITFALL 4) ------------------------------------


async def test_demo_mode_false_no_siembra(db_session, monkeypatch):
    """SC2: con DEMO_MODE=False el gate dentro del service retorna None y no
    crea ninguna fila nueva (defense-in-depth — no confiar solo en el caller)."""
    monkeypatch.setattr(settings, "DEMO_MODE", False)

    before = (
        await db_session.execute(
            select(func.count())
            .select_from(Restaurante)
            .where(Restaurante.nombre == "Restaurante Demo GRI")
        )
    ).scalar_one()

    resultado = await seed_if_demo_mode(db_session)

    assert resultado is None

    after = (
        await db_session.execute(
            select(func.count())
            .select_from(Restaurante)
            .where(Restaurante.nombre == "Restaurante Demo GRI")
        )
    ).scalar_one()
    assert after == before, "DEMO_MODE=False no debe crear filas nuevas"


async def test_demo_mode_true_siembra(db_session, monkeypatch):
    """SC2 dirección opuesta: con DEMO_MODE=True el gate delega en seed_demo
    y retorna un resumen con counts correctos."""
    monkeypatch.setattr(settings, "DEMO_MODE", True)

    resultado = await seed_if_demo_mode(db_session)

    assert resultado is not None
    assert resultado["mesas"] == 8
    assert resultado["categorias"] == 4
    assert resultado["productos"] >= 15
