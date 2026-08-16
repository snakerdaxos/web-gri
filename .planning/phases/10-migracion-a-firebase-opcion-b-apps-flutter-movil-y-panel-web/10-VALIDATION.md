---
phase: 10
slug: migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-16
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **App cliente** | flutter test con fake_cloud_firestore 4.2.0 + firebase_auth_mocks 0.15.2 (baseline 51 a portear) |
| **Panel** | flutter test con mismos fakes (baseline 61 a portear) |
| **State machines** | port 1:1 desde Python — tests unitarios puros |
| **Rules** | firebase emulators (auth+firestore) — verificación manual/scripted documentada; suite formal @firebase/rules-unit-testing DEFER v1 |
| **Seed** | script Node firebase-admin contra emuladores primero, luego proyecto real |
| **Estimated runtime** | ~60-90s por app flutter; emuladores ~30s arranque |

---

## Sampling Rate

- **After every task commit:** flutter test del feature tocado + analyze
- **After every plan wave:** flutter test completo de la app migrada + analyze 0 issues
- **Before `/gsd:verify-work`:** ambas apps verdes + smoke contra emuladores con seed (login demo → reservar → QR → pedido → cocina avanza → cuenta → calificar) + firebase deploy --only firestore (rules+indexes) al proyecto real
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-* | 01 | 1 | Infra+auth | T-10-01 | claims {role,rid} autorizan; doc usuarios espejo NUNCA autoriza; roles inmutables client-side | unit+widget (fakes) | `cd app_cliente && flutter test` | ❌ W0 | ⬜ pending |
| 10-* | 02 | 2 | Reservas+sesión+pedidos | T-10-02 | tx runTransaction con doc IDs deterministas (reserva slot única, sesión una por mesa); state machine port 1:1 | unit+widget (fakes) | `cd app_cliente && flutter test` | ❌ W0 | ⬜ pending |
| 10-* | 03 | 3 | Panel completo | T-10-03 | mismo esquema de rules; realtime onSnapshot | unit+widget (fakes) | `cd panel_admin && flutter test` | ⬜ portear | ⬜ pending |
| 10-* | 04 | 4 | Rules+seed+deploy | T-10-04 | rules despliegue al proyecto p-gri-b5b40; seed idempotente; emuladores smoke | scripted+manual | `firebase deploy --only firestore` + smoke doc | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `flutterfire configure` en ambas apps (android app_cliente + web ambas) → firebase_options.dart
- [ ] Deps: firebase_core 4.13.0, firebase_auth 6.5.7, cloud_firestore 6.8.0, fake_cloud_firestore 4.2.0, firebase_auth_mocks 0.15.2 (dev)
- [ ] `shared/state_machines.dart` port desde Python + tests porteados
- [ ] `firestore.rules` (~130 líneas del research) + `firestore.indexes.json`
- [ ] `scripts/seed_firebase.mjs` (firebase-admin, idempotente, claims) + serviceAccountKey gitignored
- [ ] firebase.json (emuladores + deploy config) + guía emuladores README
- [ ] BORRAR tras migrar cada app: ws_client, token_provider, api_client, env (y sus tests)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rules reales en p-gri-b5b40 | Seguridad | Deploy con firebase CLI (login usuario) | firebase deploy --only firestore → intentar write prohibido desde consola |
| Seed en proyecto real | Datos demo | Service account + proyecto real | node scripts/seed_firebase.mjs (con credenciales reales) → verificar en console |
| Smoke e2e con emuladores | Flujos | UI real contra emuladores | firebase emulators:start + app con useEmulator → flujo completo documentado |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify
- [x] Sampling continuity
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
