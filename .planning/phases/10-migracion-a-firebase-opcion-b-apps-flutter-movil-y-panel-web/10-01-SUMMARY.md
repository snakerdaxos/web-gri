---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "01"
subsystem: firebase-infra
tags: [firebase, firestore-rules, security, seed, emulator, indexes]
requires: []
provides:
  - "firestore.rules — autorización 100% por claims {role, rid} para las 9 colecciones (reemplazo de TenantScope + require_roles)"
  - "firestore.indexes.json — 9 índices compuestos de las queries del dominio"
  - "firebase.json — config de deploy + emuladores (auth 9099, firestore 8080, ui 4000)"
  - "scripts/seed_firebase.mjs — seed idempotente (restaurante demo + 6 usuarios + claims + 8 mesas + 4 categorías + 16 productos) contra emuladores o proyecto real"
  - "docs/FIREBASE_SETUP.md — guía completa de operación (emuladores → seed → claims → deploy)"
affects: [app_cliente, panel_admin]
tech-stack:
  added: ["firebase-admin 14.2.0 (scripts/)", "firebase-tools 15.27.0 (scripts/ devDep)"]
  patterns: ["authz declarativa por custom claims request.auth.token (0 access-calls)", "doc IDs deterministas como UNIQUE (mesas QR, sesiones/{mesaId}, reservas/{mesaId}_{fecha}_{HH}, calificaciones/{pedidoId})"]
key-files:
  created: [firestore.rules, firestore.indexes.json, firebase.json, scripts/package.json, scripts/package-lock.json, scripts/seed_firebase.mjs, docs/FIREBASE_SETUP.md, ".planning/phases/10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web/deferred-items.md"]
  modified: [".gitignore"]
decisions:
  - "Split create/update/delete en categorias+productos+mesas (resource es null en create; request.resource es null en delete)"
  - "restaurantes: super_admin solo toggle activo (PLAT-05); agregado califProm/califCount por isCliente (la tx de calificar la corre el cliente)"
  - "mesas: rama cliente con SOLO sus 2 transacciones diseñadas (tx reserva, tx abrir sesión); edición de ficha restringida a numero/capacidad"
  - "reservas create valida numPersonas <= capacidad de la mesa (mismo get cacheado, 0 access-calls extra)"
metrics:
  duration: "~2h 15m"
  completed: "2026-08-16"
  tasks: 3
  commits: 3
---

# Phase 10 Plan 01: Infra raíz Firebase (rules + indexes + seed + setup) Summary

**One-liner:** Security Rules Firestore con autorización 100% por custom claims `{role, rid}` sobre las 9 colecciones (transiciones de mesa/pedido/sesión validadas server-side, presupuesto ≤3 access-calls por match), 9 índices compuestos, emuladores configurados, seed idempotente con firebase-admin 14.2.0 (6 usuarios + claims, 8 mesas QR `GRI-MESA-demo-001..008`, menú 16 productos int COP en paridad 1:1 con `seed_service.py`) y guía de operación completa.

## What Was Built

### Task 1 — firestore.rules + firestore.indexes.json + firebase.json + .gitignore (commit 008bf1f)

- **`firestore.rules`** (raíz): `rules_version = '2'`, helpers que leen SOLO
  `request.auth.token` (`signedIn/role/rid/isSuper/isCliente/staffOf/menuStaffOf/cocinaStaffOf/soloEstado/transMesa`),
  9 match blocks (restaurantes, categorias, productos, mesas, usuarios,
  sesiones, pedidos, reservas, calificaciones). Cero `get()` sobre `usuarios/`.
  - Refinamientos obligatorios del plan aplicados:
    **[a]** mesas create usa `request.resource.data.restauranteId` y delete usa
    `resource.data.restauranteId` (request.resource es null en delete);
    **[b]** restaurantes update de super_admin restringido a
    `hasOnly(['activo'])` (paridad PLAT-05);
    **[c]** `transMesa` = MESA_TRANSITIONS 1:1 de `state_machines.py`
    (disponible→[reservada,ocupada], reservada→[ocupada,disponible],
    ocupada→[limpieza], limpieza→[disponible]);
    **[d]** comentarios por match con conteo de access-calls
    (sesiones 1, pedidos 2 docs/3 gets, reservas 1, calificaciones 2 docs/4 gets).
- **`firestore.indexes.json`**: los 9 índices compuestos del research
  (pedidos restauranteId+estado+createdAt DESC / sesionId+createdAt ASC /
  usuarioId+createdAt DESC; reservas restauranteId+fecha ASC / usuarioId+fecha
  DESC; sesiones usuarioId+estado / restauranteId+estado; productos
  restauranteId+categoriaId; mesas restauranteId+numero) + `fieldOverrides: []`.
- **`firebase.json`**: paths rules/indexes + emuladores auth 9099, firestore
  8080, ui 4000 enabled.
- **`.gitignore`**: + `serviceAccountKey.json`, `emulator_data/`,
  `scripts/node_modules/`, `.firebase/`, `firebase-debug.log`, `ui-debug.log`.

### Task 2 — scripts/seed_firebase.mjs + scripts/package.json (commit 65bbed8)

- Seed idempotente ESM con **firebase-admin 14.2.0**; detección automática de
  modo: `GOOGLE_APPLICATION_CREDENTIALS` → proyecto real con `cert()`;
  si no → emuladores vía `FIREBASE_AUTH_EMULATOR_HOST`/`FIRESTORE_EMULATOR_HOST`
  (falla rápido con mensaje si faltan). Loguea el modo activo.
- Contenido en paridad 1:1 con `backend/app/services/seed_service.py`:
  restaurante `demo` ("Restaurante Demo GRI", Colombiana, Cra. 7 #63-44,
  califProm 0/califCount 0), 6 usuarios password `Demo!1234` con
  `setCustomUserClaims({role, rid})` + doc espejo merge, 8 mesas doc ID
  determinista `GRI-MESA-demo-001..008` capacidades [2,2,4,4,4,6,6,8], 4
  categorías, 16 productos int COP.
- Idempotencia por natural key ANTES de cada write: usuario por email
  (catch `auth/email-already-exists` → `getUserByEmail`; claims/espejo merge
  SIEMPRE), mesa/restaurante por doc ID (set merge), categoría por
  (restauranteId, nombre), producto por (restauranteId, categoriaId, nombre).
  Log resumen creado/existente por entidad (greppable para la doble corrida).
- `npm install` OK (726 paquetes), `node --check` OK.

### Task 3 — docs/FIREBASE_SETUP.md (commit 8cffb2d)

Guía de 9 secciones: (1) Requisitos, (2) Emuladores (--import/--export-on-exit,
UI 4000, volatilidad, Android 10.0.2.2), (3) Seed emuladores + real
(habilitar Email/Password, serviceAccountKey GITIGNORED, doble corrida como
prueba de idempotencia), (4) Custom claims con pitfall de propagación
(refresh hasta 1h / `getIdToken(true)`), (5) Deploy rules+indexes con
advertencia, (6) Flag USE_EMULATORS, (7) firebase_options.dart con
flutterfire configure + **fallback manual completo** (androidOptions y
webOptions con los valores reales de `documentos/`), (8) Formato QR
`GRI-MESA-{rid}-{num:03d}`, (9) Troubleshooting.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `allow write` con `resource.data` en create (categorias/productos)**
- **Found during:** Task 1
- **Issue:** El esqueleto del research usaba `menuStaffOf(resource.data.restauranteId)` para write — en CREATE `resource` es null → todo create de categorías/productos habría sido denegado siempre.
- **Fix:** Split `create` (valida `request.resource.data.restauranteId`) / `update` (doc existente + restauranteId inmutable) / `delete` (doc existente). Mismo patrón exigido por el refinamiento [a] para mesas.
- **Files:** firestore.rules
- **Commit:** 008bf1f

**2. [Rule 2 - Funcionalidad faltante] restaurantes: agregado califProm/califCount inalcanzable para quien lo escribe**
- **Found during:** Task 1
- **Issue:** El esqueleto permitía ese update solo a `staffOf(rid)`, pero la tx de calificar (patrón 5 del research) la corre el CLIENTE → commit de la tx habría fallado.
- **Fix:** Rama `isCliente()` con `hasOnly(['califProm','califCount'])` + type checks (`califProm is number`, `califCount is int`). Un update standalone de esas keys sin calificación real queda como gap estructural aceptado v1 (validación fuerte = Functions, DEFERRED — comentado en las propias rules).
- **Files:** firestore.rules
- **Commit:** 008bf1f

**3. [Rule 2 - Funcionalidad faltante] mesas: las tx del cliente (reserva / abrir sesión) no podían actualizar estado**
- **Found during:** Task 1
- **Issue:** El update de estado de mesa solo permitía staff, pero los patrones 1-2 del research (`tx.update(mesa, {estado: 'reservada'|'ocupada'})`) los ejecuta la app cliente.
- **Fix:** Rama `isCliente()` + `soloEstado()` limitada EXACTAMENTE a sus 2 transiciones diseñadas (disponible→reservada; disponible|reservada→ocupada). Además la rama de edición de ficha (menu staff) quedó acotada a `hasOnly(['numero','capacidad','updatedAt'])` para que TODO cambio de estado pase por `transMesa` (MIGRA-03: transiciones validadas server-side, sin bypass por admin).
- **Files:** firestore.rules
- **Commit:** 008bf1f

**4. [Rule 2 - Hardening] validaciones estructurales gratuitas (0 access-calls extra, mismo doc cacheado)**
- **Found during:** Task 1
- **Fix:** sesiones create valida `mesaId == docId` y `restauranteId == mesa.restauranteId`; pedidos create valida `sesionId == mesaId`; reservas create valida `numPersonas <= mesa.capacidad` (restaura la validación de capacidad del backend); calificaciones create valida `pedidoId == docId` y restauranteId consistente; read de sesiones incluye `isSuper()` (paridad con pedidos/reservas). Seed: `emailVerified: true` en createUser (login demo sin fricción).
- **Files:** firestore.rules, scripts/seed_firebase.mjs
- **Commits:** 008bf1f, 65bbed8

### Clarificaciones de verificación (no desviaciones de contenido)

- **Conteo `match /` = 10, no 9:** el match raíz `match /databases/{database}/documents` es sintaxis obligatoria de Firestore Rules y también contiene el patrón. Los 9 match blocks de colección requeridos están verificados con regex específico por colección (intento del plan cumplido).
- **`rg` no instalado en la máquina:** verificaciones ejecutadas con equivalentes node (mismos patrones regex exactos).
- **`npm install --prefix scripts` falla en Windows/npm 10.9.7** (resuelve package.json del padre): install corrido desde `scripts/`. `npx --prefix scripts firebase` SÍ funciona (verificado → 15.27.0). Ambos detalles documentados en la guía (§1 y §9).

## Authentication Gates

- **`firebase login` (OAuth interactivo) requerido para validar/deployar rules**: `firebase deploy --dry-run` también exige sesión. La validación sintáctica server-side de las rules queda para el deploy del plan 10-07 (paso del usuario, documentado en FIREBASE_SETUP.md §5). Mientras tanto: revisión manual CEL documentada (helpers monolinea, `diff().affectedKeys().hasOnly()`, `get()` bien formados, sin loops).
- **Java JRE ausente** → emuladores no disponibles en esta máquina: la doble corrida del seed (prueba de idempotencia en vivo) quedó documentada en FIREBASE_SETUP.md §3 como gate de 10-07, tal como prevé el plan.

## Verification Results

| Check | Resultado |
|---|---|
| `firebase.json` / `firestore.indexes.json` parsean JSON | ✅ json ok |
| firestore.rules: match blocks de colección | ✅ 9/9 |
| firestore.rules: `request.auth.token` | ✅ 5 ocurrencias (≥4) |
| firestore.rules: `get()` sobre usuarios/ | ✅ ninguno |
| `node --check scripts/seed_firebase.mjs` | ✅ |
| `npm install` (scripts/) | ✅ 726 paquetes, firebase-admin 14.2.0 + firebase-tools 15.27.0 en lock |
| `setCustomUserClaims` + doc IDs `GRI-MESA-demo-00*` en seed | ✅ |
| docs/FIREBASE_SETUP.md: 9 secciones `^## `, USE_EMULATORS, `firebase deploy --only firestore:rules`, fallback manual con valores reales, formato QR | ✅ |
| .gitignore: serviceAccountKey.json, emulator_data/, scripts/node_modules/, .firebase/, logs | ✅ 6/6 |
| `npx --prefix scripts firebase --version` | ✅ 15.27.0 |
| Doble corrida seed vs emuladores | ⏸ gate 10-07 (sin Java) |

## Deferred Issues

- Ver `deferred-items.md` (mismo directorio): pantalla "Clientes" del panel no podrá listar `usuarios/` (derivar de pedidos denormalizados en el wave del panel); doble corrida del seed pendiente por Java.

## Self-Check: PASSED

- Archivos verificados en disco: firestore.rules ✅ · firestore.indexes.json ✅ · firebase.json ✅ · scripts/package.json ✅ · scripts/package-lock.json ✅ · scripts/seed_firebase.mjs ✅ · docs/FIREBASE_SETUP.md ✅ · .gitignore (modificado) ✅ · deferred-items.md ✅
- Commits verificados en `git log`: 008bf1f ✅ · 65bbed8 ✅ · 8cffb2d ✅
