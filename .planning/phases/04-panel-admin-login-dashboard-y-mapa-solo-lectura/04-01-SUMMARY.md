---
phase: 04-panel-admin-login-dashboard-y-mapa-solo-lectura
plan: 01
subsystem: api
tags: [fastapi, cors, tenant-isolation, staff-endpoints, dashboard-stats, mesa-map, sqlalchemy]

# Dependency graph
requires:
  - phase: 02-auth-y-multi-tenant
    provides: get_tenant_scope/TenantScope (deps/auth.py), patrón get_restaurante_for_staff, /auth/login + /auth/me
  - phase: 03-modelo-de-dominio
    provides: Modelos Mesa/Pedido/Reserva (enums + indexes compuestos), seed demo (Restaurante Demo GRI id dinámico, admin@demo.gri.dev/Demo!1234, 8 mesas GRI-MESA-001..008)
provides:
  - "GET /staff/mesas — lista MesaRead tenant-scoped (ADMN-02, mapa de mesas del panel)"
  - "GET /staff/stats — DashboardStats con 7 counts reales de BD (ADMN-01)"
  - "CORSMiddleware con origins explícitos via CORS_ORIGINS (panel :5173 → API :8000)"
  - "staff_service._resolve_rid — el helper que fuerza scope.restaurant_id para staff (patrón reutilizable Phase 5+)"
affects: [04-02-panel-admin-flutter, 05-pedidos-cocina, 07-tiempo-real-websockets]

# Tech tracking
tech-stack:
  added: []  # cero deps nuevas (uv.lock sin cambios) — CORSMiddleware viene con FastAPI
  patterns:
    - "_resolve_rid(scope, restaurante_id): staff → SIEMPRE scope.restaurant_id (param ignorado); super_admin → param requerido (400) + validación activo (404)"
    - "Stats con 1 solo GROUP BY por estado + func.curdate() DB-side para 'hoy' (nunca date.today())"
    - "Tests deterministas ante residuo de BD: subset seed por patrón (GRI-MESA-\\d{3}) + invariantes + DB cross-check"

key-files:
  created:
    - backend/app/api/staff.py
    - backend/app/services/staff_service.py
    - backend/app/schemas/mesa.py
    - backend/app/schemas/dashboard.py
    - backend/tests/test_staff_read.py
    - backend/tests/test_cors.py
  modified:
    - backend/app/main.py
    - backend/app/core/config.py
    - docker-compose.yml
    - .env.example

key-decisions:
  - "_resolve_rid ignora ?restaurante_id= para staff (T-04-02): el param es hint SOLO para super_admin"
  - "Tests de counts usan cross-check DB + subset seed en vez de números absolutos (residuo GRI-TEST-* crece por run)"
  - "docker-compose.yml interpola CORS_ORIGINS al contenedor (sin eso el .env no tenía efecto)"
  - "reservas_hoy con func.curdate() (TZ Bogota DB-side) y pedidos_activos excluye borrador y terminales"

patterns-established:
  - "Patrón /staff: router delgado + service con _resolve_rid — Phase 5 (pedidos cocina) lo replica"
  - "Convención de test: assert absoluto solo sobre subset seed identificable (QR pattern), nunca sobre counts globales de la BD compartida"

requirements-completed: [ADMN-01, ADMN-02]

# Metrics
duration: 9min
completed: 2026-08-14
---

# Phase 4 Plan 01: Backend Read Endpoints Panel Admin Summary

**GET /staff/mesas + GET /staff/stats tenant-scoped vía _resolve_rid (param ignorado para staff, 400/404 para super_admin) + CORSMiddleware con origins explícitos — suite 59 → 70 tests**

## Performance

- **Duration:** 9 min
- **Started:** 2026-08-13T23:54:25Z
- **Completed:** 2026-08-14T00:03:27Z
- **Tasks:** 2/2
- **Files modified:** 10 (6 creados, 4 modificados)

## Accomplishments

- **GET /staff/mesas (ADMN-02):** lista `MesaRead {id, numero, capacidad, codigo_qr, estado}` ordenada por numero, filtrada SIEMPRE por el tenant del token. Staff que envía `?restaurante_id=` ajeno recibe sus PROPIAS mesas (param ignorado, T-04-02); super_admin sin param → 400; con rid inexistente/inactivo → 404 (existence hiding).
- **GET /staff/stats (ADMN-01):** `DashboardStats` con 7 counts reales de BD — mesas por estado en 1 GROUP BY (1 round-trip), `reservas_hoy` con `func.curdate()` DB-side (America/Bogota, Pitfall 6) excluyendo canceladas, `pedidos_activos` en estados {enviado, aceptado, en_preparacion, servido} aprovechando `ix_pedido_restaurante_estado`.
- **CORSMiddleware (Pitfall 1):** origins explícitos desde `CORS_ORIGINS` (comma-separated, default `http://localhost:5173`), `allow_credentials=True`, sin wildcard. Preflight desde :5173 → 200 + `Access-Control-Allow-Origin` echo; origen no listado → 400 sin leak del header.
- **Aislamiento verificado empíricamente:** 401 sin token, 403 cliente (get_tenant_scope), 404 cross-tenant para super_admin con rid desconocido, respuesta idéntica con/sin param para staff.

## Task Commits

1. **Task 1: CORS + schemas + /staff service y router** — `f7b42f6` (feat)
2. **Task 2: Tests de aislamiento tenant + CORS preflight** — `f9a6368` (test)

## Endpoints Added

| Path | Response | Notas |
|------|----------|-------|
| `GET /staff/mesas` | `[{id, numero, capacidad, codigo_qr, estado}]` | response_model=list[MesaRead]; Query param `restaurante_id` (hint super_admin) |
| `GET /staff/stats` | `{mesas_disponibles, mesas_ocupadas, mesas_reservadas, mesas_limpieza, total_mesas, reservas_hoy, pedidos_activos}` (7 ints) | DTO calculado, no ORM |

## Files Created/Modified

- `backend/app/api/staff.py` — router `/staff` (GET /mesas, GET /stats), deps get_session + get_tenant_scope
- `backend/app/services/staff_service.py` — `_resolve_rid` + `list_mesas` + `get_stats` (toda la lógica tenant)
- `backend/app/schemas/mesa.py` — `MesaRead` (5 campos)
- `backend/app/schemas/dashboard.py` — `DashboardStats` (7 counts int)
- `backend/tests/test_staff_read.py` — 8 tests de aislamiento + counts
- `backend/tests/test_cors.py` — 3 tests de preflight/simple-request
- `backend/app/main.py` — CORSMiddleware + include_router(staff.router)
- `backend/app/core/config.py` — `CORS_ORIGINS: str`
- `docker-compose.yml` — pasa `CORS_ORIGINS` al contenedor api
- `.env.example` — documenta CORS_ORIGINS

## Decisions Made

- `_resolve_rid` es async y toma `session` (el plan lo firmaba sin session, pero la validación de restaurante activo la necesita): super_admin sin param → 400; rid inexistente/inactivo → 404; staff → `scope.restaurant_id` SIEMPRE.
- Tests de counts NO usan números absolutos de BD (ver Deviations): asserts absolutos solo sobre el subset seed identificable por patrón QR + invariantes estructurales + DB cross-check.
- `pedidos_activos` excluye `borrador` (el cliente aún compone; cocina no ve nada) y los terminales `pagado`/`rechazado`.
- Stats por estado en 1 solo query GROUP BY (elegido por el plan sobre 4 scalar counts).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] docker-compose.yml no pasaba CORS_ORIGINS al contenedor**
- **Found during:** Task 2 (primera corrida de tests dentro del contenedor)
- **Issue:** El plan añadía CORS_ORIGINS a Settings + .env, pero docker-compose.yml no lo interpolaba en el servicio api — cambiar el .env no habría tenido efecto en el contenedor (la config era inerte salvo por el default).
- **Fix:** `CORS_ORIGINS: ${CORS_ORIGINS:-http://localhost:5173}` en el environment del servicio api.
- **Files modified:** docker-compose.yml
- **Verification:** El comportamiento era correcto por el default (verificado con preflight 200 + ACAO), y ahora el .env es efectivo.
- **Committed in:** f9a6368

**2. [Rule 1 - Bug] Tests del plan asumían BD con exactamente 8 mesas; la BD real acumula residuo**
- **Found during:** Task 1 (smoke test mostró 14 mesas, no 8)
- **Issue:** `test_domain_constraints.py` (Phase 3) COMMITEA filas uuid-tag (`GRI-TEST-*` mesas, pedidos `borrador`) en el restaurante demo sin cleanup — cada run completo de la suite suma ~6 mesas más. Los asserts literales del plan (`len == 8`, `total_mesas == 8`) fallarían y serían flaky por orden alfabético de ejecución (staff corre DESPUÉS de constraints).
- **Fix:** Tests con triple estrategia: (a) asserts absolutos solo sobre subset seed por patrón `GRI-MESA-\d{3}` == 8 (convención ya usada por test_seed.py), (b) invariante `total_mesas == suma de los 4 estados`, (c) DB cross-check: los números de la API == realidad BD filtrada por tenant (incluido residuo). Inmune al crecimiento del residuo.
- **Files modified:** backend/tests/test_staff_read.py
- **Verification:** 70/70 verde; el residuo creció de 14 → 20 mesas durante la ejecución y los tests siguen pasando.
- **Committed in:** f9a6368

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug/determinismo de tests)
**Impact on plan:** Ambas necesarias para corrección operativa y determinismo. Cero scope creep.

## Issues Encountered

- **Bug propio en primer run de tests:** `test_mesas_cliente_forbidden` desempaquetaba `login()` al revés (`_, access` tomaba el REFRESH token) → 401 "Tipo de token incorrecto". El guard PITFALL 6 de Phase 2 funcionó exactamente como debe; corregido el unpack, 11/11 verde.
- **PowerShell 5.1:** `Get-Date -AsUTC` no existe (es PS 6+) — se usa `[DateTimeOffset]::UtcNow`.
- **Contenedor sin volume mount:** el código va horneado en la imagen → cada cambio de código/test requiere `docker compose up -d --build api` (convención del env note, confirmada).

## Verification

- `docker compose exec api uv run pytest tests/ -v` → **70/70 passed** (59 baseline + 8 staff + 3 cors; el plan estimaba 67 pero su propio acceptance criteria corregía a 70) en ~13s.
- OpenAPI incluye `/staff/mesas` y `/staff/stats`; `alembic upgrade head` idempotente (head 0002, cero migraciones); `uv.lock` sin cambios (cero deps).
- Preflight: `OPTIONS /staff/mesas` con `Origin: http://localhost:5173` → 200, `access-control-allow-origin: http://localhost:5173`, `access-control-allow-credentials: true`. Origen bloqueado → 400 sin ACAO.
- Aislamiento: staff + `?restaurante_id=999` → mismas mesas propias (JSON idéntico); super_admin sin param → 400 `"restaurante_id requerido para super_admin"`; super_admin + rid 999999 → 404; sin token → 401; cliente → 403.

### `/staff/stats` JSON contra el seed demo (fixture para Plan 04-02)

En una BD recién sembrada (DEMO_MODE=true, sin residuo de tests):

```json
{
  "mesas_disponibles": 8,
  "mesas_ocupadas": 0,
  "mesas_reservadas": 0,
  "mesas_limpieza": 0,
  "total_mesas": 8,
  "reservas_hoy": 0,
  "pedidos_activos": 0
}
```

OJO dev DB: la BD de desarrollo acumula residuo `GRI-TEST-*` (al cierre de este plan: `total_mesas: 20`). Los widget tests del Plan 04-02 deben mockear este shape con valores inyectados, y los tests de integración frontend NO deben asumir counts absolutos contra la dev DB.

`GET /staff/mesas` (dev DB, primeros items — seed subset):

```json
[
  {"id": 1, "numero": 1, "capacidad": 2, "codigo_qr": "GRI-MESA-001", "estado": "disponible"},
  {"id": 2, "numero": 2, "capacidad": 2, "codigo_qr": "GRI-MESA-002", "estado": "disponible"}
]
```

## User Setup Required

None — no external service configuration required. (`.env` local ya actualizado con `CORS_ORIGINS=http://localhost:5173`.)

## Next Phase Readiness

- **Plan 04-02 (panel Flutter Web) puede consumir:** login vía `/auth/login` existente, "mi restaurante" vía `/admin/restaurantes/{restaurant_id}` (decisión del research: NO se añadió `/staff/yo`), stats y mesas vía los dos endpoints nuevos. CORS listo para `flutter run -d chrome --web-port=5173`.
- **Para super_admin en el panel (Open Q1):** el endpoint exige `?restaurante_id=` — el panel debe resolverlo con `GET /admin/restaurantes` + picker (o default demo).
- **Sin blockers.** El polling de 04-02 golpea `/staff/mesas`|`/staff/stats`; Phase 7 reemplaza el timer por WS.
- Nota para Phase 5: replicar el patrón `_resolve_rid` en el service de pedidos.

---
*Phase: 04-panel-admin-login-dashboard-y-mapa-solo-lectura*
*Completed: 2026-08-14*

## Self-Check: PASSED

- 6 archivos creados: FOUND (staff.py, staff_service.py, mesa.py, dashboard.py, test_staff_read.py, test_cors.py)
- 9 patrones must_haves (prefix="/staff", _resolve_rid, class MesaRead, class DashboardStats, test cross-tenant, Access-Control-Allow-Origin, CORSMiddleware, include_router(staff.router), CORS_ORIGINS): FOUND
- Commits f7b42f6 + f9a6368: FOUND en git log
