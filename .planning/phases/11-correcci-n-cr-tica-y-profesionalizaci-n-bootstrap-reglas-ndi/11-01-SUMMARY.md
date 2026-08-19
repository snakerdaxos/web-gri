---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 01
subsystem: infra
tags: [firebase, emuladores, java, cloud-functions, firestore-rules, node-test, tooling]

# Dependency graph
requires:
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: firestore.rules, firebase.json, scripts/seed_firebase.mjs, firebase-tools local en scripts/
provides:
  - "scripts/run_emulators.mjs — resolución automática de Java + wrapper de firebase emulators:exec"
  - ".firebaserc con alias default (p-gri-b5b40) y demo (demo-gri)"
  - "Codebase functions/ arrancable (Node 22, firebase-admin 14.2.0, firebase-functions 7.3.2)"
  - "firebase.json con bloque functions[] y emulators.functions.port 5001"
  - "Arnés de tests de firestore.rules: scripts/test/rules/_contexts.mjs (7 contextos de rol) + smoke.test.mjs"
  - "npm scripts test:rules / test:functions / test en scripts/"
  - "CLAUDE.md con el stack vivo Flutter+Firebase (el FastAPI+MySQL archivado ya no aparece como stack actual)"
affects: [11-03, 11-04, 11-06, 11-07, 11-08, cualquier plan futuro que lea CLAUDE.md]

# Tech tracking
tech-stack:
  added:
    - "@firebase/rules-unit-testing 5.0.1 (scripts/, versión exacta)"
    - "firebase 12.17.1 (JS client SDK, scripts/, versión exacta)"
    - "firebase-functions 7.3.2 (functions/)"
    - "firebase-admin 14.2.0 (functions/, misma versión exacta que scripts/)"
  patterns:
    - "Wrapper Node que resuelve el toolchain (Java) e inyecta entorno SOLO al proceso hijo"
    - "Todos los tests contra emulador usan --project demo-gri; el alias default queda prohibido en tests"
    - "Configuración determinista de Functions en emulador vía functions/.env.{projectId} versionado"
    - "Fixture compartido de contextos por rol como contrato entre planes de la fase"

key-files:
  created:
    - scripts/run_emulators.mjs
    - scripts/test/rules/_contexts.mjs
    - scripts/test/rules/smoke.test.mjs
    - .firebaserc
    - functions/package.json
    - functions/index.js
    - functions/.env.example
    - functions/.env.demo-gri
    - functions/.gitignore
  modified:
    - firebase.json
    - .gitignore
    - CLAUDE.md
    - docs/FIREBASE_SETUP.md
    - scripts/package.json

key-decisions:
  - "El wrapper ejecuta firebase-tools/lib/bin/firebase.js con process.execPath en vez del shim .bin/firebase.cmd, porque desde Node 18.20/20.12 spawnear un .cmd obliga a shell:true y eso corrompe el paso de argumentos con comillas"
  - "El wrapper re-cita cada token del comando post-`--` para reconstruir el string único que espera `emulators:exec <script>`"
  - "Los npm scripts de test usan rutas relativas a la RAÍZ del repo (scripts/test/rules/...) porque el wrapper fija cwd en la raíz"
  - "Node 24 no acepta un directorio en `node --test`; se usa el glob *.test.mjs"
  - "La suite de rules usa projectId propio (demo-gri-rules) para no pisar el namespace de la suite de functions dentro del mismo emulador"
  - "@firebase/rules-unit-testing, firebase, firebase-admin y firebase-functions se fijan con versión EXACTA (sin ^) por la mitigación T-11-01-SC"

patterns-established:
  - "Resolución de Java: JAVA_HOME → PATH → JBR de Android Studio, con fallo explícito y accionable si no hay JVM"
  - "Aislamiento de proyecto en tests: prefijo demo- para que el CLI y los SDK rechacen credenciales reales por diseño"
  - "functions/index.js llama initializeApp() una sola vez; los módulos de src/ solo usan getAuth()/getFirestore()"

requirements-completed: [ENV-01, DOC-01]

# Metrics
duration: 25min
completed: 2026-08-19
---

# Phase 11 Plan 01: Bootstrap del entorno de test Firebase Summary

**El emulador de Firestore ya arranca sin configurar Java a mano y la suite de `firestore.rules` corre de punta a punta: `npm run test:rules` levanta el emulador, ejecuta 2 casos en verde y lo apaga con exit 0.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-19T15:07Z (aprox.)
- **Completed:** 2026-08-19T15:32Z
- **Tasks:** 3/3
- **Files modified/created:** 14

## Accomplishments

- **Desbloqueado el testing contra emuladores.** Java no estaba en el PATH y `.firebaserc` no existía: eran los dos bloqueos duros de los planes 03, 04, 06, 07 y 08. `scripts/run_emulators.mjs` resuelve Java (JBR de Android Studio, OpenJDK 21.0.10) e inyecta `JAVA_HOME`/`PATH` **solo en el proceso hijo**, sin tocar la máquina.
- **Arnés de rules operativo.** `scripts/test/rules/_contexts.mjs` expone los 7 contextos de rol (`anon`, `cliente`, `adminDemo`, `adminOtro`, `mesero`, `cocina`, `superAdmin`) + `sembrar()`, y `smoke.test.mjs` demuestra que la cadena completa discrimina permitido/denegado contra las rules reales.
- **Codebase `functions/` en pie.** Creado a mano (prohibido `firebase init functions`), con `engines.node = "22"`, `initializeApp()` una sola vez y el índice de las funciones que llegan en 11-07 y 11-08. El emulador de Functions arranca junto al de Firestore y carga `functions/.env.demo-gri`.
- **CLAUDE.md deja de mentir.** Su sección `## Technology Stack` describía el backend FastAPI + MySQL archivado en la Fase 10; ahora describe el stack vivo Flutter + Firebase y marca `backend/` como archivado. `## Constraints` queda marcado `SUPERSEDED`.

## Task Commits

1. **Tarea 1: Resolver Java, crear .firebaserc y corregir el stack documentado** — `46e2422` (feat)
2. **Tarea 2: Scaffold del codebase functions/ y bloque functions en firebase.json** — `58063f0` (feat)
3. **Tarea 3: Arnés de tests de firestore.rules con caso de humo** — `af125a8` (test)

## Files Created/Modified

**Creados**
- `scripts/run_emulators.mjs` — resuelve Java, reenvía a `firebase emulators:exec` con cwd en la raíz, soporta `--set-env K=V`
- `.firebaserc` — alias `default` → `p-gri-b5b40`, `demo` → `demo-gri`
- `functions/package.json` — `gri-functions`, ESM, `engines.node = "22"`
- `functions/index.js` — `initializeApp()` único + índice de exports futuros
- `functions/.env.example` — plantilla (el `.env` real NO se commitea)
- `functions/.env.demo-gri` — config determinista de emulador (SÍ se commitea)
- `functions/.gitignore` — `node_modules/`, `.env`, `*-debug.log`
- `scripts/test/rules/_contexts.mjs` — fixture compartido, contrato de los planes 03/04/08
- `scripts/test/rules/smoke.test.mjs` — 2 casos de humo sobre `restaurantes/{id}`
- `scripts/test/functions/.gitkeep` — carpeta lista para 11-07/11-08

**Modificados**
- `firebase.json` — +8 líneas: `functions[]` (source/codebase/ignore) y `emulators.functions.port = 5001`. Bloque `firestore` intacto
- `.gitignore` — `functions/node_modules/`, `functions/lib/`, `functions/.env`, `*-debug.log`
- `CLAUDE.md` — `## Technology Stack` reescrita; `## Constraints` marcada SUPERSEDED
- `docs/FIREBASE_SETUP.md` — nueva §2.1 "Java y emuladores" + fila de troubleshooting actualizada
- `scripts/package.json` — 2 devDependencies nuevas (versión exacta) y 3 npm scripts

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Emulador Firestore | `node run_emulators.mjs --only firestore --project demo-gri -- node -e "console.log('EMULADOR_OK')"` | `EMULADOR_OK` · `Script exited successfully (code 0)` · exit 0 |
| `--set-env` | `node run_emulators.mjs --set-env GRI_PRUEBA=ok ... -- node -e "process.exit(...)"` | `SET_ENV_OK` (exit 0) |
| `.firebaserc` | `JSON.parse` + comprobación de ambos alias | `FIREBASERC_OK` |
| CLAUDE.md limpio | `grep -v '^#' CLAUDE.md \| grep -ci "SQLAlchemy\|asyncmy\|uvicorn\|MySQL 8.4"` | `0` → `CLAUDE_MD_OK` |
| `.gitignore` | `git check-ignore -v` x4 | `functions/.env` → ignorado (`.gitignore:46`); `functions/.env.demo-gri` y `functions/.env.example` → **no** ignorados; `functions/node_modules/x` → ignorado (`:44`); `firestore-debug.log` → ignorado (`:49`) |
| `functions/` instala | `cd functions && npm install` | `added 284 packages in 11s` · `ENGINES_OK` (warning esperado: `EBADENGINE required node 22 / current v24`) |
| `firebase.json` | validación de `functions`, `emulators.functions.port`, `firestore.rules` | `FIREBASE_JSON_OK` · `git diff --stat` = **8 insertions, 0 deletions** (límite del plan: <12) |
| `.env.demo-gri` | `grep BOOTSTRAP_EMAIL= / BOOTSTRAP_SECRET=` | `ENV_DEMO_OK` |
| Emulador Functions | `--only functions,firestore` | `Loaded functions definitions from source: .` · `Loaded environment variables from functions\.env.demo-gri` · `FUNCTIONS_EMU_OK` · exit 0 |
| **Suite de rules** | `cd scripts && npm run test:rules` | `tests 2 · pass 2 · fail 0` · `duration_ms 1376` · **exit 0** |
| Suite completa | `cd scripts && npm test` | `test:rules` 2/2 + `test:functions` 0 tests (aún vacía) · **exit 0** |
| 3 emuladores | `--only auth,functions,firestore` | `Starting emulators: auth, functions, firestore` · `Script exited successfully (code 0)` |
| Baseline Flutter | `flutter analyze` x2 | `app_cliente`: **No issues found!** · `panel_admin`: **No issues found!** |
| Baseline tests | `flutter test` x2 | `app_cliente`: **+91 All tests passed!** · `panel_admin`: **+84 All tests passed!** (175 total, sin regresión) |

## Decisions Made

- **Ejecutar el entrypoint JS de firebase-tools en vez del shim `.cmd`.** Desde Node 18.20/20.12, `spawn()` de un `.cmd` exige `shell: true`, y con shell los argumentos con comillas y paréntesis (`node -e "console.log('X')"`) se corrompen. Ejecutar `firebase-tools/lib/bin/firebase.js` con `process.execPath` pasa el argv exacto. Se conserva fallback al shim si el JS no existiera.
- **Re-citado de tokens.** `firebase emulators:exec <script>` recibe UN string; nuestro argv llega ya tokenizado por el shell del llamador. El wrapper re-cita cada token para que el shell interno de firebase-tools (cmd.exe en Windows) no reinterprete paréntesis ni comodines.
- **`projectId` separado para la suite de rules** (`demo-gri-rules`) frente al `--project demo-gri` del emulador: cada projectId es un namespace independiente, así la suite de rules no pisará los datos de la suite de callables de 11-07/11-08 cuando ambas convivan.
- **Versiones exactas sin `^`** en los 4 paquetes Firebase nuevos (mitigación T-11-01-SC). `npm i` los dejó con `^`; se corrigieron a pin exacto y se reinstaló.

## Deviations from Plan

### Auto-fixed Issues

**1. [Regla 3 - Bloqueante] La verificación de `.firebaserc` del plan no puede ejecutarse tal cual**
- **Found during:** Tarea 1
- **Issue:** `node -e "require('./.firebaserc')"` falla con `SyntaxError: Unexpected token ':'` — Node no reconoce la extensión `.firebaserc` y carga el archivo como CommonJS/JS, no como JSON.
- **Fix:** El gate se ejecutó con `JSON.parse(fs.readFileSync('.firebaserc','utf8'))`, comprobando además el alias `demo`. La intención del gate (ambos alias correctos) se cumplió íntegra.
- **Files modified:** ninguno (solo el comando de verificación)
- **Verification:** `FIREBASERC_OK`

**2. [Regla 3 - Bloqueante] Las rutas de los npm scripts de test eran relativas a `scripts/`, pero el cwd es la raíz**
- **Found during:** Tarea 3
- **Issue:** El plan especifica `node --test test/rules/`, pero el propio plan fija el cwd del wrapper en la RAÍZ del repo (necesario para que resuelvan `firebase.json`, `.firebaserc` y `firestore.rules`). `test/rules/` no existe en la raíz.
- **Fix:** Los scripts usan `scripts/test/rules/` y `scripts/test/functions/`.
- **Files modified:** `scripts/package.json`
- **Verification:** `npm run test:rules` → exit 0
- **Committed in:** `af125a8`

**3. [Regla 3 - Bloqueante] Node 24 no acepta un directorio en `node --test`**
- **Found during:** Tarea 3
- **Issue:** `node --test scripts/test/rules/` intenta cargar el directorio como módulo y muere con `MODULE_NOT_FOUND: Cannot find module '...\scripts\test\rules'`. Reproducido también sin barra final en un directorio de prueba aislado.
- **Fix:** Se usa el glob `scripts/test/rules/*.test.mjs`. Verificado además que un glob sin coincidencias (caso de `test/functions/`, aún vacío) sale con código 0, así que `npm test` no revienta antes de 11-07.
- **Files modified:** `scripts/package.json`
- **Verification:** `tests 2 · pass 2 · fail 0`, exit 0
- **Committed in:** `af125a8`

**4. [Regla 1 - Contradicción interna del plan] El texto de la sección "NO USAR" de CLAUDE.md violaba su propio gate**
- **Found during:** Tarea 1
- **Issue:** El plan pedía literalmente escribir `MySQL, SQLAlchemy, Alembic, asyncmy, PyJWT, uvicorn` en la línea "NO USAR", pero su gate exige `grep -ci "SQLAlchemy|asyncmy|uvicorn|MySQL 8.4"` == 0 sobre las líneas no-heading. Ambas cosas son incompatibles.
- **Fix:** La sección "NO USAR" describe el stack archivado por su función ("su base de datos relacional, su ORM, sus migraciones, su driver async, su servidor ASGI") sin nombrar los paquetes. Se cumple la intención (ningún agente futuro planificará contra ese stack) y el gate pasa.
- **Files modified:** `CLAUDE.md`
- **Verification:** `CLAUDE_MD_OK` (contador = 0)
- **Committed in:** `46e2422`

**5. [Regla 2 - Correctitud] Se versionan los lockfiles**
- **Found during:** Tareas 2 y 3
- **Issue:** El plan no menciona `functions/package-lock.json`. Sin él la instalación no es reproducible y la mitigación de pin exacto se debilita.
- **Fix:** `functions/package-lock.json` y el `scripts/package-lock.json` actualizado se commitean.
- **Committed in:** `58063f0`, `af125a8`

**6. [Regla 3 - Bloqueante] STATE.md y REQUIREMENTS.md no encajan con los handlers del SDK**
- **Found during:** cierre del plan
- **Issue:** `state.advance-plan`, `state.update-progress`, `state.record-metric`, `state.add-decision` y `state.record-session` devolvieron todos error (`Cannot parse Current Plan`, `Progress field not found`, `Performance Metrics section not found`, `No session fields found`): el `STATE.md` heredado de la Fase 10 no tiene las secciones que esos handlers esperan. Además, `requirements.mark-complete ENV-01 DOC-01` devolvió `not_found` para ambos: esos IDs viven en `ROADMAP.md` (Fase 11) pero **no** en `.planning/REQUIREMENTS.md`, que solo contiene los requisitos v1.
- **Fix:** `roadmap.update-plan-progress 11` sí funcionó (`updated: true`, 20 planes / 1 summary / In Progress). `STATE.md` se actualizó a mano y se le añadieron las secciones `## Decisions`, `## Performance Metrics`, `## Session` y `## Blockers / Notas` para que los handlers puedan operar en los planes siguientes. Ambas incidencias quedan anotadas en `## Blockers / Notas` de `STATE.md`.
- **Files modified:** `.planning/STATE.md`
- **Verification:** contenido revisado en disco; `roadmap.update-plan-progress` → `{"updated": true, "plan_count": 20, "summary_count": 1}`

---

**Total deviations:** 6 auto-corregidas (4× Regla 3, 1× Regla 1, 1× Regla 2)
**Impact on plan:** Ninguna reduce alcance. Tres son incompatibilidades del texto del plan con el runtime real (Node 24, cwd del wrapper, carga de `.firebaserc`), una resuelve una contradicción interna del propio plan y la última refuerza la mitigación de supply-chain. Sin scope creep.

## Issues Encountered

- **Warning esperado y no accionable:** `Your requested "node" version "22" doesn't match your global version "24". Using node@24 from host.` Es exactamente lo que el plan anticipó: Node 24 no es runtime soportado por Cloud Functions, `engines.node` se mantiene en `22` y el código debe ceñirse a APIs de Node 22. El emulador funciona igualmente.
- `npm install` en `functions/` emite `EBADENGINE` por la misma razón. Correcto y deliberado.
- Los emuladores dejan `firestore-debug.log` en la raíz del repo; ya queda cubierto por el patrón `*-debug.log` añadido en la Tarea 1.

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-01-SC | Mitigado | Los 4 paquetes (`@firebase/rules-unit-testing`, `firebase`, `firebase-functions`, `firebase-admin`) instalados con versión EXACTA, verificado en `scripts/package.json` y `functions/package.json`. Ninguno requirió checkpoint humano (veredicto `OK` en la auditoría de 11-RESEARCH) |
| T-11-01-02 | Mitigado | Los 3 npm scripts pasan `--project demo-gri` explícito; el alias `default` no aparece en ningún script de test. El CLI confirmó en cada corrida: `Detected demo project ID "demo-gri" ... attempts to access non-emulated services for this project will fail` |
| T-11-01-03 | Mitigado | `git check-ignore -v functions/.env` → ignorado (`.gitignore:46`) + `functions/.gitignore`. `functions/.env.example` y `functions/.env.demo-gri` confirmados NO ignorados |
| T-11-01-04 | Mitigado | `git check-ignore -v firestore-debug.log` → ignorado (`.gitignore:49`, patrón `*-debug.log`) |

## Known Stubs

- `functions/index.js` no exporta ninguna función todavía (`initializeApp()` y un índice comentado). **Intencional y declarado en el plan**: `bootstrapPlataforma` llega en 11-07 y `crearUsuarioStaff` en 11-08. El objetivo de este plan es que el codebase arranque, no que tenga lógica.
- `scripts/test/functions/` contiene solo `.gitkeep`. **Intencional**: los tests de callables llegan en 11-07/11-08. El glob vacío sale con exit 0, así que `npm test` no se rompe entretanto.

## User Setup Required

Ninguno. Todo se resuelve solo en esta máquina: el wrapper localiza el JDK del JBR de Android Studio y no hace falta definir `JAVA_HOME` ni instalar nada. Si algún día se trabaja en una máquina sin Android Studio, el wrapper imprime instrucciones accionables (instalar Temurin 21 o definir `JAVA_HOME`) y sale con código 1.

## Next Phase Readiness

**Listo para los planes que dependían de esto (03, 04, 06, 07, 08):**
- Los tests de rules ya tienen dónde apoyarse: `import { adminDemo, adminOtro, superAdmin, sembrar } from './_contexts.mjs'` y `npm run test:rules`.
- Los planes de Cloud Functions tienen codebase, `initializeApp()` resuelto, `functions/.env.demo-gri` con `BOOTSTRAP_EMAIL`/`BOOTSTRAP_SECRET`, y el script `test:functions` ya cableado con los 3 emuladores.
- CLAUDE.md ya no envía a ningún agente contra el stack archivado.

**Notas para quien siga:**
- El wrapper impone cwd en la raíz del repo: cualquier ruta que se pase al comando de test debe ser relativa a la raíz, no a `scripts/`.
- `--set-env` NO alcanza al emulador de Functions. Para que una función vea una variable en emulador hay que declararla en `functions/.env.demo-gri`; `--set-env` solo informa al proceso de test de qué esperar.
- Al añadir un test de rules nuevo, el archivo debe terminar en `.test.mjs` o el glob no lo recogerá.

## Self-Check: PASSED

Archivos declarados como creados — todos verificados en disco:
`scripts/run_emulators.mjs`, `.firebaserc`, `functions/package.json`, `functions/index.js`, `functions/.env.example`, `functions/.env.demo-gri`, `functions/.gitignore`, `scripts/test/rules/_contexts.mjs`, `scripts/test/rules/smoke.test.mjs`, `scripts/test/functions/.gitkeep`.

Commits declarados — todos verificados en `git log`: `46e2422`, `58063f0`, `af125a8`.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
