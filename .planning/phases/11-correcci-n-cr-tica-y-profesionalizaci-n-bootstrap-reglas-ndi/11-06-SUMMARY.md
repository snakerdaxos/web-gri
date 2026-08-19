---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 06
subsystem: app_cliente + panel_admin — usabilidad y accesibilidad de los campos de contraseña
tags: [ux, accesibilidad, auth, formularios, widget-compartido, tdd, rotura-deliberada]

# Dependency graph
requires:
  - plan: 11-02
    provides: baseline de suites verdes en ambas apps (96 / 132) sobre la que no se puede regresar
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: login_screen/register_screen/perfil_screen del cliente y login_screen del panel, con Form + AutovalidateMode.onUserInteraction y las ValueKey de test
provides:
  - "PasswordField (app_cliente) — campo de contraseña con ver/ocultar, tooltip por estado y area tactil 48x48 garantizada por el propio widget"
  - "PasswordField (panel_admin) — copia deliberada con la MISMA API, con cabecera de sincronizacion cruzada"
  - "Confirmar contraseña en el registro del cliente, con aviso 'Las contraseñas no coinciden' y bloqueo del envio"
  - "autofillHints.password en el campo de registro (paridad con el login)"
affects: [11-07, 11-09, 11-10, 11-17]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extraer un campo repetido a widget compartido conservando su `ValueKey` en un parametro `fieldKey`, para no romper los tests que ya lo buscaban"
    - "Duplicacion deliberada entre apps con cabecera de SINCRONIZAR cruzada, en vez de un paquete `path:` compartido"
    - "El mensaje de un validador y la condicion que apaga el boton salen de la MISMA funcion, para que no puedan desincronizarse"
    - "Un assert de tamaño accesible solo tiene dientes si el test anula antes los defaults del framework que ya lo cumplian"

key-files:
  created:
    - app_cliente/lib/features/shared/password_field.dart
    - panel_admin/lib/features/shared/password_field.dart
  modified:
    - app_cliente/lib/features/auth/login_screen.dart
    - app_cliente/lib/features/auth/register_screen.dart
    - app_cliente/lib/features/perfil/perfil_screen.dart
    - app_cliente/test/auth/login_register_test.dart
    - app_cliente/test/perfil/perfil_edit_test.dart
    - panel_admin/lib/features/auth/login_screen.dart
    - panel_admin/test/auth/login_form_test.dart

key-decisions:
  - "La ValueKey va al TextFormField interno via `fieldKey`, no al PasswordField: asi `find.byKey` sigue apuntando al mismo widget que antes y los tests previos no cambian"
  - "La API minima del plan se amplia con `helperText` y `prefixIcon` porque el perfil los usaba: sin ellos la extraccion habria PERDIDO decoracion existente, y el plan exige extraer, no rediseñar"
  - "`fieldKey` es `Key?` y no `ValueKey?` como decia el plan: `ValueKey` sin argumento de tipo es `ValueKey<dynamic>` y estrecha sin ganar nada"
  - "El validador de la confirmacion y `_canSubmit` comparten `_errorConfirmacion`; asi el aviso y el boton no pueden contradecirse"
  - "auth_controller.dart NO se toco: la confirmacion es de UI y `RegisterController.submit` conserva sus 3 parametros (T-11-06-02)"

patterns-established:
  - "Todo campo de contraseña nuevo (11-07 alta de staff, 11-17 Google Sign-In) usa PasswordField; nunca `TextFormField(obscureText: true)`"
  - "Quien edite uno de los dos password_field.dart debe portar el cambio al otro: la cabecera de cada archivo lo dice y los dos tienen suite propia"

requirements-completed: [UX-01]

# Metrics
duration: ~40min
completed: 2026-08-19
---

# Phase 11 Plan 06: Ver la contraseña que se escribe Summary

**Los 5 campos de contraseña del sistema ya permiten revisar lo escrito con un botón etiquetado y alcanzable —la queja literal del usuario, cerrada— y el registro del cliente dejó de dejar equivocarse a ciegas: pide confirmación y avisa cuando no coinciden.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-19T17:05Z (aprox.)
- **Completed:** 2026-08-19T17:45Z (aprox.)
- **Tasks:** 2/2
- **Files created/modified:** 9

## Accomplishments

- **Cero toggles → cinco.** Antes de este plan no existía **ni un solo** botón de ver/ocultar en todo el repo (`grep -rn "obscureText"` daba 5 literales `true` y nada más). Ahora `grep -rn "obscureText" app_cliente/lib panel_admin/lib` devuelve exactamente **dos** líneas, ambas `obscureText: _obscure` dentro de los dos `password_field.dart`. No queda un solo campo ciego.
- **El registro ya no permite tipear mal la contraseña sin enterarse.** Campo "Confirmar contraseña", aviso `Las contraseñas no coinciden` y botón apagado hasta que coincidan. La confirmación **no viaja** a `RegisterController.submit` ni a Firestore (T-11-06-02), verificado con un doble del controller que registra lo que recibe.
- **La accesibilidad está verificada, no asumida.** El descubrimiento con más valor del plan: el assert de 48×48 **pasaba por construcción** — Flutter ya da 48×48 al sufijo por `InputDecoration.suffixIconConstraints`. Quitar el `constraints` explícito dejaba la suite entera en verde. Se añadió un caso que anula ese default del framework: sin `constraints` propias el botón cae a **24×24** y el test se pone rojo.
- **La extracción no perdió nada.** Se conservan controladores, validadores, prefijos, `helperText` y las cinco `ValueKey` que buscaban los tests previos. La identidad visual (decisión LOCKED) queda intacta: mismo `labelText`, mismo `OutlineInputBorder`, mismo candado; solo se añade el sufijo.
- **Sin regresiones:** app_cliente 96 → **112**, panel_admin 132 → **139**, `flutter analyze` **0 issues** en las dos apps, rules **208/208** y auditoría de índices **0 fallos** (ambos intactos: este plan no toca Firestore).

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | PasswordField de app_cliente + 4 campos + confirmar contraseña | RED | `958d59f` (test) |
| 1 | PasswordField de app_cliente + 4 campos + confirmar contraseña | GREEN | `3723572` (feat) |
| 2 | PasswordField del panel aplicado al login | RED | `fd5a3e7` (test) |
| 2 | PasswordField del panel aplicado al login | GREEN | `f3c2f99` (feat) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline app_cliente | `cd app_cliente && flutter analyze && flutter test` | `No issues found! (ran in 2.7s)` · `00:05 +96: All tests passed!` |
| Baseline panel_admin | `cd panel_admin && flutter analyze && flutter test` | `No issues found! (ran in 3.2s)` · `00:05 +132: All tests passed!` |
| T1 RED | `cd app_cliente && flutter test test/auth/ test/perfil/` | `00:01 +7 -4: Some tests failed.` — `login_register_test.dart` no compila (`password_field.dart` no existe) y 3 casos de perfil fallan por `Found 0 widgets with type "IconButton"` |
| T1 GREEN | `cd app_cliente && flutter analyze && flutter test test/auth/ test/perfil/` | `No issues found! (ran in 3.2s)` · `00:02 +32: All tests passed!` |
| T1 verify (plan) | `grep -rc "obscureText: true" lib/features/auth lib/features/perfil \| grep -v ':0$' ; test $? -eq 1` | sin salida · `exit del grep-v: 1` → **gate cumplido** |
| T1 suite | `cd app_cliente && flutter test` | `00:05 +111: All tests passed!` (antes del test extra de 48×48) |
| T2 RED | `cd panel_admin && flutter test test/auth/login_form_test.dart` | `Error when reading 'lib/features/shared/password_field.dart'` + `Method not found: 'PasswordField'` · `00:00 +0 -1: Some tests failed.` |
| T2 GREEN | `cd panel_admin && flutter analyze && flutter test test/auth/login_form_test.dart` | `No issues found! (ran in 3.0s)` · `00:01 +14: All tests passed!` |
| T2 verify (plan, literal) | `grep -rc "obscureText: true" lib/features/auth \| grep -q '^0$'` | `exit=1` — **el comando del plan está mal escrito**, ver Desviación 3 |
| T2 verify (equivalente) | `grep -rn "obscureText: true" lib/features/auth` | sin salida, `exit=1` → **0 coincidencias, propiedad cumplida** |
| **Verificación final del plan** | `grep -rn "obscureText" app_cliente/lib panel_admin/lib` | exactamente 2 líneas: `app_cliente/.../password_field.dart:65` y `panel_admin/.../password_field.dart:65`, ambas `obscureText: _obscure` |
| **Suite final app_cliente** | `cd app_cliente && flutter analyze && flutter test` | `No issues found! (ran in 4.3s)` · `00:06 +112: All tests passed!` |
| **Suite final panel_admin** | `cd panel_admin && flutter analyze && flutter test` | `No issues found! (ran in 4.4s)` · `00:05 +139: All tests passed!` |
| No regresión rules | `cd scripts && npm run test:rules` | `pass 208 · fail 0 · duration_ms 16995.2` · **exit 0** |
| No regresión índices | `cd scripts && npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` |

**Conteo: app_cliente 96 → 112 (+16), panel_admin 132 → 139 (+7). Total apps 228 → 251.** Rules 208 sin cambio (este plan no toca `firestore.rules`).

## Verificación por rotura deliberada (12 roturas, todas revertidas)

Un gate no está verificado hasta que se rompe lo que protege y la suite se pone en rojo **por los casos correctos** (patrón 11-04 / 11-05).

| # | Rotura aplicada | Resultado | Revertida |
|---|---|---|---|
| A | `password_field.dart` (cliente): `obscureText: _obscure` → `true` (el ojo cambia de icono pero no revela nada) | `+28 -4` — caen los 2 casos de alternancia, el de independencia del registro y el del perfil | ✔ |
| B | icono fijo `Icons.visibility` (no refleja el estado) | `+30 -2` — caen los 2 casos que leen el icono tras alternar | ✔ |
| C | tooltip fijo `'Mostrar contraseña'` | `+31 -1` — cae "el ojo está etiquetado y es alcanzable" | ✔ |
| D | `bool _obscure` → `static bool _obscure` (estado compartido entre instancias) | `+29 -3` — caen los 2 casos de independencia (registro y perfil) y el aislado | ✔ |
| E | quitar `constraints: BoxConstraints(minWidth:48,minHeight:48)` del `IconButton` | **1er intento: `+33 All tests passed`** → el assert pasaba por construcción. Tras añadir el caso que anula los defaults: `Expected: >= 48.0 / Actual: 24.0`, `+22 -1` | ✔ |
| F | `_canSubmit` ignora la confirmación | `+30 -3` — caen "distintas bloquean el envío", "cambiar la contraseña después de confirmarla" y el caso de habilitación pre-red | ✔ |
| G | el campo de confirmación sin `validator` (no pinta el aviso) | `+30 -3` — caen los 3 casos que buscan el texto `Las contraseñas no coinciden` | ✔ |
| H | quitar `autofillHints` del campo de registro (estado original) | `+32 -1` — cae "declara autofillHints.password (paridad con login)" | ✔ |
| I | `password_field.dart` (panel): `obscureText: _obscure` → `true` | `+13 -1` — cae la alternancia del login del panel | ✔ |
| J | `_obscure` `static` en el panel | **1er intento: `+14 All tests passed`** — el panel tiene UN solo campo, ningún test de pantalla podía detectarlo. Tras añadir "dos instancias NO comparten estado": `+14 -1` | ✔ |
| K | `login_screen.dart` del panel pierde `ValueKey('login-password')` | `+9 -5` — caen los 5 casos que localizan el campo por su key | ✔ |
| L | icono fijo en el panel | `+13 -1` — cae la alternancia | ✔ |

`flutter analyze` → `No issues found!` y suites verdes tras revertir cada rotura.

## Hallazgos sobre la calidad de los propios tests

Los dos hallazgos de este plan son del mismo tipo que el de 11-05: **una aserción que estaba verde por un motivo distinto del que decía comprobar.**

1. **El assert de 48×48 pasaba por construcción.** `InputDecoration` envuelve el `suffixIcon` en un `ConstrainedBox` cuyo default ya es `minWidth: 48, minHeight: 48`; el `constraints` del `IconButton` era redundante **en esa posición**. Con la rotura E la suite seguía en verde, es decir: el test no verificaba nuestro código sino un default del framework. Se añadió `PasswordField: los 48x48 los pone el widget, no el default del framework`, que pumpea el campo bajo un `ThemeData` con `suffixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0)` e `iconButtonTheme` encogido. Sin `constraints` propias el botón mide **24×24** y el test cae. Esto importa de verdad porque el bloque 3 de la fase (tokens de diseño y `inputDecorationTheme` centralizado) puede tocar exactamente ese default.
2. **La independencia de estado no estaba cubierta en el panel.** El panel tiene un único campo de contraseña, así que hacer `_obscure` `static` (rotura J) dejaba la suite entera verde. Como el widget está **duplicado**, heredar la cobertura de `app_cliente` habría sido una suposición, no una verificación. Se añadió un caso que pumpea dos `PasswordField` a la vez — y que además adelanta el escenario de 11-07, cuyo formulario de alta de staff sí tendrá dos campos.
3. **El caso "cambiar la contraseña DESPUÉS de confirmarla vuelve a avisar" no es decorativo.** Cubre la trampa exacta que 11-05 documentó: con `AutovalidateMode.onUserInteraction` un validador solo corre si el usuario tocó **ese** campo. Aquí sí se dispara (el `Form` revalida los campos ya interactuados cuando cambia cualquiera), pero sin el caso nadie lo sabría, y `_canSubmit` sería la única red.
4. **El caso "el email NO lleva ojo" lleva control positivo.** Sin la segunda aserción (`el campo de contraseña SÍ tiene uno`), un finder mal construido daría 0 coincidencias en ambos y el test estaría verde por incompetencia del finder.

## Files Created/Modified

**Creados**
- `app_cliente/lib/features/shared/password_field.dart` (86 líneas) — `StatefulWidget` con `_obscure = true` de partida, `suffixIcon: IconButton` con icono y tooltip dependientes del estado, `constraints` 48×48 y `fieldKey` para el `TextFormField` interno. Cabecera con el contrato y el aviso de SINCRONIZAR.
- `panel_admin/lib/features/shared/password_field.dart` (86 líneas) — idéntico salvo la ruta de la cabecera de sincronización (`diff` de los dos archivos: **una sola línea**).

**Modificados**
- `app_cliente/lib/features/auth/login_screen.dart` — el campo de contraseña pasa a `PasswordField`; `autofillHints`, validador, `onFieldSubmitted` y `ValueKey('login-password')` intactos.
- `app_cliente/lib/features/auth/register_screen.dart` — `PasswordField` + campo `register-password-2`, `_pass2Ctrl` (con su listener y su `dispose`), `_errorConfirmacion`, `_canSubmit` ampliado y `autofillHints.password` añadido. Doc comment actualizado explicando que la confirmación no sale de la UI.
- `app_cliente/lib/features/perfil/perfil_screen.dart` — los dos campos pasan a `PasswordField` conservando sus `helperText`.
- `panel_admin/lib/features/auth/login_screen.dart` — el único `obscureText` del panel pasa a `PasswordField`.
- `app_cliente/test/auth/login_register_test.dart` — +11 casos y helper `_rellenarRegistro` por KEY; el caso previo de habilitación se **endureció** (ver Desviación 1).
- `app_cliente/test/perfil/perfil_edit_test.dart` — +4 casos.
- `panel_admin/test/auth/login_form_test.dart` — +7 casos; los 8 previos intactos.

## Decisions Made

- **La `ValueKey` viaja al `TextFormField` interno (`fieldKey`), no al `PasswordField`.** Así `find.byKey(ValueKey('login-password'))` sigue devolviendo el mismo tipo de widget que antes de la extracción y ningún test previo cambia. Ponerla en el widget externo habría funcionado para `enterText` pero habría alterado silenciosamente lo que devuelve `tester.widget<...>` a quien lo use más adelante.
- **La API se amplía con `helperText` y `prefixIcon`.** El plan pedía una API mínima sin ellos, pero el perfil usa `helperText` en sus dos campos y las cuatro pantallas usan el candado. Sin esos parámetros, "extraer lo existente" habría significado **borrar** decoración que ya estaba. `prefixIcon` tiene default `Icon(Icons.lock_outline)` para que el caso común no lo repita.
- **`fieldKey` es `Key?`.** El plan escribía `ValueKey? fieldKey`; un `ValueKey` sin argumento de tipo es `ValueKey<dynamic>` y no aporta nada frente a `Key?`, que además deja la puerta abierta a `GlobalKey` en 11-07/11-17.
- **El validador de la confirmación y `_canSubmit` comparten `_errorConfirmacion`.** Un solo sitio decide si coinciden: es imposible que el aviso diga una cosa y el botón otra.
- **`auth_controller.dart` no se tocó.** El plan lo listaba en `files_modified` "por si hacía falta"; no hizo falta. `RegisterController.submit(nombre, email, password)` conserva su contrato de 3 parámetros, que es precisamente la garantía estructural de T-11-06-02.
- **La duplicación del widget se ejecuta tal como la decidió el plan**, con la cabecera de SINCRONIZAR cruzada en ambos archivos y suite propia en cada app. El `diff` entre los dos archivos es de **una línea**, así que una divergencia futura será obvia.

## Deviations from Plan

### Auto-corregidas

**1. [Regla 2 — Aserción que quedaba falsa] El caso previo "requiere nombre + email válido + password ≥ 8 para habilitar" ya no era cierto**
- **Found during:** Tarea 1, diseño del RED.
- **Issue:** Ese test (de la Fase 10) afirmaba que nombre + email + password ≥ 8 **habilita** el botón. Al hacer obligatoria la confirmación, eso pasa a ser falso. Dejarlo habría puesto la suite en rojo por un motivo correcto.
- **Fix:** Se **endureció**, no se relajó: el mismo test conserva el paso "sin confirmar → sigue deshabilitado" y añade después "con confirmación coincidente → habilitado". Cubre un caso más que antes.
- **Files modified:** `app_cliente/test/auth/login_register_test.dart`
- **Verification:** cae con la rotura F (`+30 -3`).
- **Committed in:** `958d59f`

**2. [Regla 2 — Funcionalidad crítica ausente] La API mínima del plan perdía decoración existente**
- **Found during:** Tarea 1.
- **Issue:** La firma propuesta (`controller, labelText, validator, autofillHints, fieldKey, textInputAction, onFieldSubmitted`) no permitía expresar el `helperText` de los dos campos del perfil ni el `prefixIcon` de los cuatro. Aplicarla al pie de la letra habría **eliminado** ayuda visible al usuario, contradiciendo el propio mandato del plan ("REPLICAR la decoración que hoy usa cada pantalla").
- **Fix:** Dos parámetros más, `helperText` y `prefixIcon` (este último con default `Icon(Icons.lock_outline)`).
- **Files modified:** `app_cliente/lib/features/shared/password_field.dart`, `panel_admin/lib/features/shared/password_field.dart`
- **Verification:** caso `perfil: el ojo conserva el helperText y el prefijo del campo`.
- **Committed in:** `3723572` / `f3c2f99`

**3. [Reporte — comando del plan defectuoso] El gate de grep de la Tarea 2 no puede pasar tal como está escrito**
- **Found during:** Tarea 2, verificación.
- **Issue:** El plan pide `grep -rc "obscureText: true" lib/features/auth | grep -q '^0$'`. Con `-r` sobre un directorio, `grep -c` antepone el nombre de archivo (`lib/features/auth/login_screen.dart:0`), así que `^0$` **nunca** casa: el gate da `exit=1` incluso cuando la propiedad se cumple. No se ha "arreglado" reescribiéndolo a algo que pase; se ejecutó tal cual, se reporta su salida real, y se ejecutó además el equivalente semántico (`grep -rn "obscureText: true" lib/features/auth` → sin salida, `exit=1`, 0 coincidencias). El gate maestro del `<verification>` del plan (`grep -rn "obscureText" app_cliente/lib panel_admin/lib`) sí pasa y es más fuerte.
- **Files modified:** ninguno.

**4. [Regla 1 — Bug en mi propio harness de roturas] El script de rotura corrompió dos archivos al restaurar**
- **Found during:** Tarea 1, verificación por rotura.
- **Issue:** Las roturas E y G estaban definidas como **borrado** (sustituir una línea por cadena vacía). Al restaurar, `str.replace('', linea, 1)` inserta en la posición 0 y dejó la línea borrada en el **primer renglón** de `password_field.dart` y de `register_screen.dart`, con el consiguiente error de compilación que contaminó las roturas siguientes.
- **Fix:** Ambos archivos reparados (línea devuelta a su sitio, `flutter analyze` limpio y suite verde antes de continuar) y el harness reescrito: **todas** las roturas son ahora sustituciones por un marcador, nunca borrados, y cada operación lleva `assert` de que el ancla existe. Las roturas E–H se re-ejecutaron desde cero con el harness corregido.
- **Files modified:** solo el script de scratchpad; los archivos del repo quedaron idénticos a antes de la rotura.
- **Verification:** `flutter analyze` → `No issues found!` y `+112` / `+139` tras revertir.

**5. [Cosmética] `fieldKey` tipado como `Key?` en vez de `ValueKey?`** — ver Decisions.

**Total deviations:** 5 (1 test previo endurecido, 1 ampliación de API por pérdida de funcionalidad, 1 comando del plan defectuoso reportado sin maquillar, 1 bug de mi harness corregido, 1 cosmética). **Ninguna reduce alcance y ninguna aserción se relajó para poner algo en verde.**

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-06-01 (Information Disclosure — shoulder surfing) | **Aceptado, con las condiciones del plan verificadas** | El estado por defecto es oculto en los 5 campos (casos "arranca OCULTA" en cliente y panel, más el aislado); revelar exige una pulsación explícita; `_obscure` es estado de instancia, no persiste ni se comparte (roturas D y J lo confirman); el segundo toque vuelve a ocultar |
| T-11-06-02 (Tampering — la confirmación no debe alterar el payload) | **Mitigado** | `RegisterController.submit` conserva sus 3 parámetros (garantía estructural) y el caso `register: la confirmación NO viaja al controller` usa un doble que registra la invocación: `hasLength(1)` con `('Carlos Pérez','carlos@test.gri.dev','Demo!1234')`. El doc de Firestore sigue con exactamente 5 claves (caso previo de la Fase 10, intacto) |
| T-11-06-03 (Information Disclosure — `autofillHints` inconsistente) | **Mitigado** | Registro y login declaran ambos `AutofillHints.password` (no `newPassword`); el caso de paridad cae con la rotura H |

## Qué está VERIFICADO y qué solo está AFIRMADO

**Verificado por ejecución:**
- Que los 5 campos arrancan ocultos, alternan en ambos sentidos y cambian icono y tooltip con el estado.
- Que cada campo guarda su propio estado, en las dos apps (roturas D y J).
- Que el área táctil de 48×48 la impone **nuestro** widget y no un default del framework (rotura E con los defaults anulados: 24×24 sin `constraints`).
- Que el registro avisa y bloquea con contraseñas distintas, incluido el caso de editar la contraseña **después** de haberla confirmado.
- Que la confirmación no llega al controller (doble que registra la llamada).
- Que la extracción conservó `ValueKey`, controladores, validadores, prefijos y `helperText` (rotura K y el caso del perfil).
- Que ninguno de los 12 gates añadidos es decorativo.

**NO verificado por esta suite — declarado explícitamente:**
- **La accesibilidad real con un lector de pantalla.** El `tooltip` de Material se expone como etiqueta semántica, pero **no se ha ejecutado TalkBack ni VoiceOver**, ni se ha usado `SemanticsTester`. Lo verificado es que el tooltip existe y describe la acción correcta según el estado. La lectura efectiva del botón corresponde al sellado humano.
- **La apariencia.** Ningún test compara píxeles (no hay golden tests en el repo). Que la decoración se conserve está probado por la presencia de `labelText`, `helperText` y el icono de prefijo, no por una captura. **Que el ojo se vea bien en el layout real de las cuatro pantallas es un punto de verificación humana.**
- **El comportamiento del gestor de contraseñas del sistema.** `autofillHints` se afirma como declaración del widget; que Android/iOS/Chrome ofrezcan realmente autocompletar el par login/registro no es observable en `flutter test`.
- **El comportamiento en Flutter Web del panel.** La suite corre en el runner de test, no en un navegador; `flutter build web` no se ha ejecutado en este plan.
- **Que el usuario considere resuelta su queja.** Es el criterio que cierra UX-01 y solo lo cierra él, abriendo las pantallas.

## Known Stubs

Ninguno. Los dos `password_field.dart` están completamente cableados y consumidos por las 4 pantallas; no queda ningún `TODO` nuevo en el código de este plan.

## Threat Flags

Ninguna superficie de seguridad nueva fuera del `<threat_model>` del plan. No hay endpoints, rutas de auth, accesos a ficheros ni cambios de esquema: el trabajo es de presentación y validación local. `firestore.rules` y `firestore.indexes.json` no se tocaron (`git diff` de ambos vacío en este plan) y sus suites se reejecutaron como no-regresión (208/208, 0 fallos de índices).

## Issues Encountered

- **Ninguno bloqueante.** El único incidente fue el bug de mi propio harness de roturas (Desviación 4), detectado y reparado dentro de la misma tarea, con `flutter analyze` limpio y las dos suites verdes antes de seguir.
- Los archivos sin trackear del árbol (`documentos/google-services.json`, `documentos/sdk.png`, `run_app.bat`, `android/.../res/xml/`, `AndroidManifest.xml` modificado) son **previos a este plan** y ajenos a él: no se han tocado ni commiteado (misma nota que en 11-02 y 11-05).

## User Setup Required

Ninguno. No hay dependencias nuevas ni configuración que tocar.

## Next Phase Readiness

- **11-07 (bootstrap / alta de staff por Cloud Function):** el formulario nace ya con `PasswordField`. Uso: `PasswordField(fieldKey: const ValueKey('...'), controller: ctrl, labelText: '...', validator: ..., autofillHints: const [AutofillHints.newPassword])`. Si el formulario lleva contraseña y confirmación, copiar el patrón de `register_screen.dart`: una única función `_errorConfirmacion` compartida por el `validator` del segundo campo y por la condición que habilita el botón.
- **11-17 (Google Sign-In):** el login del cliente ya no tiene `TextFormField(obscureText:)` que reordenar; el botón de Google se añade debajo del formulario sin tocar el campo.
- **11-09 / bloque 3 (tokens y responsive):** **aviso concreto.** Si se centraliza un `inputDecorationTheme` con `suffixIconConstraints`, el área táctil del ojo depende de ello; el caso `PasswordField: los 48x48 los pone el widget, no el default del framework` está escrito precisamente para detectar esa regresión, y existe en las dos apps.
- **Quien edite un `password_field.dart` debe portar el cambio al otro.** Hoy el `diff` entre ambos es de una sola línea (la ruta de la cabecera de sincronización); mantenerlo así hace que cualquier divergencia salte a la vista.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `app_cliente/lib/features/shared/password_field.dart` (86 líneas, mínimo exigido 40), `panel_admin/lib/features/shared/password_field.dart` (86 líneas, mínimo exigido 40).

`key_links` del plan verificado: `grep -c "no coinciden" app_cliente/lib/features/auth/register_screen.dart` → `1`.

Commits declarados — verificados en `git log`: `958d59f`, `3723572`, `fd5a3e7`, `f3c2f99`.

Gates de TDD presentes en el historial: `test(...)` antes de `feat(...)` en las dos tareas.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
