---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: verifying
last_updated: "2026-08-19T16:29:00.000Z"
progress:
  total_phases: 11
  completed_phases: 10
  total_plans: 52
  completed_plans: 36
  percent: 67
---

# STATE

## Project Reference

See: .planning/PROJECT.md

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 11 — Correccion critica y profesionalizacion (plan 04/20 completado)

## Roadmap Evolution

- Phase 11 added (2026-08-19): Correccion critica y profesionalizacion. Auditoria del sistema encontro 3 bugs criticos independientes (sin ruta de bootstrap desde BD vacia; query de menu del cliente denegada por rules; indice compuesto de categorias faltante) + deuda de UI severa en ambas apps (sin responsive, sin toggles de password, branding Flutter por defecto). Alcance detallado en .planning/phases/11-*/SCOPE.md
- Phase 10 added (2026-08-16): Migracion Firebase Opcion B (decision usuario)
- Phase 10 executed+verified (2026-08-16): 7 planes, ambas apps 100% Firebase (app 91/91, panel 84/84), rules+seed+guia en raiz. Backend FastAPI ARCHIVADO como referencia (no borrado). Pagos en linea diferidos (solo solicitar cuenta).

## Progress

Phase 11: 4/20 planes [####----------------] 20%

- [x] 11-01 Bootstrap del entorno de test Firebase (Java + .firebaserc + functions/ + arnes de rules + CLAUDE.md corregido) — 46e2422, 58063f0, af125a8
- [x] 11-02 Base vacia + cliente de Cloud Functions (buildFakeFirestoreVacio en ambas apps, firebaseFunctionsProvider us-central1 + emulador 5001, guia de arranque del dashboard) — 9b2b965, 65a5f5d, d347b71, a2333de, f6085af
- [x] 11-03 Correccion del menu: query vs rules + indice compuesto + audit estatico (P0 de la fase) — 23151d8, 5aa08d0, 7caeb71, 52d2db6, 74ceacb
- [x] 11-04 Suite completa de firestore.rules: 7 colecciones nuevas, 190 casos, 3 vectores de escalada verificados por rotura deliberada — 0d2cafc, a0828f0, 4825e26
- [ ] 11-05 .. 11-20

Status: Phases 1-10 ejecutadas. Phase 10 verificada PASSED (automatizable); pendiente sellado humano:

1. firebase login + deploy --only firestore:rules,firestore:indexes (SMOKE-E2E [N])
2. Auth email/password en Console + serviceAccountKey + seed real x2 ([O])
3. Smoke e2e flujo completo ([A]-[M] emuladores o [P] real)

## Test Baselines (final Firebase)

- app_cliente: 96 passed + analyze 0 (11-03: +2 de filtrado del menu)
- panel_admin: 96 passed + analyze 0 (11-02: +3 base vacia, +5 contrato Functions, +4 guia dashboard)
- TOTAL apps: 192 (baseline previa 175, sin regresion)
- firestore.rules: 208 passed via `cd scripts && npm run test:rules` (11-04: +190 — mesas 26, sesiones 29, pedidos 36, reservas 27, calificaciones 21, usuarios 22, restaurantes 29)
- indices/paridad: `cd scripts && npm run audit:indexes` — 21 queries clasificadas, 0 fallos, exit 0
- Cloud Functions: sin tests aun (llegan en 11-07/11-08); `npm run test:functions` ya cableado
- backend FastAPI: archivado (215 tests referencia MySQL, no se mantiene)

## Stack actual

- Firebase p-gri-b5b40: Auth + Firestore + Rules (claims {role,rid}) + Cloud Functions (Node 22, functions/)
- Alias `demo` -> `demo-gri` en .firebaserc: proyecto ficticio para emuladores y tests
- Apps: app_cliente (android+web), panel_admin (web) — onSnapshot realtime, runTransaction concurrencia
- scripts/seed_firebase.mjs idempotente; firestore.rules + indexes + firebase.json en raiz
- scripts/run_emulators.mjs resuelve Java solo (JAVA_HOME -> PATH -> JBR de Android Studio)
- panel_admin: cloud_functions 6.3.6 (pin exacto) — firebaseFunctionsProvider region us-central1; emulador de Functions en 127.0.0.1:5001 bajo --dart-define=USE_EMULATORS=true

## Decisions

- 11-01: el wrapper de emuladores ejecuta firebase-tools/lib/bin/firebase.js con process.execPath, no el shim .bin/firebase.cmd (spawn de .cmd exige shell:true desde Node 18.20/20.12 y corrompe argumentos con comillas)
- 11-01: todos los scripts de test pasan `--project demo-gri` explicito; el alias `default` queda PROHIBIDO en cualquier script de test
- 11-01: la config de las Cloud Functions en emulador vive versionada en functions/.env.demo-gri (el emulador la carga AL ARRANCAR; --set-env no le llega)
- 11-01: los 4 paquetes Firebase nuevos se fijan con version EXACTA (sin ^) por la mitigacion T-11-01-SC
- 11-01: Node 24 no acepta un directorio en `node --test`; los npm scripts usan el glob *.test.mjs y rutas relativas a la RAIZ del repo
- 11-02: buildFakeFirestoreVacio() es el punto de partida obligatorio de toda prueba de primer arranque (planes 05, 07, 10); buildFakeFirestoreConSeed() sigue intacto
- 11-02: la region de las callables se declara EXPLICITA en cliente y servidor (us-central1) con test de contrato que falla si se quita — un desajuste da 404 opaco que en Flutter Web parece error de CORS
- 11-02: la guia del dashboard reutiliza restaurantesListProvider (ya observado por el topbar del AppShell, app_shell.dart:324): cero consultas nuevas
- 11-02: en riverpod 3 el getter de AsyncValue es .value, NO .valueOrNull
- 11-03: si firestore.rules menciona resource.data.X, la query DEBE llevar where('X') — Firestore evalua las rules contra la CONSULTA, no contra los documentos devueltos
- 11-03: el orderBy('orden') de categorias del cliente se queda CLIENT-SIDE a proposito, para no introducir el indice categorias(restauranteId, activo, orden)
- 11-03: el emulador de Firestore NO valida indices compuestos; audit_indexes.mjs es mitigacion ESTATICA, no prueba. La verificacion real del indice es el checkpoint humano de 11-16
- 11-03: la exencion de la paridad rules-query debe DECLARARSE con // AUDIT-STAFF; una exencion silenciosa cuenta como fallo
- 11-03: todo archivo de test de rules DEBE llamar initEnv('<namespace>') — node --test paraleliza por archivo contra un emulador compartido y sin namespace propio los clearFirestore() se pisan
- 11-04: un gate de seguridad no esta verificado hasta que se ROMPE la regla que protege y la suite se pone en rojo por los casos correctos (6 roturas aplicadas y revertidas en el plan)
- 11-04: un caso limite debe aislarse con su propio fixture (mesa de capacidad 30 para el tope de 20 comensales); si otra condicion lo deniega antes, el test esta verde por la razon equivocada
- 11-04: se afirman tambien los bordes PERMITIDOS (50 items, 20 personas, 1 estrella) — un <= convertido en < no rompe ningun assertFails
- 11-04: fake_cloud_firestore NO tiene motor de rules; los 192 tests Flutter prueban FILTRADO, jamas AUTORIZACION. La unica prueba de autorizacion es npm run test:rules
- 11-04: la suite verde y el proyecto seguro son afirmaciones INDEPENDIENTES — hasta firebase deploy --only firestore:rules, p-gri-b5b40 puede correr una version mas laxa
- 11-04: HALLAZGO — el super_admin no puede cerrar sesiones, cancelar reservas ni cambiar estado de mesa (staffOf compara contra rid() y el super no tiene rid); en pedidos SI esta contemplado con isSuper(). Asimetria real, a decidir en 11-10/11-16
- 11-04: 11-07 debe mantener en verde el bloque default-deny de plataforma/bootstrap; 11-10 debe cambiar conscientemente el caso // AMPLIADO EN 11-10 de usuarios.test.mjs

## Performance Metrics

| Phase | Plan | Duracion | Tareas | Archivos |
| --- | --- | --- | --- | --- |
| 11 | 01 | ~25 min | 3 | 14 |
| 11 | 02 | ~30 min | 3 | 13 |
| 11 | 03 | ~13 min | 3 | 10 |

## Session

- Last session: 2026-08-19
- Stopped at: Completado 11-03-PLAN.md (menu del cliente corregido + indice de categorias + audit estatico). Siguiente: 11-04-PLAN.md
- Resume file: .planning/phases/11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi/11-04-PLAN.md

## Blockers / Notas

- ENV-01, DOC-01 y TEST-02 (requisitos de la Fase 11 segun ROADMAP.md) NO existen en .planning/REQUIREMENTS.md, que solo contiene los requisitos v1: `requirements.mark-complete` los reporta como not_found (reconfirmado en 11-02).
- 11-03: FIX-01, FIX-02 y TEST-01 tampoco existen en .planning/REQUIREMENTS.md (mismo motivo que ENV-01/DOC-01/TEST-02): `requirements.mark-complete` no puede marcarlos.
- PENDIENTE DE SELLADO HUMANO (11-15/11-16): el indice categorias(restauranteId, orden) queda DECLARADO en firestore.indexes.json pero NO verificado — el emulador no valida indices compuestos. Requiere `firebase deploy --only firestore:indexes` contra p-gri-b5b40 y abrir el menu del panel.
- Los handlers state.advance-plan / state.update-progress / state.record-metric / state.record-session siguen sin parsear este STATE.md (reconfirmado en 11-02); se actualiza a mano. `roadmap.update-plan-progress 11` si funciona.
- 11-02 (DIFERIDO, ver phases/11-*/deferred-items.md): StatCard del panel desborda 31px cuando el grid pasa a 4 columnas (viewport >=1100px). Preexistente; debe entrar en el bloque de responsive/tokens.
- Sigue pendiente el sellado humano de la Fase 10 (deploy real + smoke, docs/SMOKE-E2E.md).
