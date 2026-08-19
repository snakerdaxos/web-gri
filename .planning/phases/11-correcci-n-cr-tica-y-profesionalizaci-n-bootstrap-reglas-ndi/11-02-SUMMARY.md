---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 02
subsystem: testing + panel
tags: [firebase, testing, fake-firestore, cloud-functions, emuladores, estados-vacios, riverpod]

# Dependency graph
requires:
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: buildFakeFirestoreConSeed(), firebase_providers.dart, firebase_bootstrap.dart, dashboard_screen.dart
  - plan: 11-01
    provides: firebase.json con emulators.functions.port 5001, codebase functions/
provides:
  - "buildFakeFirestoreVacio() en los DOS helpers de test (app_cliente y panel_admin)"
  - "app_cliente/test/base_vacia_test.dart y panel_admin/test/base_vacia_test.dart — regresión de primer arranque"
  - "firebaseFunctionsProvider (keepAlive, región explícita us-central1) en el panel"
  - "useFunctionsEmulator 127.0.0.1:5001 dentro del gate USE_EMULATORS del bootstrap del panel"
  - "Guía de arranque del dashboard para super_admin sin restaurante activo"
affects: [11-05, 11-06, 11-07, 11-08, 11-09, 11-10]

# Tech tracking
tech-stack:
  added:
    - "cloud_functions 6.3.6 (panel_admin, versión EXACTA sin ^)"
    - "cloud_functions_platform_interface 6.0.6 + cloud_functions_web 5.1.12 (transitivas)"
  patterns:
    - "Fixture de base VACÍA como par simétrico del fixture sembrado — el seed deja de ser el único punto de partida posible"
    - "Test de contrato que asserta sobre el CÓDIGO FUENTE cuando el runtime exige una app Firebase inicializada"
    - "Región de Cloud Functions declarada explícitamente en cliente y servidor, con gate automatizado que falla si se quita"
    - "Estado vacío que distingue POR QUÉ no hay datos y da el siguiente paso, en vez de renderizar ceros"

key-files:
  created:
    - app_cliente/test/base_vacia_test.dart
    - panel_admin/test/base_vacia_test.dart
    - panel_admin/test/core/functions_provider_test.dart
    - .planning/phases/11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi/deferred-items.md
  modified:
    - app_cliente/test/helpers/firebase_fakes.dart
    - panel_admin/test/helpers/firebase_fakes.dart
    - panel_admin/pubspec.yaml
    - panel_admin/pubspec.lock
    - panel_admin/lib/core/firebase_providers.dart
    - panel_admin/lib/core/firebase_providers.g.dart
    - panel_admin/lib/core/firebase_bootstrap.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/test/dashboard/stats_render_test.dart

key-decisions:
  - "La guía del dashboard se apoya en restaurantesListProvider, que el topbar del AppShell YA observa (app_shell.dart:324): cero consultas nuevas. restaurantesAdminProvider habría añadido una query, porque no está vivo en la ruta del dashboard"
  - "El test de región NO resuelve el provider: FirebaseFunctions.instanceFor exige app Firebase inicializada, imposible en flutter test. Se afirma sobre el texto de los dos archivos fuente"
  - "En riverpod 3 el getter es .value, no .valueOrNull (el plan no lo especificaba)"
  - "Los tests de base vacía son DESCRIPTIVOS del contrato actual, con TODO(11-09) donde la UI aún no guía: endurecerlos aquí habría invadido la ola de 11-09"
  - "El desbordamiento de StatCard a 4 columnas se documenta en deferred-items.md en vez de arreglarse: stat_card.dart no está en el alcance de este plan"

patterns-established:
  - "buildFakeFirestoreVacio() es el punto de partida obligatorio de cualquier prueba de primer arranque de los planes 05, 07 y 10"
  - "Toda región de callable se declara en los dos extremos y queda cubierta por un gate de contrato"

requirements-completed: [ENV-01, TEST-02]

# Metrics
duration: ~30min
completed: 2026-08-19
---

# Phase 11 Plan 02: Punto ciego de base vacía y cliente de Cloud Functions Summary

**El escenario de primer arranque —el único que nunca se había probado, y por donde se colaron los bugs que esta fase repara— ya tiene cobertura automatizada en las dos apps, y el panel puede invocar callables con la región fijada en los dos extremos.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-08-19T15:22Z (aprox.)
- **Completed:** 2026-08-19T15:52Z
- **Tasks:** 3/3
- **Files created/modified:** 13

## Accomplishments

- **Cerrado el punto ciego que dejó pasar tres bugs con 175 pruebas en verde.** `buildFakeFirestoreConSeed()` siempre pre-siembra, así que ninguna prueba había arrancado nunca desde una base sin un solo documento. `buildFakeFirestoreVacio()` existe ahora en ambos helpers y seis casos nuevos ejercitan ese camino.
- **El panel puede hablar con Cloud Functions.** `firebaseFunctionsProvider` con región explícita `us-central1`, el emulador cableado en `127.0.0.1:5001` dentro del gate de compilación, y cinco gates de contrato que fallan si alguien quita la región o saca el emulador del gate. Sin esto, los planes 06, 07 y 08 no podían existir.
- **El super_admin de una plataforma vacía ya sabe qué hacer.** Antes aterrizaba en cuatro tarjetas en cero con un selector vacío —el "selector muerto" de `CONCERNS.md`—. Ahora el dashboard distingue los dos motivos por los que no hay restaurante activo y da el siguiente paso concreto de cada uno.
- **Sin regresiones.** 175 → 190 pruebas (94 app_cliente + 96 panel_admin), `flutter analyze` en 0 issues en las dos apps.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Fixture de base vacía y regresión de primer arranque | RED | `9b2b965` (test) |
| 1 | Fixture de base vacía y regresión de primer arranque | GREEN | `65a5f5d` (feat) |
| 2 | Cliente de Cloud Functions + emulador en el bootstrap | — | `d347b71` (feat) |
| 3 | Guía de arranque del dashboard | RED | `a2333de` (test) |
| 3 | Guía de arranque del dashboard | GREEN | `f6085af` (feat) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline previo | `flutter analyze` + `flutter test` x2 | app_cliente `No issues found!` + `+91 All tests passed!`; panel_admin `No issues found!` + `+84 All tests passed!` |
| T1 RED app_cliente | `flutter test test/base_vacia_test.dart` | `Error: Method not found: 'buildFakeFirestoreVacio'` x3 · `+0 -1: Some tests failed` |
| T1 RED panel_admin | `flutter test test/base_vacia_test.dart` | `Error: Method not found: 'buildFakeFirestoreVacio'` x3 · `+0 -1: Some tests failed` |
| T1 GREEN app_cliente | `flutter test test/base_vacia_test.dart` | `+3: All tests passed!` |
| T1 GREEN panel_admin | `flutter test test/base_vacia_test.dart` | `+3: All tests passed!` |
| T2 publisher | `curl -s https://pub.dev/api/packages/cloud_functions/publisher` | `{"publisherId":"firebase.google.com"}` — coincide, se procede |
| T2 versión | API de pub.dev | `latest: 6.3.6` · `firebase_core dep: "^4.13.0"` (el repo pinea 4.13.0: compatible) · `flutter >=3.27.0` · `6.3.6 existe: true` |
| T2 instalación | `flutter pub add cloud_functions:6.3.6` | `+ cloud_functions 6.3.6` `+ cloud_functions_platform_interface 6.0.6` `+ cloud_functions_web 5.1.12` · `Changed 3 dependencies!` |
| T2 pin exacto | `grep -c "cloud_functions: 6.3.6" pubspec.yaml` | `1` (sin `^`) |
| T2 codegen | `dart run build_runner build --delete-conflicting-outputs` | `Built with build_runner/aot in 37s; wrote 42 outputs` · `firebaseFunctionsProvider` presente en el `.g.dart` |
| T2 | `flutter analyze && flutter test test/core/functions_provider_test.dart` | `No issues found!` · `+5: All tests passed!` |
| T3 RED | `flutter test test/dashboard/stats_render_test.dart` | `+7 -2` — fallan (guía a) y (guía b); **(guía c) y (guía d) pasan**, fijando la no-regresión |
| T3 GREEN | `flutter analyze && flutter test test/dashboard/ test/base_vacia_test.dart` | `No issues found!` · `+24: All tests passed!` |
| Suite final app_cliente | `flutter analyze && flutter test` | `No issues found!` · `+94: All tests passed!` |
| Suite final panel_admin | `flutter analyze && flutter test` | `No issues found!` · `+96: All tests passed!` |
| Verificación del plan | `grep -rn "buildFakeFirestoreVacio" app_cliente/test panel_admin/test` | definido en los 2 helpers, usado en los 2 `base_vacia_test.dart` + `stats_render_test.dart` |

**Conteo de pruebas: 175 → 190 (+15).** app_cliente 91 → 94 (+3), panel_admin 84 → 96 (+12: 3 de base vacía, 5 de contrato de Functions, 4 de la guía del dashboard).

## Files Created/Modified

**Creados**
- `app_cliente/test/base_vacia_test.dart` — `restaurantesList` vacío sin lanzar, `restauranteDetalle` inexistente con `StateError` controlado, `RestaurantesListScreen` con estado vacío legible y sin excepción pendiente
- `panel_admin/test/base_vacia_test.dart` — `restaurantesAdmin` vacío como super_admin, `staffMenu` con `rid` nulo, `ConfiguracionScreen` (tab Restaurantes) sin excepción pendiente
- `panel_admin/test/core/functions_provider_test.dart` — 5 gates de contrato sobre el código fuente
- `.planning/phases/11-.../deferred-items.md` — hallazgo fuera de alcance

**Modificados**
- `app_cliente/test/helpers/firebase_fakes.dart`, `panel_admin/test/helpers/firebase_fakes.dart` — `buildFakeFirestoreVacio()`; `buildFakeFirestoreConSeed()` y `mockAuth()` INTACTOS
- `panel_admin/pubspec.yaml` + `pubspec.lock` — `cloud_functions: 6.3.6`
- `panel_admin/lib/core/firebase_providers.dart` (+ `.g.dart`) — `firebaseFunctionsProvider`
- `panel_admin/lib/core/firebase_bootstrap.dart` — `useFunctionsEmulator` + comentarios ampliados a las tres piezas
- `panel_admin/lib/features/dashboard/dashboard_screen.dart` — `_GuiaSinRestaurante`
- `panel_admin/test/dashboard/stats_render_test.dart` — 4 casos nuevos + helpers `_SeleccionFija` y `_pumpDashboard`

## Decisions Made

- **`restaurantesListProvider`, no `restaurantesAdminProvider`.** El plan pedía comprobar cuál ya estaba en el árbol para no abrir una consulta nueva. Verificado: el topbar del AppShell hace `ref.watch(restaurantesListProvider)` para el super_admin (`app_shell.dart:324`), mientras que `restaurantesAdminProvider` solo vive cuando está abierto el tab Restaurantes de Configuración. Se reutiliza el primero: cero consultas añadidas.
- **El test de región lee el código fuente.** `FirebaseFunctions.instanceFor()` exige app Firebase inicializada, que `flutter test` no puede dar; resolver el provider reventaría con `No Firebase App '[DEFAULT]'`. Lo que hay que proteger no es el runtime sino el ACUERDO entre cliente y servidor, y eso vive en el texto de los dos archivos.
- **Tests descriptivos, no aspiracionales.** Donde la UI hoy no guía (tab Restaurantes vacío del panel), el test solo afirma "no hay excepción pendiente" + el contador real, con `TODO(11-09)`.
- **La guía distingue los dos casos y añade un botón de atajo** a `/configuracion` en el caso de plataforma vacía. El plan pedía el texto; el botón es el mismo `ElevatedButton` con `GriColors.primary` ya usado en la pantalla — sin estilo nuevo y sin anticipar el `EmptyState` compartido de 11-09.
- **Mientras la lista carga o falla, no se afirma que la plataforma esté vacía.** Cargando → spinner; error → mensaje del selector. Decir "no hay restaurantes" sin haber podido leerlos sería mentirle al operador.

## Deviations from Plan

### Auto-fixed Issues

**1. [Regla 3 - Bloqueante] En riverpod 3 el getter es `.value`, no `.valueOrNull`**
- **Found during:** Tarea 3
- **Issue:** El código escrito con `AsyncValue.valueOrNull` (nombre del API en riverpod 2) falló con `The getter 'valueOrNull' isn't defined for the type 'AsyncValue<...>'` — 2 errores de `flutter analyze`.
- **Fix:** Sustituido por `.value` en las dos lecturas.
- **Files modified:** `panel_admin/lib/features/dashboard/dashboard_screen.dart`
- **Verification:** `flutter analyze` → `No issues found!`
- **Committed in:** `f6085af`

**2. [Regla 1 - Bug en mi propio test] El gate del emulador buscaba la primera aparición de `useFunctionsEmulator`, que está en el doc comment**
- **Found during:** Tarea 2
- **Issue:** `bootstrap.indexOf('useFunctionsEmulator')` casaba con la MENCIÓN del doc comment de cabecera del archivo, situada ANTES del gate `if (useEmulators)`. El test fallaba afirmando que la llamada estaba fuera del gate cuando sí está dentro.
- **Fix:** Se busca la invocación literal `.useFunctionsEmulator('127.0.0.1', 5001)` y se añaden dos aserciones previas (`la llamada debe existir`, `el gate debe cerrarse`) para que un índice `-1` no pase inadvertido.
- **Files modified:** `panel_admin/test/core/functions_provider_test.dart`
- **Verification:** `+5: All tests passed!`
- **Committed in:** `d347b71`

**3. [Regla 1 - Aserción imprecisa] `find.textContaining('Configuración')` casaba dos veces**
- **Found during:** Tarea 3
- **Issue:** La implementación quedó con el texto guía Y el botón de atajo, ambos con la palabra "Configuración" → `findsOneWidget` fallaba con 2 coincidencias.
- **Fix:** Se ENDURECIÓ la aserción en vez de relajarla: `find.text('Ve a Configuración → Restaurantes para crear el primero.')` exacto + `find.text('Ir a Configuración')`. La cobertura sube, no baja.
- **Files modified:** `panel_admin/test/dashboard/stats_render_test.dart`
- **Verification:** `+24: All tests passed!`
- **Committed in:** `f6085af`

### Fuera de alcance (NO arreglado — anotado en `deferred-items.md`)

**`StatCard` desborda 31px cuando el grid pasa a 4 columnas.** Descubierto al pumpear el dashboard con un viewport de 1200px: con `maxWidth >= 1100` el grid va a 4 columnas y el `childAspectRatio: 2.6` deja 59.8px para ~91px de contenido → `RenderFlex overflowed by 31 pixels on the bottom` (`widgets/stat_card.dart:50`). Es un defecto de responsive **preexistente**, no introducido aquí, y `stat_card.dart` no está en los `files_modified` de este plan: arreglarlo colisionaría con el bloque de sistema de diseño. Los tests nuevos usan un viewport de 800px (el mismo camino de 1 columna que los tests de render ya existentes), con un comentario en el código que explica por qué. **Afecta al panel real, que es web y se ve en pantallas anchas — debe entrar en el plan de responsive del bloque 3.**

---

**Total deviations:** 3 auto-corregidas (2× Regla 1, 1× Regla 3) + 1 hallazgo diferido.
**Impact on plan:** Ninguna reduce alcance. Dos eran defectos en las aserciones que yo mismo escribí (una de ellas se corrigió endureciendo el test) y una es una diferencia de API entre riverpod 2 y 3 que el plan no anticipaba. Sin scope creep.

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-02-SC | Mitigado | Publisher consultado ANTES de instalar: `{"publisherId":"firebase.google.com"}` — coincide con el exigido. Versión pineada EXACTA (`cloud_functions: 6.3.6`, sin `^`, verificado con `grep -c` → 1). `pubspec.lock` versionado |
| T-11-02-02 | Mitigado | `us-central1` explícito en `firebase_providers.dart` y en `firebase_bootstrap.dart` (`grep -c` → 1 en cada uno), con 2 tests que fallan si se quita |
| T-11-02-03 | Mitigado | Test `el cableado del emulador vive DENTRO del gate useEmulators`: comprueba que existe `bool.fromEnvironment('USE_EMULATORS', defaultValue: false)` y que el índice de la llamada cae entre la apertura y el cierre del bloque. Sin el `--dart-define`, la llamada no existe en el binario |
| T-11-02-04 | Aceptado | El fixture vacío solo afecta a tests; sin superficie de producción |
| T-11-02-05 | Mitigado | La guía describe el siguiente paso operativo y el conteo agregado; no enumera restaurantes de otros tenants (y el super_admin ya los ve por rules) |

## Known Stubs

- **`_GuiaSinRestaurante` es el ÚNICO estado vacío endurecido de este plan.** El tab Restaurantes de `/configuracion` con la plataforma vacía sigue mostrando solo `0 restaurantes en la plataforma` sin llamada a la acción, y la lista del cliente muestra `No hay restaurantes disponibles` sin guía. **Intencional y exigido por el plan**: "Está PROHIBIDO arreglar aquí la UI de los estados vacíos: eso es el plan 11-09". Ambos puntos quedan marcados con `TODO(11-09)` en los tests correspondientes.
- **`firebaseFunctionsProvider` no lo consume nadie todavía.** Es infraestructura para 11-06/11-07/11-08 (bootstrap de plataforma y alta de staff). Declarado en el plan como su propósito.

## Threat Flags

Ninguna superficie de seguridad nueva fuera del `<threat_model>` del plan. El único canal nuevo hacia código privilegiado (panel → Cloud Functions) estaba previsto y sus tres amenazas quedan mitigadas arriba. La guía del dashboard no lee ninguna colección que el super_admin no leyera ya.

## Issues Encountered

- **Ninguno bloqueante.** El `EBADENGINE` de `functions/` heredado de 11-01 no interviene aquí: este plan no ejecuta el emulador de Functions, solo cablea el cliente. La conexión real cliente↔emulador se verificará cuando exista la primera callable (11-07).
- Los tres archivos pendientes del árbol de trabajo (`AndroidManifest.xml` modificado, `documentos/`, `run_app.bat`, `res/xml/`) son PREVIOS a este plan y ajenos a él: no se han tocado ni commiteado.

## User Setup Required

Ninguno. `flutter pub get` lo resuelve `flutter pub add` automáticamente y el emulador de Functions ya quedó configurado en 11-01.

## Next Phase Readiness

**Listo para los planes que dependían de esto:**
- **11-05, 11-07, 11-10** ya pueden partir de `buildFakeFirestoreVacio()` para probar el arranque desde cero.
- **11-06 / 11-07 / 11-08** tienen el cliente de callables: `ref.watch(firebaseFunctionsProvider).httpsCallable('nombre')`. La función del lado servidor DEBE declarar `region: 'us-central1'` o el test de contrato quedará desalineado con la realidad (un desajuste da 404 opaco, disfrazado de CORS en web).
- **11-09** hereda dos `TODO(11-09)` concretos y ya localizados: el tab Restaurantes del panel y la lista vacía del cliente.

**Notas para quien siga:**
- En riverpod 3 el getter de `AsyncValue` es `.value`, no `.valueOrNull`.
- Para pumpear el dashboard con providers reales existe `_pumpDashboard` en `stats_render_test.dart`, junto a `_SeleccionFija` para fijar la selección del super_admin (el `AppShell`, que en producción setea el default, no participa en los pumps sueltos).
- **No usar un viewport ≥1100px en tests del dashboard hasta que se arregle el desbordamiento de `StatCard`** (ver `deferred-items.md`).

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `app_cliente/test/base_vacia_test.dart`, `panel_admin/test/base_vacia_test.dart`, `panel_admin/test/core/functions_provider_test.dart`, `deferred-items.md`.

Commits declarados — verificados en `git log`: `9b2b965`, `65a5f5d`, `d347b71`, `a2333de`, `f6085af`.

Gates de TDD presentes en el historial: `test(...)` antes de `feat(...)` en las Tareas 1 y 3.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
