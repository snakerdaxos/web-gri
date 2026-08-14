---
phase: 6
slug: app-cliente-pedido-por-qr-rest-y-vista-cocina
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-14
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest + pytest-asyncio (httpx AsyncClient vs stack Docker) |
| **Backend quick run** | `cd backend && uv run pytest tests/test_sesion_mesa.py -x -q` |
| **Backend full suite** | `cd backend && uv run pytest tests/ -q` (baseline 105) |
| **Flutter app** | `cd app_cliente && flutter test` |
| **Panel** | `cd panel_admin && flutter test` |
| **Estimated runtime** | ~30s backend / ~60s cada app flutter |

---

## Sampling Rate

- **After every task commit:** suite del módulo tocado (backend archivo específico; flutter feature)
- **After every plan wave:** suite backend completa (105 regression) + flutter test ambas apps + flutter analyze 0 issues
- **Before `/gsd:verify-work`:** las 3 suites verdes + concurrencia sesión (2 sesiones misma mesa → 1×201+1×409)
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-* | 01 | 1 | MESA-05, MESA-06 | T-06-01 | sesión: QR válido abre+mesa ocupada; inválido 404; ajeno 409; propio idempotente; única activa (concurrencia 1×201+1×409) | integration | `uv run pytest tests/test_sesion_mesa.py -x -q` | ❌ W0 | ⬜ pending |
| 06-* | 01 | 1 | PEDI-01, PEDI-02 | T-06-02 | pedido: total server-side, snapshot precio, agotado 409, cross-tenant producto 404, sesión requerida | integration | `uv run pytest tests/test_cliente_pedidos.py -x -q` | ❌ W0 | ⬜ pending |
| 06-* | 01 | 1 | PEDI-03, PEDI-05, PEDI-06 | T-06-03 | transiciones válidas 200/inválidas 409; matriz roles (mesero solo servido); cola tenant-scoped | integration | `uv run pytest tests/test_staff_pedidos.py -x -q` | ❌ W0 | ⬜ pending |
| 06-* | 01 | 1 | PAGO-01 | T-06-04 | cuenta: flag+solicitada_en, idempotente, visible en cola staff | integration | `uv run pytest tests/test_cuenta.py -x -q` | ❌ W0 | ⬜ pending |
| 06-* | 02 | 2 | MESA-05/06, PEDI-01/02/04, PAGO-01 (UI) | — | scan fallback input + banner mesa, carrito, chips estado, botón cuenta | widget | `cd app_cliente && flutter test` | ❌ W0 | ⬜ pending |
| 06-* | 03 | 2 | ADMN-05 | — | cola cocina: cards mesa/items/total/badge cuenta; avanzar estado; mesero solo Servido | widget | `cd panel_admin && flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/alembic/versions/0004_*.py` — pedido.sesion_id FK + sesion.solicita_cuenta/solicitada_en + UNIQUE sesión activa por usuario
- [ ] `backend/app/api/cliente.py` (EXTENDER: sesiones, pedidos, cuenta) + `services/{sesion_service,pedido_service}.py` + `schemas/{sesion,pedido}.py`
- [ ] `backend/app/api/staff.py` (EXTENDER: GET /staff/pedidos, POST /staff/pedidos/{id}/estado)
- [ ] `backend/tests/test_{sesion_mesa,cliente_pedidos,staff_pedidos,cuenta}.py` + helpers conftest (abrir_sesion, login staff demo cocina/mesero)
- [ ] `app_cliente/lib/features/{sesion_qr,pedidos}/` + tests (scan_test, carrito_test, estado_test, cuenta_test)
- [ ] `panel_admin/lib/features/cocina/` + test/cocina/cola_test.dart

---

## Manual-Only Verifications

*None automatizado-excluido. Nota: el escaneo con cámara real (mobile_scanner en dispositivo) queda como UAT manual documentado — el input manual GRI-MESA-XXX es vía primera clase cubierta por widget tests.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
