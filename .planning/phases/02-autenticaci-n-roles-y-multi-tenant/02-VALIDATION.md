---
phase: 2
slug: autenticaci-n-roles-y-multi-tenant
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-13
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 9.1.1 + pytest-asyncio 1.4.0 + httpx 0.28.1 (instalado en Phase 1) |
| **Config file** | `backend/pyproject.toml` `[tool.pytest.ini_options]` (asyncio_mode="auto") |
| **Quick run command** | `cd backend && uv run pytest tests/ -x` |
| **Full suite command** | `cd backend && uv run pytest tests/ -v` |
| **Estimated runtime** | ~30 seconds (requiere stack Docker corriendo con migración aplicada) |

---

## Sampling Rate

- **After every task commit:** Run `cd backend && uv run pytest tests/ -x`
- **After every plan wave:** Run `docker compose up -d --build` + full suite + `scripts/verify_auth.sh`
- **Before `/gsd:verify-work`:** Full suite verde AND `verify_auth.sh` verde. **Hard gate: `test_staff_cross_tenant_404`** (AUTH-04 es el requisito de mayor riesgo)
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-* | 01 | 1 | AUTH-01, AUTH-02 | T-02-01 | register no expone password_hash; login/refresh validan tipo de token | integration | `uv run pytest tests/test_auth_flow.py -x` | ❌ W0 | ⬜ pending |
| 02-01-* | 01 | 1 | AUTH-03 | T-02-02 | role enforcement 401/403 | integration | `uv run pytest tests/test_roles.py -x` | ❌ W0 | ⬜ pending |
| 02-01-* | 01 | 1 | AUTH-04 | T-02-03 | cross-tenant = 404 (hard gate) | integration | `uv run pytest tests/test_multitenant.py -x` | ❌ W0 | ⬜ pending |
| 02-01-* | 01 | 1 | PLAT-02, PLAT-03 | T-02-04 | solo super_admin crea restaurantes/staff; roles staff válidos | integration | `uv run pytest tests/test_admin_platform.py -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/tests/conftest.py` — MODIFY: helpers `register_cliente`, `login -> (access, refresh)`, `auth_header`, fixture `super_admin_token` (env SUPER_ADMIN_EMAIL/PASSWORD)
- [ ] `backend/tests/test_auth_flow.py` — AUTH-01/02: register (201, sin password_hash), duplicate 409, login tokens, wrong password 401, refresh rotación, refresh rechaza access token, /me 200 y 401
- [ ] `backend/tests/test_roles.py` — AUTH-03: cliente→admin 403, no-token 401
- [ ] `backend/tests/test_multitenant.py` — AUTH-04: cross-tenant 404, own-tenant 200, super_admin sin filtro
- [ ] `backend/tests/test_admin_platform.py` — PLAT-02/03: crear restaurante 201 con campos, staff asignado 201, rol inválido 422, restaurante inexistente 404
- [ ] `backend/scripts/verify_auth.sh` — aceptación manual curl (happy + sad paths)
- [ ] Stack precondition: Docker up + `.env` con JWT_SECRET/SUPER_ADMIN_EMAIL/SUPER_ADMIN_PASSWORD + `alembic upgrade head` (Dockerfile CMD)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bootstrap super-admin al primer arranque | PLAT-03 | Requiere arranque limpio del stack | `verify_auth.sh`: login con credenciales env → 200 con tokens |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
