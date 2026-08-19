---
status: Phase 10 (Migracion Firebase Opcion B) ejecutada y verificada — checkpoint humano pendiente (deploy real + smoke)
stopped_at: "Checkpoint humano: seguir docs/SMOKE-E2E.md (deploy rules + seed real + smoke). Resume-signal: approved. Luego: milestone v2 Firebase"
current_phase: 10 (verificada, sellado humano pendiente)
updated: 2026-08-16
---

# STATE

## Project Reference

See: .planning/PROJECT.md

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 10 sellado humano (deploy Firebase) — docs/SMOKE-E2E.md

## Roadmap Evolution
- Phase 11 added (2026-08-19): Correccion critica y profesionalizacion. Auditoria del sistema encontro 3 bugs criticos independientes (sin ruta de bootstrap desde BD vacia; query de menu del cliente denegada por rules; indice compuesto de categorias faltante) + deuda de UI severa en ambas apps (sin responsive, sin toggles de password, branding Flutter por defecto). Alcance detallado en .planning/phases/11-*/SCOPE.md
- Phase 10 added (2026-08-16): Migracion Firebase Opcion B (decision usuario)
- Phase 10 executed+verified (2026-08-16): 7 planes, ambas apps 100% Firebase (app 91/91, panel 84/84), rules+seed+guia en raiz. Backend FastAPI ARCHIVADO como referencia (no borrado). Pagos en linea diferidos (solo solicitar cuenta).

## Progress

Status: Phases 1-10 ejecutadas. Phase 10 verificada PASSED (automatizable); pendiente sellado humano:
1. firebase login + deploy --only firestore:rules,firestore:indexes (SMOKE-E2E [N])
2. Auth email/password en Console + serviceAccountKey + seed real x2 ([O])
3. Smoke e2e flujo completo ([A]-[M] emuladores o [P] real)

## Test Baselines (final Firebase)
- app_cliente: 91 passed + analyze 0 (100% Firebase, purge legacy completa)
- panel_admin: 84 passed + analyze 0 (100% Firebase, purge legacy completa)
- backend FastAPI: archivado (215 tests referencia MySQL, no se mantiene)

## Stack actual
- Firebase p-gri-b5b40: Auth + Firestore + Rules (claims {role,rid})
- Apps: app_cliente (android+web), panel_admin (web) — onSnapshot realtime, runTransaction concurrencia
- scripts/seed_firebase.mjs idempotente; firestore.rules + indexes + firebase.json en raiz
