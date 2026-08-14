---
phase: 7
slug: tiempo-real-websockets
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-14
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest + pytest-asyncio + httpx-ws >=0.9.0 (WS tests contra stack Docker vivo) |
| **Backend quick run** | `cd backend && uv run pytest tests/test_ws.py -x -q` |
| **Backend full suite** | `cd backend && uv run pytest tests/ -q` (baseline 141) |
| **Flutter apps** | `cd app_cliente && flutter test` / `cd panel_admin && flutter test` |
| **Estimated runtime** | ~45s backend (WS) / ~60s por app flutter |

---

## Sampling Rate

- **After every task commit:** suite del módulo tocado (test_ws.py backend; feature flutter)
- **After every plan wave:** suite backend completa (141 regression) + flutter test ambas apps + analyze
- **Before `/gsd:verify-work`:** las 3 suites verdes + test de aislamiento cross-tenant WS + reconexión (fake close → re-sync GET llamado)
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-* | 01 | 1 | RT-01, RT-02 (backend) | T-07-01 | WS auth JWT (4401 close inválido), rooms aisladas cross-tenant, eventos con seq, NO Depends(get_session) en WS | integration WS | `uv run pytest tests/test_ws.py -x -q` | ❌ W0 | ⬜ pending |
| 07-* | 02 | 2 | RT-01, RT-02 (panel) | — | cocina + mapa mesas + stats en vivo (kick-to-refetch), reconexión backoff | widget | `cd panel_admin && flutter test` | ❌ W0 | ⬜ pending |
| 07-* | 03 | 2 | RT-01, RT-03 (cliente) | — | pedido en vivo + reconexión con re-sync + dedup seq | widget | `cd app_cliente && flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/pyproject.toml` — añadir httpx-ws (dev) para tests WS
- [ ] `backend/app/core/broadcaster.py` (o realtime/) — Broadcaster interface + InMemoryBroadcaster + seq por room
- [ ] `backend/app/api/ws.py` — /ws/staff?token= + /ws/cliente?token= (auth manual async_session_maker corto, 4401)
- [ ] Emisiones en pedido_service / sesion_service / staff_service (6 eventos mapeados)
- [ ] `backend/tests/test_ws.py` — conexión, eventos, aislamiento, 4401, seq
- [ ] `app_cliente/lib/core/ws_client.dart` + provider real-time + tests (reconexión fake)
- [ ] `panel_admin/lib/core/ws_client.dart` + integración cocina/mapa/stats + tests
- [ ] `backend/app/core/db.py` — pool_recycle=3600 (mitigación W01)

---

## Manual-Only Verifications

*None — WS testeable con httpx-ws; reconexión real (wifi off/on) queda como UAT manual documentado (tests usan fakes).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
