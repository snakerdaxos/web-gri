---
phase: 02-autenticaci-n-roles-y-multi-tenant
plan: "02"
subsystem: auth
tags: [rbac, multi-tenant, tenant-scope, fastapi-deps, jwt, pydantic, pytest]

# Dependency graph
requires:
  - phase: 02-autenticaci-n-roles-y-multi-tenant
    plan: "01"
    provides: "CurrentUser + get_current_user (deps/auth.py), Usuario/Restaurante ORM + RolUsuario enum, hash_password, auth test helpers (register_cliente, login, auth_header, super_admin_token)"
provides:
  - "require_roles(*roles) — dependency factory RBAC (AUTH-03): 403 fuera del allowlist"
  - "TenantScope + get_tenant_scope — el filtro estructural multi-tenant (AUTH-04): super_admin sin filtro, cliente 403, staff sin restaurante 403"
  - "Endpoints /admin/restaurantes (POST, GET list, GET by id) + /admin/restaurantes/{id}/staff (POST)"
  - "StaffRole enum restringido (admin_restaurante|mesero|cocina) — imposible escalar a super_admin vía API (422)"
  - "Patrón tenant-scoped read: get_restaurante_for_staff (WHERE id == scope.restaurant_id → None → 404 uniforme)"
  - "verify_auth.sh 19 checks — aceptación manual integral de toda la fase"
affects: [03-domain (cada service staff repite el patrón TenantScope + WHERE restaurant_id), 05-cliente-discover (endpoints públicos de cliente usan require_roles(cliente) o get_current_user), 06-qr-ordering (staff cocina/mesero gates), 07-websockets (mismo JWT + TenantScope en el handshake WS), 08-panel (endpoints admin_restaurante con get_tenant_scope)]

# Tech tracking
tech-stack:
  added: []   # sin dependencias nuevas — solo composición de las de Plan 02-01
  patterns:
    - require_roles-dependency-factory
    - tenant-scope-derived-filter (JWT identity → WHERE clause, nunca param ad-hoc)
    - cross-tenant-404-not-403 (no revelar existencia del recurso)
    - restricted-staff-enum-via-pydantic (422 antes de tocar el service)
    - defense-in-depth-get_tenant_scope (cliente 403 aunque el endpoint olvide require_roles)
    - uniform-404-for-missing-and-cross-tenant

key-files:
  created:
    - backend/app/schemas/restaurante.py
    - backend/app/services/admin_service.py
    - backend/app/api/admin.py
    - backend/tests/test_admin_platform.py
    - backend/tests/test_roles.py
    - backend/tests/test_multitenant.py
  modified:
    - backend/app/deps/auth.py
    - backend/app/main.py
    - backend/scripts/verify_auth.sh
    - .env.example

key-decisions:
  - "Cross-tenant = 404 (NO 403) — respuesta uniforme para no-existente, inactivo y de-otro-tenant: la existencia de recursos ajenos nunca se revela"
  - "get_tenant_scope rechaza cliente con 403 explícito (defense-in-depth): un endpoint mal declarado no deja entrar al cliente por la vía del scope"
  - "StaffRole enum Pydantic restringido a los 3 roles staff — cliente/super_admin en body.role → 422 en validación, antes del service"
  - "Staff para restaurante inexistente → 404 ANTES de insertar el usuario (chequeo FK previo); email duplicado → 409 (unicidad global cross-tenant)"
  - "list_restaurantes y get_restaurante_for_staff filtran solo activos también para super_admin — gestión de inactivos diferida a Phase 8 (PLAT-05)"
  - "require_roles resuelve ANTES que el handler → 403 gana a 404: los role checks nunca filtran existencia de recursos"

patterns-established:
  - "Pattern: require_roles(*roles) como ÚNICA forma de gatear roles en endpoints (nunca if user.role == ... en el router)"
  - "Pattern: toda query staff lleva .where(Model.id_column == scope.restaurant_id) cuando not scope.is_super_admin — el filtro se deriva de la identidad, no se pasa como parámetro"
  - "Pattern: servicio tenant-scoped retorna None y el router traduce a 404 uniforme (el servicio no decide códigos HTTP de aislamiento)"
  - "Pattern: StaffRead/UserRead explícitos SIN el hash — nunca response_model = ORM"

requirements-completed: [AUTH-03, AUTH-04, PLAT-02, PLAT-03]

# Metrics
duration: 45min (sesión de reanudación; RED commit 5f67579 fue de la sesión anterior)
completed: 2026-08-13
---

# Phase 2 Plan 02: Roles, Multi-tenant y Admin Platform Summary

**RBAC con require_roles + aislamiento TenantScope (cross-tenant = 404 hard gate) + endpoints /admin/restaurantes y staff — las 4 Success Criteria restantes de la fase cerradas, suite 34/34 verde, verify_auth.sh 19/19**

## Goal

Slice vertical de roles (AUTH-03), aislamiento multi-tenant (AUTH-04), administración de plataforma (PLAT-02 crear restaurantes, PLAT-03 crear staff). El `TenantScope` es la decisión arquitectónica central: el filtro tenant se deriva estructuralmente de la identidad del llamador, haciendo imposible olvidar el `WHERE restaurant_id` en fases futuras.

## Accomplishments

- ✅ **Task 1 (GREEN, commit `c9495f0`)**: `deps/auth.py` extendido con `require_roles(*roles)` (factory 403), `TenantScope` dataclass y `get_tenant_scope` (super_admin→sin filtro / cliente→403 defense-in-depth / staff sin restaurante→403 / staff→su tenant). `schemas/restaurante.py` con `StaffRole` enum restringido (los 3 roles staff; cliente/super_admin → 422). `admin_service.py` con create/list/create_staff (404 FK previo, 409 dup email) y **`get_restaurante_for_staff`** — la función crítica AUTH-04 con el filter tenant. `api/admin.py` con 4 endpoints. `main.py` incluye el router. 9/9 tests PLAT-02/03.
- ✅ **Task 2 (commit `1afeaf7`)**: `test_roles.py` (6 tests AUTH-03: cliente 403 en los 3 endpoints admin, no-token 401 ×2, token inválido 401), `test_multitenant.py` (5 tests AUTH-04 con el **hard gate `test_staff_cross_tenant_404`** — mesero de A pide restaurante B y recibe 404, NO 403), `verify_auth.sh` extendido a 19 checks consecutivos con secciones ADMIN PLATFORM / ROLE ENFORCEMENT / MULTI-TENANT ISOLATION.

## Matriz de roles aplicada (verificada con tests)

| Endpoint | super_admin | admin_restaurante | mesero | cocina | cliente | sin token |
|---|---|---|---|---|---|---|
| POST /admin/restaurantes | **201** | 403 | 403 | 403 | 403 | 401 |
| GET /admin/restaurantes (list) | **200** | 403 | 403 | 403 | 403 | 401 |
| POST /admin/restaurantes/{id}/staff | **201/404/409/422** | 403 | 403 | 403 | 403 | 401 |
| GET /admin/restaurantes/{id} | **200** (cualquier activo) | 200 propio / **404** ajeno | 200 propio / **404** ajeno | 200 propio / **404** ajeno | 403 | 401 |
| POST /auth/{register,login} | *(público)* | — | — | — | — | 201/200 |
| GET /auth/me | 200 | 200 | 200 | 200 | 200 | 401 |

Notas: (1) el 403 de `require_roles` resuelve antes que el handler → gana al 404 de FK inexistente (los role checks no filtran existencia). (2) GET by id usa `get_tenant_scope`, no `require_roles`: staff de cualquier rol + super_admin. (3) Body role inválido en staff (`cliente`/`super_admin`) → 422 del enum Pydantic.

## Files Created/Modified

- `backend/app/deps/auth.py` — añadidos `require_roles`, `TenantScope`, `get_tenant_scope` (67→131 líneas)
- `backend/app/schemas/restaurante.py` — RestauranteCreate/Read, StaffRole (restringido), StaffCreate (password ≤64), StaffRead (sin hash)
- `backend/app/services/admin_service.py` — create_restaurante, list_restaurantes (solo activos), create_staff, get_restaurante_for_staff (**el filter tenant**)
- `backend/app/api/admin.py` — router `/admin` con 4 endpoints (3 con require_roles(super_admin), 1 con get_tenant_scope)
- `backend/app/main.py` — `app.include_router(admin.router)`
- `backend/tests/test_admin_platform.py` — 9 tests PLAT-02/03 (commit RED previo `5f67579`)
- `backend/tests/test_roles.py` — 6 tests AUTH-03
- `backend/tests/test_multitenant.py` — 5 tests AUTH-04 (hard gate)
- `backend/scripts/verify_auth.sh` — 6 → 19 checks
- `.env.example` — SUPER_ADMIN_EMAIL=admin@gri.dev (alineado con .env real)

## Verification

- `pytest tests/` → **34/34 PASSED** (2 Phase 1 + 12 AUTH-01/02 + 9 PLAT-02/03 + 6 AUTH-03 + 5 AUTH-04)
- **HARD GATE**: `test_multitenant.py::test_staff_cross_tenant_404` PASSED (cross-tenant = 404)
- `sh scripts/verify_auth.sh` (en contenedor) → **ALL CHECKS PASSED** (19/19)
- Greps de aceptación: `scope.restaurant_id` presente en admin_service (la línea crítica); `require_roles|get_tenant_scope` ×7 en admin.py; `HTTP_404_NOT_FOUND` en admin.py; `password_hash` ×0 en schemas/; `class StaffRole` definido; `algorithms=["HS256"]` en security.py; passlib ×0 y verify_exp False ×0 en app/
- Stack: `docker compose ps` → gri-mysql healthy + gri-api Up; `/health` 200 connected

## Issues Encountered

- **Artefacto de quoting PowerShell→docker (no bug de código)**: al invocar `docker exec ... sh -c "... $VAR ..."` desde PowerShell 5.1, `\$VAR` se interpola a vacío del lado de PS → el env llegaba vacío y CHECK 7 daba 422. Solución de ejecución: pipear el script por stdin (`Get-Content ... -Raw | docker exec -i gri-api sh`) o pasar args simples. La ejecución canónica `docker exec -w /app gri-api sh scripts/verify_auth.sh` pasa limpia.
- **El contenedor no ve archivos nuevos sin rebuild**: la imagen copia el código en build; tras escribir tests nuevos hace falta `docker compose up -d --build` (capa COPY, rápido por cache).
- `curl`/`jq` no viven en la imagen (por diseño, imagen lean): se instalan efímeramente con `docker exec -u root ... apt-get install` para correr verify_auth.sh; no modifica el Dockerfile.

## Deviations from Plan

- **[Menor] test_admin_platform.py quedó con 9 tests (el plan listaba 7)**: la sesión anterior (commit RED `5f67579`) dividió invalid-role en dos tests (cliente y super_admin por separado) y añadió `test_create_staff_duplicate_email` (409). Todos verdes; cobertura estrictamente superior a la planificada.
- **[Menor] .env.example con SUPER_ADMIN_EMAIL=admin@gri.dev** en vez de admin@gri.local (ejemplo del research): `.local` es rechazado por email-validator (TLD special-use) y el login del super_admin vía API fallaría con 422. Alineado con el .env real ya usado por el bootstrap. Commiteado junto al GREEN.
- Ninguna otra desviación — decisiones locked del research aplicadas sin renegociar (404-no-403, TenantScope, enum restringido, super_admin sin filtro).

## User Setup Required

None — todo funciona con el stack existente (`docker compose up -d`).

## Notas para Phase 3 (base que deja este plan)

- **El patrón a repetir en CADA service staff** (mesas, pedidos, productos):
  1. El endpoint declara `scope: TenantScope = Depends(get_tenant_scope)`.
  2. El service recibe `scope` y aplica `if not scope.is_super_admin: stmt = stmt.where(Model.restaurant_id == scope.restaurant_id)`.
  3. Ausente/cross-tenant → mismo 404 uniforme.
- `TenantScope.restaurant_id` es el filtro derivado de la identidad (claim JWT → DB check en get_current_user) — nunca aceptar restaurant_id como parámetro del cliente en endpoints staff.
- El truth "staff sin restaurant_id (NULL) → 403" está implementado en `get_tenant_scope` pero NO tiene test integration: la API no puede crear staff sin restaurante (create_staff exige FK válida), habría que sembrarlo por DB directa. Cubierto por unit-review del código; anotado para no perder el rastro.
- Los servicios de cocina/mesero de Phase 6-7 (QR ordering + WS) reutilizan `require_roles(RolUsuario.mesero, RolUsuario.cocina)` y el mismo TenantScope; el JWT que ya emite /auth/login es el mismo que aceptará el WS handshake.
- PLAT-05 (gestión de inactivos) quedará en Phase 8: hoy list/get filtran solo activos incluso para super_admin.

## Task Commits

1. **Task 1 RED** (sesión anterior): `5f67579` — test(02-02): failing tests PLAT-02/03
2. **Task 1 GREEN**: `c9495f0` — feat(02-02): TenantScope + require_roles + admin platform API
3. **Task 2**: `1afeaf7` — test(02-02): role enforcement + cross-tenant hard gate + verify_auth.sh 19 checks

## Self-Check: PASSED
- ✅ Archivos clave existen: deps/auth.py (extendido), schemas/restaurante.py, services/admin_service.py, api/admin.py, tests/{test_admin_platform,test_roles,test_multitenant}.py, scripts/verify_auth.sh
- ✅ Commits existen: 5f67579, c9495f0, 1afeaf7
- ✅ Suite pytest: 34/34 PASSED (incl. hard gate cross-tenant 404)
- ✅ verify_auth.sh: ALL CHECKS PASSED (19 checks)
- ✅ Stack: gri-api Up + gri-mysql healthy

---
*Phase: 02-autenticaci-n-roles-y-multi-tenant (Plan 02 — cierra la fase)*
*Completed: 2026-08-13*
