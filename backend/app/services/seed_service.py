"""Seed del restaurante demo (Phase 3 Plan 02 — PLAT-04 + INFR-03).

Siembra el restaurante demo de la plataforma GRI con su menú, mesas, staff y
clientes demo. Diseñado para correr en el lifespan del API **después** de
``ensure_super_admin`` (que es el trust root) y solo cuando
``settings.DEMO_MODE=True``. El gate vive DENTRO de este service
(defense-in-depth — PITFALL 4: no confiar solo en el caller del lifespan).

Idempotencia (PITFALL 3): cada entidad se busca por su natural key ANTES de
insertar — email (usuarios), codigo_qr (mesas, unique global), nombre
(restaurante), (restaurant_id, nombre) (categoría), (restaurant_id,
categoria_id, nombre) (producto). Reiniciar el contenedor N veces deja
exactamente el mismo estado.

Atomicidad (PITFALL 6): un SOLO ``await session.commit()`` al final de
``seed_demo``. Los ``flush()`` intermedios asignan ids sin commit (necesario
para que los FKs dentro de la transacción resuelvan). Si algo falla a mitad
(p.ej. IntegrityError por un typo), la transacción se revierte completa — no
queda un restaurante sin menú ni mesas sin restaurante.

Contenido (prescrito en 03-RESEARCH.md "Pattern 4 > Contenido del seed"):
- Restaurante: "Restaurante Demo GRI" (activo=True → visible en list_restaurantes).
- Staff (3): admin/mesero/cocina @demo.gri.dev, password Demo!1234.
- Mesas (8): numeros 1-8, capacidades [2,2,4,4,4,6,6,8], QR GRI-MESA-001..008.
- Categorías (4): Entradas(1), Platos Fuertes(2), Bebidas(3), Postres(4).
- Productos (16): COP realistas, Decimal exacto (no float).
- Clientes (2): carlos@demo.gri.dev, maria@demo.gri.dev.

Emails usan @demo.gri.dev — .dev es gTLD real (a diferencia de .local que
email-validator rechaza; lección 02-02-SUMMARY).
"""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.menu import Categoria, Producto
from app.models.mesa import EstadoMesa, Mesa
from app.models.restaurante import Restaurante
from app.models.usuario import RolUsuario, Usuario

# --- Constantes módulo ----------------------------------------------------

DEMO_RESTAURANTE_NOMBRE = "Restaurante Demo GRI"
# Demo-only. DEMO_MODE=False en prod lo excluye completamente (PITFALLS
# Security: "Contraseñas de seed/demo en prod"). Cumple la policy de schemas
# (8+ chars, mayúscula, minúscula, dígito, símbolo).
DEMO_PASSWORD = "Demo!1234"

# Capacidades de las 8 mesas (índice 0 → mesa #1, ..., índice 7 → mesa #8).
_DEMO_MESA_CAPACIDADES = [2, 2, 4, 4, 4, 6, 6, 8]

# Categorías: (nombre, orden).
_DEMO_CATEGORIAS = [
    ("Entradas", 1),
    ("Platos Fuertes", 2),
    ("Bebidas", 3),
    ("Postres", 4),
]

# Productos: (categoría, nombre, descripción, precio COP como Decimal).
# Precios prescritos en 03-RESEARCH.md — COP realistas.
_DEMO_PRODUCTOS = [
    # Entradas (4)
    ("Entradas", "Patacón con Hogao", "Patacón crujiente con hogao casero", Decimal("12000.00")),
    ("Entradas", "Empanadas x3", "Tres empanadas de carne con ají", Decimal("9500.00")),
    ("Entradas", "Arepa Rellena", "Arepa rellena de queso y carne", Decimal("11000.00")),
    ("Entradas", "Sopita del Día", "Sopa tradicional de la casa", Decimal("14000.00")),
    # Platos Fuertes (5)
    ("Platos Fuertes", "Bandeja Paisa", "Bandeja paisa tradicional completa", Decimal("32000.00")),
    ("Platos Fuertes", "Ajiaco Santafereño", "Ajiaco bogotano con tres papas y guascas", Decimal("28000.00")),
    ("Platos Fuertes", "Lechona Tolimense", "Lechona tolimense con insulso y arepa", Decimal("30000.00")),
    ("Platos Fuertes", "Trout Moqueta", "Trucha con moqueta de frijoles", Decimal("34000.00")),
    ("Platos Fuertes", "Sancocho", "Sancocho trifásico de la casa", Decimal("26000.00")),
    # Bebidas (4)
    ("Bebidas", "Limonada de Coco", "Limonada de coco helada", Decimal("9000.00")),
    ("Bebidas", "Jugo Natural", "Jugo natural de fruta de la temporada", Decimal("8000.00")),
    ("Bebidas", "Gaseosa", "Gaseosa 350ml", Decimal("5500.00")),
    ("Bebidas", "Cerveza Artesanal", "Cerveza artesanal nacional", Decimal("12000.00")),
    # Postres (3)
    ("Postres", "Tres Leches", "Postre de tres leches", Decimal("9500.00")),
    ("Postres", "Flan de Coco", "Flan de coco con arequipe", Decimal("8500.00")),
    ("Postres", "Café con Leche", "Café con leche colombiano", Decimal("4500.00")),
]


# --- Gate (defense-in-depth) ---------------------------------------------


async def seed_if_demo_mode(session: AsyncSession) -> dict | None:
    """Gate del lifespan: no-op cuando ``settings.DEMO_MODE=False`` (SC2).

    El gate vive DENTRO del service — si un caller futuro se equivoca y llama
    ``seed_demo`` directamente sin checkear el flag, ese caller tiene la culpa.
    El service no siembra nada en prod aunque el caller se equivoque.
    """
    if not settings.DEMO_MODE:
        return None
    return await seed_demo(session)


# --- Helpers natural-key get-or-create -----------------------------------


async def _get_or_create_restaurante(
    session: AsyncSession, *, nombre: str, **kwargs
) -> Restaurante:
    """Natural key: nombre exacto (único semántico del restaurante demo)."""
    stmt = select(Restaurante).where(Restaurante.nombre == nombre)
    r = (await session.execute(stmt)).scalar_one_or_none()
    if r is not None:
        return r
    r = Restaurante(nombre=nombre, **kwargs)
    session.add(r)
    await session.flush()  # asigna id sin commit — permite FKs en la tx
    return r


async def _get_or_create_usuario(
    session: AsyncSession,
    *,
    email: str,
    nombre: str,
    role: RolUsuario,
    restaurant_id: int | None,
) -> Usuario:
    """Natural key: email (lower+strip — mismo patrón que admin_service.py).

    Previene duplicados por mayúsculas/espacios en restart reales.
    """
    normalized = email.lower().strip()
    stmt = select(Usuario).where(Usuario.email == normalized)
    user = (await session.execute(stmt)).scalar_one_or_none()
    if user is not None:
        return user
    user = Usuario(
        nombre=nombre,
        email=normalized,
        password_hash=hash_password(DEMO_PASSWORD),
        role=role,
        restaurant_id=restaurant_id,
    )
    session.add(user)
    await session.flush()
    return user


async def _get_or_create_mesa(
    session: AsyncSession,
    *,
    restaurant_id: int,
    numero: int,
    capacidad: int,
    codigo_qr: str,
) -> Mesa:
    """Natural key: codigo_qr (UNIQUE GLOBAL — el unique real está en esa
    columna, no en (restaurant_id, numero))."""
    stmt = select(Mesa).where(Mesa.codigo_qr == codigo_qr)
    mesa = (await session.execute(stmt)).scalar_one_or_none()
    if mesa is not None:
        return mesa
    mesa = Mesa(
        restaurant_id=restaurant_id,
        numero=numero,
        capacidad=capacidad,
        codigo_qr=codigo_qr,
        estado=EstadoMesa.disponible,
    )
    session.add(mesa)
    await session.flush()
    return mesa


async def _get_or_create_categoria(
    session: AsyncSession, *, restaurant_id: int, nombre: str, orden: int
) -> Categoria:
    """Natural key: (restaurant_id, nombre) — UNIQUE compuesto en BD."""
    stmt = select(Categoria).where(
        Categoria.restaurant_id == restaurant_id,
        Categoria.nombre == nombre,
    )
    cat = (await session.execute(stmt)).scalar_one_or_none()
    if cat is not None:
        return cat
    cat = Categoria(restaurant_id=restaurant_id, nombre=nombre, orden=orden)
    session.add(cat)
    await session.flush()
    return cat


async def _get_or_create_producto(
    session: AsyncSession,
    *,
    restaurant_id: int,
    categoria_id: int,
    nombre: str,
    descripcion: str | None,
    precio: Decimal,
) -> Producto:
    """Natural key: (restaurant_id, categoria_id, nombre). No hay unique
    declarado en BD, pero el seed lo garantiza por construcción."""
    stmt = select(Producto).where(
        Producto.restaurant_id == restaurant_id,
        Producto.categoria_id == categoria_id,
        Producto.nombre == nombre,
    )
    p = (await session.execute(stmt)).scalar_one_or_none()
    if p is not None:
        return p
    p = Producto(
        restaurant_id=restaurant_id,
        categoria_id=categoria_id,
        nombre=nombre,
        descripcion=descripcion,
        precio=Decimal(precio),
        imagen_url=None,  # v1: StaticFiles local en Phase 8
        disponible=True,
    )
    session.add(p)
    await session.flush()
    return p


# --- Orquestación --------------------------------------------------------


async def seed_demo(session: AsyncSession) -> dict:
    """Siembra el restaurante demo completo (PLAT-04).

    Patrón (anti-PITFALL 6):
    1. Restaurante → flush (id asignado).
    2. 3 staff → flush.
    3. 8 mesas → flush.
    4. 4 categorías → flush (capturar para usar IDs en productos).
    5. 16 productos COP → flush.
    6. 2 clientes → flush.
    7. UN commit al final (atomicidad — o todo se siembra o nada).

    Retorna un dict resumen con counts para logs del lifespan.
    """
    # 1. Restaurante demo.
    restaurante = await _get_or_create_restaurante(
        session,
        nombre=DEMO_RESTAURANTE_NOMBRE,
        descripcion="Restaurante de demostración de la plataforma GRI.",
        tipo_cocina="Colombiana",
        direccion="Cra. 7 #63-44, Bogotá",
        activo=True,
    )
    await session.flush()

    # 2. Staff: admin, mesero, cocina atados al restaurante demo.
    await _get_or_create_usuario(
        session,
        email="admin@demo.gri.dev",
        nombre="Admin Demo",
        role=RolUsuario.admin_restaurante,
        restaurant_id=restaurante.id,
    )
    await _get_or_create_usuario(
        session,
        email="mesero@demo.gri.dev",
        nombre="Mesero Demo",
        role=RolUsuario.mesero,
        restaurant_id=restaurante.id,
    )
    await _get_or_create_usuario(
        session,
        email="cocina@demo.gri.dev",
        nombre="Cocina Demo",
        role=RolUsuario.cocina,
        restaurant_id=restaurante.id,
    )
    await session.flush()

    # 3. 8 mesas: numeros 1-8, capacidades prescritas, QR GRI-MESA-001..008.
    for idx, capacidad in enumerate(_DEMO_MESA_CAPACIDADES, start=1):
        await _get_or_create_mesa(
            session,
            restaurant_id=restaurante.id,
            numero=idx,
            capacidad=capacidad,
            codigo_qr=f"GRI-MESA-{idx:03d}",
        )
    await session.flush()

    # 4. 4 categorías — capturar objetos para usar categoria_id en productos.
    categoria_por_nombre: dict[str, Categoria] = {}
    for nombre, orden in _DEMO_CATEGORIAS:
        categoria_por_nombre[nombre] = await _get_or_create_categoria(
            session,
            restaurant_id=restaurante.id,
            nombre=nombre,
            orden=orden,
        )
    await session.flush()

    # 5. 16 productos COP — precios Decimal exactos del research.
    for cat_nombre, prod_nombre, prod_desc, prod_precio in _DEMO_PRODUCTOS:
        await _get_or_create_producto(
            session,
            restaurant_id=restaurante.id,
            categoria_id=categoria_por_nombre[cat_nombre].id,
            nombre=prod_nombre,
            descripcion=prod_desc,
            precio=prod_precio,
        )
    await session.flush()

    # 6. 2 clientes demo — cross-tenant (restaurant_id=None).
    await _get_or_create_usuario(
        session,
        email="carlos@demo.gri.dev",
        nombre="Carlos Cliente",
        role=RolUsuario.cliente,
        restaurant_id=None,
    )
    await _get_or_create_usuario(
        session,
        email="maria@demo.gri.dev",
        nombre="María Cliente",
        role=RolUsuario.cliente,
        restaurant_id=None,
    )

    # 7. Atomicidad: un solo commit al final.
    await session.commit()

    # Resumen para logs del lifespan (todos los counts son del 1-set demo).
    return {
        "restaurante": 1,
        "staff": 3,
        "mesas": 8,
        "categorias": 4,
        "productos": len(_DEMO_PRODUCTOS),  # 16
        "clientes": 2,
    }
