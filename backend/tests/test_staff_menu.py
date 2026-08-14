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
from sqlalchemy import delete, select
from uuid import uuid4

from app.models.menu import Categoria, Producto
from app.models.restaurante import Restaurante
from app.models.usuario import Usuario

from .conftest import auth_header, login, login_staff_demo


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


# --- Task 2: CRUD staff de menú — helpers --------------------------------------

_ADMIN_DEMO = "admin@demo.gri.dev"
_MESERO_DEMO = "mesero@demo.gri.dev"


async def create_restaurante_con_staff(
    client, super_admin_token: str, nombre_base: str
) -> tuple[int, str, str]:
    """POST /admin/restaurantes + /admin/restaurantes/{id}/staff (super_admin)
    → (restaurante_id, access_token del admin B, email del staff B).

    El CALLER es dueño del cleanup (delete user + restaurante por estos
    identificadores — orden FK: user antes que restaurante)."""
    suffix = uuid4().hex[:6]
    email = f"admin-{suffix}@x.com"
    password = "S3cret0!"
    sa = auth_header(super_admin_token)
    r1 = await client.post(
        "/admin/restaurantes",
        json={"nombre": f"{nombre_base} {suffix}"},
        headers=sa,
    )
    assert r1.status_code == 201, r1.text
    rid = r1.json()["id"]
    r2 = await client.post(
        f"/admin/restaurantes/{rid}/staff",
        json={
            "nombre": "Admin Tenant B",
            "email": email,
            "password": password,
            "role": "admin_restaurante",
        },
        headers=sa,
    )
    assert r2.status_code == 201, r2.text
    access, _ = await login(client, email, password)
    return rid, access, email


async def _delete_categoria(db_session, categoria_id: int | None) -> None:
    """Borra una categoría de test y sus productos (FK primero)."""
    if categoria_id is None:
        return
    await db_session.rollback()
    await db_session.execute(
        delete(Producto).where(Producto.categoria_id == categoria_id)
    )
    await db_session.execute(delete(Categoria).where(Categoria.id == categoria_id))
    await db_session.commit()


async def _delete_producto(db_session, producto_id: int | None) -> None:
    if producto_id is None:
        return
    await db_session.rollback()
    await db_session.execute(delete(Producto).where(Producto.id == producto_id))
    await db_session.commit()


async def _cleanup_tenant_b(
    db_session, staff_email: str, rid: int, categoria_ids: list[int]
) -> None:
    """Borra categorías creadas en B, luego el staff user y el restaurante
    (orden FK: user antes que restaurante — patrón _cleanup_tenant_2 de
    test_staff_reservas)."""
    await db_session.rollback()
    for cid in categoria_ids:
        await db_session.execute(
            delete(Producto).where(Producto.categoria_id == cid)
        )
    await db_session.execute(
        delete(Categoria).where(
            Categoria.restaurant_id == rid, Categoria.id.in_(categoria_ids)
        )
    )
    await db_session.execute(delete(Usuario).where(Usuario.email == staff_email))
    await db_session.execute(delete(Restaurante).where(Restaurante.id == rid))
    await db_session.commit()


# --- Task 2: POST/PATCH categorías ---------------------------------------------


@pytest.mark.asyncio
async def test_post_categoria_201_dup_409_mesero_403(async_client, db_session):
    """POST /staff/categorias como admin → 201 (id/orden/activo=True);
    nombre duplicado → 409; mesero → 403 (writes son solo admin/super)."""
    admin = await login_staff_demo(async_client, _ADMIN_DEMO)
    nombre = f"Cat Test {uuid4().hex[:6]}"
    cat_id = None
    try:
        resp = await async_client.post(
            "/staff/categorias",
            json={"nombre": nombre, "orden": 7},
            headers=auth_header(admin),
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["nombre"] == nombre
        assert body["orden"] == 7
        assert body["activo"] is True
        assert isinstance(body["id"], int)
        cat_id = body["id"]

        # Duplicado (mismo tenant, mismo nombre) → 409 amigable.
        dup = await async_client.post(
            "/staff/categorias",
            json={"nombre": nombre},
            headers=auth_header(admin),
        )
        assert dup.status_code == 409, dup.text

        # Mesero → 403 (require_roles admin_restaurante/super_admin).
        mesero = await login_staff_demo(async_client, _MESERO_DEMO)
        forb = await async_client.post(
            "/staff/categorias",
            json={"nombre": f"Otra {uuid4().hex[:6]}"},
            headers=auth_header(mesero),
        )
        assert forb.status_code == 403, forb.text
    finally:
        await _delete_categoria(db_session, cat_id)


@pytest.mark.asyncio
async def test_patch_categoria_toggle_activo_staff_ve_todo(
    async_client, db_session
):
    """PATCH /staff/categorias/{id}: toggle activo=False → el STAFF la sigue
    viendo en GET /staff/menu con su flag (ve TODO), pero /public la oculta.
    PATCH inexistente → 404."""
    admin = await login_staff_demo(async_client, _ADMIN_DEMO)
    nombre = f"Cat Toggle {uuid4().hex[:6]}"
    cat_id = None
    try:
        resp = await async_client.post(
            "/staff/categorias", json={"nombre": nombre}, headers=auth_header(admin)
        )
        assert resp.status_code == 201, resp.text
        cat_id = resp.json()["id"]

        toggled = await async_client.patch(
            f"/staff/categorias/{cat_id}",
            json={"activo": False},
            headers=auth_header(admin),
        )
        assert toggled.status_code == 200, toggled.text
        assert toggled.json()["activo"] is False

        menu = await async_client.get(
            "/staff/menu", headers=auth_header(admin)
        )
        assert menu.status_code == 200, menu.text
        cats = {c["id"]: c for c in menu.json()}
        assert cat_id in cats, "el STAFF ve categorías inactivas (con flag)"
        assert cats[cat_id]["activo"] is False

        public = await async_client.get("/public/restaurantes/1")
        assert cat_id not in {c["id"] for c in public.json()["categorias"]}, (
            "la categoría inactiva NO llega a /public"
        )

        missing = await async_client.patch(
            "/staff/categorias/999999999",
            json={"orden": 3},
            headers=auth_header(admin),
        )
        assert missing.status_code == 404, missing.text
    finally:
        await _delete_categoria(db_session, cat_id)


# --- Task 2: POST/PATCH productos ----------------------------------------------


@pytest.mark.asyncio
async def test_post_producto_201_precio_float_422_404(async_client, db_session):
    """POST /staff/productos → 201 con precio float; precio<=0 → 422;
    categoria_id inexistente → 404; mesero → 403."""
    admin = await login_staff_demo(async_client, _ADMIN_DEMO)
    cat_id = None
    try:
        cat = await async_client.post(
            "/staff/categorias",
            json={"nombre": f"Cat Prod {uuid4().hex[:6]}"},
            headers=auth_header(admin),
        )
        assert cat.status_code == 201, cat.text
        cat_id = cat.json()["id"]

        resp = await async_client.post(
            "/staff/productos",
            json={
                "categoria_id": cat_id,
                "nombre": "Producto Test 08",
                "descripcion": "Descripción de prueba",
                "precio": 25000.5,
                "imagen_url": "https://example.com/foto.jpg",
            },
            headers=auth_header(admin),
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["nombre"] == "Producto Test 08"
        assert body["precio"] == 25000.5
        assert isinstance(body["precio"], float), "precio viaja como JSON number"
        assert body["categoria_id"] == cat_id
        assert body["disponible"] is True and body["activo"] is True

        # Precio <= 0 → 422 (server-side, gt=0).
        for precio_malo in (0, -1):
            bad = await async_client.post(
                "/staff/productos",
                json={"categoria_id": cat_id, "nombre": "X", "precio": precio_malo},
                headers=auth_header(admin),
            )
            assert bad.status_code == 422, bad.text

        # Categoría inexistente → 404 (existence hiding).
        nf = await async_client.post(
            "/staff/productos",
            json={"categoria_id": 999999999, "nombre": "X", "precio": 1000},
            headers=auth_header(admin),
        )
        assert nf.status_code == 404, nf.text

        # Mesero → 403.
        mesero = await login_staff_demo(async_client, _MESERO_DEMO)
        forb = await async_client.post(
            "/staff/productos",
            json={"categoria_id": cat_id, "nombre": "Y", "precio": 1000},
            headers=auth_header(mesero),
        )
        assert forb.status_code == 403, forb.text
    finally:
        await _delete_categoria(db_session, cat_id)


@pytest.mark.asyncio
async def test_patch_producto_toggles_public_end_to_end(async_client, db_session):
    """PATCH producto: disponible=False (agotado) NO lo saca de /public (llega
    con su flag); activo=False SÍ lo saca. PATCH inexistente → 404."""
    admin = await login_staff_demo(async_client, _ADMIN_DEMO)
    cat_id = None
    prod_id = None

    async def _public_ids() -> dict[int, dict]:
        resp = await async_client.get("/public/restaurantes/1")
        assert resp.status_code == 200, resp.text
        return {
            p["id"]: p
            for c in resp.json()["categorias"]
            for p in c["productos"]
        }

    try:
        cat = await async_client.post(
            "/staff/categorias",
            json={"nombre": f"Cat Tog {uuid4().hex[:6]}"},
            headers=auth_header(admin),
        )
        assert cat.status_code == 201, cat.text
        cat_id = cat.json()["id"]
        prod = await async_client.post(
            "/staff/productos",
            json={"categoria_id": cat_id, "nombre": "Toggle Prod", "precio": 12300},
            headers=auth_header(admin),
        )
        assert prod.status_code == 201, prod.text
        prod_id = prod.json()["id"]

        # Agotado: SIGUE en /public con disponible=False.
        r1 = await async_client.patch(
            f"/staff/productos/{prod_id}",
            json={"disponible": False},
            headers=auth_header(admin),
        )
        assert r1.status_code == 200, r1.text
        assert r1.json()["disponible"] is False
        pub = await _public_ids()
        assert prod_id in pub and pub[prod_id]["disponible"] is False

        # Soft-delete: DESAPARECE de /public.
        r2 = await async_client.patch(
            f"/staff/productos/{prod_id}",
            json={"activo": False},
            headers=auth_header(admin),
        )
        assert r2.status_code == 200, r2.text
        assert r2.json()["activo"] is False
        pub = await _public_ids()
        assert prod_id not in pub, "activo=False saca el producto de /public"

        # Edición parcial (nombre + precio float) reactivándolo.
        r3 = await async_client.patch(
            f"/staff/productos/{prod_id}",
            json={"activo": True, "nombre": "Toggle Prod Editado", "precio": 15000.25},
            headers=auth_header(admin),
        )
        assert r3.status_code == 200, r3.text
        assert r3.json()["nombre"] == "Toggle Prod Editado"
        assert r3.json()["precio"] == 15000.25
        assert isinstance(r3.json()["precio"], float)

        missing = await async_client.patch(
            "/staff/productos/999999999",
            json={"disponible": True},
            headers=auth_header(admin),
        )
        assert missing.status_code == 404, missing.text
    finally:
        await _delete_producto(db_session, prod_id)
        await _delete_categoria(db_session, cat_id)


# --- Task 2: aislamiento cross-tenant + contrato super_admin --------------------


@pytest.mark.asyncio
async def test_cross_tenant_menu_crud(async_client, db_session, super_admin_token):
    """Existence hiding: staff B NO puede tocar categorías/productos de A
    (404 idéntico a inexistente); el unique de nombre es POR TENANT (mismo
    nombre en B → 201)."""
    admin = await login_staff_demo(async_client, _ADMIN_DEMO)
    rid_b, token_b, email_b = await create_restaurante_con_staff(
        async_client, super_admin_token, "Cross Menu"
    )
    cat_a_id = None
    cat_b_id = None
    prod_a_id = None
    try:
        nombre = f"Compartida {uuid4().hex[:6]}"
        cat_a = await async_client.post(
            "/staff/categorias", json={"nombre": nombre}, headers=auth_header(admin)
        )
        assert cat_a.status_code == 201, cat_a.text
        cat_a_id = cat_a.json()["id"]
        prod_a = await async_client.post(
            "/staff/productos",
            json={"categoria_id": cat_a_id, "nombre": "Prod A", "precio": 9000},
            headers=auth_header(admin),
        )
        assert prod_a.status_code == 201, prod_a.text
        prod_a_id = prod_a.json()["id"]

        # PATCH categoría de A con staff B → 404 (existence hiding).
        xb = await async_client.patch(
            f"/staff/categorias/{cat_a_id}",
            json={"orden": 9},
            headers=auth_header(token_b),
        )
        assert xb.status_code == 404, xb.text

        # PATCH producto de A con staff B → 404.
        xp = await async_client.patch(
            f"/staff/productos/{prod_a_id}",
            json={"disponible": False},
            headers=auth_header(token_b),
        )
        assert xp.status_code == 404, xp.text

        # POST producto en B apuntando a la categoría de A → 404 (ajena).
        xa = await async_client.post(
            "/staff/productos",
            json={"categoria_id": cat_a_id, "nombre": "Spoof", "precio": 100},
            headers=auth_header(token_b),
        )
        assert xa.status_code == 404, xa.text

        # El MISMO nombre de A en B → 201 (unique por tenant).
        same = await async_client.post(
            "/staff/categorias",
            json={"nombre": nombre},
            headers=auth_header(token_b),
        )
        assert same.status_code == 201, same.text
        cat_b_id = same.json()["id"]

        # Sanity: B ve SU categoría en su /staff/menu, no la de A.
        menu_b = await async_client.get(
            "/staff/menu", headers=auth_header(token_b)
        )
        assert menu_b.status_code == 200, menu_b.text
        ids_b = {c["id"] for c in menu_b.json()}
        assert cat_b_id in ids_b and cat_a_id not in ids_b
    finally:
        await _delete_producto(db_session, prod_a_id)
        await _delete_categoria(db_session, cat_a_id)
        await _cleanup_tenant_b(db_session, email_b, rid_b, [cat_b_id])


@pytest.mark.asyncio
async def test_super_admin_contract_menu(async_client, db_session, super_admin_token):
    """super_admin: POST/GET sin ?restaurante_id= → 400; con param → 201/200
    (patrón uniforme _resolve_rid — Pitfall 5)."""
    sa = auth_header(super_admin_token)
    cat_id = None
    try:
        sin = await async_client.post(
            "/staff/categorias",
            json={"nombre": f"SA {uuid4().hex[:6]}"},
            headers=sa,
        )
        assert sin.status_code == 400, sin.text

        con = await async_client.post(
            "/staff/categorias",
            params={"restaurante_id": 1},
            json={"nombre": f"SA {uuid4().hex[:6]}"},
            headers=sa,
        )
        assert con.status_code == 201, con.text
        cat_id = con.json()["id"]

        menu_sin = await async_client.get("/staff/menu", headers=sa)
        assert menu_sin.status_code == 400, menu_sin.text

        menu_con = await async_client.get(
            "/staff/menu", params={"restaurante_id": 1}, headers=sa
        )
        assert menu_con.status_code == 200, menu_con.text
        assert cat_id in {c["id"] for c in menu_con.json()}

        # Restaurante inexistente → 404.
        nf = await async_client.get(
            "/staff/menu", params={"restaurante_id": 999999}, headers=sa
        )
        assert nf.status_code == 404, nf.text
    finally:
        await _delete_categoria(db_session, cat_id)


@pytest.mark.asyncio
async def test_get_menu_mesero_200(async_client, db_session):
    """GET /staff/menu es un READ abierto a todo el staff (mesero → 200) con
    la shape anidada CategoriaStaff/ProductoStaff."""
    mesero = await login_staff_demo(async_client, _MESERO_DEMO)
    resp = await async_client.get("/staff/menu", headers=auth_header(mesero))
    assert resp.status_code == 200, resp.text
    cats = resp.json()
    assert isinstance(cats, list) and len(cats) >= 1
    by_nombre = {c["nombre"]: c for c in cats}
    assert "Entradas" in by_nombre, "la categoría seed aparece para el staff"
    entradas = by_nombre["Entradas"]
    assert entradas["activo"] is True
    assert isinstance(entradas["productos"], list)
    assert len(entradas["productos"]) >= 1
    prod = entradas["productos"][0]
    assert {"id", "categoria_id", "nombre", "precio", "disponible", "activo"} <= set(
        prod.keys()
    )
    assert isinstance(prod["precio"], float)
