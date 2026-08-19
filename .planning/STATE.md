---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: verifying
last_updated: "2026-08-19T15:35:01.839Z"
progress:
  total_phases: 11
  completed_phases: 10
  total_plans: 52
  completed_plans: 33
  percent: 63
---

# STATE

## Project Reference

See: .planning/PROJECT.md

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 11 — Correccion critica y profesionalizacion (plan 01/20 completado)

## Roadmap Evolution

- Phase 11 added (2026-08-19): Correccion critica y profesionalizacion. Auditoria del sistema encontro 3 bugs criticos independientes (sin ruta de bootstrap desde BD vacia; query de menu del cliente denegada por rules; indice compuesto de categorias faltante) + deuda de UI severa en ambas apps (sin responsive, sin toggles de password, branding Flutter por defecto). Alcance detallado en .planning/phases/11-*/SCOPE.md
- Phase 10 added (2026-08-16): Migracion Firebase Opcion B (decision usuario)
- Phase 10 executed+verified (2026-08-16): 7 planes, ambas apps 100% Firebase (app 91/91, panel 84/84), rules+seed+guia en raiz. Backend FastAPI ARCHIVADO como referencia (no borrado). Pagos en linea diferidos (solo solicitar cuenta).

## Progress

Phase 11: 1/20 planes [#-------------------] 5%
- [x] 11-01 Bootstrap del entorno de test Firebase (Java + .firebaserc + functions/ + arnes de rules + CLAUDE.md corregido) — 46e2422, 58063f0, af125a8
- [ ] 11-02 .. 11-20

Status: Phases 1-10 ejecutadas. Phase 10 verificada PASSED (automatizable); pendiente sellado humano:

1. firebase login + deploy --only firestore:rules,firestore:indexes (SMOKE-E2E [N])
2. Auth email/password en Console + serviceAccountKey + seed real x2 ([O])
3. Smoke e2e flujo completo ([A]-[M] emuladores o [P] real)

## Test Baselines (final Firebase)

- app_cliente: 91 passed + analyze 0 (reverificado 2026-08-19 tras 11-01, sin regresion)
- panel_admin: 84 passed + analyze 0 (reverificado 2026-08-19 tras 11-01, sin regresion)
- firestore.rules: 2 passed via `cd scripts && npm run test:rules` (arnes nuevo en 11-01)
- Cloud Functions: sin tests aun (llegan en 11-07/11-08); `npm run test:functions` ya cableado
- backend FastAPI: archivado (215 tests referencia MySQL, no se mantiene)

## Stack actual

- Firebase p-gri-b5b40: Auth + Firestore + Rules (claims {role,rid}) + Cloud Functions (Node 22, functions/)
- Alias `demo` -> `demo-gri` en .firebaserc: proyecto ficticio para emuladores y tests
- Apps: app_cliente (android+web), panel_admin (web) — onSnapshot realtime, runTransaction concurrencia
- scripts/seed_firebase.mjs idempotente; firestore.rules + indexes + firebase.json en raiz
- scripts/run_emulators.mjs resuelve Java solo (JAVA_HOME -> PATH -> JBR de Android Studio)

## Decisions

- 11-01: el wrapper de emuladores ejecuta firebase-tools/lib/bin/firebase.js con process.execPath, no el shim .bin/firebase.cmd (spawn de .cmd exige shell:true desde Node 18.20/20.12 y corrompe argumentos con comillas)
- 11-01: todos los scripts de test pasan `--project demo-gri` explicito; el alias `default` queda PROHIBIDO en cualquier script de test
- 11-01: la config de las Cloud Functions en emulador vive versionada en functions/.env.demo-gri (el emulador la carga AL ARRANCAR; --set-env no le llega)
- 11-01: los 4 paquetes Firebase nuevos se fijan con version EXACTA (sin ^) por la mitigacion T-11-01-SC
- 11-01: Node 24 no acepta un directorio en `node --test`; los npm scripts usan el glob *.test.mjs y rutas relativas a la RAIZ del repo

## Performance Metrics

| Phase | Plan | Duracion | Tareas | Archivos |
| --- | --- | --- | --- | --- |
| 11 | 01 | ~25 min | 3 | 14 |

## Session

- Last session: 2026-08-19
- Stopped at: Completado 11-01-PLAN.md (bootstrap del entorno de test Firebase). Siguiente: 11-02-PLAN.md
- Resume file: .planning/phases/11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi/11-02-PLAN.md

## Blockers / Notas

- ENV-01 y DOC-01 (requisitos de la Fase 11 segun ROADMAP.md) NO existen en .planning/REQUIREMENTS.md, que solo contiene los requisitos v1: `requirements.mark-complete` los reporto como not_found.
- Los handlers state.advance-plan / state.update-progress / state.record-metric / state.record-session no saben parsear este STATE.md; se actualizo a mano en 11-01.
- Sigue pendiente el sellado humano de la Fase 10 (deploy real + smoke, docs/SMOKE-E2E.md).
