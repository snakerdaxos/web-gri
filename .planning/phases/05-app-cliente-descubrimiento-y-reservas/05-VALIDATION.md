---
phase: 5
slug: app-cliente-descubrimiento-y-reservas
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-13
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest 8.x + pytest-asyncio (asyncio_mode="auto") — ya configurado |
| **Backend quick run** | `cd backend && uv run pytest tests/test_reserva.py -v` |
| **Backend full suite** | `cd backend && uv run pytest tests/ -v` (baseline 70 Phase 4) |
| **Frontend framework** | `flutter test` (widget tests) — Wave 0 crea app_cliente/ |
| **Frontend quick run** | `cd app_cliente && flutter test` |
| **Estimated runtime** | ~20s backend / ~90s flutter test |

---

## Sampling Rate

- **After every task commit:** test file(s) específicos que la tarea tocó
- **After every plan wave:** suite backend completa (regression 70) + flutter test verde
- **Before `/gsd:verify-work`:** backend verde + flutter verde + HARD GATE `test_reserva_concurrency.py` (10 POSTs concurrentes mismo slot → 1×201 + 9×409)
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-* | 01 | 1 | RESV-02 | T-05-01 | concurrencia slot — UNIQUE + FOR UPDATE + IntegrityError→409 | integration concurrent | `uv run pytest tests/test_reserva_concurrency.py -v` | ❌ W0 | ⬜ pending |
| 05-* | 01 | 1 | REST-01/02, RESV-01/03/04 | T-05-02..05 | /public/* + /cliente/* (NO get_tenant_scope — cliente via get_current_user+require_roles); cross-user existence hiding 404 | integration | `uv run pytest tests/test_public_read.py tests/test_reserva.py tests/test_cliente_perfil.py -v` | ❌ W0 | ⬜ pending |
| 05-* | 02 | 2 | RESV-05, MESA-04 | T-05-06 | /staff/* tenant-scoped (cross-tenant 404); MESA_TRANSITIONS válidas/inválidas 409 | integration | `uv run pytest tests/test_staff_reservas.py tests/test_mesa_estado.py -v` | ❌ W0 | ⬜ pending |
| 05-* | 03 | 3 | AUTH-05, REST-01, REST-02, RESV-01, RESV-03 | — | app móvil Flutter: login+perfil, lista restaurantes, detalle menú, wizard reserva, mis reservas | widget | `cd app_cliente && flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/alembic/versions/0003_*.py` — UNIQUE (mesa_id, fecha, hora_inicio)
- [ ] `backend/app/api/public.py` + `services/public_service.py` + `schemas/menu.py` (con @field_serializer precio → float)
- [ ] `backend/app/api/cliente.py` + `services/reserva_service.py` (con FOR UPDATE) + `services/cliente_service.py` + `schemas/reserva.py` + `schemas/perfil.py`
- [ ] `backend/app/api/staff.py` (EXTENDER) — GET /staff/reservas, POST /staff/mesas/{id}/estado
- [ ] `backend/app/main.py` — CORS añadir http://localhost:5174 + include_router public/cliente
- [ ] `backend/tests/test_{public_read,reserva,reserva_concurrency,cliente_perfil,staff_reservas,mesa_estado}.py`
- [ ] `app_cliente/` scaffold (platforms android,web) copiando lib/core/ de panel_admin + deps + build_runner
- [ ] `app_cliente/test/` widget tests (auth/perfil, restaurantes/list, reservas/wizard, reservas/mis_reservas_render)

---

## Manual-Only Verifications

*None — todos los requisitos tienen test automatizado. La concurrencia (RESV-02) se valida exclusivamente con test_reserva_concurrency.py (PITFALLS P1).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
