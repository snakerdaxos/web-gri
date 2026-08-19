---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 03
subsystem: menu (cliente + panel) + rules/indices
tags: [firestore-rules, query-vs-rules, indices-compuestos, audit-estatico, menu, p0]

# Dependency graph
requires:
  - plan: 11-01
    provides: scripts/run_emulators.mjs, scripts/test/rules/_contexts.mjs, npm run test:rules
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: firestore.rules, firestore.indexes.json, restaurantes_provider.dart, menu_provider.dart
provides:
  - "scripts/test/rules/categorias.test.mjs y productos.test.mjs — 16 casos que prueban el modo de fallo query-vs-rules contra el emulador"
  - "app_cliente restauranteDetalle con filtros server-side que replican EXACTAMENTE la rama pública de firestore.rules"
  - "firestore.indexes.json con el índice categorias(restauranteId, orden) que exige el menú del panel"
  - "scripts/audit_indexes.mjs + npm run audit:indexes — audit estático de índices Y de paridad rules↔query"
  - "initEnv(namespace) en _contexts.mjs — aislamiento por archivo de test (contrato ampliado, retrocompatible)"
affects: [11-04, 11-08, 11-10, 11-15, 11-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Regla mental permanente: si la rule menciona resource.data.X, la query DEBE llevar where('X', …)"
    - "Gate estático como única mitigación posible cuando el emulador no puede verificar (índices compuestos)"
    - "Exención por comentario DECLARADO (// AUDIT-STAFF) — la exención silenciosa cuenta como fallo"
    - "Un archivo de test de rules por colección (por match), no por rol"
    - "Un projectId por archivo de test: node --test paraleliza por archivo contra un emulador compartido"

key-files:
  created:
    - scripts/test/rules/categorias.test.mjs
    - scripts/test/rules/productos.test.mjs
    - scripts/audit_indexes.mjs
  modified:
    - app_cliente/lib/features/restaurantes/restaurantes_provider.dart
    - app_cliente/test/restaurantes/list_test.dart
    - firestore.indexes.json
    - scripts/package.json
    - scripts/test/rules/_contexts.mjs
    - scripts/test/rules/smoke.test.mjs
    - panel_admin/lib/features/menu/menu_provider.dart

key-decisions:
  - "El orderBy('orden') de categorías sigue siendo client-side en el cliente: hacerlo server-side obligaría al índice categorias(restauranteId, activo, orden) y el emulador no valida índices, así que cada índice extra es un punto de fallo que solo se descubre en producción"
  - "El audit NO marca como FALTA un rango solo, sin igualdades ni orderBy: lo resuelve el índice automático de campo único. Marcarlo sería un falso positivo bloqueante"
  - "El audit acepta la dirección invertida del orderBy: un índice de Firestore se recorre en los dos sentidos (por eso pedidos(…, createdAt DESC) sirve al orderBy('createdAt') ASC de cocina)"
  - "La paridad rules↔query se aplica a TODAS las apps, no solo a app_cliente: así el marcador // AUDIT-STAFF del panel es un mecanismo vivo y la exención queda declarada por escrito"

patterns-established:
  - "Cualquier test de rules nuevo (11-04, 11-08) DEBE llamar initEnv('<su-namespace>')"
  - "Tocar la rama pública de firestore.rules obliga a actualizar PARIDAD_RULES_QUERY en el MISMO commit"

requirements-completed: [FIX-01, FIX-02, TEST-01]

# Metrics
duration: ~13min
completed: 2026-08-19
---

# Phase 11 Plan 03: Corrección del menú (query vs rules + índice) Summary

**El menú del cliente deja de estar denegado siempre —la query ahora replica lo que la regla exige por documento— y el menú del panel tiene por fin su índice compuesto declarado, con dos gates automatizados que impiden que cualquiera de los dos bugs vuelva a llegar a producción.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-08-19T15:56:22Z
- **Completed:** 2026-08-19T16:09:44Z
- **Tasks:** 3/3
- **Files created/modified:** 10

## Accomplishments

- **Cerrado el P0 del menú del cliente.** `restauranteDetalle` consultaba `categorias` y `productos` filtrando `activo` CLIENT-SIDE. Firestore evalúa las rules contra la CONSULTA, no contra los documentos, así que la petición se rechazaba entera — **incondicionalmente, también contra el seed prístino donde todo está activo**. Ahora los `where` replican exactamente la rama pública de la regla.
- **Escrita la evidencia ejecutable del modo de fallo.** 16 casos nuevos contra el emulador con las rules reales. La query que hoy hace la app está afirmada como DENEGADA; la corregida, como PERMITIDA y filtrando de verdad (1 de 2 categorías, 1 de 3 productos).
- **Declarado el índice que faltaba.** `categorias(restauranteId ASC, orden ASC)` — el que exige `menu_provider.dart:39` y por cuya ausencia el menú del panel daba `FAILED_PRECONDITION` en cada carga. `firestore.indexes.json` pasa de 9 a 10 índices, **8 inserciones y 0 borrados**.
- **Dos redes de seguridad nuevas, ambas verificadas rompiéndolas a propósito.** `npm run audit:indexes` clasifica las 21 queries del repo y falla si alguna pierde su índice o un filtro que la regla exige.
- **Cambio de comportamiento deliberado:** un producto **agotado** (`disponible: false`) ya NO aparece en el menú del cliente. Antes el filtrado client-side solo miraba `activo`, así que un agotado sí llegaba a la UI (cuando la query no estaba denegada, es decir: nunca en producción).
- **Sin regresiones:** app_cliente 94 → 96 tests, panel_admin 96 (intacto), rules 2 → 18. `flutter analyze` en 0 issues en ambas apps.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Suite de rules de categorias y productos | — (evidencia, no RED→GREEN) | `23151d8` (test) |
| 2 | Corregir las queries del menú del cliente | RED | `5aa08d0` (test) |
| 2 | Corregir las queries del menú del cliente | GREEN | `7caeb71` (feat) |
| 3 | Índice + audit de índices + paridad rules↔query | — | `52d2db6` (feat) |
| — | Desviación: carrera del arnés de rules | fix | `74ceacb` (fix) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline previo | `cd app_cliente && flutter analyze` | `No issues found! (ran in 9.8s)` |
| **T1** | `node run_emulators.mjs --only firestore --project demo-gri -- node --test .../categorias.test.mjs .../productos.test.mjs` | `tests 16 · pass 16 · fail 0` · `duration_ms 2600.5` · **exit 0** |
| **T2 RED** | `cd app_cliente && flutter test test/restaurantes/list_test.dart` | `+5 -1: Some tests failed` — `Expected: not contains 'Sancocho agotado'` / `Actual: [… 'Sancocho agotado' …]` |
| **T2 GREEN** | `cd app_cliente && flutter analyze && flutter test test/restaurantes/list_test.dart` | `No issues found!` · `+7: All tests passed!` |
| T2 grep | `grep -c "where('disponible', isEqualTo: true)" …/restaurantes_provider.dart` | `1` |
| **T3** | `cd scripts && npm run audit:indexes` | 21 queries clasificadas · 4 sujetas a paridad · `0 fallo(s)` · **exit 0** |
| T3 índice | `node -e "…filtrar categorias… f!=='restauranteId,orden' → exit 1"` | `INDICE_OK` · `total indices: 10` |
| T3 diff | `git diff --stat firestore.indexes.json` | `8 ++++++++` · **0 borrados** (los 9 índices previos intactos) |
| **T3 gate por construcción A** | quitar el índice `categorias` → `npm run audit:indexes` | `menu_provider.dart:39 … FALTA ÍNDICE COMPUESTO` · `1 fallo(s)` · **exit 1**. Índice restaurado |
| **T3 gate por construcción B** | quitar `where('disponible')` del provider → `npm run audit:indexes` | `restaurantes_provider.dart:77 productos restauranteId== activo== → FALTA where('disponible')` · `1 fallo(s)` · **exit 1**. Provider restaurado (`git diff` vacío) |
| T3 exención | sin `// AUDIT-STAFF` en `menu_provider.dart` | `FALTA where('activo')` + `FALTA where('activo') + where('disponible')` · **exit 1** → la exención silenciosa efectivamente cuenta como fallo |
| Verificación final — rules | `cd scripts && npm run test:rules` | `tests 18 · suites 3 · pass 18 · fail 0` · **exit 0** |
| Verificación final — rules en PARALELO | `node --test scripts/test/rules/*.test.mjs` (sin `--test-concurrency=1`) | `tests 18 · pass 18 · fail 0` · **exit 0** — el aislamiento por namespace basta por sí solo |
| Verificación final — suite scripts | `cd scripts && npm test` | **exit 0** |
| Verificación final — app_cliente | `flutter test` + `flutter analyze` | `+96: All tests passed!` · `No issues found!` |
| Verificación final — panel_admin | `flutter test` + `flutter analyze` | `+96: All tests passed!` · `No issues found!` |
| Verificación manual del plan | `grep -n "activo" …/restaurantes_provider.dart` | Solo `where('activo', isEqualTo: true)` y comentarios. `grep "retainWhere\|producto.activo\|continue;"` → **vacío**: cero filtrado client-side residual |

**Conteo de pruebas: 190 → 192 en apps (+2 en app_cliente) y 2 → 18 en rules (+16).** Ninguna bajó.

## Files Created/Modified

**Creados**
- `scripts/test/rules/categorias.test.mjs` (189 líneas) — 7 casos. Cabecera documenta el modo de fallo con la cita textual de la doc oficial y el enlace a `firestore.rules:104-108`, que ya lo advertía por escrito
- `scripts/test/rules/productos.test.mjs` (173 líneas) — 9 casos, incluidos los 3 de escritura denegada al cliente
- `scripts/audit_indexes.mjs` (461 líneas) — parser de cadenas de query Dart + check de índices + check de paridad rules↔query

**Modificados**
- `app_cliente/lib/features/restaurantes/restaurantes_provider.dart` — `+where('activo')` en categorías, `+where('activo')+where('disponible')` en productos; borrados `if (!producto.activo) continue;` y `..retainWhere((c) => c.activo)`; doc del provider reescrito explicando que el motivo es autorización, no rendimiento
- `app_cliente/test/restaurantes/list_test.dart` — 2 casos nuevos + helper `sembrarMenuSucio`
- `firestore.indexes.json` — +1 índice (`categorias`)
- `scripts/package.json` — `audit:indexes` + `--test-concurrency=1` en los dos scripts de test
- `scripts/test/rules/_contexts.mjs` — `initEnv(namespace)` (retrocompatible)
- `scripts/test/rules/smoke.test.mjs` — usa su namespace
- `panel_admin/lib/features/menu/menu_provider.dart` — **solo comentarios**: los 2 marcadores `// AUDIT-STAFF`. Las queries NO cambian

## Decisions Made

- **El `orderBy('orden')` del cliente se queda client-side.** Hacerlo server-side obligaría al índice `categorias(restauranteId, activo, orden)`. El N de categorías por restaurante es pequeño, y como el emulador no valida índices, cada índice extra es un punto de fallo que solo se descubre en producción. Queda razonado en el propio código para que no se "optimice" a ciegas.
- **El audit acepta la dirección de `orderBy` invertida.** Un índice de Firestore se recorre en los dos sentidos, así que `pedidos(restauranteId, estado, createdAt DESC)` sirve al `orderBy('createdAt')` ASCENDENTE de cocina. Sin este matiz, el audit habría reportado un falso `FALTA` sobre una query que lleva funcionando desde la Fase 10.
- **Un rango solo (sin igualdades ni `orderBy`) NO se marca como falta.** Lo resuelve el índice automático de campo único. La formulación corta del plan ("si hay rango, hace falta compuesto") produciría un falso positivo bloqueante. Ninguna query actual del repo cae en ese caso, así que ambas lecturas coinciden hoy.
- **La paridad rules↔query se aplica a las dos apps, no solo a `app_cliente`.** Si se hubiera restringido por app, el marcador `// AUDIT-STAFF` del panel sería código muerto. Aplicándola en todas partes, la exención del staff tiene que declararse por escrito y queda auditada — que es justo lo que pedía el plan ("una exención silenciosa cuenta como fallo").

## Deviations from Plan

### Auto-fixed Issues

**1. [Regla 1 — Bug real en el arnés compartido] Carrera entre archivos de test de rules**
- **Found during:** verificación final de la Tarea 3 (`npm run test:rules`)
- **Issue:** Los 16 casos nuevos pasaban en solitario, pero al correr la suite COMPLETA fallaba `ANÓNIMO: query CON where('activo') → PERMITIDA` con `snap.size` 0 en vez de 1. `node --test` ejecuta los archivos en PARALELO (un proceso por archivo) contra el MISMO emulador, y los 3 archivos compartían el `projectId` `demo-gri-rules`: el `clearFirestore()` del `beforeEach` de uno borraba el seed que otro acababa de escribir. Bug **latente desde 11-01**, invisible mientras solo existía `smoke.test.mjs`.
- **Por qué NO se tocó la aserción:** el plan prohíbe explícitamente reescribir el veredicto del caso anónimo para que coincida con lo observado. El fallo era del arnés, no de la expectativa — y en efecto, arreglado el arnés, el veredicto PERMITIDA del plan se confirma.
- **Fix:** `initEnv(namespace)` opcional en `_contexts.mjs` → `projectId` propio por archivo (`demo-gri-rules-categorias`, `-productos`, `-smoke`). Firma retrocompatible, porque `_contexts.mjs` es un contrato del que dependen 11-04 y 11-08. Además `--test-concurrency=1` en los npm scripts como red de seguridad para que olvidar el namespace no pueda volver a romper nada.
- **Verification:** `tests 18 · pass 18 · fail 0` en serie **y** en paralelo sin `--test-concurrency=1` (el aislamiento basta por sí solo).
- **Committed in:** `74ceacb`

**2. [Regla 3 — Bloqueante] `panel_admin/lib/features/menu/menu_provider.dart` no estaba en los `files_modified` del plan**
- **Found during:** Tarea 3
- **Issue:** El plan exige que las queries de staff sobre `categorias`/`productos` se eximan de la paridad **marcándolas** con `// AUDIT-STAFF: <motivo>`, y que el script exija ese comentario. Sin tocar `menu_provider.dart`, `npm run audit:indexes` sale con **exit 1** y la Tarea 3 no puede cumplir su `<done>`.
- **Fix:** Añadidos los 2 marcadores. **Solo comentarios — ninguna query del panel cambia** (el plan es explícito: "La query del panel NO cambia; lo que falta es el índice").
- **Verification:** `flutter analyze` en panel_admin `No issues found!` · `flutter test` `+96: All tests passed!` (idéntico al baseline) · audit exit 0.
- **Committed in:** `52d2db6`

### Aclaraciones de interpretación (sin cambio de alcance)

**3. "admin del tenant, query sin filtros → PERMITIDA" (`<behavior>` de productos).** Una query literalmente sin filtros —ni siquiera `restauranteId`— está DENEGADA también para el staff: `menuStaffOf(resource.data.restauranteId)` exige que la consulta fije `restauranteId`, y la rama pública tampoco es demostrable. La lectura coherente con el caso paralelo de `categorias` ("sin filtro de activo") es "sin los filtros de `activo`/`disponible`", y así está implementado. Para no perder cobertura, se **añadió** un caso extra que afirma que la query verdaderamente sin filtros SÍ queda denegada. La cobertura sube, no baja.

**4. Referencia de línea `firestore.rules:109-111`.** El bloque real es `104-108` en el fichero vigente. Se cita la línea correcta en la cabecera del test.

---

**Total deviations:** 2 auto-corregidas (1× Regla 1, 1× Regla 3) + 2 aclaraciones de interpretación.
**Impact on plan:** Ninguna reduce alcance. La Regla 1 destapó un defecto real y preexistente del arnés compartido que habría hecho intermitentes los tests de 11-04 y 11-08. Sin scope creep.

## Qué queda VERIFICADO y qué NO — leer antes de dar el bug por cerrado

### Verificado de verdad (automatizado, con las rules reales)

- **El bug del cliente (query vs rules) está cerrado y probado.** `categorias.test.mjs` / `productos.test.mjs` corren contra el motor de rules del emulador de Firestore con `firestore.rules` real. Afirman que la query vieja está denegada, que la nueva está permitida, y que filtra de verdad. Esto es prueba, no indicio.
- **El aislamiento cross-tenant sigue en pie:** un `admin_restaurante` de otro `rid` queda denegado en ambas colecciones (T-11-03-01).
- **El cliente no puede escribir el menú:** `create`/`update`/`delete` denegados (T-11-03-04).
- **La pérdida futura de un filtro exigido por la regla la detecta un comando**, verificado por construcción quitando `where('disponible')` → exit 1 (T-11-03-05).
- **El filtrado que ve el usuario** (inactivos y agotados fuera del menú) está probado en `app_cliente` sobre `fake_cloud_firestore`.

### NO verificado — y no puede verificarse localmente

- ⚠️ **El bug del índice compuesto NO está probado por ningún test.** El emulador de Firestore **no rastrea índices compuestos y ejecuta cualquier query válida**: una suite local no puede reproducir el `FAILED_PRECONDITION` del menú del panel ni demostrar que el índice nuevo lo cura. `audit_indexes.mjs` es una **mitigación estática**, no una prueba: comprueba que el índice está **declarado** en `firestore.indexes.json`, no que exista ni funcione en el proyecto real.
- **La verificación real del índice es el checkpoint humano de 11-16**, tras `firebase deploy --only firestore:indexes` contra `p-gri-b5b40` y abrir el menú del panel. Hasta ese momento, lo correcto es decir "el índice está declarado", nunca "el bug está cerrado".
- **`fake_cloud_firestore` no tiene motor de rules.** Los tests de `app_cliente` verifican FILTRADO, jamás AUTORIZACIÓN. Está dicho en un comentario dentro del propio test para que nadie lo confunda.
- **`audit_indexes.mjs` es heurístico sobre texto.** No entiende queries construidas dinámicamente, `Query` guardadas en variable, ni `collectionGroup`. Un OK significa "no se detecta nada mal", no "está probado". Está escrito en la cabecera del script y se imprime en cada ejecución.

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-03-01 | Mitigado | Los filtros replican exactamente la condición de la regla. `categorias.test.mjs` y `productos.test.mjs` afirman que el admin de otro tenant sigue denegado y que inactivos/agotados no salen de la query filtrada |
| T-11-03-02 | **Parcialmente mitigado** | Cliente: **cerrado y probado** (16 casos contra el emulador). Panel: el índice está **declarado**, pero el emulador no valida índices → la mitigación es estática y la verificación real es el checkpoint humano de 11-16 |
| T-11-03-03 | Mitigado | `git diff --stat firestore.indexes.json` = 8 inserciones, 0 borrados. El audit falla si una query futura pierde su índice (verificado quitando el de `categorias` → exit 1) |
| T-11-03-05 | Mitigado | Check de paridad con exenciones que deben declararse por comentario. Verificado por construcción: quitar `where('disponible')` → exit 1; quitar el `// AUDIT-STAFF` del panel → exit 1 |
| T-11-03-04 | Mitigado | 3 casos `assertFails` de create/update/delete del cliente sobre `productos` |

## Known Stubs

Ninguno. Las 3 tareas quedan completas y sin marcadores pendientes. La entrada `usuarios` de la tabla `PARIDAD_RULES_QUERY` **no** es un stub: es la regla ya declarada para cuando 11-10 añada la pantalla de gestión de equipo; hoy ninguna query la alcanza y el audit lo dice explícitamente en su salida.

## Threat Flags

Ninguna. Este plan **reduce** superficie: las queries del cliente pasan a estar acotadas por los mismos campos que exige la regla, y no se añade ningún endpoint, ruta de auth ni cambio de esquema.

## Issues Encountered

- **Trampa de cwd en Windows/Git Bash:** en un comando compuesto, un `cd scripts` intermedio deja el `cwd` cambiado, y un `cp … firestore.indexes.json` posterior escribió el fichero en `scripts/` en vez de en la raíz. Detectado de inmediato, fichero raíz restaurado desde el backup y la copia espuria borrada (`git status` limpio, `git diff` del provider vacío). Sin impacto en ningún commit.
- El emulador deja `firestore-debug.log` en la raíz; ya está cubierto por `*-debug.log` en `.gitignore` desde 11-01.
- Los ficheros pendientes del árbol de trabajo (`AndroidManifest.xml`, `documentos/`, `run_app.bat`, `res/xml/`) son PREVIOS a este plan y ajenos a él: no se han tocado ni commiteado.

## User Setup Required

Ninguno para los gates automatizados. **Pendiente para cerrar de verdad el bug del índice:**
`firebase deploy --only firestore:indexes` contra `p-gri-b5b40` y abrir el menú del panel. Los índices tardan minutos en construirse. Es el paso del runbook de 11-15/11-16, no de este plan.

## Next Phase Readiness

- **11-04 y 11-08** (más tests de rules): el arnés ya soporta varios archivos sin pisarse. **Obligatorio llamar a `initEnv('<su-namespace>')`** — sin namespace se comparte base y los tests fallan por la razón equivocada.
- **11-10** (gestión de equipo): la fila `usuarios → where('restauranteId')` ya está declarada en `PARIDAD_RULES_QUERY`. Cuando ese plan toque la rama del admin del tenant en `firestore.rules`, debe actualizar la tabla **en el mismo commit**; el propio script lo ordena por escrito.
- **11-15/11-16** (runbook E2E y checkpoint humano): heredan el único punto que no se puede automatizar — verificar el índice compuesto contra el proyecto real.
- **Cualquier plan que añada una query:** `cd scripts && npm run audit:indexes` antes de commitear. Si una query no es parseable, el audit falla en vez de callarse; se declara con `// AUDIT-IGNORE: motivo`.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `scripts/test/rules/categorias.test.mjs` (189 líneas ≥ 50 exigidas), `scripts/test/rules/productos.test.mjs` (173), `scripts/audit_indexes.mjs` (461 ≥ 90 exigidas).

`firestore.indexes.json` contiene `categorias` con campos `restauranteId,orden` — verificado con el propio gate del plan (`INDICE_OK`).

`scripts/package.json` referencia `audit_indexes.mjs` — verificado.

Commits declarados — todos verificados en `git log`: `23151d8`, `5aa08d0`, `7caeb71`, `52d2db6`, `74ceacb`.

Gates de TDD presentes en el historial de la Tarea 2: `test(11-03)` (`5aa08d0`) antes de `feat(11-03)` (`7caeb71`).

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
