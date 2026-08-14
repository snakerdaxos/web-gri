---
phase: 05-app-cliente-descubrimiento-y-reservas
verified: 2026-08-14T12:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
human_verification:
  - test: "Journey completo en Chrome (flutter run -d chrome --web-port=5174)"
    expected: "Login carlos@demo.gri.dev/Demo!1234 → home → restaurantes → detalle con menú COP → wizard reserva → SnackBar '¡Reserva confirmada! Mesa N' → mis reservas (próximas/pasadas + cancelar con dialog) → perfil (nombre editable, email disabled, logout)"
    why_human: "Flujo visual, look & feel del mockup y persistencia de sesión (F5) no verificables por grep/CLI"
  - test: "Marcar mesa ocupada como staff en runtime real"
    expected: "POST /staff/mesas/{id}/estado con reservada→ocupada responde 200; inválida (limpieza→ocupada) responde 409 sin drift"
    why_human: "Cubierto por tests automatizados, pero conviene ejercicio manual con token de admin real (curl/Bruno) para el flujo 'cliente llega → mesa ocupada'"
---

# Phase 5: App Cliente — Descubrimiento y Reservas Verification Report

**Phase Goal:** Un cliente descubre restaurantes y completa el ciclo de reserva (buscar → reservar → consultar → cancelar → sentarse)
**Verified:** 2026-08-14T12:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Registro/login app móvil + perfil (nombre/password editables, email immutable) | ✓ VERIFIED | Login runtime 200 (carlos@demo.gri.dev); `POST /auth/login` + redirect guard + register con auto-login en Flutter; `PerfilUpdate` con `extra="forbid"` (email → 422, schemas/perfil.py:19); GET/PATCH `/cliente/perfil` en openapi; `require_roles(RolUsuario.cliente)` sin `get_tenant_scope` (api/cliente.py:32-85); tests perfil 2/2 + Flutter 5 auth + 3 perfil |
| 2 | Lista restaurantes activos + detalle con menú (precio float COP) | ✓ VERIFIED | `GET /public/restaurantes` sin auth → 200 con 'Restaurante Demo GRI'; filtro `activo=True` (public_service.py:46) + 404 inactivos; detalle con categorías/productos, precio `11000.0` float (test_precio_is_float PASSED); Flutter: lista con rating "—", detalle ExpansionTiles + formatCOP |
| 3 | Reserva anti-sobre-reservas BAJO CONCURRENCIA (HARD GATE) | ✓ VERIFIED | `test_reserva_concurrency.py::test_concurrent_reservas_same_slot_only_one_wins` PASSED (10 POSTs concurrentes → 1×201 + 9×409); `with_for_update()` (reserva_service.py:103) + IntegrityError → 409 (:173) + migración 0003 UNIQUE (mesa_id, fecha, hora_inicio); runtime: POST mismo slot asigna OTRA mesa (comportamiento correcto de asignación automática) |
| 4 | Consultar reservas propias + cancelar futura (reverte mesa solo si reservada) | ✓ VERIFIED | Runtime: GET `/cliente/reservas` lista propia; POST cancelar → 200 estado=cancelada (ids 177/178/179, residuo de verificación limpiado); código: existence hiding 404 ajena, 400 pasada, `validar_transicion` reserva, Pitfall 4 reverte mesa SOLO si `EstadoMesa.reservada` (reserva_service.py:229-232); Flutter: mis_reservas split próximas/pasadas + dialog cancelar |
| 5 | Staff ve reservas del día + marca mesa ocupada; transiciones inválidas → 409 | ✓ VERIFIED (backend) | openapi live: `/staff/reservas` + `/staff/mesas/{mesa_id}/estado`; `list_reservas_by_fecha` con `_resolve_rid` + `func.curdate()` DB-side; `set_mesa_estado` → `validar_transicion("mesa",...)` (staff_service.py:158) → 409; 10/10 tests staff (tenant isolation, cross-tenant 404, 409 sin drift); **caveat:** UI del panel que consume estos endpoints se defiere a Phase 7/8 (ver Issues) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/app/api/public.py` | GET /public/restaurantes{,/{id}} sin auth | ✓ VERIFIED | En openapi runtime + 7 tests |
| `backend/app/api/cliente.py` | Reservas + perfil con require_roles(cliente) | ✓ VERIFIED | 5 endpoints, 0 menciones a get_tenant_scope |
| `backend/app/services/reserva_service.py` | FOR UPDATE + IntegrityError 409 + cancelar Pitfall 4 | ✓ VERIFIED | Líneas 103, 173, 229-232 |
| `backend/alembic/versions/0003_reserva_unique_slot.py` | UNIQUE (mesa_id, fecha, hora_inicio) | ✓ VERIFIED | HARD GATE pasa contra MySQL real |
| `backend/app/api/staff.py` | GET /reservas + POST /mesas/{id}/estado | ✓ VERIFIED | Presente en openapi live |
| `app_cliente/lib/app.dart` | StatefulShellRoute.indexedStack 4 branches | ✓ VERIFIED | Línea 71 + navigationShell en app_shell.dart |
| `app_cliente/lib/features/reservas/*` | Wizard + mis_reservas + controller/provider | ✓ VERIFIED | horasSlot :00 12-21, esProxima split, cancel con dialog |
| `app_cliente/lib/features/perfil/*` | Perfil edit + email disabled + logout | ✓ VERIFIED | perfil_controller PATCH /cliente/perfil |
| `app_cliente/test/*` | 19 widget tests | ✓ VERIFIED | 19/19 passed (~2s) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| api_client.dart | /public/restaurantes | dio get | ✓ WIRED | api_client.dart:75,84 |
| api_client.dart | /cliente/reservas CRUD | dio get/post | ✓ WIRED | :90,101,110 |
| auth_controller | registro → login → JWTs | dio + auth_storage | ✓ WIRED | auto-login post-registro, 5 tests |
| restaurantes_provider | api_client.public* | family providers | ✓ WIRED | .g.dart generado + screens consumen |
| reserva_controller | create/cancel + invalidate | api_client | ✓ WIRED | 409 → mensaje user-friendly |
| staff.py | staff_service + validar_transicion | Depends + import | ✓ WIRED | TransicionInvalidaError → 409 en router |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUTH-05 | 05-01, 05-03 | Perfil ver/editar cliente | ✓ SATISFIED | PATCH perfil extra=forbid email; UI perfil Flutter |
| REST-01 | 05-01, 05-03 | Lista restaurantes activos | ✓ SATISFIED | /public sin auth + activo=True + UI lista |
| REST-02 | 05-01, 05-03 | Detalle con menú | ✓ SATISFIED | Categorías/productos anidados, precio float |
| RESV-01 | 05-01, 05-03 | Reservar fecha/hora/personas | ✓ SATISFIED | POST 201 runtime + wizard UI slots :00 |
| RESV-02 | 05-01 | Sin sobre-reservas concurrentes | ✓ SATISFIED | HARD GATE PASSED + UNIQUE slot |
| RESV-03 | 05-01, 05-03 | Consultar reservas próximas/pasadas | ✓ SATISFIED | GET lista runtime + split esProxima |
| RESV-04 | 05-01, 05-03 | Cancelar reserva futura | ✓ SATISFIED | 200 runtime + Pitfall 4 + dialog UI |
| RESV-05 | 05-02 | Admin ve reservas del día + marca ocupada | ✓ SATISFIED (backend) | /staff/reservas + /staff/mesas/{id}/estado, 4+6 tests |
| MESA-04 | 05-02 | Estados mesa con transiciones válidas | ✓ SATISFIED | validar_transicion → 409, sin drift |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| home_screen.dart | 152 | SnackBar 'Próximamente' (placeholder QR) | ℹ️ Info | Documentado como placeholder para Phase 6 (mobile_scanner) |
| staff_service.py | 147 | "TODO lo anterior" (falso positivo) | ℹ️ Info | Docstring en español, no es marcador TODO |

### Issues / Warnings (no bloqueantes)

1. **⚠️ Residuo de tests en BD dev:** `/public/restaurantes` devuelve 229 restaurantes y el restaurante demo tiene 82 categorías — residuo acumulado de tests que crean restaurantes/menús vía `/admin` sin cleanup. El código filtra `activo=True` correctamente; es higiene del entorno dev. **Sugerencia:** truncar residuo (o re-seed) antes de UAT/demo para que la lista del cliente muestre solo el restaurante demo.
2. **⚠️ UI del panel no consume endpoints staff nuevos:** `panel_admin` no llama `/staff/reservas` ni `POST /staff/mesas/{id}/estado`. El roadmap difiere explícitamente el cambio de estado de mesa en el mapa a **Phase 8 criterio 3** y el mapa en vivo a Phase 7 — pero la vista "reservas del día en el panel" del success criterion 5 no tiene dueño explícito en fases posteriores. **Acción sugerida:** enrutarla a Phase 8 (o refinamiento) vía `/gsd-phase`.
3. **ℹ️ Roadmap checkbox 05-03 sin marcar:** el plan 05-03 está DONE (SUMMARY + commits eb3522e..65b76bb verificados en git log) pero en ROADMAP.md figura `[ ]`. Sincronizar estado.
4. **ℹ️ Traceability en REQUIREMENTS.md:** AUTH-05, REST-01/02, RESV-01..04 siguen "Pending" en la tabla pese a estar implementados y testeados (MESA-04/RESV-05 sí se marcaron). Actualizar al cerrar la fase.
5. **ℹ️ Conteo docs 05-01:** SUMMARY dice "3 concurrency tests" pero `test_reserva_concurrency.py` contiene 1 test (el HARD GATE, que pasa). Inaccuracia documental menor.

### Evidence Summary (ejecutado hoy)

| Check | Resultado |
|-------|-----------|
| `docker compose exec api uv run pytest tests/ -q` | **105 passed** in 23.00s |
| `pytest tests/test_reserva_concurrency.py -v` (HARD GATE) | **1 passed** (10 concurrentes → 1×201 + 9×409) |
| Runtime: login → /public (sin auth) → detalle → POST reserva → cancelar | 200 / 200 con demo / precio float / **201 confirmada mesa 1** / **200 cancelada** |
| Runtime: 2º POST mismo slot | 201 en **mesa distinta** (asignación automática correcta; overbooking por-mesa-slot bloqueado por HARD GATE) |
| `flutter test` (app_cliente) | **19/19 passed** |
| `flutter analyze` | **No issues found** |
| Commits 34f6793, b5e5948, 0454d35, da8ec8e, eb3522e, 27dcd4c, ec580b3, 1b8dafd, 65b76bb | Presentes en git log |

### Human Verification Required (UAT manual — no bloqueante)

1. **Journey completo web**: `cd app_cliente; $env:Path += ";C:\src\flutter\bin"; flutter run -d chrome --web-port=5174` → login demo → wizard → confirmar → cancelar → perfil → F5 persiste sesión. *(Visual/UX, no automatizable.)*
2. **Flujo staff "cliente llega"**: con token admin, marcar mesa reservada → ocupada y validar 409 en transición inválida. *(Cubierto por tests; ejercicio manual recomendado.)*

### Gaps Summary

Sin gaps. Los 5 must-haves del goal están verificados con evidencia runtime + tests + código. Los 5 issues listados son advertencias de higiene/sync de estado y una deferral de UI del panel ya contemplada (parcialmente) en el roadmap — ninguna bloquea el goal de la fase.

---

_Verified: 2026-08-14T12:30:00Z_
_Verifier: Claude (gsd-verifier)_
