---
phase: 4
slug: panel-admin-login-dashboard-y-mapa-solo-lectura
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-13
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest 8.x + pytest-asyncio (asyncio_mode="auto") — ya configurado |
| **Backend quick run** | `cd backend && uv run pytest tests/test_staff_read.py -v` |
| **Backend full suite** | `cd backend && uv run pytest tests/ -v` (baseline 59) |
| **Frontend framework** | `flutter test` (widget tests) — Wave 0 crea panel_admin/ |
| **Frontend quick run** | `cd panel_admin && flutter test` |
| **Estimated runtime** | ~15s backend / ~60s flutter test |

---

## Sampling Rate

- **After every task commit:** pytest test_staff_read.py y/o flutter test según la tarea
- **After every plan wave:** suite backend completa (regression 59) + flutter test verde
- **Before `/gsd:verify-work`:** backend verde + flutter verde + UAT manual (login admin@demo.gri.dev / Demo!1234 → dashboard con stats y mapa) + flip manual de estado de mesa (SQL) con verificación de color
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-* | 01 | 1 | ADMN-01/02 | T-04-01 | /staff/* tenant-scoped, cross-tenant 404 | integration | `uv run pytest tests/test_staff_read.py -v` | ❌ W0 | ⬜ pending |
| 04-* | 02 | 2 | PLAT-01 | — | login form valida + llama /auth/login | widget | `cd panel_admin && flutter test test/auth/login_form_test.dart` | ❌ W0 | ⬜ pending |
| 04-* | 02 | 2 | ADMN-01 | — | dashboard renderiza 4 stat cards | widget | `cd panel_admin && flutter test test/dashboard/stats_render_test.dart` | ❌ W0 | ⬜ pending |
| 04-* | 02 | 2 | ADMN-02 | — | tile color por estado (4 colores) | widget | `cd panel_admin && flutter test test/dashboard/mesa_tile_color_test.dart` | ❌ W0 | ⬜ pending |
| 04-* | 01 | 1 | CORS | — | preflight :5173 → ACAO header | integration | `uv run pytest tests/test_cors.py -v` | ❌ W0 | ⬜ pending |
| 04-* | 02 | 2 | ADMN-02 | — | flip estado en BD → color cambia al refrescar | manual e2e | docker exec SQL + visual | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Flutter SDK on PATH — 3.47.0 instalado en C:\src\flutter (verificado con flutter doctor)
- [ ] `panel_admin/` scaffolded (`flutter create --platforms=web`) + deps (riverpod, go_router, dio, flutter_secure_storage, flutter_dotenv) + build_runner
- [ ] `backend/app/main.py` — CORSMiddleware (origins explícitos, allow_credentials sin wildcard)
- [ ] `backend/app/api/staff.py` + `services/staff_service.py` + `schemas/{mesa,dashboard}.py`
- [ ] `backend/tests/test_staff_read.py` — mesas/stats own-tenant + cross-tenant 404
- [ ] `backend/tests/test_cors.py` — preflight allowed origin
- [ ] `panel_admin/test/auth/login_form_test.dart` + `panel_admin/test/dashboard/*_test.dart` — widget tests con mockApiClient override

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Login real contra API + sesión persiste (refresh página) | PLAT-01 | E2E browser | flutter run -d chrome --web-port=5173 → login demo staff → F5 → sigue logueado |
| Color de mesa cambia al flip BD | ADMN-02 | Fase read-only sin endpoint de mutación | `docker exec gri-mysql mysql ... UPDATE mesa SET estado='ocupada' WHERE numero=2` → refresh panel → tile rojo |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
