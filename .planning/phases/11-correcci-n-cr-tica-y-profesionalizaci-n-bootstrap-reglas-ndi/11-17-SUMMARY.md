---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 17
subsystem: app_cliente — autenticación federada con Google + coherencia de configuración Firebase
tags: [auth, google-sign-in, oauth, firebase-config, tdd, rotura-deliberada, checkpoint-humano]

# Dependency graph
requires:
  - plan: 11-06
    provides: PasswordField y las ValueKey de los formularios de auth que este plan no debe romper
  - plan: 11-04
    provides: "contrato de usuarios/{uid} — create exige role == 'cliente' && restauranteId == null"
  - plan: 11-02
    provides: buildFakeFirestoreVacio() y el patrón de override de providers
provides:
  - "Ingreso y registro con Google en la app cliente, con rama Web operativa y rama Android completa"
  - "Espejo usuarios/{uid} para usuarios federados, idempotente y sin claims"
  - "Traducción de la colisión de cuentas email/contraseña vs Google"
  - "CORRECCIÓN: la app Android apuntaba al registro de Firebase equivocado desde la Fase 10"
  - "Gate que ata el applicationId de Gradle al appId de firebase_options"
affects: [11-15, 11-16, 11-19]

# Tech tracking
tech-stack:
  added:
    - "google_sign_in 7.2.0 (publisher verificado flutter.dev, pin exacto — T-11-17-SC)"
  patterns:
    - "Rama de plataforma explícita: Web usa signInWithPopup de firebase_auth; Android/iOS usa el plugin. Cada una con el mecanismo que NO arrastra dependencias de la otra"
    - "Costura inyectable (googleAuthAccionProvider) para probar la lógica post-handshake sin mockear el plugin — y declarar por escrito qué NO cubre"
    - "Gate de coherencia entre dos archivos de build (Gradle ↔ Dart) con dart:io puro: barato y caza una clase de deriva que ningún linter ve"
    - "Un mínimo táctil debe estar DECLARADO además de rendido: el rendido puede cumplirse por el padding y no detecta la regresión"

key-files:
  created:
    - app_cliente/lib/core/google_auth.dart
    - app_cliente/lib/core/google_auth.g.dart
    - app_cliente/lib/features/shared/google_boton.dart
    - app_cliente/test/auth/google_signin_test.dart
    - app_cliente/test/core/firebase_options_coherencia_test.dart
  modified:
    - app_cliente/pubspec.yaml
    - app_cliente/pubspec.lock
    - app_cliente/lib/features/auth/auth_controller.dart
    - app_cliente/lib/features/auth/auth_controller.g.dart
    - app_cliente/lib/features/auth/login_screen.dart
    - app_cliente/lib/features/auth/register_screen.dart
    - app_cliente/lib/firebase_options.dart
    - app_cliente/test/auth/login_register_test.dart
    - panel_admin/lib/firebase_options.dart
    - docs/FIREBASE_SETUP.md

key-decisions:
  - "El appId de Android se corrigió A MANO y NO con flutterfire configure: `firebase apps:sdkconfig` demostró que el apiKey es el MISMO en los dos registros, así que el diff de valores se reduce a una línea y regenerar habría reescrito el archivo entero sin necesidad"
  - "El appId VIEJO no se transcribe ni en un comentario: el gate prohíbe su presencia en el archivo, para que no pueda volver por un copiar-pegar"
  - "Las dos apps comparten UN solo registro web a propósito (verificado: el proyecto tiene una sola app web). El registro web no aporta aislamiento — la authz vive en claims + rules"
  - "El botón de Google NO usa el logo oficial de Google (asset de marca de terceros): icono neutro de Material, sin descargar nada al repo"
  - "AndroidManifest.xml NO se tocó: google_sign_in_android 7.x no exige ninguna entrada, y el archivo tiene cambios locales sin commitear ajenos a este plan"

patterns-established:
  - "Todo assert de tamaño táctil debe afirmar TAMBIÉN el valor declarado en el estilo, no solo el rendido"
  - "Antes de tocar firebase_options.dart, consultar `firebase apps:list --json` (packageName autoritativo) y NO `apps:sdkconfig`, que ignora el appId que se le pasa"

requirements-completed: [AUTH-G01]

# Metrics
duration: ~95min
completed: 2026-08-19
---

# Phase 11 Plan 17: Ingreso con Google en la app cliente Summary

**Un cliente ya puede entrar con su cuenta de Google —y en Flutter Web sin ningún trámite pendiente—, y por el camino se descubrió y corrigió que la app Android llevaba diez fases apuntando al registro de Firebase equivocado, con un gate que impide que la deriva vuelva a pasar inadvertida.**

## Performance

- **Duration:** ~95 min (con una interrupción por límite de sesión de la API, reanudada sin pérdida)
- **Tasks:** 3/4 autónomas completas — la 4 es el checkpoint humano, **PENDIENTE**
- **Files created/modified:** 15

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Adaptador, espejo de perfil y rama Web | RED | `fb74927` |
| 1 | Adaptador, espejo de perfil y rama Web | GREEN | `018c73c` |
| 2 | Botón de Google en login y registro + docs | RED | `41675a0` |
| 2 | Botón de Google en login y registro + docs | GREEN | `c2f4bdc` |
| 3 | Corrección del appId de Android + gate | RED | `a0495d0` |
| 3 | Corrección del appId de Android + gate | GREEN | `8183896` |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline app_cliente | `flutter analyze && flutter test` | `No issues found! (ran in 4.2s)` · `00:13 +112: All tests passed!` |
| Publisher del paquete | `curl -s .../google_sign_in/publisher` | `{"publisherId":"flutter.dev"}` · latest `7.2.0` (2025-09-17) |
| T1 RED | `flutter test test/auth/google_signin_test.dart` | `Undefined name 'googleSignInControllerProvider'` … · `00:00 +0 -1: Some tests failed.` |
| T1 GREEN | idem | `00:00 +13: All tests passed!` |
| T1 verify (plan) | `grep -c "google_sign_in: 7.2.0" pubspec.yaml` | `1` |
| T1 verify (plan) | `grep -q "703827387403-o05u1u7gffibbfqo4419ds3pjcul12g2..."` | `CLIENT_ID_OK` |
| T2 RED | `flutter test test/auth/google_signin_test.dart` | `Undefined name 'GoogleBoton'` · `00:00 +0 -1: Some tests failed.` |
| T2 GREEN | idem | `00:01 +27: All tests passed!` |
| T2 verify (plan) | `flutter analyze && flutter test test/auth/` | `No issues found!` · `00:04 +50: All tests passed!` |
| T3 RED | `flutter test test/core/firebase_options_coherencia_test.dart` | `+1 -3` — caen los 3 casos de la incoherencia, con el mensaje `INCOHERENCIA DE CONFIGURACIÓN / appId declarado: …b55b9ee… / appId que le toca: …1f0746d…` |
| T3 GREEN | idem | `00:00 +9: All tests passed!` |
| T3 verify (plan) | `grep -q "…1f0746d…" && test $(grep -c "b55b9ee…") -eq 0` | `APPID_ANDROID_OK` |
| T3 verify (plan) | `grep -n "android:" lib/firebase_options.dart` | 3 líneas, todas `…1f0746d200e4e12ce6d30e`; cero del viejo |
| **Suite final app_cliente** | `flutter analyze && flutter test` | `No issues found! (ran in 3.3s)` · `00:07 +158: All tests passed!` |
| **Suite final panel_admin** | `flutter analyze && flutter test` | `No issues found! (ran in 2.7s)` · `00:07 +163: All tests passed!` |
| Rules `usuarios` | `run_emulators.mjs --only firestore … node --test scripts/test/rules/usuarios.test.mjs` | `tests 22 · pass 22 · fail 0` · `duration_ms 2736.4` · **exit 0** |
| Integridad de rules | `git diff --name-only firestore.rules` | **vacío** — este plan no toca la capa de autorización |
| Compilación de la rama Web | `flutter build web --release` | `✓ Built build\web` (45.4s) — la rama Web y el plugin web compilan |
| Gradle intacto tras las roturas | `git status --short android/app/build.gradle.kts` | **vacío** |

**Conteo:** app_cliente **112 → 158**. De los +46, **36 son míos** (27 de `google_signin_test.dart` + 9 de `firebase_options_coherencia_test.dart`); los otros 10 son de los ejecutores concurrentes de 11-08/11-09, que trabajan en el mismo repo. panel_admin 157 → 163 (ninguno mío: solo toqué un comentario de su `firebase_options.dart`). Rules `usuarios` 22 sin cambio. **Ninguna suite bajó.**

## Verificación por rotura deliberada (17 roturas, todas revertidas)

| # | Rotura | Resultado | Revertida |
|---|---|---|---|
| A | espejo con `role: 'admin_restaurante'` | **1er intento: `+13 All tests passed`** — el harness rompió el controlador EQUIVOCADO (ver Hallazgo 1). Rehecha con ancla única (A2): `-2`, caen los 2 casos del espejo | ✔ |
| B | el espejo se sobrescribe siempre | `-1` — cae "el segundo ingreso NO pisa el nombre que el usuario editó" | ✔ |
| C | sin fallback a la parte local del correo | `-2` — caen los 2 casos de derivación del nombre | ✔ |
| D | sin traducción de la colisión de cuentas | `-1` — cae el caso de `account-exists-with-different-credential` | ✔ |
| E | la cancelación se lanza como error | `-1` — cae "GoogleIngresoCancelado NO es error" | ✔ |
| F | el cierre del popup no se trata como cancelación | `-1` — cae el caso de los 4 códigos de popup | ✔ |
| G | un carácter mal copiado en el client ID | `-1` — cae "es EXACTAMENTE el que entregó el usuario" | ✔ |
| H | espejo con `restauranteId` no nulo | **1er intento verde por el mismo bug del harness.** Rehecha (H2): `-2` | ✔ |
| J | se cuela una clave extra en el mapa del espejo | `-1` — cae la aserción sobre el conjunto de claves | ✔ |
| K | el botón sin `minimumSize` | **1er intento: `+27 All tests passed`** → el assert de 48 pasaba por construcción (ver Hallazgo 2). Tras endurecerlo: `-2` en las dos pantallas | ✔ |
| L | el botón no se deshabilita en vuelo | `-2` — caen los 2 casos de doble toque | ✔ |
| M | cambia la etiqueta del botón | `-4` — caen render y semántica en las dos pantallas | ✔ |
| N | el login pierde el separador "o" | `-1` | ✔ |
| P | el registro ignora el estado en vuelo | `-1` | ✔ |
| Q | el botón nunca muestra el indicador | `-2` | ✔ |
| R | vuelve el appId del registro viejo | `-2` — caen "CORRESPONDE al applicationId" y "el registro viejo NO aparece" | ✔ |
| S | `applicationId` cambia a un paquete no declarado | `-2` — caen la tabla y la correspondencia | ✔ |
| T | la regeneración altera el `projectId` | `-1` | ✔ |
| U | la regeneración altera el bloque web | `-1` — cae "el bloque web queda intacto (lo comparte el panel admin)" | ✔ |
| V | el comentario vuelve a etiquetar el bloque como el registro viejo | `-1` | ✔ |
| W | el panel deja de declarar el mismo registro web | `-1` | ✔ |
| — | **Controles negativos** (cambio cosmético en el controlador, y otro en `firebase_options.dart`) | `+13` y `+9`, **verdes** — las roturas discriminan | ✔ |

`flutter analyze` → `No issues found!` y suites verdes tras revertir todas.

## Hallazgos

### 1. Mi propio harness rompió el controlador equivocado (roturas A y H verdes)

`'role': 'cliente',` aparece **dos veces** en `auth_controller.dart`: primero en `RegisterController.submit` (Fase 10) y después en el espejo de Google. `String.replace(from, to)` sustituye solo la **primera** ocurrencia, así que las roturas A y H estaban modificando el registro con email/contraseña —cuyos tests viven en otro archivo que yo no estaba ejecutando— y por eso salían verdes.

No es un fallo del test: rehechas con un ancla única de 4 líneas (A2/H2), **caen los 2 casos del espejo cada una**. Pero el modo de fallo es instructivo: *una rotura que no rompe lo que crees produce exactamente la misma señal que un test sin dientes*. Por eso toda rotura de este plan lleva ahora `assert` de que el ancla aparece **exactamente una vez** (`n !== 1` → rotura omitida y avisada), y no solo de que aparece.

### 2. El assert de 48 de alto pasaba por construcción — otra vez

Es el mismo hallazgo que la rotura E de 11-06, en otro widget. Quitar `minimumSize: Size.fromHeight(48)` del `GoogleBoton` dejaba la suite **entera en verde**: el `padding` vertical (12+12) más el contenido ya suman 48 por casualidad. El test medía el padding, no la garantía.

Importa de verdad porque **el plan 11-19 va a tocar precisamente ese padding** al migrar los literales a tokens: el día que lo reduzca, el mínimo táctil se cae y nada avisa. El caso ahora afirma **también el `minimumSize` declarado** en el `ButtonStyle` resuelto. Con esa aserción, la rotura K produce `-2`.

### 3. El registro viejo `gri.app` es real, pero `firebase apps:sdkconfig` miente sobre él

`apps:sdkconfig ANDROID <appId>` devuelve `package_name: com.gri.gri_cliente` **para los dos appId**, incluido el viejo: ignora el appId que se le pasa. La fuente autoritativa es `apps:list ANDROID --json`, que sí distingue:

```
{"appId":"1:...:android:1f0746d200e4e12ce6d30e","displayName":"gri_cliente (android)","packageName":"com.gri.gri_cliente"}
{"appId":"1:...:android:b55b9ee758dc5108e6d30e","packageName":"gri.app"}
```

El plan tenía razón en el diagnóstico. Pero quien repita la comprobación con `sdkconfig` concluirá que no hay problema.

### 4. El `apiKey` NO estaba atado al registro (el plan asumía que sí)

El plan preveía que corregir solo el `appId` dejaría el `apiKey` incoherente, y por eso prefería regenerar con `flutterfire configure`. Comprobado contra el proyecto real: el `current_key` del registro correcto es `AIzaSyBZe8QtDCsv3RTZc9ykoQ9wBJskboyOzwk` — **el mismo** que ya estaba (ambos registros usan la clave Android del proyecto). Por eso se corrigió a mano y **el diff de valores es exactamente una línea**, revisado campo por campo como pedía el plan.

### 5. La SHA-1 sigue sin registrar, y ahora hay una comprobación precisa

El 11-CONTEXT decía "la ausencia de `oauth_client` confirma que la SHA-1 no está registrada". Matiz: el registro **correcto** SÍ tiene un `oauth_client`, pero de `client_type: 3` (web). El que exige la huella es el de `client_type: 1` (Android), y hay **0**:

```
1:...:1f0746d200e4e12ce6d30e → oauth_client total: 1 · client_type 1: 0 · client_type 3: 1
```

Comprobación reutilizable tras el checkpoint: si aparece un `client_type: 1`, la huella quedó registrada.

## Frontera honesta de la cobertura

Lo declara la cabecera de `google_signin_test.dart` y se respeta al pie de la letra:

- **`firebase_auth_mocks` no modela** `signInWithCredential` con credencial de Google ni `signInWithPopup` real; el plugin `google_sign_in` necesita canales de plataforma inexistentes en `flutter test`. **No se mockeó el plugin** para fabricar cobertura del handshake.
- **Lo cubierto:** todo lo posterior al handshake (espejo, idempotencia, nombre, traducción de errores, cancelación) y todo el comportamiento del botón, a través de `googleAuthAccionProvider`.
- **Lo NO cubierto por tests:** el handshake real con Google, en cualquiera de las dos plataformas.

## Estado real de cada rama

| Rama | Implementada | Compila | Handshake real verificado |
|---|---|---|---|
| **Web** | ✅ | ✅ `flutter build web --release` OK | ❌ **NO** — ver más abajo |
| **Android** | ✅ | — | ❌ bloqueada por la SHA-1 (checkpoint) |

**El plan asumía que la verificación manual de la rama Web la podía hacer yo en la Tarea 1. No es cierto y no la voy a dar por hecha:** completar el popup de Google exige iniciar sesión con una cuenta de Google real, es decir, las credenciales personales del usuario. No las tengo ni debo tenerlas. Lo que sí queda verificado de la rama Web es que **compila para el target web con el plugin incluido** y que toda la lógica posterior al handshake está probada. **El popup en sí es verificación humana**, igual que la de Android — con la diferencia importante de que la de Web **no depende de ningún trámite en la consola** y se puede hacer ya mismo.

## Deviations from Plan

### 1. [Regla 1 — Regresión causada por mi cambio] 7 tests de `login_register_test.dart` se pusieron en rojo

- **Found during:** Tarea 2, gate `flutter test test/auth/`.
- **Issue:** El bloque de Google alarga la card del login ~100px. En el viewport de 800×600 del test, el enlace `¿No tienes cuenta? Regístrate` queda en `Offset(400.0, 602.0)`, fuera del árbol de render, y los 7 taps que lo usan para navegar a `/register` fallan con *"would not hit test on the specified widget"*.
- **Análisis:** **no es un bug de producto** — el contenido está dentro de un `SingleChildScrollView` y un usuario real se desplaza. Lo que falla es una suposición posicional de los tests.
- **Fix:** `await tester.ensureVisible(...)` antes de cada uno de los 7 taps, con el comentario que explica por qué.
- **⚠️ `app_cliente/test/auth/login_register_test.dart` NO está en `files_modified`.** Lo edité igualmente porque el `<behavior>` de la Tarea 2 exige explícitamente "ninguna regresión en `login_register_test.dart`", y dejar en rojo una suite que yo rompí bloquea a los demás ejecutores. **Queda reportado como desviación de alcance.** Se commiteó solo ese archivo, nunca `git add -A`.
- **Committed in:** `c2f4bdc`

### 2. [Regla 3 — Comando del plan defectuoso] El gate de rules no puede pasar tal como está escrito

- **Issue:** El plan pide `cd scripts && node run_emulators.mjs … -- node --test test/rules/usuarios.test.mjs`. El wrapper ejecuta el comando **desde la raíz del repo** (decisión 11-01, ya registrada en STATE.md), así que la ruta relativa a `scripts/` no existe. Salida real: `Could not find 'test/rules/usuarios.test.mjs'` · `Script exited unsuccessfully (code 1)`.
- **No se maquilló:** se ejecutó tal cual, se reporta su salida, y se ejecutó además el equivalente correcto (`scripts/test/rules/usuarios.test.mjs`), que da `pass 22 · fail 0 · exit 0`.
- **Files modified:** ninguno.

### 3. [Desviación de método, mejor que lo planeado] El appId se corrigió a mano y no con `flutterfire configure`

- **Motivo:** ver Hallazgo 4 — el `apiKey` resultó ser el mismo en ambos registros, así que la premisa que justificaba regenerar no se sostiene. Regenerar habría reescrito el archivo entero (y sus comentarios, que documentan decisiones de la Fase 10) para cambiar una línea.
- **Verificación:** el diff de valores es literalmente `- appId: …b55b9ee…` / `+ appId: …1f0746d…`, revisado campo por campo, más 4 casos de test que afirman que `projectId`, `messagingSenderId`, `storageBucket` y el bloque `web` no se movieron.
- **Committed in:** `8183896`

### 4. [Regla 2 — Ficheros generados no listados] `*.g.dart` versionados

- `app_cliente/lib/core/google_auth.g.dart` (nuevo) y `app_cliente/lib/features/auth/auth_controller.g.dart` (regenerado) son consecuencia obligada de `@riverpod` y están versionados en este repo, pero no aparecían en `files_modified`. Commiteados con su fuente.
- ⚠️ `dart run build_runner build` también regeneró `restaurantes_provider.g.dart`, que pertenece a un ejecutor concurrente: **NO se stageó**.

### 5. [Aserción propia que me cazó a mí] El appId viejo no puede ni mencionarse en un comentario

Mi primer comentario explicativo del bloque `android` citaba el appId viejo literalmente. Tanto mi propio test como el grep del `<verify>` del plan prohíben esa cadena **en cualquier posición** del archivo. **No relajé la aserción**: quité el literal del comentario y remití a `docs/FIREBASE_SETUP.md §9.5`. El tripwire vale más que la comodidad de tenerlo a mano — y de hecho impide que vuelva por un copiar-pegar desde el propio comentario. Lo mismo con `gri.app`, que se nombra en la doc y no en el código.

### 6. [Alcance no tocado] `AndroidManifest.xml` NO se modificó

`google_sign_in_android` 7.x no exige ninguna entrada de manifiesto (el plugin declara lo suyo y Gradle lo fusiona). El plan ya lo condicionaba a "solo si el plugin lo exige". Además el archivo tiene cambios locales sin commitear ajenos a este plan (`networkSecurityConfig`, BOM), que quedan intactos.

**Total: 6 desviaciones.** Ninguna reduce alcance. **Ninguna aserción se relajó para poner algo en verde** — al contrario, dos se endurecieron (el mínimo táctil y el harness de roturas).

## Threat Flags

Ninguna superficie nueva fuera del `<threat_model>` del plan. Estado de las mitigaciones:

| Threat ID | Estado |
|---|---|
| T-11-17-01 (escalada vía espejo) | **mitigado y verificado** — roturas A2/H2/J + rules `usuarios` 22/22 |
| T-11-17-02 (idToken de otra app) | **mitigado, parcialmente afirmado** — el test del client ID exacto y el error explícito por idToken nulo están; el canje real no es observable en `flutter test` |
| T-11-17-03 (toma de cuenta existente) | **mitigado y verificado** — rotura D |
| T-11-17-04 / T-11-17-07 (config equivocada) | **mitigado y verificado** — corregido + 6 roturas del gate |
| T-11-17-SC (cadena de suministro) | **mitigado** — publisher `flutter.dev` comprobado contra la API de pub.dev, pin exacto |
| T-11-17-05 / 06 | **accept**, como decidió el plan |

## Pendiente de verificación humana

1. **La SHA-1 de Android — checkpoint BLOQUEANTE de este plan** (detalle abajo).
2. **El popup de Google en Flutter Web** — no depende de ningún trámite; solo de que una persona con cuenta de Google lo pulse.
3. **El aspecto real del botón** en las dos pantallas no es observable en `flutter test`.

## Self-Check: PASSED

Todos los archivos declarados existen en disco y los 6 commits existen en `git log`.
