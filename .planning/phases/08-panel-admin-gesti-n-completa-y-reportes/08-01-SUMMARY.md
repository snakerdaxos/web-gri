---
phase: 08-panel-admin-gesti-n-completa-y-reportes
plan: "01"
subsystem: backend
tags: [menu-crud, clientes, soft-delete, tenant-isolation, alembic]
requires:
  - "Migración 0004 (pedido.sesion_id + sesión QR — fixtures de clientes usan API F6)"
  - "_resolve_rid + get_tenant_scope + require_roles (deps/auth, F2/F4)"
  - "Seed demo rid=1 (4 categorías, 16 productos, staff Demo!1234)"
provides:
  - "Migración 0005: categoria.activo + producto.activo (Boolean NOT NULL server_default true)"
  - "GET /staff/menu — menú completo del tenant con flags activo/disponible (staff ve TODO)"
  - "POST/PATCH /staff/categorias + POST/PATCH /staff/productos (writes admin/super_admin)"
  - "GET /staff/clientes — JOIN pedido→usuario con num_pedidos/total_gastado/ultimo_pedido_at"
  - "GET /staff/clientes/{usuario_id}/historial — PedidoStaffRead reusado (F6), 404 existence hiding relacional"
  - "Schemas: CategoriaStaff, ProductoStaff, CategoriaCreate/Update, ProductoCreate/Update, ClienteResumen"
affects:
  - "public_service.get_public_restaurante_detalle (ahora filtra activo en categorías y productos)"
  - "Plan 08-04 (panel: pantallas menú/clientes consumen estos 7 endpoints)"
tech-stack:
  added: []  # cero deps nuevas Python (decisión del plan cumplida)
  patterns:
    - "soft-delete activo ≠ disponible (agotado) — dos columnas, dos semánticas"
    - "agregación SQL GROUP BY + JOIN (clientes) con Decimal→float field_serializer (Pitfall 1)"
    - "pre-check 409 amigable + except IntegrityError como red de seguridad (Pitfall 7)"
key-files:
  created:
    - backend/alembic/versions/0005_menu_activo.py
    - backend/app/schemas/cliente.py
    - backend/tests/test_staff_menu.py
    - backend/tests/test_staff_clientes.py
  modified:
    - backend/app/models/menu.py
    - backend/app/services/public_service.py
    - backend/app/schemas/menu.py
    - backend/app/api/staff.py
    - backend/app/services/staff_service.py
decisions:
  - "activo (soft-delete, desaparece de /public) vs disponible (agotado transitorio, SIGUE visible con flag) — columnas separadas, public_service filtra SOLO activo"
  - "list_clientes cuenta TODOS los estados de pedido (comportamiento del cliente ≠ facturación; REPO-01 filtra servido|pagado en su propio endpoint)"
  - "cliente del restaurante = usuario CON pedidos en el tenant (JOIN); quien solo reservó NO aparece (decisión v1 del research)"
  - "historial vacío → 404 'Cliente no encontrado' (existence hiding relacional — no revela que el usuario_id existe globalmente)"
metrics:
  duration: "~50 min (2026-08-14)"
  tests: "155 → 169 (+9 test_staff_menu, +5 test_staff_clientes), 2 runs consecutivos verdes"
  completed: 2026-08-14
---

# Phase 8 Plan 01: Backend menú CRUD + clientes Summary

**One-liner:** Migración 0005 (soft-delete `activo` en categoria/producto con menú público filtrando inactivos), CRUD staff de menú tenant-scoped (409 dup nombre, 422 precio≤0, 404 existence hiding) y clientes del restaurante vía JOIN pedido→usuario con historial reusando PedidoStaffRead — suite 155 → 169.

## Tasks Completed

| # | Task | Commit | Verificación |
|---|------|--------|--------------|
| 1 | Migración 0005 (categoria.activo + producto.activo) + filtro menú público | `0ec0ddf` (RED) + `932f7b8` (GREEN) | `alembic current` = 0005_menu_activo; 2 tests nuevos + test_public_read sin regresiones |
| 2 | CRUD staff menú: GET /staff/menu + POST/PATCH categorías y productos | `f725f38` (RED) + `0f3f023` (GREEN) | 9/9 test_staff_menu; suite 164; toggles verificados end-to-end contra /public |
| 3 | Clientes + historial (JOIN por pedidos) | `2254f85` (RED) + `47aaf3d` (GREEN) | 5/5 test_staff_clientes; suite 169 × 2 runs; mesa 2 disponible al terminar (invariante restaurado vía API) |

## What Was Built

### Migración 0005 (`0005_menu_activo.py`)
- `categoria.activo` y `producto.activo` — `sa.Boolean` NOT NULL `server_default=sa.text("1")` (gotcha STATE: `sa.true_()` no existe top-level en SA 2.0; `sa.text("1")` backfilla el demo en el mismo ALTER).
- `down_revision = "0004"` (revision id exacto de 0004, verificado). Downgrade espejo en orden inverso.

### Menú público (public_service)
- `get_public_restaurante_detalle` filtra `Categoria.activo.is_(True)` y `Producto.activo.is_(True)`. **Cero cambios en el manejo de `disponible`** — un agotado sigue llegando al cliente con su flag (semántica F5 intacta, verificada por test).

### 5 endpoints de menú (MENU-01/02)
- `GET /staff/menu` → `list[CategoriaStaff]` anidado con productos — INCLUYE inactivos y agotados con flags (el staff ve TODO; /public filtra). Read abierto a todo el staff.
- `POST /staff/categorias` (201) / `PATCH /staff/categorias/{id}` — 409 nombre dup por tenant (pre-check + `IntegrityError`→409 como red de seguridad, Pitfall 7); toggle `activo` verificado contra /public.
- `POST /staff/productos` (201) / `PATCH /staff/productos/{id}` — 422 precio≤0 (`gt=0` server-side), 404 categoría inexistente/ajena, `Decimal(str(precio))` exacto, respuesta `precio` float (Pitfall 3).
- Los 4 writes con `require_roles(admin_restaurante, super_admin)` — mesero/cocina → 403. Contrato super_admin (400 sin `?restaurante_id=`) en todos vía `_resolve_rid` primera línea.

### 2 endpoints de clientes (ADMN-03)
- `GET /staff/clientes` — `SELECT Usuario.id/nombre/email, COUNT(pedido), SUM(total), MAX(created_at) JOIN pedido WHERE pedido.restaurant_id = rid GROUP BY usuario ORDER BY SUM DESC`. `total_gastado` float via `field_serializer` (Pitfall 1). Jamás expone la tabla global de usuarios.
- `GET /staff/clientes/{usuario_id}/historial` — pedidos del usuario EN el tenant (todos los estados, newest first) con joins batch (items+producto.nombre, mesa.numero, usuario.nombre), reusando `PedidoStaffRead` sin modificarlo. Vacío → 404 existence hiding relacional.

### Tests (155 → 169)
- `test_staff_menu.py` (9): migración default true; categoría/producto inactivo fuera de /public; agotado visible con flag; CRUD con 201/200/409/422/404/403; cross-tenant con restaurante B real (unique nombre POR TENANT verificado: mismo nombre en B → 201); contrato super_admin; GET /menu como mesero.
- `test_staff_clientes.py` (5): fixture crea pedido REAL vía API F6 (register → sesión GRI-MESA-002 → POST /cliente/pedidos con items del menú demo); num_pedidos/total_gastado(approx)/ultimo_pedido_at + orden DESC; historial con items/mesa/usuario; sin pedidos → 404; cross-tenant (lista e historial); contrato super_admin + read mesero. Cleanup: borra pedidos del usuario + mesa a disponible VÍA API (ocupada→limpieza→disponible, cierra sesión anti-zombi) — invariante verificado tras la suite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `await db_session.expire_all()` en tests RED del Task 1**
- **Found during:** Task 1 (RED)
- **Issue:** `expire_all()` es síncrono en SQLAlchemy 2.0 — `await` lanzaba `TypeError` antes de llegar al assert.
- **Fix:** Reemplazo a llamada síncrona en todo el archivo (los tests entonces fallaron por las razones correctas: AttributeError columna inexistente + filtro inexistente).
- **Files:** backend/tests/test_staff_menu.py
- **Commit:** 0ec0ddf

**2. [Rule 1 - Bug] Import fantasma `app.schemas.masa` en staff_service.py**
- **Found during:** Task 2 (edición de imports)
- **Issue:** Línea de import inexistente introducida por error de edición.
- **Fix:** Eliminada en el mismo paso de edición antes de cualquier commit/test (auto-detectado al revisar el edit).
- **Files:** backend/app/services/staff_service.py
- **Commit:** n/a (nunca llegó a commit)

**3. [Nota - Lint] +14 instancias B008 en endpoints nuevos**
- **Found during:** Task 2/3 (ruff check)
- **Issue:** Los 7 endpoints nuevos agregan 14 instancias de B008 (`Depends()` en defaults) — el mismo patrón FastAPI que las 67 instancias pre-existentes en todo `app/`.
- **Decisión:** Se mantiene la convención del archivo (reestructurar a singletons module-level o ignorar B008 globalmente es una decisión de repo completa, fuera del alcance de esta wave). Los 2 I001 nuevos (orden de imports) SÍ se corrigieron; E501/B904/UP017/S105 sin cambios (todos pre-existentes).
- **Commits:** 0f3f023, 47aaf3d

## Auth Gates

None — no se requirió intervención humana de autenticación.

## Verification Results

| Check | Resultado |
|-------|-----------|
| `uv run pytest -q` (workdir backend) | **169 passed** × 2 runs consecutivos (155 previos + 14 nuevos) |
| `uv run ruff check app/` | Sin findings nuevos de tipos nuevos; +14 B008 siguiendo convención existente (ver desviación 3) |
| `docker compose exec api alembic current` | **0005_menu_activo (head)** |
| OpenAPI `/docs` | Los 7 endpoints nuevos bajo /staff con sus matrices de error en docstrings |
| Residuo BD | Mesa 2 disponible tras la suite (invariante restaurado); categorías/productos/tenants de test borrados en finally |

## Requirements Covered

- **MENU-01** — CRUD categorías operativo: 201/PATCH/toggle activo, 409 por nombre duplicado (tenant-scoped), unique por tenant verificado cross-tenant.
- **MENU-02** — CRUD productos: precio>0 validado (422), imagen_url opcional, toggles agotado/activo con semánticas distintas y efecto observable en /public (end-to-end).
- **ADMN-03 (backend)** — Lista JOIN-por-pedidos + historial reusando PedidoStaffRead, existence hiding relacional, aislamiento cross-tenant.

## Notes for Next Plans

- Plan 08-04 (panel): `GET /staff/menu` ya expone flags `activo`/`disponible` por ítem — la pantalla de menú los renderiza directo; PATCH parcial acepta cualquier subconjunto de campos.
- `ClienteResumen.total_gastado` y `ProductoStaff.precio` viajan como JSON number — safe para `double.parse` de Dart.
- La suite de clientes depende del flujo API F6 (sesión QR + pedidos): si mesas 1-8 del seed cambian de invariante por un test roto, `_reset_mesa` auto-repara al inicio de cada fixture.

## Self-Check: PASSED

- Archivos creados verificados en disco: 0005_menu_activo.py, schemas/cliente.py, test_staff_menu.py (626 líneas ≥ min 80), test_staff_clientes.py (309 líneas ≥ min 60) — FOUND.
- 6/6 commits verificados en `git log`: 0ec0ddf, 932f7b8, f725f38, 0f3f023, 2254f85, 47aaf3d — FOUND.
