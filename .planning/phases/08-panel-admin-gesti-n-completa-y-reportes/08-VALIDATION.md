---
phase: 8
slug: panel-admin-gesti-n-completa-y-reportes
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-14
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest + pytest-asyncio (uv), stack Docker vivo (baseline 155) |
| **Panel framework** | flutter_test (baseline 28) |
| **Quick run backend** | `uv run pytest tests/test_staff_menu.py -q` |
| **Quick run panel** | `flutter test test/menu/menu_screen_test.dart` |
| **Full suites** | `uv run pytest -q` / `flutter test` |
| **Estimated runtime** | ~45s backend / ~90s panel |

---

## Sampling Rate

- **After every task commit:** test file(s) del requisito + analyze (panel) / ruff check (backend)
- **After every plan wave:** suites full (155+new backend, 28+new panel)
- **Before `/gsd:verify-work`:** ambas suites verdes + flutter build web OK
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-* | 01 | 1 | MESA-01 | T-08-01 | mesas CRUD: QR autogen determinista, 409 dup, 404 cross-tenant, 400 super_admin sin param | integration | `uv run pytest tests/test_staff_mesas_crud.py -q` | ❌ W0 | ⬜ pending |
| 08-* | 01 | 1 | MENU-01, MENU-02 | T-08-02 | menú CRUD: 409 dup categoría, 422 precio<=0, 404 categoría ajena, toggles activo/disponible, public filtra activos | integration | `uv run pytest tests/test_staff_menu.py -q` | ❌ W0 | ⬜ pending |
| 08-* | 01 | 1 | ADMN-03 | T-08-03 | clientes: solo del tenant (JOIN), count/total con fixture, historial 404 | integration | `uv run pytest tests/test_staff_clientes.py -q` | ❌ W0 | ⬜ pending |
| 08-* | 01 | 1 | REPO-01, REPO-02 | T-08-04 | ventas solo servido|pagado; agrupación día; rango inclusive; 422 desde>hasta; top platos SUM DESC top10 tenant-scoped | integration | `uv run pytest tests/test_staff_reportes.py -q` | ❌ W0 | ⬜ pending |
| 08-* | 01 | 1 | PLAT-05 | T-08-05 | desactivar: fuera de /public, visible con incluir_inactivos, staff 403, reactivar | integration | `uv run pytest tests/test_admin_platform.py -q` (extender) | 🔁 extender | ⬜ pending |
| 08-* | 02 | 2 | MESA-01/03, MENU-01/02, ADMN-03/04, REPO-01/02, PLAT-05 (UI) | — | 5 pantallas + QR dialog + acciones mapa solo transiciones válidas + sidebar completo | widget | `cd panel_admin && flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/alembic/versions/0005_*.py` — columna activo en categoria y producto + filtro public_service
- [ ] Endpoints: POST/PATCH /staff/mesas, GET/POST/PATCH /staff/categorias, /staff/productos, GET /staff/clientes (+/{id}/historial), GET /staff/reportes/ventas, GET /staff/reportes/top-platos, PATCH /admin/restaurantes/{id} (activo)
- [ ] `backend/tests/test_{staff_mesas_crud,staff_menu,staff_clientes,staff_reportes}.py` + extender test_admin_platform.py
- [ ] `flutter pub add qr_flutter data_table_2 web` + models freezed + build_runner
- [ ] `panel_admin/lib/features/{mesas,menu,clientes,reportes,reservas,configuracion}/` + sidebar/TopBar wiring + tests

---

## Manual-Only Verifications

*None — QR dialog testeable con widget tests (QrImageView render); impresión real (window.print/Ctrl+P) queda como UAT manual documentado.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
