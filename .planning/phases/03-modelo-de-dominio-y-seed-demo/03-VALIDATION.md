---
phase: 3
slug: modelo-de-dominio-y-seed-demo
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest ≥8.0 + pytest-asyncio ≥0.24 (ya instalado; sin deps nuevas) |
| **Config file** | `backend/pyproject.toml` `[tool.pytest.ini_options]` (asyncio_mode="auto") |
| **Quick run command** | `uv run pytest tests/test_state_machines.py -x` (unitarios puros, sin stack) |
| **Full suite command** | `uv run pytest` (requiere stack Docker up) |
| **Estimated runtime** | ~5s unitarios / ~30s suite completa |

---

## Sampling Rate

- **After every task commit:** `uv run pytest tests/test_state_machines.py -x` (models/SM) o `uv run pytest tests/test_seed.py tests/test_domain_constraints.py -x` (seed/constraints)
- **After every plan wave:** `uv run pytest` completa (34 de Phase 1-2 como regression gate)
- **Before `/gsd:verify-work`:** suite completa verde + `verify_seed.sh` ALL CHECKS PASSED
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-* | 01 | 1 | PLAT-04 | — | seed idempotente, gate DEMO_MODE | integration DB | `uv run pytest tests/test_seed.py -x` | ❌ W0 | ⬜ pending |
| 03-01-* | 01 | 1 | MESA-02 | — | QR único global (IntegrityError) | integration DB | `uv run pytest tests/test_domain_constraints.py -k qr -x` | ❌ W0 | ⬜ pending |
| 03-01-* | 01 | 1 | INFR-03 | — | migraciones+seed automáticos en boot | scripted | `docker compose down -v && up -d --build && verify_seed.sh` | ❌ W0 (script) | ⬜ pending |
| 03-01-* | 01 | 1 | (impl) | — | state machines válidas/inválidas | unit | `uv run pytest tests/test_state_machines.py -x` | ❌ W0 | ⬜ pending |
| 03-01-* | 01 | 1 | (impl) | — | una sesión activa por mesa; CHECKs estrellas/cantidad | integration DB | `uv run pytest tests/test_domain_constraints.py -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/tests/conftest.py` — fixture `db_session` (asyncmy directo a localhost:3306) + helper compartido para parser .env
- [ ] `backend/tests/test_state_machines.py` — unitarios de MESA_TRANSITIONS y PEDIDO_TRANSITIONS (válidas, inválidas, terminales)
- [ ] `backend/tests/test_seed.py` — PLAT-04: contenido seed, idempotencia (2a corrida = mismo estado), DEMO_MODE=false no siembra
- [ ] `backend/tests/test_domain_constraints.py` — MESA-02 QR duplicado IntegrityError + formato GRI-MESA-\d{3} + unique sesión activa + CHECKs
- [ ] `backend/scripts/verify_seed.sh` — INFR-03 aceptación manual (boot limpio con volumen borrado)
- Framework install: ninguna necesaria

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Boot limpio desde cero siembra demo | INFR-03 | Destructivo (borra volumen) | `docker compose down -v && docker compose up -d --build` → `verify_seed.sh` dentro del contenedor |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
