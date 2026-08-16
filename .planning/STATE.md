---
status: Roadmap v1 completo. Phase 10 agregada: Migracion a Firebase (Opcion B) - pendiente planear
stopped_at: "Phase 10 agregada. Decision del usuario: reemplazar MySQL+FastAPI por Firebase directo (Auth + Firestore + listeners). Pendiente: confirmar web app en Firebase console + plan de pagos. Luego /gsd-plan-phase 10"
current_phase: 10
updated: 2026-08-16
---

# STATE

## Project Reference

See: .planning/PROJECT.md

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 10 — Migracion a Firebase Opcion B (apps directas a Firestore)

## Roadmap Evolution
- Phase 10 added (2026-08-16): Migracion a Firebase Opcion B — decision del usuario tras crear proyecto Firebase p-gri-b5b40. Las apps Flutter (movil + panel web) pasan a hablar directo a Firebase Auth + Firestore con security rules; backend FastAPI (215 tests) se archiva como referencia. google-services.json (Android gri.app) en documentos/.

## Progress

Status: Phases 1-9 COMPLETE (verified). Phase 10 NOT PLANNED.

### Pendientes previos a planear Phase 10 (decision usuario)
1. Registrar Web app en Firebase console para panel_admin (solo existe Android gri.app)
2. Pagos en la migracion: Firebase Functions (webhook Wompi) o diferir

## Test Baselines (referencia MySQL — seran reemplazados)
- Backend: 215 passed (FastAPI+MySQL, se archiva)
- App cliente: 51 passed | Panel: 61 passed (UI se conserva, capa datos se reescribe)
