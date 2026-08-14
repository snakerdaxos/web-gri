---
phase: 08-panel-admin-gesti-n-completa-y-reportes
plan: "02"
subsystem: backend
tags: [mesas-crud, qr-determinista, reportes, ventas, top-platos, platform-management, tenant-isolation]
requires:
  - "Plan 08-01 completo (migración 0005 aplicada, suite 169 verde)"
  - "_resolve_rid + get_tenant_scope + require_roles (deps/auth)"
  - "Seed demo rid=1 (mesas 1-8 GRI-MESA-001..008, menú 16 productos, staff Demo!1234)"
  - "emitter broadcaster.emit_event + suite WS con kick-to-refetch mesa.estado"
provides:
  - "POST /staff/mesas — mesa con QR determinista GRI-MESA-R{rid}-{numero:03d} autogenerado, 201"
  - "PATCH /staff/mesas/{id} — numero/capacidad parcial; cambio de numero REGENERA el QR"
  - "GET /staff/reportes/ventas — total/num_pedidos/por_dia con venta=servido|pagado, rango inclusivo, defaults DB-side"
  - "GET /staff/reportes/top-platos — SUM(cantidad) DESC top-N tenant-scoped sobre pedido_item"
  - "PATCH /admin/restaurantes/{id} {activo} — desactivar/reactivar (super_admin only)"
  - "GET /admin/restaurantes?incluir_inactivos=true — única vista que expone inactivos"
  - "Schemas: MesaCreate/MesaUpdate, VentaDia/VentasReporte/TopPlato, RestauranteActivoUpdate"
affects:
  - "Plan 08-03/08-05 (panel: pantallas mesas/reportes/gestión plataforma consumen estos 6 endpoints)"
  - "_staff_write_roles (antes _menu_write_roles): guard compartido de writes staff"
tech-stack:
  added: []  # cero deps nuevas Python (decisión del plan cumplida)
  patterns:
    - "QR determinista derivado (rid, numero) — collision-free por construcción, jamás input del cliente"
    - "venta = estado IN (servido, pagado) — JAMÁS solo pagado (reportes no vacíos hasta F9)"
    - "defaults de fecha con func.curdate() DB-side + boundaries inclusivos [desde 00:00, hasta+1d 00:00)"
    - "toggle activo super_admin sin tocar public_service (el filtro activo ya vive en todos los reads)"
key-files:
  created:
    - backend/app/schemas/reporte.py
    - backend/tests/test_staff_mesas_crud.py
    - backend/tests/test_staff_reportes.py
  modified:
    - backend/app/schemas/mesa.py
    - backend/app/schemas/restaurante.py
    - backend/app/api/staff.py
    - backend/app/api/admin.py
    - backend/app/services/staff_service.py
    - backend/app/services/admin_service.py
    - backend/tests/test_admin_platform.py
decisions:
  - "QR determinista GRI-MESA-R{rid}-{numero:03d} (Pattern 1 research): convive con el seed GRI-MESA-001..008 sin colisión; PATCH-numero lo regenera (el impreso anterior queda obsoleto — Pitfall 6)"
  - "venta = servido|pagado (locked): filtrar solo pagado dejaría los reportes vacíos hasta F9; P2 en enviado queda excluido con assert explícito"
  - "top-platos usa nombre ACTUAL del producto (pedido_item no tiene snapshot de nombre); los MONTOS sí son exactos por snapshot de precio (Open Question 3 documentada en docstring)"
  - "ALCANCE v1 PLAT-05 (locked): desactivar oculta de /public y del listado activo, pero el staff con token vigente SIGUE operando (bloqueo operacional = PLT2 futuro); el get de set_restaurante_activo NO filtra por activo (reactivar debe encontrar inactivos)"
  - "helpers de suites hermanas importados (create_restaurante_con_staff, _reset_mesa, _borrar_pedidos_usuario, _restaurar_mesa_via_api) en vez de extraer a conftest — patrón cross-test ya establecido por test_staff_clientes; extracción a conftest cuando un 3er consumidor lo pida"
metrics:
  duration: "~25 min (2026-08-14 13:28→13:53 UTC)"
  tests: "169 → 181 (+7 mesas_crud, +3 reportes, +2 plat05), 2 runs consecutivos verdes"
  completed: 2026-08-14
---

# Phase 8 Plan 02: Backend mesas CRUD + reportes + PLAT-05 Summary

**One-liner:** Mesas CRUD con QR determinista `GRI-MESA-R{rid}-{numero:03d}` (regenerado al cambiar numero, 409 pre-check + IntegrityError safety net), reportes de ventas por día/rango y top-platos como agregaciones SQL puras tenant-scoped con venta=servido|pagado, y toggle PLAT-05 de restaurantes (PATCH activo super_admin + ?incluir_inactivos) — suite 169 → 181.

## Tasks Completed

| # | Task | Commit | Verificación |
|---|------|--------|--------------|
| 1 | Mesas CRUD QR determinista (POST/PATCH /staff/mesas) | `73e3538` (RED) + `6aabb06` (GREEN) | 7/7 test_staff_mesas_crud; QR asserts literales; suite 176 |
| 2 | Reportes ventas + top-platos (GET /staff/reportes/*) | `a0cf71a` (RED) + `bdb4cca` (GREEN) | 3/3 test_staff_reportes; fixture P1 servido vs P2 enviado; suite 179 |
| 3 | PLAT-05 PATCH activo + incluir_inactivos | `7b5b9a3` (RED) + `3f4ee96` (GREEN) | 2/2 tests nuevos + 9 existentes + test_public_read sin regresiones; suite 181 × 2 runs |

## What Was Built

### Mesas CRUD (MESA-01) — `staff_service.create_mesa/update_mesa`
- `_codigo_qr(rid, numero)` = `f"GRI-MESA-R{rid}-{numero:03d}"` — ~22 chars, jamás input del cliente. Collision-free por construcción: rid distinto ⇒ prefijo distinto (uq_mesa_codigo_qr global intacta); dentro del tenant uq_mesa_restaurante_numero garantiza el par. Test cross-tenant explícito: B crea mesa con el MISMO numero → 201 con QR `R{rid_b}`.
- POST: pre-check SELECT count → 409 amigable "La mesa {n} ya existe" + `except IntegrityError → rollback + 409` (red de seguridad de la carrera, Pitfall 7). Estado nace `disponible`.
- PATCH parcial: `{}` → 422 "Nada que actualizar"; `{capacidad}` → QR intacto; `{numero}` → pre-check 409 + REGENERACIÓN del QR (Pitfall 6 — el impreso anterior queda obsoleto). Existence hiding cross-tenant (ajena == inexistente → 404 idéntico). Sin drift en rechazos (asserts).
- Ambos emiten `mesa.estado` post-commit (commit → refresh → emit) — kick-to-refetch gratis del mapa, reusando el tipo de evento que YA testea la suite WS (cero tipos nuevos).

### Reportes (REPO-01/02) — `get_reporte_ventas/get_top_platos`
- Constante `_VENTAS_ESTADOS = [servido, pagado]` (decisión locked — PROHIBIDO solo pagado: los reportes saldrían vacíos hasta F9; test aserta que el P2 en `enviado` NO cuenta).
- `_rango_reportes`: defaults DB-side con `select(func.curdate())` (desde=hoy-6, hasta=hoy — Pitfall 3, nunca `date.today()` Python); `desde > hasta` → 422; boundaries inclusivos `[desde 00:00:00, hasta+1d 00:00:00)`.
- Ventas: UNA query `func.date(created_at), count(), sum(total)` GROUP BY fecha, rideando `ix_pedido_restaurante_estado`; totales generales = suma de los rows (0.0/0 si vacío).
- Top-platos: SUM(cantidad) DESC + SUM(subtotal) sobre `PedidoItem.restaurant_id` (denormalizado, index propio) JOIN Pedido SOLO para el filtro de estado y Producto para nombre; `limit` 1..50 (default 10). Nota docstring: nombre ACTUAL, montos exactos por snapshot (Open Question 3).
- Schemas `VentaDia/VentasReporte/TopPlato` con money `float` + `@field_serializer` (Pitfall 1: SUM devuelve Decimal → JSON number, no string).
- Reads abiertos a todo el staff (un mesero viendo reportes es correcto); contrato super_admin `_resolve_rid` (400 sin param / 404 unknown).

### Plataforma (PLAT-05) — `admin_service.set_restaurante_activo/list_restaurantes`
- PATCH `/admin/restaurantes/{id}` `{activo: bool}` con `require_roles(super_admin)` — staff → 403 (un admin_restaurante jamás desactiva su propio tenant); body sin activo → 422; inexistente → 404 uniforme. El get NO filtra por activo: reactivar DEBE encontrar inactivos.
- Desactivar oculta de `/public` (lista y detalle 404 — el filtro `activo` ya vivía en todos los reads públicos, cero cambios en public_service) y del listado activo; `?incluir_inactivos=true` es la ÚNICA vista que los expone. `_resolve_rid` del super_admin ya 404-ea inactivos en /staff (comportamiento existente, verificado por test).
- **Alcance v1 documentado y asertado**: el staff del restaurante inactivo con token vigente SIGUE operando (GET /staff/mesas → 200). Bloqueo operacional = PLT2 futuro.

### Tests (169 → 181)
- `test_staff_mesas_crud.py` (7, 294 líneas): QR determinista literal + dup 409 sin drift; capacidad preserva QR / numero regenera; 409/422/404; cross-tenant 404 + QR collision-free mismo-numero; contrato super_admin (400/201); mesero 403 POST+PATCH. Numeros únicos por run (100+uuid%8000, M=N+4000); cleanup delete por id en finally.
- `test_staff_reportes.py` (3, 295 líneas): fixture API F6 completo (cliente dedicado → sesión GRI-MESA-003 → P1 A×2+B×1 avanzado a servido con cocina@demo, P2 A×1 dejado en enviado); defaults/rango-inclusivo/2020-vacío/desde>hasta-422; top-platos DESC con filtro-estado EXACTO (A=2, no 3), limit, 2020-vacío; cross-tenant cero fuga + contrato super_admin. `hoy` siempre vía `func.curdate()` DB-side.
- `test_admin_platform.py` (+2): flujo completo PLAT-05 (desactivar → oculto de /public+admin, visible con flag, super_admin /staff 404, staff B sigue 200, reactivar restaura) con finally que reactiva SIEMPRE antes del cleanup; guards 403/422/404.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `sum(start=Decimal(0))` → TypeError mixto Decimal+float**
- **Found during:** Task 2 (primer GREEN run — 500 en /staff/reportes/ventas)
- **Issue:** `VentaDia.total` ya es `float` tras la coerción de Pydantic al validar; sumar con `start=Decimal(0)` lanza `TypeError: unsupported operand types for +: Decimal and float`.
- **Fix:** `start=0.0` con comentario explicando la coerción previa (el field_serializer de VentaDia es por-wire, no por-validación).
- **Files:** backend/app/services/staff_service.py
- **Commit:** bdb4cca

**2. [Rule 1 - Bug] Corrupción de encoding por round-trip PowerShell (`Set-Content -Encoding utf8` = BOM + mojibake)**
- **Found during:** Task 1 (rename _menu_write_roles vía `(Get-Content)|Set-Content`)
- **Issue:** PowerShell 5.1 leyó UTF-8 como codepage del sistema y reescribió el archivo con BOM — `—` se volvió `â€”` en TODO el archivo.
- **Fix:** `git checkout --` del archivo y rename re-hecho con la herramienta Edit. Detectado por git diff antes de cualquier commit/test (nunca llegó a commit).
- **Files:** backend/app/api/staff.py
- **Commit:** n/a (nunca llegó a commit)

**3. [Nota - Lint] Delta ruff en archivos tocados: +15 B008, +3 E501 (tipos pre-existentes)**
- **Found during:** verification (ruff check app/ — baseline comparado contra 9329a7c con los 6 archivos extraídos a temp)
- **Issue/Decisión:** B008 (`Depends()` en defaults) sigue la convención FastAPI del repo (39 instancias pre-existentes en esos archivos, 67+ repo-wide); E501 ×3 son filas de las tablas de matriz de roles en docstrings. Mismos tipos que la desviación 3 del 08-01. Bonus: −6 I001 (mis bloques de import quedaron ordenados). Reestructurar B008 globalmente es decisión de repo completa, fuera de esta wave.
- **Commits:** 6aabb06, bdb4cca, 3f4ee96

**4. [Fuera de alcance — no arreglado] 72 mesas fantasma `GRI-TEST-*` pre-existentes en restaurante 1**
- **Found during:** Task 1 verification (invariante post-suite: mesas 1-8 disponibles ✓ pero 75 filas extra)
- **Issue:** leak acumulado de `test_domain_constraints.py` (test_qr_formato_demo hace `add+flush` sin cleanup; una mesa por run desde fechas anteriores a esta wave).
- **Acción:** registrado en `deferred-items.md` con sugerencia de fix; NO tocado (SCOPE BOUNDARY). Verificado que 08-02 aporta CERO residuo propio (`GRI-MESA-R%` = 0 tras 2 runs).

## Auth Gates

None — no se requirió intervención humana de autenticación.

## Verification Results

| Check | Resultado |
|-------|-----------|
| `uv run pytest -q` (workdir backend, tras rebuild) | **181 passed** × 2 runs consecutivos (169 previos + 12 nuevos) |
| Invariante post-suite | Mesas demo 1-8 en `disponible`; `codigo_qr LIKE 'GRI-MESA-R%'` = 0 filas (cero residuo propio) |
| `uv run ruff check app/` | Delta en archivos tocados: +15 B008 / +3 E501 / −6 I001 vs baseline 9329a7c — mismos tipos pre-existentes (desviación 3) |
| OpenAPI `/docs` | 6 endpoints nuevos presentes: POST /staff/mesas, PATCH /staff/mesas/{mesa_id}, GET /staff/reportes/ventas, GET /staff/reportes/top-platos, PATCH /admin/restaurantes/{id}, GET /admin/restaurantes (+incluir_inactivos) — con matrices de error en docstrings |
| Tipos de evento WS | Inventario completo sin cambios: mesa.estado (×4, ahora incluye create/update), pedido.creado, pedido.estado, sesion.abierta, sesion.cerrada, sesion.cuenta — cero tipos nuevos |
| Emisión post-commit | create_mesa/update_mesa: commit → refresh → emit (orden verificable en el diff) |

## Requirements Covered

- **MESA-01** — POST/PATCH /staff/mesas con QR determinista autogenerado `GRI-MESA-R{rid}-{numero:03d}`, 409 por duplicado (pre-check + constraint), regeneración en cambio de numero, existence hiding cross-tenant.
- **REPO-01** — Ventas por día/rango (total, num_pedidos, por_dia) con venta=servido|pagado, defaults DB-side, boundaries inclusivos, 422 rango invertido.
- **REPO-02** — Top-N platos por SUM(cantidad) DESC tenant-scoped sobre pedido_item denormalizado, montos exactos por snapshot.
- **PLAT-05** — PATCH activo (super_admin only, staff 403) + ?incluir_inactivos; desactivar oculta de /public sin tocar public_service; alcance v1 (staff no bloqueado) asertado.

## Notes for Next Plans

- **08-03 (panel mesas):** POST retorna la mesa con `codigo_qr` — el form imprime con `qr_flutter` directamente; al cambiar `numero` el response trae el QR regenerado (mostrar advertencia "el QR impreso anterior queda obsoleto" ANTES de aplicar). El evento `mesa.estado` del create/update ya dispara el kick-to-refetch testeado — el mapa se actualiza solo.
- **08-05 (reportes/gráficos):** `VentasReporte.total`/`VentaDia.total`/`TopPlato.total` viajan como JSON number (safe para `double.parse`); `por_dia` viene ordenado por fecha ASC listo para `fl_chart`; el default (sin params) ya es la semana móvil [hoy-6, hoy].
- **PLAT-05 en panel:** la lista del super-admin necesita `?incluir_inactivos=true` para mostrar el toggle de reactivación; PATCH exige body `{activo: bool}` (no parcial).
- Si los tests de mesas chocan con residuo de runs abortados (numeros altos), `_delete_mesas` limpia por id; el generador `_numeros_unicos()` da [100, 8100)∪[4100, 12100) con separación 4000.

## Self-Check: PASSED

- Archivos verificados en disco: schemas/reporte.py (65 líneas), test_staff_mesas_crud.py (294 ≥ min 70), test_staff_reportes.py (295 ≥ min 80) — FOUND.
- 6/6 commits verificados en `git log`: 73e3538, 6aabb06, a0cf71a, bdb4cca, 7b5b9a3, 3f4ee96 — FOUND.
