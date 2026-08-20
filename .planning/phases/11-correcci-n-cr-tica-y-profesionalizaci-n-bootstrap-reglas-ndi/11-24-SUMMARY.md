---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 24
subsystem: cloud-functions + panel (baja reversible de personal)
tags: [cloud-functions, revocacion-de-privilegios, multi-tenant, logica-pura, e2e-emuladores, idempotencia, reversibilidad]

# Dependency graph
requires:
  - plan: 11-07
    provides: scripts/test/functions/_emu.mjs, patron de callable, glob *.e2e.mjs en test:functions
  - plan: 11-08
    provides: "auth-matrix.js (ROLES_LLAMADORES, patron de matriz PURA), crearUsuarioStaff, crearUsuarioConClaims()"
  - plan: 11-10
    provides: "features/equipo/ (provider, controlador, pantalla, gating) y la regla de usuarios acotada al rid"
  - plan: 11-12
    provides: tokens del panel (GriColors, GriSpacing, GriRadius) y griBotonPeligroTexto
  - plan: 11-05
    provides: "criterio de confirmacion SOLO en el sentido destructivo (toggle de restaurantes)"
provides:
  - "functions/src/baja-matrix.js — autorizarCambioEstado(): la matriz de la BAJA como logica PURA, con las dos prohibiciones nuevas"
  - "functions/src/cambiar-estado-staff.js — callable cambiarEstadoStaff, reversible e idempotente"
  - "functions/test/baja-matrix.test.js — 49 casos sin emulador (19 filas x 2 sentidos + propiedades + invariantes)"
  - "functions/test/cambiar-estado-staff.contrato.test.js — gate estatico de no-fuga y de que la baja NO borra el rol"
  - "scripts/test/functions/cambiar-estado-staff.e2e.mjs — 22 casos con tokens reales"
  - "panel_admin: /equipo desactiva y reactiva, con insignia de estado y confirmacion destructiva"
  - "_emu.mjs: llamarCambiarEstado(), intentarLogin(), crearPedido(); limpiar() cubre `pedidos`"
affects: [11-15, 11-16, 11-20, 11-25]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "La baja de personal es DESACTIVACION REVERSIBLE: disabled + claims a null + revokeRefreshTokens, conservando role/restauranteId en el doc espejo"
    - "El doc espejo es la UNICA fuente del rol de una persona ya desactivada: por eso la baja no puede tocar esos dos campos y por eso la reactivacion los lee de ahi"
    - "Cuando varios controles comparten codigo de error, el test asserta el MENSAJE literal; si no, uno de ellos queda sin ejercitar"
    - "Un contrato estatico sobre la fuente debe leer SOLO codigo: comparar contra el archivo entero deja que un comentario salve o hunda la asercion"

key-files:
  created:
    - functions/src/baja-matrix.js
    - functions/src/cambiar-estado-staff.js
    - functions/test/baja-matrix.test.js
    - functions/test/cambiar-estado-staff.contrato.test.js
    - scripts/test/functions/cambiar-estado-staff.e2e.mjs
    - panel_admin/test/equipo/equipo_baja_test.dart
  modified:
    - functions/index.js
    - scripts/test/functions/_emu.mjs
    - panel_admin/lib/features/equipo/equipo_provider.dart
    - panel_admin/lib/features/equipo/equipo_controller.dart
    - panel_admin/lib/features/equipo/equipo_screen.dart
    - panel_admin/test/equipo/equipo_screen_test.dart
    - docs/ICONOS-panel_admin.md

key-decisions:
  - "La matriz de la baja vive en un archivo HERMANO de auth-matrix.js, no dentro: son decisiones distintas (una crea, otra revoca) y sus tablas no se solapan. Se comparte SOLO ROLES_LLAMADORES, importado, con un test que prohibe redeclararlo aqui"
  - "El orden de comprobaciones es parte del contrato: llamador -> objetivo no super -> objetivo no soy yo -> alcance de rid -> el objetivo es personal. Consecuencia MEDIDA: un super_admin sobre si mismo muere por la prohibicion 1, no por la 2, asi que ese caso NO sirve para probar la 2"
  - "Se anade una quinta comprobacion que el plan no pedia: el objetivo tiene que ser PERSONAL. El plan declara los clientes fuera de alcance razonando que «un cliente no pertenece a ningun rid», pero eso solo cierra la puerta al admin_restaurante; el super_admin no tiene rid contra el que comparar y pasaba"
  - "La baja REPARA la ficha incompleta: si el espejo no tiene role/restauranteId, se escriben desde los claims ANTES de borrarlos. Sin eso, desactivar a esa persona destruiria el ultimo rastro de su rol y la baja dejaria de ser reversible"
  - "`activo` ausente en el doc espejo se lee como TRUE: las fichas creadas antes de este plan no lo tienen y con el criterio contrario todo el equipo existente apareceria de baja de golpe"
  - "La ventana residual de ~1 h del ID token queda ACEPTADA y documentada en el codigo, en el threat model y en el copy de la UI. Cerrarla exigiria un get() por request en las rules"

patterns-established:
  - "11-25 / quien toque /equipo: la accion por fila se oculta para uno mismo y para los super_admin, pero eso es UX; la decision vive en la callable y tiene e2e con token real"

requirements-completed: [BOOT-05]

# Metrics
duration: ~38 min
completed: 2026-08-20
---

# Phase 11 Plan 24: Baja reversible de personal Summary

**Un restaurante ya puede gestionar las salidas de su equipo sin perder ni un pedido: `cambiarEstadoStaff` deshabilita la cuenta, le retira los claims y revoca sus refresh tokens conservando el rol en el espejo — y las dos prohibiciones nuevas estan PROBADAS quitando su control y viendo caer exactamente los casos correctos, en los dos niveles.**

## Performance

- **Duration:** ~38 min
- **Tasks:** 3/3
- **Files created:** 6 · **modified:** 7

## Baseline MEDIDO antes de tocar nada

| Suite | Antes | Despues | Delta |
|---|---|---|---|
| `panel_admin` (`flutter test`) | **292** · analyze `No issues found!` | **313** · analyze `No issues found!` | +21 |
| functions unitarios (`cd functions && npm test`) | **34** | **96** | +62 |
| functions e2e (`cd scripts && npm run test:functions`) | **25** | **47** | +22 |
| `firestore.rules` (`npm run test:rules`) | **221** | **221** | 0 (el plan no toca rules) |

`app_cliente` NO se midio ni se toco: el ejecutor de 11-14 (y despues el de 11-23) trabajaban en esa app durante toda la ejecucion.

## Task Commits

| # | Tarea | Commit |
|---|---|---|
| 1 | Matriz pura `baja-matrix.js` — RED | `a392812` (test) |
| 1 | Matriz pura `baja-matrix.js` — GREEN | `ea95ed8` (feat) |
| 2 | Callable `cambiarEstadoStaff` + export + e2e + contrato estatico | `260da01` (feat) |
| 3 | Desactivar/reactivar desde `/equipo` | **`2ada353`** — ver deviation 1: el ejecutor de 11-23 committeo con mis archivos ya en el indice y se los llevo dentro de su commit |

## Gates ejecutados (salida REAL)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline panel | `cd panel_admin && flutter analyze && flutter test` | `No issues found!` · `+292: All tests passed!` |
| Baseline functions unit | `cd functions && npm test` | `tests 34 · pass 34 · fail 0` |
| Baseline functions e2e | `cd scripts && npm run test:functions` | `tests 25 · suites 2 · pass 25 · fail 0` |
| Baseline rules | `cd scripts && npm run test:rules` | `tests 221 · pass 221 · fail 0` |
| **T1 RED** | `node --test test/baja-matrix.test.js` | `ERR_MODULE_NOT_FOUND ... functions/src/baja-matrix.js` · `pass 0 · fail 1` |
| **T1 GREEN** | `cd functions && npm test` | `tests 83 · pass 83 · fail 0` · `duration_ms 233.9` (sin emulador) |
| T2 sintaxis | `node --check src/cambiar-estado-staff.js && node --check index.js` | `CHECK_OK` |
| T2 unit | `cd functions && npm test` | `tests 96 · pass 96 · fail 0` |
| **T2 e2e** | `cd scripts && npm run test:functions` | `tests 47 · suites 3 · pass 47 · fail 0` |
| T3 analyze | `cd panel_admin && flutter analyze` | `No issues found! (ran in 2.2s)` |
| T3 equipo | `cd panel_admin && flutter test test/equipo/` | `+58: All tests passed!` |
| T3 panel entero | `cd panel_admin && flutter test` | `+313: All tests passed!` |
| Final functions unit | `cd functions && npm test` | `tests 96 · suites 16 · pass 96 · fail 0` · `duration_ms 83.6` |
| Final functions e2e | `cd scripts && npm run test:functions` | `tests 47 · suites 3 · pass 47 · fail 0` |
| Final rules | `cd scripts && npm run test:rules` | `tests 221 · pass 221 · fail 0` |
| Indices | `cd scripts && npm run audit:indexes` | `22 queries analizadas · 5 sujetas a paridad · 0 fallo(s)` · exit 0 |
| Branding | `cd scripts && npm run audit:branding` | `AUDIT BRANDING OK · 2 apps · 4 archivos · 0 rastros de plantilla` |

**`npm run verify:shell` NO se ejecuto.** Exige `flutter build web --release` previo en LAS DOS apps y `app_cliente` estaba siendo modificada por otros dos ejecutores en el mismo arbol: compilarla habria medido su codigo a medias. El plan no toca web/, ni el shell, ni el branding.

## Las dos prohibiciones nuevas: ¿PROBADAS o solo asertadas?

Las dos, **PROBADAS en los dos niveles** — se quito el control y se comprobo que caen los casos correctos.

### PROHIBICION 1 — nadie puede cambiar el estado de un `super_admin`

| Nivel | Rotura | Casos que caen |
|---|---|---|
| Unitario | quitar `objetivoRole === 'super_admin'` (rotura A2) | **7**: las 3 filas marcadas `// PROHIBICION-1`, sus gemelas de `activo:false` y el test de propiedad de 256 combinaciones |
| e2e (tokens reales) | la misma (rotura O) | **4**: admin sobre super, super sobre otro super, la REACTIVACION de un super, y el super sobre si mismo |

**Y ademas se caza un verde por el motivo equivocado, ver abajo:** en la primera version, el test de propiedad de esta prohibicion **NO caia** con el control quitado.

### PROHIBICION 2 — nadie puede cambiar su propio estado

| Nivel | Rotura | Casos que caen |
|---|---|---|
| Unitario | quitar `callerUid === objetivoUid` (rotura B) | **6**: la fila AISLADA, la fila del admin sobre si mismo, sus gemelas de `activo:false`, el test de propiedad de 512 combinaciones y el de independencia |
| Unitario | comparacion laxa del uid (rotura K) | **6**, los mismos |
| e2e (tokens reales) | la misma (rotura N) | **1**, y es el correcto: `PROHIBICION 2 — un admin_restaurante sobre su PROPIO uid` |

**Matiz honesto y MEDIDO sobre el aislamiento a nivel e2e.** El caso e2e que escribi primero para aislar la prohibicion 2 —un `super_admin` con doc espejo `role: 'mesero'` actuando sobre si mismo— salio ROJO, y el codigo tenia razon: la callable deriva el rol del objetivo de sus CLAIMS y solo cae al espejo cuando no hay ninguno. Con un llamador VALIDO (que por definicion es `super_admin` o `admin_restaurante`), el unico aislamiento posible en e2e es el `admin_restaurante` sobre si mismo — que es exactamente el caso que la rotura N tumba, y el unico. El aislamiento exhaustivo vive en la matriz pura, donde el rol del objetivo es un parametro libre. La asercion NO se relajo para ponerla verde: se sustituyo por el caso que describe la realidad (`super` sobre si mismo muere por la prohibicion 1, por el ORDEN) con esa razon escrita en el propio test.

### Y la tercera, la del alta (alcance de tenant)

Rotura D (unitario): **5 casos**. Rotura P (e2e): **2**, incluido el admin ajeno intentando readmitir a alguien YA desactivado — el vector que solo existe cuando el objetivo no tiene claims y su rid solo vive en el espejo.

## Verificacion por ROTURA DELIBERADA (26 roturas, todas revertidas)

Tras cada bloque se comprobo que el archivo volvia byte a byte al original (el arnes lo verifica y lo imprime).

### Nivel unitario — `cd functions && npm test`

| # | Rotura | Caen | Revertida |
|---|---|---|---|
| A | se elimina la PROHIBICION-1 | 6 (**y la propiedad NO** — ver "verdes cazados") | Si |
| A2 | la misma, tras endurecer la propiedad | **7** | Si |
| B | se elimina la PROHIBICION-2 | 6 | Si |
| C | cualquier rol puede llamar | 8 | Si |
| D | se elimina el alcance de rid | 5 | Si |
| E | se elimina la allow-list de objetivos | 4 | Si |
| F | el admin sin rid sigue adelante | 2 | Si |
| H | la decision pasa a depender de `activo` (auto-baja permitida al reactivar) | 4 | Si |
| I | `ROLES_LLAMADORES` se redeclara en vez de importarse | 1 | Si |
| J | el modulo importa `firebase-admin` | 1 | Si |
| K | la comparacion de uid se hace laxa | 6 | Si |
| L | **asercion de mensaje DEBILITADA a solo-codigo + rotura A** | **0 filas de tabla** (solo la propiedad) | Si |
| M | asercion de mensaje debilitada + rotura B | 6 (la prohibicion 2 tiene dientes igual) | Si |

### Nivel e2e — `cd scripts && npm run test:functions`

| # | Rotura | Caen | Revertida |
|---|---|---|---|
| N | se elimina la PROHIBICION-2 | 1 (el aislado) | Si |
| O | se elimina la PROHIBICION-1 | 4 | Si |
| P | se elimina el alcance de rid | 2 | Si |
| Q | la callable IGNORA la decision (se quita el `throw`) | **10** | Si |
| R | se elimina el fallback al espejo | 3 | Si |
| S | la baja LIMPIA `role` y `restauranteId` | 3 | Si |
| T | se elimina `revokeRefreshTokens` | **0 — ver "verdes cazados"** | Si |
| T2 | la misma, con el caso nuevo | **1** | Si |
| U | se elimina la retirada de claims | 3 | Si |
| V | se elimina `disabled: true` | 5 | Si |
| W | se elimina la reparacion de la ficha incompleta | 1 | Si |

### Nivel UI — `cd panel_admin && flutter test test/equipo/`

| # | Rotura | Caen | Revertida |
|---|---|---|---|
| X | la accion aparece tambien en la PROPIA fila | 1 | Si |
| Y | la accion aparece en las filas de `super_admin` | 1 | Si |
| Z | se elimina la confirmacion de la baja | 4 | Si |
| AA | REACTIVAR tambien pide confirmacion | 5 | Si |
| AB | se elimina el bloqueo por operacion en vuelo | 1 | Si |
| AC | la lista no se refresca tras la operacion | 2 | Si |
| AD | la insignia pinta a todos como activos | 1 | Si |
| AE | el boton dice siempre "Desactivar" | 1 | Si |
| AF | el campo `activo` del espejo se ignora | 1 | Si |
| AG | la ausencia de `activo` se lee como BAJA | 1 | Si |
| AH | `permission-denied` muestra el texto CRUDO del servidor | 1 | Si |
| AI | el payload manda ademas `rol` | **0 — ver "verdes cazados"** | Si |
| AI2 | la misma, con el gate nuevo | 1 | Si |
| AJ | el payload manda `activo` como cadena | 2 | Si |

## Caza de verdes por el motivo equivocado

**Encontrados CUATRO. Los cuatro corregidos y la correccion verificada rompiendola otra vez.**

**1. El test de propiedad de la PROHIBICION 1 no probaba la prohibicion 1.**
Con el control quitado (rotura A), la propiedad seguia VERDE: un objetivo `super_admin` se denegaba igualmente, pero por la allow-list de objetivos del paso 5 —donde `super_admin` tampoco esta—. La propiedad solo comprobaba `ok === false`. Ironicamente, quien la tapaba era la comprobacion que YO habia anadido por la Regla 2.
**Correccion:** la propiedad exige ahora el MENSAJE de la prohibicion 1, que por el orden de comprobaciones es siempre ese. **Verificacion:** la rotura A2 pasa de tumbar 6 casos a **7**, y el que se suma es esa propiedad.

**2. La tabla entera estaba a un `assert` de no probar nada.**
MEDIDO con la rotura L: debilitando la asercion a solo-codigo y quitando la prohibicion 1, **NINGUNA fila de la tabla cae**. Los cinco controles devuelven `permission-denied`, asi que sin la identidad del mensaje las tres filas de la prohibicion 1 se habrian denegado por otro control y la suite habria dado el plan por bueno. Es la leccion de 11-08 aplicada antes de que costara. Con la prohibicion 2 la asimetria es real y queda dicha: ahi la rotura M tumba 6 casos igualmente, porque quitar el control convierte el caso aislado en un `ok: true`.

**3. `revokeRefreshTokens` estaba AFIRMADO, no verificado.**
La rotura T no tumbaba **nada**. Y no era mala escritura del e2e: mientras `disabled: true` siga puesto, revocar o no revocar es indistinguible por comportamiento (el emulador rechaza igual el login y el refresh). Los dos controles se solapan a proposito, pero eso dejaba el tercer paso de la baja sin gate.
**Correccion:** un caso que observa el efecto DIRECTO, `tokensValidAfterTime`. Con una espera deliberada de 1,1 s, porque esa marca tiene precision de SEGUNDO y sin ella la del alta y la de la revocacion caerian en el mismo segundo, dejando la comparacion estricta verde por construccion. **Verificacion:** rotura T2 lo tumba.

**4. El test de compatibilidad de `activo` era una TAUTOLOGIA.**
La primera version comparaba `mapa['activo'] as bool? ?? true` contra `isTrue` sobre un mapa literal del propio test: no llegaba a `equipoProvider` ni de lejos y habria seguido verde con el valor por defecto invertido en el codigo.
**Correccion:** dos casos que leen de un `FakeFirebaseFirestore` por el camino real, uno por cada direccion. **Verificacion:** roturas AF y AG tumban uno cada una.

**Un quinto candidato, la forma del payload (rotura AI):** meter `'rol': 'mesero'` en la llamada no ponia rojo nada. El servidor lo ignoraria hoy, pero el contrato de 11-08 es que el cliente no tiene palanca sobre lo que el servidor DERIVA. Se anadio el grupo `cambiarEstadoAccion — forma del payload`; las roturas AI2 y AJ lo tumban.

## Gates propios defectuosos (encontrados y corregidos ANTES de confiar en ellos)

Los tres `<verify>` del plan son ejecutables y significativos — **es el primero de la fase en varios planes que no trae ningun gate roto**. Los dos defectuosos de esta ejecucion los escribi yo:

1. **El contrato estatico de la callable comparaba contra el ARCHIVO ENTERO.** Dos casos salieron rojos con el codigo correcto: la cabecera explica los pasos de la revocacion, asi que `indexOf('setCustomUserClaims(uid, null)')` encontraba el COMENTARIO y el orden salia invertido; y el veto a `!!activo` lo disparaba su propia advertencia. Es el mismo defecto que la fase lleva ocho veces documentado en gates de `grep`: confundir "alguien lo menciona" con "el codigo lo hace". **Corregido:** todas las aserciones estructurales van contra `CODIGO` (lineas sin comentarios).
2. **El gate de "las prohibiciones estan marcadas" contaba menciones.** `/\/\/ PROHIBICION-1/g` daba 5 en vez de 3 porque casaba con la cabecera y con el separador de seccion. **Corregido:** cuenta lineas cuyo contenido es EXACTAMENTE la marca y ademas las ata al CONTENIDO de la tabla (el numero de filas que esperan cada mensaje), asi que borrar una fila y dejar la marca —o al reves— se pone rojo.

## Deviations from Plan

**1. [Colision entre ejecutores] Los archivos de la Tarea 3 acabaron dentro del commit de 11-23**

- **Found during:** el commit de la Tarea 3.
- **Issue:** un `git status --short --cached` (opcion inexistente, exit 129) corto mi cadena `&&` y dejo mis 8 archivos ESTAGEADOS sin committear. El ejecutor de 11-23, trabajando en el mismo arbol, hizo su commit acto seguido y se los llevo dentro: `2ada353` contiene su `app_cliente/lib/core/firebase_error_mapper.dart` MAS los 8 archivos de mi Tarea 3.
- **Fix:** **ninguno sobre el historial.** Reescribirlo (rebase/reset/amend) con otro ejecutor activo en el mismo arbol seria destructivo y podria tumbar trabajo ajeno. El contenido esta INTACTO y verificado: los 8 archivos estan en HEAD y las suites pasan a HEAD. Queda la atribucion cruzada, documentada aqui y en STATE.md.
- **Leccion para el siguiente:** en arbol compartido, `git add` y `git commit` tienen que ir en la MISMA invocacion y sin nada entre medias que pueda fallar.

**2. [Regla 2 — funcionalidad critica ausente] Se anade una quinta comprobacion: el objetivo tiene que ser PERSONAL**

- **Found during:** Tarea 1, al escribir la tabla.
- **Issue:** el plan declara "desactivar clientes" fuera de alcance razonando que «un cliente no pertenece a ningun rid». Ese razonamiento **solo cierra la puerta al `admin_restaurante`**, a quien lo corta el alcance de tenant. El `super_admin` no tiene rid contra el que comparar: con las cuatro comprobaciones del plan, podia deshabilitar la cuenta de un comensal de la app movil desde la pantalla de equipo.
- **Fix:** `ROLES_GESTIONABLES = ['admin_restaurante','mesero','cocina']` como allow-list de OBJETIVOS, comprobada **al final** — si fuese antes que la prohibicion 1, un objetivo `super_admin` moriria ahi y su test quedaria verde por el motivo equivocado.
- **Verification:** rotura E (4 casos unitarios) y dos casos e2e (`FUERA DE ALCANCE — nadie desactiva a un CLIENTE`, `sin rol en ninguna fuente`).

**3. [Regla 2] La baja REPARA la ficha incompleta en vez de destruir el ultimo rastro del rol**

- **Found during:** Tarea 2, escribiendo el paso 6.
- **Issue:** el plan dice que el `set` de la baja no toque `role` ni `restauranteId`. Correcto para el caso normal, pero si el espejo NO los tiene —alta que murio entre Auth y Firestore, la no-atomicidad que el propio 11-08 documenta— la baja borra los claims y ahi se acaba toda fuente del rol: esa persona ya no se puede reactivar nunca. Es justo T-11-24-05.
- **Fix:** se escriben **solo si faltan**, tomados de los claims que se estan a punto de borrar. Ningun valor existente se toca, asi que la instruccion del plan se cumple literalmente para todo espejo bien formado.
- **Verification:** rotura W tumba el caso `REPARACION`, que ademas comprueba que tras esa baja la reactivacion SIGUE funcionando.

**4. [Regla 2] Contrato estatico propio para la callable nueva**

- **Issue:** `crear-usuario-staff.contrato.test.js` (11-08) cubre solo su archivo, asi que la callable nueva nacia sin gate contra T-11-24-07. Y T-11-24-05 es una AUSENCIA (que el `set` de la baja no borre el rol), que un e2e no puede probar: solo comprueba el estado tras UNA secuencia.
- **Fix:** `functions/test/cambiar-estado-staff.contrato.test.js`, 13 casos. **Verification:** la rotura S lo pone rojo ademas de tumbar 3 e2e.

**5. [Ampliacion, dentro de lo que el plan autoriza] `_emu.mjs` se extiende y `limpiar()` cubre `pedidos`**

- **Issue:** `_emu.mjs` no esta en `files_modified`, pero el plan ordena reutilizarlo. Ademas, la decision bloqueada del usuario es no borrar PORQUE se perderian pedidos: sin sembrar un pedido no habia forma de comprobarlo, y sin limpiar `pedidos` entre casos uno heredado dejaria esa comprobacion verde por el motivo equivocado.
- **Fix:** `+llamarCambiarEstado`, `+intentarLogin`, `+crearPedido`, y `pedidos` en `limpiar()`. Los 25 casos e2e previos siguen verdes.

**6. [Fuera de `files_modified`, inevitable] `equipo_screen_test.dart` y `docs/ICONOS-panel_admin.md`**

- **Issue (a):** al anadir `activo` al record `MiembroEquipo`, las dos tuplas literales de `equipo_screen_test.dart` dejan de compilar; y al leer la tabla el uid de la sesion, ese test necesita el override de `uidSesionProvider` (sin el llega a `FirebaseAuth.instance`, que no es instanciable en `flutter test`).
- **Issue (b):** `docs/ICONOS-panel_admin.md` apuntaba a `equipo_screen.dart:135` y el icono se desplazo a la 138. **Lo detecto solo el gate de paridad de 11-21**, tal y como 11-12 dejo avisado.
- **Fix:** los dos actualizados en el mismo commit que el cambio que los movio.

**7. [Estructural, no evitable] Las Tareas 2 y 3 estan marcadas `tdd="true"` pero su RED no existe**

- **Issue:** el plan crea la callable en la Tarea 2 y su e2e en la misma tarea; la Tarea 3 crea pantalla y test a la vez. Un RED exigiria que la implementacion no existiera, lo que contradice la secuencia del propio plan. Mismo caso que reportaron 11-07 (deviation 4) y 11-08 (deviation 6).
- **Fix:** se reporta tal cual, sin fabricar un RED artificial. La **Tarea 1 SI hizo RED->GREEN de verdad** (`ERR_MODULE_NOT_FOUND` -> `83/83`) y esta committeada en dos commits separados. El equivalente con dientes para las otras dos son las 26 roturas deliberadas.

**8. [Trazabilidad] `BOOT-05` no existe en REQUIREMENTS.md**

- **Issue:** `.planning/REQUIREMENTS.md` no contiene ningun id `BOOT-*` (usa `PLAT-*`, `AUTH-*`...), como llevan reportando todos los planes de la fase desde 11-02. `requirements.mark-complete BOOT-05` devuelve `not_found`.
- **Fix:** no se invento ninguna entrada. Queda en el frontmatter de este SUMMARY.

---

**Total deviations:** 8 (1 colision de arbol compartido sin impacto en contenido, 3 ampliaciones por funcionalidad critica ausente, 1 ampliacion autorizada, 1 de archivos arrastrados, 1 estructural reportada sin maquillar, 1 de trazabilidad). **Ninguna reduce alcance. Ninguna asercion se relajo para poner algo en verde: cuatro se endurecieron y una se sustituyo por la que describe la realidad medida.**

## Mitigaciones del threat model

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-24-01 (desactivar a un `super_admin`) | **Mitigado y VERIFICADO** | Comprobacion 2 de la matriz; 3 filas marcadas x2 sentidos + propiedad de 256 combinaciones + 4 casos e2e con token real. Roturas A2 (7 caidas) y O (4) |
| T-11-24-02 (auto-baja del unico admin) | **Mitigado y VERIFICADO** | Comprobacion 3, con el uid del TOKEN; caso AISLADO cuyo objetivo no es super + propiedad de 512 combinaciones + e2e. Roturas B (6), K (6) y N (1). La UI ademas no ofrece la accion (roturas X y AB) |
| T-11-24-03 (admin de A sobre staff de B) | **Mitigado y VERIFICADO** | Comprobacion 4, identica a la del alta; incluye el vector contra alguien YA desactivado, cuyo rid solo vive en el espejo. Roturas D (5) y P (2) |
| T-11-24-04 (acceso residual con el token ya emitido) | **ACEPTADO y documentado** | Ventana de ~1 h acotada por los tres pasos. Documentada en la cabecera de la callable, en el threat model y **en el copy de la UI en los DOS sentidos**. La revocacion en si esta ahora VERIFICADA (`tokensValidAfterTime`, rotura T2) — antes solo estaba afirmada |
| T-11-24-05 (perder el rol al desactivar) | **Mitigado y VERIFICADO, y reforzado** | El espejo conserva `role`/`restauranteId`; el e2e `REVERSIBLE` lo demuestra tras una vuelta completa; el contrato estatico prohibe borrarlos con cualquier forma (`null`, `FieldValue.delete()`, `''`, `undefined`); y la rama de reparacion cubre la ficha que ya venia rota. Roturas S (3) y W (1) |
| T-11-24-06 (baja sin trazabilidad) | **Mitigado, con matiz** | `desactivadoPor`/`desactivadoAt` y `reactivadoPor`/`reactivadoAt` en el espejo, ASERTADOS en el e2e (`desactivadoPor === uid del admin`). El `logger.info` se emite y se ve en la salida del emulador, pero **su contenido no lo afirma ninguna asercion** |
| T-11-24-07 (fuga del error crudo) | **Mitigado y VERIFICADO** | `HttpsError('internal', mensaje fijo, err?.code)`; el contrato estatico rechaza `.message` y `.stack` con CUALQUIER nombre de variable, ignorando comentarios |

## Que esta VERIFICADO y que solo esta AFIRMADO

**VERIFICADO (contra emuladores reales con tokens que portan claims reales, o contra la logica pura):**
- Que un `admin_restaurante` de `demo` da de baja a un mesero de `demo` y, **inmediatamente despues, esa persona NO puede iniciar sesion** — y que **ANTES si podia** (sin esa segunda comprobacion, el caso estaria verde aunque nunca hubiera podido entrar).
- Que sus **pedidos siguen en Firestore, atribuidos a su uid**: nada quedo huerfano.
- Que la cuenta queda `disabled`, **sin claims**, y que el espejo conserva `role: 'mesero'` y `restauranteId: 'demo'` sin perder el nombre.
- Que **reactivar devuelve exactamente los claims que tenia**, leidos del espejo — el unico sitio donde sobrevivieron — y que vuelve a poder entrar.
- Que desactivar **dos veces seguidas** converge sin error, incluida la segunda llamada, en la que el objetivo ya no tiene claims.
- Que **nadie** toca a un `super_admin`: ni un admin, ni otro super, ni reactivandolo.
- Que **nadie se toca a si mismo**, con el mensaje del control de auto-baja y no el de otro.
- Que un admin de `otro` no alcanza a alguien de `demo`, tampoco cuando ya esta de baja.
- Que un mesero no puede llamar la callable y que una llamada anonima no mueve nada.
- Que la cadena `"false"` da `invalid-argument` y **no reactiva a nadie**.
- Que la revocacion de refresh tokens ocurre (`tokensValidAfterTime` avanza).
- Que `baja-matrix.js` no importa nada de Firebase y que NO redeclara `ROLES_LLAMADORES`.
- Que la callable **realmente** consulta la matriz (rotura Q: 10 caidas).
- Que ninguna linea de la callable lee `.message` ni `.stack`.
- Que la UI no ofrece la accion sobre uno mismo ni sobre un `super_admin`, que cancelar no llama a nada, que reactivar no pide confirmacion y que un doble toque no dispara dos llamadas.

**AFIRMADO, NO VERIFICADO — leer antes de confiar:**
- **El contenido del `logger.info` de auditoria.** Se emite y se ve en la salida del e2e; ninguna asercion lo comprueba (mismo hueco que 11-08).
- **`maxInstances: 5`.** Declarado, no ejercitado: el emulador no aplica limites de instancias.
- **La ventana residual de ~1 h.** Lo verificado es que la revocacion ocurre y que la cuenta queda deshabilitada; **NO se ha medido que un ID token ya emitido siga siendo aceptado por las rules durante ese rato**, que es la parte "aceptada" del riesgo.
- **Que el panel se VEA bien.** No hay golden tests en el repo. La insignia de estado, el color gris del nombre de un miembro de baja y la columna de accion no se han visto renderizados nunca.
- **El comportamiento contra el proyecto REAL `p-gri-b5b40`.** Todo corre contra `demo-gri`. **La funcion NO esta desplegada**, igual que `bootstrapPlataforma` y `crearUsuarioStaff`.
- **`npm run verify:shell`** no se ejecuto (ver la nota de la tabla de gates).

## Known Stubs

Ninguno. La funcion esta cableada de punta a punta —matriz, callable, provider, controlador y pantalla— y probada en los tres niveles.

## Threat Flags

Ninguna superficie nueva fuera del `<threat_model>` del plan. `firestore.rules` no se toca: el doc espejo lo escribe el Admin SDK, que las salta por diseno, y la lectura del equipo ya se abrio en 11-10.

Se **reduce** una superficie que el plan no habia visto: los clientes de la app movil pasan a estar explicitamente fuera del alcance de esta callable (deviation 2).

## Issues Encountered

- **Arbol compartido con 11-14 y 11-23** durante toda la ejecucion. Solo se estagearon archivos propios, nunca `git add -A` — pero aun asi la Tarea 3 acabo dentro del commit ajeno (deviation 1). En el arbol quedan sin committear, y NO son mios: `.planning/config.json`, `app_cliente/android/app/src/main/AndroidManifest.xml`, `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart` (ya declarado como ajeno por 11-13 y 11-19), `app_cliente/android/app/src/main/res/xml/`, `documentos/google-services.json`, `documentos/sdk.png` y `run_app.bat`.
- **Un heredoc de shell no puede escribir estos archivos.** Dos intentos de crear los archivos grandes con `cat > archivo <<'EOF'` fallaron con `unexpected EOF while looking for matching`, dejando el archivo sin crear. Los heredocs cortos (JSON, parches de Python) funcionan bien. Se uso la herramienta de escritura directa para los archivos largos.
- **Cada rotura e2e cuesta un arranque de emuladores** (~40 s). Se uso un driver que corre SOLO `cambiar-estado-staff.e2e.mjs` para acotar el ciclo.

## Next Phase Readiness

**Para quien consuma la callable:**
- `httpsCallable(fns, 'cambiarEstadoStaff')` en `us-central1`, con `{uid: string, activo: boolean}` (booleano ESTRICTO) y devuelve `{uid, activo, rol, restauranteId}`.
- Codigos a traducir: `unauthenticated`, `invalid-argument`, `permission-denied` (CINCO controles distintos comparten este codigo: el texto de la UI no puede afirmar cual fue), `not-found`, `failed-precondition`, `internal`.
- **La UI debe avisar en los DOS sentidos** de que la persona tiene que volver a entrar: la baja no expulsa al instante una sesion abierta y la readmision no devuelve los permisos a una sesion que siguiera viva.

**Para quien toque `scripts/test/functions/_emu.mjs`:** `limpiar()` borra TODOS los usuarios de Auth y las colecciones `usuarios`, `plataforma`, `restaurantes` y `pedidos`. Ampliar la lista si se siembran otras.

**Para el runbook de 11-15/11-16 (comprobacion manual):** desactivar a un mesero, intentar iniciar sesion con su cuenta (debe fallar), comprobar que sus pedidos siguen apareciendo en los reportes, y reactivarlo comprobando que recupera su rol.

**PENDIENTE DE SELLADO HUMANO:** desplegar `cambiarEstadoStaff` contra `p-gri-b5b40` (`firebase deploy --only functions`), junto con las de 11-07 y 11-08. Hasta entonces, en produccion no se puede dar de baja a nadie desde el producto.

## Self-Check: PASSED

Archivos declarados como creados — verificados en HEAD con `git cat-file -e`: `functions/src/baja-matrix.js`, `functions/test/baja-matrix.test.js`, `functions/src/cambiar-estado-staff.js`, `functions/test/cambiar-estado-staff.contrato.test.js`, `scripts/test/functions/cambiar-estado-staff.e2e.mjs`, `panel_admin/test/equipo/equipo_baja_test.dart`.

Commits declarados — verificados en `git log`: `a392812`, `ea95ed8`, `260da01` y `2ada353` (este ultimo, ajeno, contiene la Tarea 3: ver deviation 1).

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-20*
