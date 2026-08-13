---
phase: 02-autenticaci-n-roles-y-multi-tenant
verified: 2026-08-13T00:00:00Z
status: passed
score: 4/4 must-haves verified
re_verification:
  previous_status: none
  is_initial: true
anti_patterns:
  passlib_in_uv_lock: false
  passlib_imported: false
  password_hash_in_response_schemas: false
  verify_exp_false_in_code: false
  notes: >
    Las 2 menciones a "passlib" (pyproject.toml L20, security.py L6) y la
    única a "verify_exp.*False" (security.py L82) son COMENTARIOS documentales
    que explican por qué NO se usan esos anti-patrones. No son código. Lo
    esencial se cumple: passlib no está en uv.lock ni se importa; exp se
    verifica por defecto en decode_token.
---

# Phase 2: Autenticación, Roles y Multi-tenant — Verification Report

**Phase Goal:** Usuarios autenticados con sesión persistente, 5 roles distinguibles y aislamiento estricto por restaurante; el super-admin administra la plataforma vía API
**Verified:** 2026-08-13
**Status:** ✅ **PASSED**
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Must-Haves)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1   | Registro cliente + login con access/refresh + refresh da nueva sesión | ✅ VERIFIED | `verify_auth.sh` CHECKS 1–6 + `test_auth_flow.py` 12/12 PASSED. Refresh con access token → 401 (`test_refresh_rejects_access_token`). Rotación con `jti` distingue tokens emitidos en el mismo segundo. |
| 2   | 5 roles distinguibles, cada rol solo accede a sus endpoints (401/403) | ✅ VERIFIED | `test_roles.py` 6/6 PASSED + matriz `require_roles` en `admin.py`. Enum `RolUsuario` con EXACTAMENTE 5 valores en `models/usuario.py` L20-27. Cliente → 403 en `/admin/*`; sin token → 401; token inválido → 401. |
| 3   | Staff del restaurante A → recursos del restaurante B = 404 (aislamiento multi-tenant) | ✅ VERIFIED | **HARD GATE** `test_staff_cross_tenant_404` PASSED. `verify_auth.sh` CHECK 17 (404, NO 200, NO 403). Filter tenant literal en `admin_service.py` L108: `stmt = stmt.where(Restaurante.id == scope.restaurant_id)`. |
| 4   | Super-admin crea restaurantes y usuarios staff vía API | ✅ VERIFIED | `test_admin_platform.py` 9/9 PASSED + CHECKS 7–12 verify_auth.sh. 4 endpoints en `api/admin.py`. `StaffRole` enum restringido (422 on `cliente`/`super_admin`); 404 on FK inexistente. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `backend/app/deps/auth.py` | `require_roles`, `TenantScope`, `get_tenant_scope` | ✅ VERIFIED | 128 líneas. Factory RBAC + dataclass scope + derivación defense-in-depth (cliente→403, staff NULL→403, super_admin→sin filtro). |
| `backend/app/services/admin_service.py` | `WHERE scope.restaurant_id` | ✅ VERIFIED | L103-108: `get_restaurante_for_staff` aplica filter tenant condicional. Devuelve None → router traduce a 404 uniforme. |
| `backend/app/api/admin.py` | 4 endpoints | ✅ VERIFIED | POST/GET `/admin/restaurantes`, POST `/{id}/staff`, GET `/{id}`. 3 con `require_roles(super_admin)`, 1 con `get_tenant_scope`. |
| `backend/app/core/security.py` | bcrypt + HS256 + claim type | ✅ VERIFIED | `bcrypt` directo (no passlib), `algorithms=["HS256"]` explícito (L85), claims `{sub, role, restaurant_id, type, iat, exp, jti}`. |
| `backend/app/models/usuario.py` | Enum 5 roles + restaurant_id nullable | ✅ VERIFIED | L20-27: 5 valores exactos. L43-45: `restaurant_id: Mapped[int | None]` nullable FK. |
| `backend/app/schemas/restaurante.py` | StaffRole restringido + StaffRead sin hash | ✅ VERIFIED | L40-48: 3 roles staff. L59-67: StaffRead sin `password_hash`. |
| `backend/alembic/versions/0001_initial.py` | Migración inicial reversible | ✅ VERIFIED (vía stack) | Stack UP, `alembic_version=0001` aplicado (CMD corre `alembic upgrade head`). |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `api/admin.py` | `deps/auth.py` | `Depends(require_roles(...))` / `Depends(get_tenant_scope)` | ✅ WIRED | 4 ocurrencias en admin.py (3 require_roles + 1 get_tenant_scope). |
| `api/admin.py` | `services/admin_service.py` | `admin_service.{create,list,create_staff,get_for_staff}` | ✅ WIRED | Los 4 endpoints llaman al service. |
| `admin_service.py` | `deps/auth.py` | `scope.restaurant_id` / `scope.is_super_admin` | ✅ WIRED | Filter tenant derivado del scope, no de parámetro del cliente. |
| `admin_service.py` | `models/usuario.py` | `Usuario(...)` insert | ✅ WIRED | L78-85: crea Usuario con `role=RolUsuario(body.role.value)`, `restaurant_id=restaurante_id`. |
| `main.py` | `api/admin.py` | `include_router(admin.router)` | ✅ WIRED | Router `/admin` montado. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| AUTH-01 | 02-01 | Registro cliente | ✅ SATISFIED | `test_register_cliente` + CHECK 1 |
| AUTH-02 | 02-01 | Login + refresh persistente | ✅ SATISFIED | `test_login_returns_tokens` + `test_refresh_rotates_tokens` |
| AUTH-03 | 02-02 | 5 roles distinguibles + enforcement | ✅ SATISFIED | `test_roles.py` 6/6 + matriz `require_roles` |
| AUTH-04 | 02-02 | Aislamiento multi-tenant (404 cross) | ✅ SATISFIED | HARD GATE `test_staff_cross_tenant_404` |
| PLAT-02 | 02-02 | Crear restaurantes | ✅ SATISFIED | `test_super_admin_creates_restaurante` |
| PLAT-03 | 02-02 | Crear staff asignado | ✅ SATISFIED | `test_create_staff_assigned` + invalid role 422 + FK 404 |

**Orphaned requirements:** Ninguno. Los 6 IDs del ROADMAP (AUTH-01..04, PLAT-02, PLAT-03) están mapeados y satisfechos.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `backend/app/core/security.py` | 6, 82 | "passlib" y "verify_exp.*False" en docstrings | ℹ️ Info | Comentarios documentales que explican por qué NO se usan. No son código; no impacto. Conservados intencionalmente. |
| `backend/pyproject.toml` | 20 | Mención "NOT passlib" en comment | ℹ️ Info | Igual que arriba — documentación de decisión. |

**Sin bloqueadores ni warnings.** Ningún TODO/FIXME/HACK/placeholder en el código de auth/admin. Ningún `return null` o handler vacío. Ningún `password_hash` en schemas de respuesta (0 ocurrencias en `app/schemas/`).

### Anti-Regression Security Checks

| Check | Expected | Result |
| ----- | -------- | ------ |
| `passlib` en `uv.lock` | 0 | ✅ 0 |
| `passlib` importado en código | 0 | ✅ 0 (solo 2 menciones en comments) |
| `password_hash` en `app/schemas/` | 0 | ✅ 0 |
| `verify_exp.*False` en código activo | 0 | ✅ 0 (1 mención en docstring "we NEVER pass...") |
| `create_all()` en `app/` | 0 | ✅ 0 |
| `algorithms=["HS256"]` en security.py | ≥1 | ✅ presente (L85) |

### Test Suite Execution (real)

```
$ docker compose exec -w /app api uv run pytest tests/ -v
============================= 34 passed in 10.52s ==============================
```

Desglose:
- `test_health.py` (Phase 1 regression): 1/1 ✅
- `test_db_config.py` (Phase 1 regression): 1/1 ✅
- `test_auth_flow.py` (AUTH-01/02): 12/12 ✅
- `test_admin_platform.py` (PLAT-02/03): 9/9 ✅
- `test_roles.py` (AUTH-03): 6/6 ✅
- `test_multitenant.py` (AUTH-04): 5/5 ✅ — incluye HARD GATE

**Hard gate aislado:**
```
$ docker compose exec -w /app api uv run pytest tests/test_multitenant.py::test_staff_cross_tenant_404 -v
tests/test_multitenant.py::test_staff_cross_tenant_404 PASSED
============================= 1 passed in 1.35s ===============================
```

### verify_auth.sh (19/19)

```
[CHECK 1/19]  Register cliente -> 201, role=cliente, restaurant_id=null, no password_hash
[CHECK 2/19]  Register duplicate email -> 409
[CHECK 3/19]  Login -> 200, access + refresh present
[CHECK 4/19]  Refresh -> 200 with NEW tokens (rotation)
[CHECK 5/19]  /auth/me with access -> 200, correct email
[CHECK 6/19]  /auth/me with NO token -> 401
[CHECK 7/19]  Login super_admin (from env) -> 200 with tokens
[CHECK 8/19]  POST /admin/restaurantes -> 201 with .id and .activo==true
[CHECK 9/19]  GET /admin/restaurantes -> 200 lista >= 1 (todos activos)
[CHECK 10/19] POST staff role=mesero -> 201 .role==mesero .restaurant_id==id
[CHECK 11/19] POST staff role=cliente -> 422 (staff-only enum)
[CHECK 12/19] POST staff a restaurante inexistente (999999) -> 404
[CHECK 13/19] Registrar + login cliente -> token cliente
[CHECK 14/19] POST /admin/restaurantes con token cliente -> 403
[CHECK 15/19] POST /admin/restaurantes sin token -> 401
[CHECK 16/19] Crear restaurantes A + B, mesero para A, login mesero
[CHECK 17/19] Mesero A GET /admin/restaurantes/{B} -> 404 (NO 200, NO 403)  ← HARD GATE
[CHECK 18/19] Mesero A GET /admin/restaurantes/{A} -> 200 (su propio tenant)
[CHECK 19/19] Super_admin GET /admin/restaurantes/{B} -> 200 (sin filtro tenant)
ALL CHECKS PASSED
```

### Stack Status

```
$ docker compose ps
NAME        IMAGE       STATUS                  PORTS
gri-api     cel-api     Up 7 minutes            0.0.0.0:8000->8000/tcp
gri-mysql   mysql:8.4   Up 5 hours (healthy)    0.0.0.0:3306->3306/tcp
```

CMD confirma `alembic upgrade head && uvicorn` (migración se aplica antes del boot).

### Human Verification Required

Ninguno estrictamente necesario — toda la matriz de roles + multi-tenant está cubierta por tests integration contra el stack real (no mocks). Los flujos visuales (login desde Flutter Web, app cliente) son materia de Phase 4-6, no de esta fase backend-only.

### Notas para próximas fases

- **Verdad implícita "staff sin `restaurant_id` (NULL) → 403"**: implementada en `get_tenant_scope` (L124-127) pero NO tiene test integration — la API no puede crear staff sin restaurante (`create_staff` exige FK válida), habría que sembrarlo por DB directa. Cubierto por inspección de código. Anotado para no perder el rastro (deuda conocida, ya documentada en SUMMARY 02-02).
- **Filtro `activo=True` uniforme**: `list_restaurantes` y `get_restaurante_for_staff` filtran solo activos incluso para super_admin. Gestión de inactivos diferida a Phase 8 (PLAT-05). No es gap de Phase 2.

### Gaps Summary

**Ningún gap.** Las 4 verdades críticas de la fase están verificadas con tests integration + script de aceptación manual, todos verdes. El hard gate de multi-tenant (la decisión arquitectónica más importante de la fase) pasa limpio. Todos los anti-patrones de seguridad fueron evitados (passlib, password_hash en response, verify_exp=False, create_all). Los 6 requisitos del ROADMAP están satisfechos sin huérfanos.

La fase está lista para avanzar a Phase 3 (Modelo de Dominio y Seed Demo), que repetirá el patrón `TenantScope` + `WHERE restaurant_id` para cada service staff nuevo.

---

_Verified: 2026-08-13_
_Verifier: Claude (gsd-verifier) — goal-backward verification contra código real_
