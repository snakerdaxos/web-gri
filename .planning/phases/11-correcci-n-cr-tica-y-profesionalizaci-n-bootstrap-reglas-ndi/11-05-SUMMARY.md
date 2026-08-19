---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 05
subsystem: panel_admin — bootstrap de plataforma (alta de restaurante)
tags: [bootstrap, slug, firestore, riverpod, estados-vacios, confirmacion-destructiva, tdd]

# Dependency graph
requires:
  - plan: 11-02
    provides: buildFakeFirestoreVacio() en panel_admin/test/helpers/firebase_fakes.dart
  - plan: 11-04
    provides: scripts/test/rules/restaurantes.test.mjs — la autorización de `restaurantes` ya probada contra el emulador
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: restaurantes_admin_provider.dart (listar + toggle), configuracion_screen.dart, seleccionRestauranteProvider
provides:
  - "generarSlug + slugEsValido — identificador canónico del restaurante, con el puente probado hacia la regexp del escáner del móvil"
  - "crearRestaurante(db, ...) — alta con validación de slug y check de existencia previo"
  - "RestauranteFormDialog — diálogo de alta con vista previa del identificador"
  - "Tab Restaurantes: botón de alta, estado vacío guiado con CTA y confirmación antes de desactivar"
  - "Selección automática del restaurante recién creado (desbloquea mesas y menú para el super_admin)"
affects: [11-06, 11-07, 11-09, 11-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "El identificador estructural se valida ANTES de escribir y se le MUESTRA al usuario antes de confirmar (es irreversible)"
    - "Check de existencia previo a un .set() cuando las rules solo permiten updates parciales: convierte un permission-denied críptico en un mensaje de negocio"
    - "Confirmación destructiva SOLO en el sentido destructivo, con el radio de impacto explícito en el texto"
    - "Toda acción de alta que cambia el contexto de trabajo fija ese contexto al cerrar (aquí: seleccionRestauranteProvider)"
    - "Todo gate añadido se verifica ROMPIÉNDOLO (9 roturas deliberadas en este plan, todas revertidas)"

key-files:
  created:
    - panel_admin/lib/features/configuracion/slug.dart
    - panel_admin/lib/features/configuracion/restaurante_form_dialog.dart
    - panel_admin/test/configuracion/slug_test.dart
    - panel_admin/test/configuracion/crear_restaurante_test.dart
  modified:
    - panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart
    - panel_admin/lib/features/configuracion/configuracion_screen.dart
    - panel_admin/test/configuracion/restaurantes_test.dart
    - panel_admin/test/base_vacia_test.dart

key-decisions:
  - "El CTA del estado vacío se llama 'Crear el primer restaurante' y no repite '+ Nuevo restaurante': dos botones con el mismo texto habrían hecho ambiguos todos los finders y el copy específico guía mejor"
  - "El mensaje del slug vacío se fuerza con InputDecoration.errorText, no con el validator: con AutovalidateMode.onUserInteraction el validador NUNCA se dispara en ese caso porque el usuario jamás toca ese campo"
  - "La aserción con dientes del doble-guardado es que el botón se apaga, no el doc-count: el count seguiría en 1 aunque el guard no existiera, porque el check de existencia rechaza el segundo intento"
  - "El diálogo se pumpea con showDialog sobre una ruta anfitriona en vez de como home directo: el pop del éxito necesita una ruta a la que volver"
  - "crearRestaurante NO usa transacción: las rules rechazarían igualmente al segundo escritor (un .set() sobre doc existente es update y el super solo puede tocar 'activo'), así que la carrera no puede corromper datos"

patterns-established:
  - "Quien toque slug.dart debe correr test/configuracion/slug_test.dart: su grupo 'puente con el escáner' es el único punto donde el contrato panel↔móvil es ejecutable"
  - "Los planes que añadan pantallas de alta deben fijar el contexto de trabajo al cerrar, como hace este diálogo con seleccionRestauranteProvider"

requirements-completed: [BOOT-02, UX-04]

# Metrics
duration: ~15min
completed: 2026-08-19
---

# Phase 11 Plan 05: Alta de restaurante desde el producto Summary

**Un super_admin que entra a una plataforma vacía ya no está en un callejón sin salida: crea su primer restaurante desde el panel, ve el identificador —que decide para siempre si los QR de sus mesas serán escaneables— antes de confirmarlo, y sale del alta con ese restaurante ya seleccionado y listo para recibir mesas y menú.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-19T16:33:31Z
- **Completed:** 2026-08-19T16:48Z
- **Tasks:** 3/3
- **Files created/modified:** 8

## Accomplishments

- **Cerrada la primera mitad del hueco de bootstrap.** Hasta hoy el tab Restaurantes solo LISTABA y toggleaba `activo`; poblar la plataforma exigía script o consola de Firebase. Las rules ya permitían el `create` al super (`firestore.rules:88`) — faltaba la función y la pantalla, y ya existen.
- **La restricción dura del slug es ahora ejecutable, no un comentario.** `generarSlug`/`slugEsValido` pliegan tildes y ñ, y el test compone `GRI-MESA-{slug}-001` y lo evalúa contra la regexp REAL del escáner del móvil. Con **control negativo**: el nombre crudo (`GRI-MESA-Pizzería Doña Ana-001`) debe ser RECHAZADO, para que la aserción positiva no esté verde por construcción.
- **El duplicado da un mensaje de negocio, no un `permission-denied`.** El check de existencia va antes del `.set()` porque Firestore evalúa un set sobre un doc existente como **update**, y la regla del super solo admite `hasOnly(['activo'])`.
- **El alta deja el panel operativo.** Sin fijar `seleccionRestauranteProvider` al cerrar, el super se quedaba sin restaurante activo para siempre (`_maybeInitDefaultRid` ya corrió en `initState` con la lista vacía) y no podía crear ni una mesa ni una categoría. Hay test que falla si se quita esa línea (rotura E).
- **Desactivar exige confirmación con el radio de impacto explícito**; activar no. Ambos sentidos están probados, y las dos roturas (quitar la confirmación / ponerla en ambos sentidos) ponen en rojo tests distintos.
- **Sin regresiones:** panel 96 → **132**, app_cliente **96** intacto, rules **208** intactos, `flutter analyze` 0 issues en las dos apps.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Generación y validación de slug | RED | `5d02e98` (test) |
| 1 | Generación y validación de slug | GREEN | `c2e62d2` (feat) |
| 2 | crearRestaurante() + diálogo de alta | RED | `66afa5b` (test) |
| 2 | crearRestaurante() + diálogo de alta | GREEN | `72b9234` (feat) |
| 3 | Tab: alta, estado vacío guiado y confirmación | — | `f137263` (feat) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline | `cd panel_admin && flutter analyze && flutter test` | `No issues found! (ran in 2.9s)` · `00:05 +96: All tests passed!` |
| T1 RED | `flutter test test/configuracion/slug_test.dart` | `Error: Method not found: 'generarSlug'` / `'slugEsValido'` · `00:00 +0 -1: Some tests failed.` |
| T1 GREEN | `flutter test test/configuracion/slug_test.dart` | `00:00 +21: All tests passed!` · `flutter analyze` → `No issues found!` |
| T2 RED | `flutter test test/configuracion/crear_restaurante_test.dart` | error de compilación (`RestauranteException`, `crearRestaurante`, `RestauranteFormDialog` inexistentes) · `00:00 +0 -1: Some tests failed.` |
| T2 (1er intento) | ídem | `00:01 +8 -1` — falla "un nombre sin letras ni dígitos deja el slug vacío y pide uno". **Se corrigió la implementación, no el test** (ver Desviación 1) |
| T2 GREEN | `flutter analyze && flutter test test/configuracion/crear_restaurante_test.dart` | `No issues found!` · `00:01 +9: All tests passed!` |
| T3 | `flutter test test/configuracion/restaurantes_test.dart` | `00:01 +9: All tests passed!` (3 previos + 6 nuevos) |
| T3 | `flutter test test/configuracion/ test/base_vacia_test.dart` | `00:01 +36: All tests passed!` |
| **Suite final panel** | `cd panel_admin && flutter test && flutter analyze` | `00:07 +132: All tests passed!` · `No issues found! (ran in 4.1s)` |
| **No regresión app_cliente** | `cd app_cliente && flutter analyze && flutter test` | `No issues found! (ran in 3.1s)` · `00:06 +96: All tests passed!` |
| **No regresión rules** | `cd scripts && npm run test:rules` | `tests 208 · suites 40 · pass 208 · fail 0` · `duration_ms 15030.8` · **exit 0** |
| No regresión índices | `cd scripts && npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` |
| Verificación del plan | `grep -rn "crearRestaurante" panel_admin/lib/features/configuracion/` | definido en `restaurantes_admin_provider.dart:72`, usado en `restaurante_form_dialog.dart:130` |

**Conteo: panel_admin 96 → 132 (+36).** slug 21, alta 9, tab +6. **Total apps 192 → 228.** Rules 208 (sin cambio: este plan no toca `firestore.rules`).

## Verificación por rotura deliberada (9 roturas, todas revertidas)

Un gate no está verificado hasta que se rompe lo que protege y la suite se pone en rojo **por los casos correctos** (patrón 11-04).

| # | Rotura aplicada | Resultado | Revertida |
|---|---|---|---|
| A | `slug.dart`: quitar el plegado de acentos | `+18 -3` — caen los casos de tildes/ñ, el de propiedad y el puente con el escáner | ✔ |
| B | `slug.dart`: `length <= 40` → `< 40` | `+20 -1` — cae SOLO "acepta exactamente 40 caracteres" (el borde permitido) | ✔ |
| C | `crearRestaurante`: quitar el check de existencia | `+7 -2` — caen "slug duplicado … NO pisa el doc existente" y el caso de UI del duplicado | ✔ |
| D | `crearRestaurante`: quitar `slugEsValido` | `+8 -1` — cae "slug inválido lanza … SIN tocar Firestore" | ✔ |
| E | diálogo: quitar `seleccionRestauranteProvider.set(slug)` | `+8 -1` — cae "tras el alta, la selección y ridActivo apuntan al restaurante nuevo" | ✔ |
| F | diálogo: quitar `!_saving` de `_puedeGuardar` | `+8 -1` — cae "guardar dos veces seguidas no crea dos documentos" | ✔ |
| G | tab: `if (!valor)` → `if (false)` (sin confirmación) | `+7 -2` — caen (g) y (h) | ✔ |
| H | tab: `if (!valor)` → `if (true)` (confirmar también al activar) | `+7 -2` — caen (b) y (i) | ✔ |
| I | tab: quitar la rama `isEmpty` | `+7 -2` — caen (d) y (e) | ✔ |

`git status` limpio tras cada rotura; el árbol final solo contiene los cambios commiteados.

## Files Created/Modified

**Creados**
- `panel_admin/lib/features/configuracion/slug.dart` — `generarSlug` + `slugEsValido`, sin dependencias externas. Cabecera que explica por qué es restricción dura, citando `app_cliente/lib/features/sesion_qr/scan_screen.dart:41`.
- `panel_admin/lib/features/configuracion/restaurante_form_dialog.dart` (280 líneas) — 5 campos, vista previa del identificador en vivo, desacople al editarlo a mano, Guardar deshabilitado, selección automática al cerrar.
- `panel_admin/test/configuracion/slug_test.dart` — 21 casos (incluye el grupo "puente con el escáner del cliente" y su control negativo).
- `panel_admin/test/configuracion/crear_restaurante_test.dart` — 9 casos (3 de unidad, 6 de widget).

**Modificados**
- `panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart` — `RestauranteException` + `crearRestaurante`; `restaurantesAdminProvider` y `toggleRestauranteActivo` INTACTOS.
- `panel_admin/lib/features/configuracion/configuracion_screen.dart` — `_RestaurantesTab`: cabecera con botón de alta, rama `isEmpty` guiada, confirmación de desactivación.
- `panel_admin/test/configuracion/restaurantes_test.dart` — 6 casos nuevos (d…i); los 3 previos intactos.
- `panel_admin/test/base_vacia_test.dart` — su `TODO(11-09)` queda resuelto para esta pantalla; aserción endurecida.

## Decisions Made

- **El CTA del estado vacío NO repite el texto del botón de cabecera.** "Crear el primer restaurante" vs "+ Nuevo restaurante": dos botones con el mismo texto habrían vuelto ambiguo cualquier `find.text` y el copy específico guía mejor a quien nunca ha usado el panel.
- **El aviso del identificador vacío se fuerza con `InputDecoration.errorText`.** Con `AutovalidateMode.onUserInteraction`, el validador de un campo que el usuario NUNCA toca no se dispara jamás — y ese es exactamente el caso del nombre que no produce slug. El formulario habría quedado mudo, con Guardar apagado y sin decir por qué.
- **`crearRestaurante` no usa transacción.** Entre el `get()` y el `set()` cabe una carrera teórica (dos super creando el mismo slug a la vez), pero las rules rechazan al segundo escritor por el mismo motivo que motiva el check: su `.set()` es un update no permitido. La carrera no corrompe datos, solo produce un error menos legible. Documentado en el código.
- **El invalidate de `restaurantesAdminProvider` se hace en los DOS sitios** (diálogo y pantalla). Redundante a propósito: la pantalla es la dueña de la lista y no debe depender de que el diálogo la refresque.
- **La confirmación reutiliza el `AlertDialog` de `mesa_form_dialog.dart:155-171`** tal cual (mismos botones, mismo rojo de Material). Cero rediseño, cero paleta nueva — decisión bloqueada del usuario respetada.

## Deviations from Plan

### Auto-corregidas

**1. [Regla 1 — Bug real, detectado por un test que falló] El aviso "escribe un identificador" no se mostraba nunca**
- **Found during:** Tarea 2, primera ejecución del GREEN (`+8 -1`).
- **Issue:** El `<behavior>` del plan exige que, con un nombre que no produce slug, "el formulario pide escribirlo manualmente". Con `AutovalidateMode.onUserInteraction` en el campo del identificador, el validador solo corre si el usuario interactúa con **ese** campo — y en ese escenario nunca lo hace: escribe el nombre y el slug queda vacío solo. El formulario se quedaba con Guardar apagado y sin explicación.
- **Fix:** Getter `_errorSlugForzado` inyectado en `InputDecoration.errorText`, que muestra el mensaje en cuanto hay nombre y el slug está vacío. **Se corrigió la implementación, no la aserción.**
- **Files modified:** `restaurante_form_dialog.dart`
- **Verification:** `00:01 +9: All tests passed!`
- **Committed in:** `72b9234`

**2. [Regla 3 — Bloqueante de test] El diálogo se pumpea vía `showDialog` sobre una ruta anfitriona**
- **Found during:** Tarea 2, diseño del test.
- **Issue:** El plan sugería `MaterialApp(home: Scaffold(body: RestauranteFormDialog()))`. Con el diálogo como ruta raíz, el `Navigator.pop()` del camino de éxito no tiene a dónde volver, y dos aserciones del `<behavior>` dependen de ese pop (el diálogo se cierra tras el alta; sigue abierto tras un duplicado).
- **Fix:** Helper `_abrirDialogo` que pumpea un `Scaffold` con un botón que hace `showDialog` — exactamente como lo abre la pantalla real.
- **Files modified:** `crear_restaurante_test.dart`
- **Committed in:** `66afa5b`

**3. [Regla 2 — Aserción que quedaba falsa] `base_vacia_test.dart` fuera de `files_modified`**
- **Found during:** Tarea 3.
- **Issue:** Ese archivo (de 11-02) afirmaba como "contrato ACTUAL" que el tab vacío no tiene ninguna llamada a la acción, con un `TODO(11-09)`. Este plan lo vuelve falso. Dejarlo habría dejado en el repo un comentario que miente sobre el estado del producto.
- **Fix:** Comentario actualizado y aserción **endurecida** (afirma ahora el titular del estado vacío y el CTA). No se borró ni se relajó nada.
- **Files modified:** `panel_admin/test/base_vacia_test.dart` (no estaba en `files_modified` del plan)
- **Committed in:** `f137263`

**4. [Cosmética] Etiqueta del CTA del estado vacío**
- El plan decía "CTA apuntando al botón de alta". Se usó un texto distinto del botón de cabecera ("Crear el primer restaurante") por la razón explicada en Decisions.

**Total deviations:** 4 (1 bug real de implementación, 1 ajuste de harness, 1 archivo extra por coherencia, 1 cosmética). Ninguna reduce alcance; ninguna aserción se relajó para poner algo en verde.

## Hallazgos sobre la calidad de los propios tests

- **"Guardar dos veces no crea dos documentos" habría pasado por construcción.** Aunque se quitara el guard de `_saving`, el segundo intento sería rechazado por el check de existencia y el doc-count seguiría siendo 1. La aserción que realmente prueba el guard es que `onPressed` del botón sea `null` mientras `_saving` — y es la que cae en la rotura F. Queda comentado dentro del test para quien lo lea después.
- **El control negativo del puente con el escáner es imprescindible.** Sin él, "todo slug generado pasa la regexp" podría estar verde porque la regexp acepta cualquier cosa. El caso que exige que el nombre CRUDO sea rechazado demuestra que la regexp discrimina y que el trabajo lo hace `generarSlug`.
- **Los dos sentidos de la confirmación se prueban por separado** (roturas G y H): sin el caso "activar NO pide confirmación", poner el diálogo en ambos sentidos habría pasado desapercibido.

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-05-01 (Tampering — slug) | Mitigado | `slugEsValido` bloquea la escritura (rotura D lo confirma) + el test que compone `GRI-MESA-{slug}-001` contra la regexp del escáner, con control negativo |
| T-11-05-02 (EoP — crear desde el panel) | Transferido, como preveía el plan | La autorización es `allow create: if isSuper()` (`firestore.rules:88`), cubierta por `scripts/test/rules/restaurantes.test.mjs` — **208/208 verde en este plan**. El gate de UI (tab solo para super) es UX |
| T-11-05-03 (Tampering — `.set()` sobre slug existente) | Mitigado | Check de existencia previo; el test afirma que el doc original conserva su `nombre` tras el intento fallido (rotura C lo confirma) |
| T-11-05-04 (DoS — desactivación accidental) | Mitigado | `AlertDialog` SOLO en el sentido destructivo, con "desaparece de la app de clientes" en el texto; cancelar no escribe nada (caso g) |
| T-11-05-06 (EoP — selección automática) | Aceptado, sin cambios | `seleccionRestauranteProvider` solo lo consume el super_admin; para el staff `ridActivo` viene de claims e ignora la selección (`restaurante_provider.dart:63-70`) |
| T-11-05-05 (Repudiation — alta sin rastro) | Aceptado | El doc lleva `createdAt` con `serverTimestamp`; auditoría por actor fuera del alcance de v1 |

## Qué está VERIFICADO y qué solo está AFIRMADO

**Verificado por ejecución:**
- La lógica de slug, incluido el borde de 40 y el plegado de acentos (21 casos + 2 roturas).
- El comportamiento de `crearRestaurante` contra `fake_cloud_firestore`: forma exacta del doc, rechazo sin escribir, duplicado sin pisar.
- El comportamiento del diálogo y del tab en el árbol de widgets real, incluida la selección resultante de `ridActivoProvider`.
- Que ninguno de los gates nuevos es decorativo (9 roturas deliberadas).

**NO verificado por esta suite — declarado explícitamente:**
- **La autorización.** `fake_cloud_firestore` **no tiene motor de rules** (decisión 11-04): en estos tests cualquiera podría escribir `restaurantes/x`. La única prueba de que solo el super crea restaurantes es `npm run test:rules` contra el emulador, que aquí solo se ejecuta como no-regresión — este plan no añadió casos de rules porque no cambió ni una regla.
- **El contrato con el escáner está probado contra una COPIA de la regexp.** El test declara la regexp de `scan_screen.dart:41` literalmente porque el panel no depende del paquete de la app cliente. Si alguien cambia la regexp allá, este test seguirá verde y quedará desalineado. Está anotado en la cabecera del archivo de test.
- **El comportamiento real de `FieldValue.serverTimestamp()`** y del `.set()` contra Firestore de producción: el fake resuelve el timestamp localmente.
- **El recorrido humano completo** (abrir el panel en un navegador, crear el restaurante, ver el topbar cambiar y crear una mesa) — corresponde al sellado del bloque 4 (11-16 / `docs/SMOKE-E2E.md`).

## Known Stubs

Ninguno introducido por este plan. El alta escribe todos los campos que el modelo `Restaurante` lee, y el estado vacío del tab ya no es un hueco.

Sigue pendiente **fuera de este plan**: la segunda mitad del bootstrap (alta de staff por Cloud Function callable, 11-07/11-08). Un restaurante creado aquí todavía no tiene usuarios propios: hasta que exista esa callable, el `admin_restaurante` inicial solo puede crearse con el Admin SDK.

## Threat Flags

Ninguna superficie de seguridad nueva fuera del `<threat_model>` del plan. La única escritura nueva desde el cliente es `restaurantes/{slug}`, que ya estaba contemplada y autorizada por `firestore.rules:88`. No se tocó `firestore.rules` ni `firestore.indexes.json` (`git diff` de ambos vacío en este plan).

## Issues Encountered

- Ninguno bloqueante.
- Los 4 archivos sin trackear del árbol (`documentos/google-services.json`, `documentos/sdk.png`, `run_app.bat`, `android/.../res/xml/`) son **previos a este plan** y ajenos a él: no se han tocado ni commiteado (misma nota que en 11-02).

## Next Phase Readiness

- **11-07 (alta de staff)** puede asumir que existe un restaurante creado desde el producto y que su `rid` es un slug válido: la callable recibirá un `rid` que ya pasó `slugEsValido`.
- **11-09 (estados vacíos / UI)** hereda un `TODO(11-09)` menos: el del tab Restaurantes queda resuelto. Sigue vivo el de la lista vacía de `app_cliente`.
- **11-16 (E2E desde cero)** ya tiene el primer paso del runbook cubierto por producto: "crear restaurante" deja de necesitar script o consola.
- **Aviso para quien toque el escáner:** cambiar `_codigoRegExp` en `app_cliente/lib/features/sesion_qr/scan_screen.dart:41` exige actualizar a mano `panel_admin/test/configuracion/slug_test.dart`, que lleva una copia literal de esa regexp.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `slug.dart`, `restaurante_form_dialog.dart`, `slug_test.dart`, `crear_restaurante_test.dart`.

Commits declarados — verificados en `git log`: `5d02e98`, `c2e62d2`, `66afa5b`, `72b9234`, `f137263`.

Gates de TDD presentes en el historial: `test(...)` antes de `feat(...)` en las Tareas 1 y 2.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
