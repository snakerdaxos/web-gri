---
phase: 9
slug: pagos-calificaciones-y-deploy
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-14
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest + pytest-asyncio (stack Docker vivo, baseline 181) |
| **App cliente** | flutter test (baseline 41) |
| **Panel** | flutter test (baseline 61 — sin cambios esperados) |
| **Quick run backend** | `uv run pytest tests/test_pagos.py -x -q` |
| **Quick run cliente** | `cd app_cliente && flutter test test/pagos/` |
| **Estimated runtime** | ~45s backend / ~60s flutter |

---

## Sampling Rate

- **After every task commit:** suite del módulo tocado + analyze
- **After every plan wave:** backend full (181 regression) + flutter cliente full
- **Before `/gsd:verify-work`:** suites verdes + e2e sandbox (aprobar pago → efectos verificables) + docker compose -f prod config válido
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-* | 01 | 1 | PAGO-02, PAGO-03 | T-09-01 | intención con monto server-side + integrity signature; webhook firma timing-safe; idempotencia transaction.id:status UNIQUE + no-op terminal | integration | `uv run pytest tests/test_pagos.py -x -q` | ❌ W0 | ⬜ pending |
| 09-* | 01 | 1 | PAGO-04 | T-09-02 | pago aprobado: pedido→pagado, sesión cerrada, mesa→limpieza (misma tx) + WS emits | integration | `uv run pytest tests/test_pagos.py -k efectos -v` | ❌ W0 | ⬜ pending |
| 09-* | 01 | 1 | CALI-01, CALI-02 | T-09-03 | calificación solo post-pago (409 dup, 404 ajeno); promedio en /public | integration | `uv run pytest tests/test_calificaciones.py -x -q` | ❌ W0 | ⬜ pending |
| 09-* | 02 | 2 | PAGO-02, CALI-01 (UI) | — | pantalla pago + checkout launch + polling + success → calificación estrellas; rating real en lista restaurantes | widget | `cd app_cliente && flutter test` | ❌ W0 | ⬜ pending |
| 09-* | 03 | 3 | INFR (deploy) | T-09-04 | nginx conf válida (nginx -t), compose prod config válida, guía completa, sandbox 404 en prod mode | config/scripts | `docker compose -f deploy/docker-compose.prod.yml config -q` + nginx -t en contenedor | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/alembic/versions/0006_*.py` — pago.sesion_id NOT NULL + pedido_id nullable + transaction_id unique + tabla pago_event
- [ ] `backend/app/services/pago_service.py` + `core/gateways/{base,wompi_gateway,sandbox_gateway}.py` + `api/pagos.py` + `api/webhooks.py` + schemas
- [ ] Sandbox checkout: GET /pagos/sandbox/{referencia} (HTML aprobar/rechazar, SOLO SANDBOX_MODE)
- [ ] CALI endpoints: POST /cliente/calificaciones + promedio en public_service
- [ ] `backend/tests/test_{pagos,calificaciones}.py`
- [ ] `app_cliente`: url_launcher, features/pagos/, features/calificacion/, rating en restaurantes
- [ ] `deploy/`: docker-compose.prod.yml, nginx/gri.conf, .env.production.example, README.md guía Ubuntu

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Checkout real Wompi | PAGO-02 | Requiere credenciales merchant (KYC pendiente) | Tras obtener keys: SANDBOX_MODE=false + env vars → flujo idéntico (documentado en deploy/README) |
| Deploy real a Ubuntu Server | INFR | Sin acceso SSH desde dev | Seguir deploy/README.md paso a paso (guía completa) |
| TLS/certbot | INFR | Requiere dominio real | certbot --nginx según guía |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
