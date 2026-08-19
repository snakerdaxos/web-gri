---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 07
subsystem: cloud-functions + panel (bootstrap del primer super_admin)
tags: [cloud-functions, escalada-de-privilegios, guarda-atomica, timing-safe, go-router, riverpod, firestore-rules, e2e-emuladores]

# Dependency graph
requires:
  - plan: 11-01
    provides: scripts/run_emulators.mjs (--set-env), codebase functions/, functions/.env.demo-gri, npm run test:functions
  - plan: 11-02
    provides: firebaseFunctionsProvider (region us-central1), useFunctionsEmulator 5001, buildFakeFirestoreVacio()
  - plan: 11-04
    provides: bloque de default-deny sobre plataforma/bootstrap en restaurantes.test.mjs (contrato a respetar)
  - plan: 11-06
    provides: PasswordField del panel
provides:
  - "functions/src/bootstrap-plataforma.js — callable de un solo uso con guarda atomica, doble factor y auditoria"
  - "firestore.rules: match /plataforma/{doc} { allow read, write: if false; }"
  - "scripts/test/functions/_emu.mjs — montaje e2e compartido (lo reutiliza 11-08)"
  - "scripts/test/functions/bootstrap.e2e.mjs — 11 casos contra emuladores reales, incluida carrera real de 5 llamadas"
  - "panel_admin /bootstrap: pantalla, controlador con dos costuras y ruta exenta del guard"
  - "npm run test:functions operativo (era una suite vacia)"
affects: [11-08, 11-09, 11-10, 11-15, 11-16, 11-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guarda de unicidad con DocumentReference.create() colocada ANTES de cualquier consulta, para que la rama ALREADY_EXISTS sea alcanzable por los tests"
    - "Controles de autorizacion evaluados sin cortocircuito, con mensaje y codigo identicos en todos los motivos de denegacion"
    - "Comparacion de secretos en tiempo constante con trabajo de relleno tambien en el camino de longitud distinta"
    - "Segunda costura inyectable (bootstrapCallableProvider) cuando el SDK real no es instanciable en flutter test: convierte una afirmacion en una verificacion"
    - "Tests e2e que exigen su configuracion por --set-env y fallan ruidosamente si no llega (sin falsos verdes por configuracion ausente)"

key-files:
  created:
    - functions/src/bootstrap-plataforma.js
    - scripts/test/functions/_emu.mjs
    - scripts/test/functions/bootstrap.e2e.mjs
    - panel_admin/lib/features/bootstrap/bootstrap_controller.dart
    - panel_admin/lib/features/bootstrap/bootstrap_controller.g.dart
    - panel_admin/lib/features/bootstrap/bootstrap_screen.dart
    - panel_admin/test/bootstrap/bootstrap_router_test.dart
    - panel_admin/test/bootstrap/bootstrap_screen_test.dart
  modified:
    - functions/index.js
    - firestore.rules
    - docs/FIREBASE_SETUP.md
    - scripts/package.json
    - panel_admin/lib/app.dart
    - panel_admin/lib/features/auth/login_screen.dart
    - .planning/phases/11-*/deferred-items.md

key-decisions:
  - "La comprobacion secundaria (query de super_admin) se ejecuta SOLO cuando el centinela se creo en esta invocacion. Sin esa condicion, el camino de reparacion y la carrera se rompen: el super_admin que encontraria la consulta seria el propio llamador. Verificado con la rotura E"
  - "Se anade una SEGUNDA costura, bootstrapCallableProvider, sobre la unica que pedia el plan. FirebaseFunctions no se puede instanciar en flutter test, asi que sin ella el bootstrapAccionProvider REAL seria inejecutable y tanto el invalidate de claims como la reversion de cuenta quedarian afirmados en vez de verificados"
  - "El test del router filtra EXCLUSIVAMENTE las excepciones `A RenderFlex overflowed`: el sidebar del AppShell desborda 85px a cualquier ancho y es deuda preexistente del bloque 3, no de este plan"
  - "La carrera se prueba con N llamadas del MISMO usuario autorizado: Firebase Auth normaliza el correo (cinco cuentas con el mismo correo es inejecutable) y con el filtro por BOOTSTRAP_EMAIL cinco correos distintos moririan antes de llegar a la guarda"

patterns-established:
  - "Cualquier control de seguridad nuevo se verifica ROMPIENDOLO y comprobando que caen los casos correctos; en este plan, 13 roturas deliberadas"
  - "11-08 (crearUsuarioStaff) reutiliza scripts/test/functions/_emu.mjs tal cual"

requirements-completed: [BOOT-01]

# Metrics
duration: ~65min
completed: 2026-08-19
---

# Phase 11 Plan 07: Bootstrap del primer super_admin Summary

**GRI ya se arranca desde una pantalla: `/bootstrap` crea el primer `super_admin` con una callable de un solo uso protegida por correo verificado + secreto de despliegue, con guarda atomica real (probada rompiendola) y el centinela blindado en las rules — se acabo el `serviceAccountKey.json` en manos de nadie.**

## Performance

- **Duration:** ~65 min
- **Tasks:** 3/3
- **Files created:** 8 · **modified:** 7

## Accomplishments

- **La mitad que faltaba del bootstrap.** 11-05 dejo al panel capaz de crear restaurantes, pero solo un `super_admin` puede hacerlo y ese `super_admin` solo nacia de `scripts/seed_firebase.mjs` con una clave de servicio. Ahora nace de una pantalla.
- **Dos factores de verdad, no uno.** El correo del fundador **no es un secreto** (el registro email/contrasena esta abierto: lo usa la app cliente). Por eso la funcion exige ademas `email_verified === true` y `BOOTSTRAP_SECRET`. Los dos tienen caso negativo dedicado en el e2e y los dos se verificaron rompiendolos.
- **La guarda atomica esta REALMENTE ejercitada.** Es el punto que mas facil habria sido fingir. Se comprobo sustituyendo `create()` por `set()`: caen 3 casos (carrera, segunda llamada y centinela ajeno). Con `set()`, la carrera devuelve 5 `creado: true` **y el centinela de otra persona se sobrescribe** — es decir, la guarda no es decorativa, es lo que impide una escalada de privilegios.
- **El guard del router ya no expulsa a mitad de operacion.** `createUserWithEmailAndPassword` emite un evento de `authStateChanges` que re-evalua el `redirect`; sin la exencion, el usuario salia de `/bootstrap` con la callable en vuelo y la reversion de la cuenta se quedaba sin pantalla. Probado sobre el **GoRouter real**, emitiendo ese evento exacto.
- **Los claims llegan frescos.** `ref.invalidate(claimsProvider)` tras la callable, con un test que cuenta reconstrucciones del provider y que se pone en rojo si se quita.
- **Sin regresiones.** rules 208 → 208, functions 0 → 11, app_cliente 112, panel_admin 139 → **157**. `flutter analyze` 0 issues en las dos apps. `audit:indexes` sin fallos.

## Task Commits

| # | Tarea | Commit |
|---|---|---|
| 1 | Callable `bootstrapPlataforma` + rule del centinela + docs | `06ba232` (feat) |
| 2 | e2e contra emuladores reales (`_emu.mjs` + `bootstrap.e2e.mjs`) | `8dc3e35` (test) |
| 3 | Pantalla `/bootstrap`, controlador, ruta exenta y 18 tests | `28c1714` (feat) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline previo panel | `flutter analyze && flutter test` | `No issues found!` · `+139: All tests passed!` |
| Baseline previo cliente | `flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Baseline previo rules | `npm run test:rules` | `tests 208 · pass 208 · fail 0` |
| T1 sintaxis | `node --check src/bootstrap-plataforma.js && node --check index.js` | `CHECK_OK` |
| T1 doble factor | `grep timingSafeEqual && grep email_verified` | `DOBLE_FACTOR_OK` |
| T1 default-deny (contrato 11-04) | `run_emulators --only firestore -- node --test scripts/test/rules/restaurantes.test.mjs` | `tests 29 · pass 29 · fail 0` |
| T1 rules completas | `npm run test:rules` | `tests 208 · pass 208 · fail 0` |
| T2 e2e | `npm run test:functions` | `tests 11 · pass 11 · fail 0` · `Script exited successfully (code 0)` |
| T2 anti-falso-verde | mismo comando **sin** `--set-env` | `Error: Faltan BOOTSTRAP_EMAIL / BOOTSTRAP_SECRET...` · `pass 0` · `Script exited unsuccessfully (code 1)` |
| T3 RED | `flutter test test/bootstrap/` | `Error: 'BootstrapException' isn't a type` etc. · `+0 -2: Some tests failed` |
| T3 GREEN | `flutter test test/bootstrap/` | `+18: All tests passed!` |
| T3 invalidate | `grep -q "invalidate(claimsProvider)"` | `INVALIDATE_OK` |
| Suite panel final | `flutter analyze && flutter test` | `No issues found!` · `+157: All tests passed!` |
| Suite cliente final | `flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Rules final | `npm run test:rules` | `tests 208 · pass 208 · fail 0` |
| Functions final | `npm run test:functions` | `tests 11 · pass 11 · fail 0` |
| Indices | `npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` |
| Verificacion del plan | `grep -n plataforma firestore.rules` | `match /plataforma/{doc} { allow read, write: if false; }` (linea 300) |

**Conteo de pruebas: 251 → 269 en las apps** (app_cliente 112 sin cambio, panel_admin 139 → 157) **+ 11 e2e de functions nuevas** (la suite `test:functions` existia vacia desde 11-01). Rules estables en 208.

## Verificacion por ROTURA DELIBERADA (13 roturas, todas revertidas)

Un `assertFails` en verde no prueba nada por si mismo. Cada control se rompio a proposito y se comprobo que caen **los casos correctos**.

### Rules

| # | Rotura | Resultado | Revertida |
|---|---|---|---|
| R | `match /plataforma` a `if true` | `restaurantes.test.mjs`: `pass 22 · fail 7` (los 7 casos de lectura/escritura del centinela desde anon, cliente, admin y super) | Si · `29/29` de nuevo |

### Cloud Function (`npm run test:functions`, 11 casos)

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| A | `centinela.create()` → `centinela.set()` (guarda atomica eliminada) | **3**: CARRERA REAL, SEGUNDA LLAMADA, **CENTINELA AJENO** | Si |
| B | `email_verified === true` → `true` | 1: FACTOR EMAIL_VERIFIED | Si |
| C | secreto siempre aceptado | 2: los dos FACTOR SECRETO | Si |
| D | no borrar el centinela huerfano en la comprobacion secundaria | 1: PROYECTO SEMBRADO | Si |
| E | quitar la condicion `if (creado)` de la comprobacion secundaria | 2: SEGUNDA LLAMADA, CARRERA REAL | Si |
| F | mensaje distinto en la denegacion por centinela ajeno | 1: CENTINELA AJENO (asercion de identidad del mensaje) | Si |

Tras revertir: `git diff functions/src/bootstrap-plataforma.js` vacio y `tests 11 · pass 11 · fail 0`.

### Panel

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| 1 | guard ORIGINAL, sin ninguna exencion de `/bootstrap` | **3**: `SIN sesion...`, `EL CASO QUE ROMPE EL FLUJO`, `enlace de primera vez` | Si |
| 1b | quitar SOLO el `return null` incondicional (dejando `rutasPublicas`) | **0 — ver "verde por el motivo equivocado" abajo** | Si |
| 2 | quitar `ref.invalidate(claimsProvider)` | 1: `tras la callable INVALIDA claimsProvider` | Si |
| 3 | reversion sin `currentUser.delete()` (solo `signOut`) | 1: `si la callable falla y la cuenta se creo aqui` | Si |
| 4 | revertir SIEMPRE (ignorar `cuentaCreadaAqui`) | 1: `si el correo YA existia... NO se elimina` | Si |
| 5 | `_canSubmit` ignora la confirmacion | 1: `contrasenas distintas` | Si |
| 6 | quitar el bloqueo de doble envio (boton + cerrojo) | 1: `doble envio imposible` | Si |

## Caza de verdes por el motivo equivocado

**Encontrados dos.** Se reportan sin maquillar, como exige el estandar de 11-05 y 11-06.

**1. El `return null` incondicional para `/bootstrap` en `app.dart` es HOY REDUNDANTE.**
La rotura 1b lo elimino dejando solo el conjunto `rutasPublicas` y la suite del router siguio en **`+5: All tests passed!`**. El motivo: el guard resultante solo redirige fuera de `/login` cuando hay sesion (`if (state.matchedLocation == '/login') return '/'`), asi que `/bootstrap` con sesion ya devolvia `null` por el camino normal. Ningun test puede distinguir las dos versiones.
Se **conserva** porque el plan lo exige explicitamente y porque es defensa en profundidad frente a un futuro `if (loggedIn && !esPublica)`, con el comentario que explica el motivo. Pero queda dicho: **esa linea concreta esta AFIRMADA, no verificada.** Lo que si esta verificado (rotura 1) es que sin NINGUNA exencion el flujo se rompe en 3 casos.

**2. El caso `CON sesion, /bootstrap no redirige a /` pasa tambien con el guard original.**
En la rotura 1 ese caso quedo en verde. Es correcto y esperado: el guard viejo nunca expulsaba de `/bootstrap` **por tener sesion**; el peligro real era exclusivamente la rama "sin sesion → `/login`", que es la que dispara el evento del alta de cuenta. El caso se conserva como no-regresion declarada, pero **no tiene dientes por si solo** — los dientes los pone `EL CASO QUE ROMPE EL FLUJO`.

**Candidato que SI resulto tener dientes (era el de mayor riesgo del plan):** cualquier test que siguiera pasando con la guarda atomica eliminada. Se comprobo explicitamente con la rotura A: caen 3 de los 11 casos, incluido el de sobrescritura del centinela ajeno. **La guarda atomica esta genuinamente ejercitada.**

**Tercer candidato revisado y descartado:** que el espia de borrado de cuenta pasara solo por el `signOut` (que tambien deja `currentUser` en null). La rotura 3 lo descarta: quitando el `delete()` y dejando el `signOut`, el caso cae.

## Files Created/Modified

**Creados**
- `functions/src/bootstrap-plataforma.js` (282 lineas) — la callable. Cabecera con los 5 controles y por que ninguno es opcional.
- `scripts/test/functions/_emu.mjs` (192) — montaje compartido; **11-08 lo reutiliza tal cual**.
- `scripts/test/functions/bootstrap.e2e.mjs` (338) — 11 casos.
- `panel_admin/lib/features/bootstrap/bootstrap_controller.dart` (175) + `.g.dart`.
- `panel_admin/lib/features/bootstrap/bootstrap_screen.dart` (304).
- `panel_admin/test/bootstrap/bootstrap_router_test.dart` (153) — 5 casos sobre el GoRouter real.
- `panel_admin/test/bootstrap/bootstrap_screen_test.dart` (434) — 13 casos (7 de formulario + 6 de controlador real).

**Modificados**
- `functions/index.js` — exporta `bootstrapPlataforma`; `initializeApp()` unico intacto.
- `firestore.rules` — +10 lineas: `match /plataforma/{doc} { allow read, write: if false; }` con el motivo.
- `docs/FIREBASE_SETUP.md` — nueva §4.1 "Inicializar una plataforma nueva" + 2 filas de troubleshooting.
- `scripts/package.json` — `test:functions` pasa `--set-env` y recoge `*.e2e.mjs`.
- `panel_admin/lib/app.dart` — ruta `/bootstrap` fuera del ShellRoute + exencion del redirect.
- `panel_admin/lib/features/auth/login_screen.dart` — enlace "¿Primera vez? Inicializar plataforma".
- `deferred-items.md` — desborde del sidebar del AppShell.

## Decisions Made

- **El orden guarda-primero / consulta-despues es la decision central.** Con la consulta delante, la rama `ALREADY_EXISTS` de `create()` quedaria practicamente inalcanzable y los tests pasarian identicos con la guarda borrada. El comentario del codigo lo dice con esas palabras para que nadie lo "ordene mejor" en el futuro.
- **La comprobacion secundaria solo corre si `creado === true`.** Sin esa condicion, el camino de reparacion (y por tanto la carrera) encuentra al propio llamador como super_admin y se auto-deniega. Verificado con la rotura E.
- **Segunda costura `bootstrapCallableProvider`, ampliando lo que pedia el plan.** Ver deviations.
- **La carrera se prueba con 5 llamadas del MISMO usuario.** Motivo escrito en la cabecera del e2e; el escenario ajeno se cubre de forma determinista sembrando el centinela con el Admin SDK.
- **`maxInstances: 3`** como unico freno a la invocacion masiva. App Check queda como deuda conocida (DIFERIDO, T-11-07-07).

## Deviations from Plan

**1. [Regla 2 — Funcionalidad critica ausente] El plan solo preveia UNA costura, y con ella el controlador real era intestable**

- **Found during:** Tarea 3.
- **Issue:** El plan manda una unica costura, `bootstrapAccionProvider`. Pero `FirebaseFunctions.instanceFor(...)` exige una app Firebase inicializada, imposible en `flutter test` (lo documenta el propio `functions_provider_test.dart` de 11-02). Con la accion entera sustituida por un doble, **nada** de lo que el plan considera critico quedaria verificado: ni el `ref.invalidate(claimsProvider)`, ni la reversion de la cuenta, ni el acotado por `cuentaCreadaAqui`. Serian afirmaciones apoyadas en un `grep`.
- **Fix:** Se anade `bootstrapCallableProvider` (solo la llamada a la callable). Los tests de formulario siguen usando la costura que pide el plan; los 6 casos de controlador usan el `bootstrapAccionProvider` **REAL** con `firebaseAuthProvider` (MockFirebaseAuth) y la callable doblada.
- **Verification:** roturas 2, 3 y 4 — cada una pone en rojo exactamente su caso.
- **Committed in:** `28c1714`.

**2. [Regla 3 — Bloqueante] El glob de `test:functions` no recogia `bootstrap.e2e.mjs`**

- **Found during:** Tarea 2.
- **Issue:** 11-01 dejo `test:functions` apuntando a `scripts/test/functions/*.test.mjs`, pero el plan nombra el archivo `bootstrap.e2e.mjs`. La suite habria salido con 0 tests y exit 0 — un falso verde perfecto.
- **Fix:** El script recoge `*.e2e.mjs` **y** `*.test.mjs`.
- **Committed in:** `8dc3e35`.

**3. [Regla 3 — Bloqueante, fuera de alcance] El sidebar del `AppShell` desborda 85px y tumbaba el test del router**

- **Found during:** Tarea 3, primer test del repo que renderiza `AppShell` completo (los del dashboard pumpean `DashboardScreen` suelta).
- **Issue:** `app_shell.dart:171` mete en un `Container` de 220px fijos un `Row` que pide ~248px. **No depende del viewport**: pasa igual a 800px que a 1920px. Un segundo `Row` (`:264`) desborda 33px. Es un defecto de layout **real, visible en produccion**, preexistente a este plan.
- **Fix:** NO se arregla aqui — `app_shell.dart` no esta en `files_modified` y el responsive es el bloque 3 (SCOPE BOUNDARY). Se registra en `deferred-items.md` con el arreglo propuesto, y el test del router filtra **exclusivamente** las excepciones `A RenderFlex overflowed`, con instruccion explicita de retirar el filtro cuando el bloque 3 corrija el sidebar. Cualquier otra excepcion sigue tumbando el test.
- **Committed in:** `28c1714`.

**4. [Estructural, no evitable] La Tarea 2 esta marcada `tdd="true"` pero su gate RED no existe**

- **Issue:** El plan crea la funcion en la Tarea 1 y sus tests en la Tarea 2. Un RED de la Tarea 2 exigiria que la implementacion no existiera todavia, lo que contradice la secuencia del propio plan. Los 11 casos salieron **verdes en la primera ejecucion**.
- **Fix:** Se reporta tal cual, sin fabricar un RED artificial. El equivalente con dientes son las **6 roturas deliberadas** (A–F) de la tabla de arriba, que es el mismo criterio que aplico 11-04 para las suites de rules. La Tarea 3, que si podia, si hizo RED→GREEN (`+0 -2` → `+18`).

**5. [Cosmetica] Viewport de escritorio en los tests de widget**

- **Issue:** Con el viewport de 800x600 por defecto, el boton del formulario cae fuera de la ventana y el `tap` no acierta.
- **Fix:** `tester.view.physicalSize` a 900x1400 (pantalla) y 1000x900 (router, por debajo del breakpoint de 1100 que dispara el desborde de StatCard de 11-02), con `addTearDown(tester.view.reset)`.

**6. [Sin cambio] `functions/.env.demo-gri` y `.env.example` ya traian `BOOTSTRAP_SECRET`**

- El plan pedia anadirlos "si 11-01 no lo dejo ya". Ya estaban. No se toco ningun archivo de entorno.

---

**Total deviations:** 6 (1 ampliacion por funcionalidad critica ausente, 2 bloqueantes, 1 estructural reportada sin maquillar, 1 cosmetica, 1 no-cambio). **Ninguna reduce alcance y ninguna asercion se relajo para poner algo en verde.**

## Mitigaciones del threat model

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-07-01 (suplantacion del correo del fundador) | **Mitigado y verificado** | `email_verified === true` + `BOOTSTRAP_SECRET` en tiempo constante. Casos negativos propios (`FACTOR EMAIL_VERIFIED`, 2× `FACTOR SECRETO`, `OTRO CORREO`). Roturas B y C los ponen en rojo |
| T-11-07-02 (segunda invocacion / carrera) | **Mitigado y verificado** | `create()` antes de toda consulta. `CARRERA REAL`: 5 llamadas en paralelo → 1 `creado` + 4 `reparado`, 1 centinela, 1 super_admin. Rotura A demuestra que la guarda es lo que lo sostiene |
| T-11-07-03 (promocion de un uid ajeno) | **Mitigado y verificado** | El payload solo lleva `nombre` y `secreto` (caso `la callable recibe SOLO nombre y secreto`). `CENTINELA AJENO` → `permission-denied` y el centinela intacto |
| T-11-07-04 (borrado del centinela para re-abrir) | **Mitigado (rules) / parcial (deploy)** | `match /plataforma/{doc} { allow read, write: if false; }`, 8 casos de default-deny de 11-04 en verde, rotura R los pone en rojo. **Pendiente el deploy real** — ver abajo |
| T-11-07-05 (repudio) | **Mitigado, con matiz** | El centinela guarda uid, email, nombre y `createdAt` de servidor (aserciones en `CAMINO FELIZ`). `userAgent` e `ip` se escriben pero **no se afirman en los tests**: en el emulador pueden ser null |
| T-11-07-06 (mensajes como oraculo) | **Mitigado y verificado** | Mismo texto y codigo en los 5 motivos; aserciones de igualdad literal en 3 casos; rotura F las pone en rojo. Los 3 controles se computan siempre antes de decidir |
| T-11-07-07 (invocacion masiva) | **Parcial (declarado)** | `maxInstances: 3` presente en el codigo. **NO verificado**: el emulador no aplica limites de instancias. App Check DIFERIDO |
| T-11-07-08 (cuenta huerfana / plataforma bloqueada) | **Mitigado y verificado** | Reversion en cliente (roturas 3 y 4), camino de reparacion idempotente (`SEGUNDA LLAMADA`) y borrado del centinela recien creado (`PROYECTO SEMBRADO`, rotura D) |
| T-11-07-09 (expulsion del guard con la callable en vuelo) | **Mitigado y verificado** | `EL CASO QUE ROMPE EL FLUJO` sobre el GoRouter real; rotura 1 lo pone en rojo |

## Que esta VERIFICADO y que solo esta AFIRMADO

**VERIFICADO (ejecutado contra emuladores reales o contra el GoRouter real):**
- Que una llamada anonima, un secreto incorrecto, un secreto de longitud distinta, un correo sin verificar y un correo ajeno **no** promueven a nadie, y que los cuatro rechazos dan el mismo texto.
- Que 5 invocaciones **en paralelo** del mismo usuario producen exactamente 1 `creado`, 4 `reparado`, un unico centinela con un unico `createdAt` y un unico `super_admin`.
- Que la guarda atomica es lo que sostiene ese resultado (rotura A) y que sin ella el centinela de otra persona se **sobrescribe**.
- Que el token refrescado tras el exito contiene `role: 'super_admin'` y `rid: null`, y que existe `usuarios/{uid}` con esos valores.
- Que un proyecto sembrado con el seed bloquea el bootstrap y que el centinela creado en esa invocacion se borra.
- Que `plataforma/**` es inaccesible desde el SDK cliente para anonimo, cliente, admin y super_admin.
- Que `/bootstrap` es alcanzable sin sesion y que el evento de sesion del alta de cuenta **no** expulsa; y que `/mesas` sin sesion sigue yendo a `/login`.
- Que `claimsProvider` se **recomputa** tras la callable (contador de construcciones, no un `grep`).
- Que la cuenta creada en el intento se **borra** al fallar, y que una cuenta preexistente **no**.

**AFIRMADO, NO VERIFICADO — leer antes de confiar:**
- **El `return null` incondicional de `/bootstrap` en `app.dart` es hoy redundante** (rotura 1b). Ver la seccion de verdes por el motivo equivocado.
- **La resistencia real a un ataque de temporizacion.** Se verifica que `timingSafeEqual` esta y que una longitud distinta deniega sin reventar; **no** se mide el tiempo de respuesta. Un test de temporizacion fiable no es viable en el emulador.
- **`maxInstances: 3`.** Declarado en el codigo, no ejercitado.
- **`userAgent` e `ip` del centinela.** Se escriben; su contenido no se afirma.
- **El comportamiento contra el proyecto REAL `p-gri-b5b40`.** Todo esto corre contra `demo-gri`. La rule del centinela **no esta desplegada**: hasta `firebase deploy --only firestore:rules`, produccion sigue con la version anterior. La funcion tampoco esta desplegada.
- **La verificacion del correo en produccion.** El emulador de Auth permite marcar `emailVerified` con el Admin SDK; en real hace falta el enlace de confirmacion (o una cuenta de Google, que llega verificada — 11-17). El flujo de "aun no verificado, revisa tu correo" **no tiene pantalla propia**: el usuario ve el mensaje generico.
- **El aspecto visual de `/bootstrap`.** No es observable en `flutter test`.

## Known Stubs

Ninguno. `/bootstrap` esta cableada de punta a punta contra la callable real.

## Threat Flags

Ninguna superficie nueva fuera del `<threat_model>` del plan. La unica ampliacion respecto a lo planeado es `bootstrapCallableProvider`, que no cruza ninguna frontera de confianza nueva: envuelve exactamente la invocacion que ya estaba prevista.

## Issues Encountered

- **El heredoc de bash con contenido UTF-8 largo fallo** al crear el primer archivo (`unexpected EOF`); se uso la herramienta de escritura de archivos. Sin impacto.
- **`firebase-functions` 7.3.2 expone `./https`** como subpath ESM (verificado importandolo antes de escribir codigo contra el).
- **`FirebaseFunctionsException` tiene el constructor `@protected`**: instanciarlo directo en un test dispara `invalid_use_of_protected_member` y romperia el `analyze` en 0. Se resuelve con una subclase en el test (uso legitimo de un miembro protegido).
- Los emuladores dejan `firestore-debug.log` y `ui-debug.log`; ya cubiertos por `*-debug.log` en `.gitignore`.

## Next Phase Readiness

**Para 11-08 (`crearUsuarioStaff`):**
- `scripts/test/functions/_emu.mjs` esta listo para reutilizar: `montar()`, `crearUsuario()`, `login()`, `limpiar()`, `configEsperada()`. Anadir un `bootstrapPlataforma` previo si el test necesita un super_admin real con claims.
- El glob de `test:functions` ya recoge `*.e2e.mjs` **y** `*.test.mjs`.
- `functions/index.js` tiene su linea de export comentada esperando.
- **Aviso:** `limpiar()` borra TODOS los usuarios de Auth y las colecciones `usuarios` y `plataforma`. Si 11-08 siembra otras colecciones, debe ampliar la lista.

**Para el bloque 3 (responsive/tokens):** el desborde del sidebar de `AppShell` esta en `deferred-items.md`. Al corregirlo, **retirar el filtro de `A RenderFlex overflowed`** de `bootstrap_router_test.dart`.

**PENDIENTE DE SELLADO HUMANO:** desplegar la funcion y las rules contra `p-gri-b5b40` con `BOOTSTRAP_EMAIL`/`BOOTSTRAP_SECRET` reales en `functions/.env`, y ejecutar el flujo de `/bootstrap` una vez. Runbook en `docs/FIREBASE_SETUP.md` §4.1.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `functions/src/bootstrap-plataforma.js`, `scripts/test/functions/_emu.mjs`, `scripts/test/functions/bootstrap.e2e.mjs`, `panel_admin/lib/features/bootstrap/bootstrap_controller.dart`, `bootstrap_controller.g.dart`, `bootstrap_screen.dart`, `panel_admin/test/bootstrap/bootstrap_router_test.dart`, `bootstrap_screen_test.dart`.

Commits declarados — verificados en `git log`: `06ba232`, `8dc3e35`, `28c1714`.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
