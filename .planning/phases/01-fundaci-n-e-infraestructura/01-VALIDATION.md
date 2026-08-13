---
phase: 1
slug: fundaci-n-e-infraestructura
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 8.x + pytest-asyncio 0.24+ + httpx 0.28+ |
| **Config file** | `backend/pyproject.toml` `[tool.pytest.ini_options]` (asyncio_mode="auto") |
| **Quick run command** | `cd backend && uv run pytest tests/ -x` |
| **Full suite command** | `cd backend && uv run pytest tests/ -v` |
| **Estimated runtime** | ~10 seconds (smoke, requiere stack corriendo) |

---

## Sampling Rate

- **After every task commit:** Run `cd backend && uv run pytest tests/ -x`
- **After every plan wave:** Run `docker compose up -d --build` + full suite + `curl :8000/health`
- **Before `/gsd:verify-work`:** Script manual `verify_infra.sh` (persistencia + env-swap) verde
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | INFR-01 | — | N/A | integration | `cd backend && uv run pytest tests/test_db_config.py -x` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | INFR-02 | — | N/A | smoke | `cd backend && uv run pytest tests/test_health.py -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/tests/conftest.py` — fixture httpx AsyncClient apuntando a `http://localhost:8000` (asume stack corriendo)
- [ ] `backend/tests/test_health.py` — `GET /health` asserts 200 + `"database":"connected"` (INFR-02)
- [ ] `backend/tests/test_db_config.py` — conecta vía asyncmy, asserts `@@character_set_database='utf8mb4'`, `@@global.time_zone='-05:00'`, round-trip de `'Açaí 🍜'` (INFR-01)
- [ ] `uv add --dev pytest pytest-asyncio httpx` — no existe infra de tests aún
- [ ] `backend/scripts/verify_infra.sh` — script de aceptación manual (persistencia + env-swap)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Datos sobreviven reinicio de contenedor | INFR-01 | Orquestación compose lenta (>30s) | `verify_infra.sh` paso 3: crear fila, `docker compose restart mysql`, verificar fila |
| Cambiar `.env` cambia la conexión | INFR-02 | Requiere compose re-up | `verify_infra.sh` paso 4: DB_NAME inválido → `/health` responde 503 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
