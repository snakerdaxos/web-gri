---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 08
subsystem: cloud-functions (alta de staff con custom claims)
tags: [cloud-functions, escalada-de-privilegios, multi-tenant, anti-secuestro, idempotencia, logica-pura, e2e-emuladores]

# Dependency graph
requires:
  - plan: 11-01
    provides: codebase functions/, scripts/run_emulators.mjs, npm run test:functions
  - plan: 11-02
    provides: firebaseFunctionsProvider del panel (region us-central1)
  - plan: 11-04
    provides: "hallazgo clave — un cliente auto-registrado NO lleva claim `role`; la ausencia de rol se interpreta como cliente en firestore.rules"
  - plan: 11-05
    provides: slug canonico [a-z0-9-] del doc ID de restaurante
  - plan: 11-07
    provides: scripts/test/functions/_emu.mjs, patron de callable, glob *.e2e.mjs en test:functions
provides:
  - "functions/src/auth-matrix.js — autorizarAlta(): la matriz BLOQUEADA del usuario como logica PURA"
  - "functions/src/crear-usuario-staff.js — callable crearUsuarioStaff idempotente con anti-secuestro de 3 ramas"
  - "functions/test/auth-matrix.test.js — 27 casos sin emulador (19 de tabla + 4 de propiedad + 4 invariantes)"
  - "functions/test/crear-usuario-staff.contrato.test.js — gate REAL de no-fuga del error crudo (el del plan era ciego)"
  - "scripts/test/functions/crear-usuario-staff.e2e.mjs — 14 casos con tokens reales portando claims"
  - "_emu.mjs: llamarCrearStaff(), crearUsuarioConClaims(), crearRestaurante(); limpiar() cubre `restaurantes`"
affects: [11-09, 11-10, 11-15, 11-16, 11-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "La decision de autorizacion se aisla como modulo PURO sin imports de Firebase, para que su combinatoria completa corra en milisegundos sin emulador"
    - "El rid efectivo se DERIVA del claim del llamador, nunca del payload: el cliente no puede elegirlo aunque mienta"
    - "Anti-secuestro por correo con tres ramas, la tercera consultando el DOC ESPEJO porque los claims no bastan para detectar a un cliente"
    - "Todo caso de denegacion asserta la IDENTIDAD DEL MENSAJE, no solo el codigo: dos controles distintos que comparten codigo son indistinguibles y uno de los dos queda sin ejercitar"
    - "Un gate de grep con un punto sin escapar es decoracion: hay que probarlo contra la forma REAL de la fuga antes de confiar en el"

key-files:
  created:
    - functions/src/auth-matrix.js
    - functions/src/crear-usuario-staff.js
    - functions/test/auth-matrix.test.js
    - functions/test/crear-usuario-staff.contrato.test.js
    - scripts/test/functions/crear-usuario-staff.e2e.mjs
  modified:
    - functions/index.js
    - functions/package.json
    - scripts/test/functions/_emu.mjs

key-decisions:
  - "La prohibicion de asignar super_admin es ABSOLUTA, no relativa al rol del llamador: ni el propio super_admin puede crear otro por esta via. Cierra el vector entero en vez de dejarlo condicionado; el unico super nace de bootstrapPlataforma (11-07)"
  - "La tercera rama del anti-secuestro consulta el DOC ESPEJO, no solo los claims. Un cliente auto-registrado no tiene claim `role` (11-04), asi que una comprobacion por claims no veria nada y cualquiera que conozca el correo de un cliente podria convertirlo en su mesero"
  - "Se acepta y documenta un riesgo residual: una cuenta en Auth SIN claims y SIN doc espejo es indistinguible de un alta de staff incompleta, y se deja pasar. Cerrar ese hueco romperia la reparacion idempotente, que es la unica mitigacion de la no-atomicidad Auth/Firestore"
  - "Se anade functions/test/crear-usuario-staff.contrato.test.js porque el gate del plan para T-11-08-05 (`grep -c \"e.message\"`) es CIEGO a `err.message`, que es la forma que este codebase escribiria"
  - "Toda denegacion asserta el mensaje literal. Es lo CONTRARIO de 11-07 (donde los 5 motivos comparten texto para no ser un oraculo) y es correcto: alli el llamador podia ser un anonimo; aqui ya es staff autenticado y T-11-08-06 acepta explicitamente la enumeracion"

patterns-established:
  - "11-10 (pantalla de gestion de equipo) consume esta callable; el formulario debe exigir 8 caracteres de contrasena y su copy debe decir que reintentar con el mismo correo repara un alta incompleta"

requirements-completed: [BOOT-03]

# Metrics
duration: ~2h 14min
completed: 2026-08-19
---

# Phase 11 Plan 08: Alta de staff con custom claims Summary

**Un restaurante ya puede montar su propio equipo sin scripts ni clave de servicio: `crearUsuarioStaff` concede claims `{role, rid}` con la matriz del usuario aplicada EN EL SERVIDOR, y las dos prohibiciones absolutas estan demostradas rompiendo a proposito el control que dicen proteger — no solo afirmadas.**

## Performance

- **Duration:** ~2h 14min (incluye un reinicio por limite de sesion de la API)
- **Tasks:** 3/3
- **Files created:** 5 · **modified:** 3

## Accomplishments

- **La segunda superficie de acuñacion de privilegios de la fase, y la que hace el producto autosuficiente.** 11-07 dejo nacer al primer `super_admin` desde una pantalla; esto deja que ese super de de alta el `admin_restaurante` de un restaurante y que, a partir de ahi, ese admin gestione su propio equipo sin volver a depender de nadie.
- **La matriz vive en un modulo PURO.** `auth-matrix.js` no importa nada de Firebase (hay un test que lo verifica leyendo la fuente). Por eso su combinatoria completa —19 filas + 4 tests de propiedad— corre en **61 ms sin emulador**. Ahi es donde vive la seguridad de la matriz; el e2e prueba otra cosa: que esa decision es la que gobierna la funcion real.
- **Las dos prohibiciones absolutas estan PROBADAS, no asertadas.** Cada una se verifico quitando su control y comprobando que caen exactamente los casos correctos, en los DOS niveles (unitario y e2e con tokens reales). Detalle abajo.
- **El anti-secuestro tiene tres ramas y la tercera es la que nadie habria escrito.** Un cliente auto-registrado no lleva claim `role`, asi que mirar los claims no detecta nada: hay que consultar el doc espejo. Sin esa rama, cualquiera que conozca el correo de un cliente lo convierte en mesero de su restaurante sin consentimiento. En produccion hay hoy dos cuentas de cliente auto-registradas que estarian expuestas.
- **Se encontro un verde por el motivo equivocado con consecuencias reales** (ESCALADA HORIZONTAL) y **un gate del propio plan que era decoracion** (el `grep` de `e.message`). Los dos, corregidos y verificados rompiendolos.
- **Sin regresiones.** rules 208 → 208, functions e2e 11 → **25**, unitarios de functions 0 → **34**, `flutter analyze` 0 issues en las dos apps, `audit:indexes`, `audit:branding` y `verify:shell` verdes.

## Task Commits

| # | Tarea | Commit |
|---|---|---|
| 1 | Matriz pura `auth-matrix.js` + combinatoria de escalada (RED→GREEN) | `94f35f1` (feat) |
| 2 | Callable `crearUsuarioStaff` + export + gate real de no-fuga | `5761769` (feat) |
| 3 | e2e con tokens reales + refuerzo de las aserciones de denegacion | `b7b59a8` (test) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline previo cliente | `flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Baseline previo panel | `flutter analyze && flutter test` | `No issues found!` · `+157: All tests passed!` |
| Baseline previo rules | `npm run test:rules` | `tests 208 · pass 208 · fail 0` |
| Baseline previo functions | `npm run test:functions` | `tests 11 · pass 11 · fail 0` |
| **T1 RED** | `node --test test/auth-matrix.test.js` | `ERR_MODULE_NOT_FOUND ... functions/src/auth-matrix.js` · `pass 0 · fail 1` |
| **T1 GREEN** | `node --test test/auth-matrix.test.js` | `tests 27 · pass 27 · fail 0` · `duration_ms 61.5815` (sin emulador) |
| T2 sintaxis | `node --check src/crear-usuario-staff.js && node --check index.js` | `CHECK_OK` |
| T2 unitarios | `node --test test/*.test.js` | `tests 34 · pass 34 · fail 0` |
| T2 gate del plan | `grep -c "e.message" ... \| grep -q '^0$'` | `GATE_E_MESSAGE_OK` — **pero es ciego, ver abajo** |
| T2 gate reforzado | `grep -nE '\.message' src/crear-usuario-staff.js` | `SIN_NINGUN_.message_OK` (ni `.stack`) |
| **T3 e2e** | `npm run test:functions` | `tests 25 · suites 2 · pass 25 · fail 0` · `Script exited successfully (code 0)` |
| Rules final | `npm run test:rules` | `tests 208 · pass 208 · fail 0` |
| Indices | `npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` |
| Branding | `npm run audit:branding` | `2 apps · 4 archivos · 0 rastros de plantilla` |
| Shell de carga | `npm run verify:shell` | `OK app_cliente 1239ms · OK panel_admin 923ms` |
| Panel final | `flutter analyze && flutter test` | `No issues found!` · `+157: All tests passed!` |
| Cliente final | `flutter analyze && flutter test` | `No issues found!` · `+130: All tests passed!` |

**Conteo de pruebas.** Aportacion de ESTE plan: **+34 unitarios de functions** (no existian) y **+14 e2e** (11 → 25). Rules estables en 208.
`app_cliente` paso de 112 a **130** durante la ejecucion: **ese +18 NO es de este plan** — es de los ejecutores de 11-09 y 11-17, que corrian en paralelo. Este plan no toca ni un archivo Dart. `panel_admin` sigue en 157. Total apps 269 → 287, sin regresion.

## Verificacion por ROTURA DELIBERADA (18 roturas, todas revertidas)

Un test verde no prueba nada por si mismo. Cada control se rompio a proposito y se comprobo que caen **los casos correctos**. Tras cada bloque se verifico con `cmp` que la fuente volvia a ser byte a byte la original.

### Nivel unitario — `functions/test/*.test.js` (34 casos)

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| A | `super_admin` entra en `ROLES_ASIGNABLES` | **5**: las 2 filas ESCALADA vertical, la propiedad 1, y el invariante de la allow-list | Si |
| B | se elimina el rechazo de rid ajeno | **3**: las 2 filas ESCALADA horizontal y la propiedad 2 | Si |
| C | cualquier rol puede llamar (`ROLES_LLAMADORES` ignorado) | 4: mesero, cocina, cliente y sin-rol | Si |
| D | se normaliza el rol recibido con `toLowerCase()` | 1: `'MESERO'@demo` | Si |
| E | `SLUG_RE` laxa (`/^.+$/`) | 2: `'Demo Café'` y el invariante del slug | Si |
| F | el super_admin puede omitir `restauranteId` | 1 | Si |
| G | el admin sin rid sigue adelante (sin `failed-precondition`) | 1 | Si |
| H | fuga real del error crudo como `err.message` | **2 del gate nuevo — y el gate del PLAN pasa** (ver abajo) | Si |
| I | los claims se escriben con el `restauranteId` del payload | 1: el contrato del rid efectivo | Si |
| J | se elimina la tercera rama (cuenta de cliente) | 1: el contrato de las tres ramas | Si |

### Nivel e2e — `npm run test:functions` (14 casos de staff)

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| K | `super_admin` entra en `ROLES_ASIGNABLES` | **2**: las dos ESCALADA VERTICAL | Si |
| L | se elimina el rechazo de rid ajeno | **1**: ESCALADA HORIZONTAL | Si |
| M | `rid = restauranteId ?? decision.rid` | **0 — ver "verdes por el motivo equivocado"** | Si |
| M-bis | la callable ignora la denegacion de la matriz (se quita el `throw`) | **4**: ESCALADA HORIZONTAL, las 2 VERTICAL y el mesero llamador | Si |
| N | se elimina la rama (c) de cuenta de cliente | 1: SECUESTRO DE CLIENTE | Si |
| O | se elimina la rama (a) de plataforma | 1: PLATAFORMA | Si |
| P | se elimina la rama (b) de otro tenant | 1: SECUESTRO ENTRE TENANTS | Si |
| Q | se elimina el check de restaurante existente | 1: el caso `not-found` | Si |
| R | se elimina la recuperacion por correo ya existente | 4: IDEMPOTENCIA y los 3 de anti-secuestro | Si |
| S | **el arnes no lleva los claims al token** | 10 antes del refuerzo, **11 despues** | Si |

## Las dos prohibiciones absolutas: ¿probadas o solo asertadas?

**PROHIBICION 1 — nadie puede asignar `super_admin`: PROBADA en los dos niveles.**
Al añadir `super_admin` a `ROLES_ASIGNABLES` caen 5 casos unitarios (rotura A) y **2 casos e2e con tokens reales** (rotura K): tanto el intento de un `admin_restaurante` como el del propio `super_admin`. El test de propiedad recorre `ROLES_LLAMADORES × 4 rids de llamador × 6 rids pedidos` = 48 combinaciones y ninguna devuelve `ok`, con una asercion que impide que el bucle pase por vacuidad si alguien vaciara la lista.

**PROHIBICION 2 — un `admin_restaurante` nunca toca otro rid: PROBADA en los dos niveles, y sostenida por DOS controles independientes.**
- Control preventivo (`autorizarAlta` rechaza el rid ajeno): al quitarlo caen 3 casos unitarios (rotura B) y el caso e2e ESCALADA HORIZONTAL (rotura L).
- Control de contencion (rama (b) del anti-secuestro): al quitarlo cae SECUESTRO ENTRE TENANTS (rotura P). Este es el que impide que el admin de `otro` se apodere de una cuenta que ya es staff de `demo` **sin mandar ningun rid ajeno** — o sea, el vector que el control preventivo no ve.
- Que la callable REALMENTE consulte la matriz esta probado aparte por la rotura M-bis (caen 4 casos).
- Los casos e2e no se limitan al codigo de error: comprueban que **la victima no se movio** (claims originales intactos, `restauranteId` intacto, ni siquiera el nombre sobrescrito) y que **no queda cuenta creada** en Auth tras un rechazo.

**Matiz honesto:** la linea `const rid = decision.rid;` NO esta verificada por el e2e (rotura M: 0 caidas). No es debilidad del test — es que, dada la postcondicion de la matriz, `decision.rid` y `restauranteId ?? decision.rid` son **provablemente equivalentes** cuando la decision es `ok` (para el super, `decision.rid === ridPedido`; para el admin, `ridPedido` o es `undefined` o es igual al suyo). Lo que si la verifica es el test de contrato estatico (rotura I). Queda dicho: esa linea es **defensa en profundidad verificada estaticamente**, no por comportamiento.

## Caza de verdes por el motivo equivocado

**Encontrados dos. Los dos corregidos y la correccion verificada rompiendola.**

**1. ESCALADA HORIZONTAL estaba verde sin haber ejercitado nunca el control horizontal.**
El caso asertaba solo el codigo `functions/permission-denied`. Pero ese es **exactamente** el codigo que devuelve tambien un llamador sin rol reconocido. La rotura S lo destapo: con el arnes roto —los claims del admin no llegando al token— el caso **seguia en verde**, denegado por "no se quien eres" en vez de por "no puedes cruzar de restaurante". Un e2e escrito con el orden claims/login invertido habria dado esta suite por buena sin haber probado la prohibicion 2 ni una sola vez.
**Correccion:** el caso asserta ahora la **identidad literal del mensaje** (`'No puedes crear usuarios de otro restaurante.'`). Mismo refuerzo en las dos ESCALADA VERTICAL y en el caso del mesero llamador. **Verificacion de la correccion:** la rotura S pasa de tumbar 10 casos a tumbar **11**, y el que se suma es precisamente ESCALADA HORIZONTAL.

**2. El gate del plan para T-11-08-05 (`grep -c "e.message"`) es CIEGO a la fuga real.**
En `grep` el punto es un comodin, asi que el patron exige la letra `e` inmediatamente antes de `message`. Comprobado con los tres literales:

| Linea | `grep -c "e.message"` |
|---|---|
| `throw new HttpsError("internal", e.message);` | **1** (lo caza) |
| `throw new HttpsError("internal", err.message);` | **0** (no lo ve) |
| `throw new HttpsError("internal", err?.message);` | **0** (no lo ve) |

Y `err` es justo el nombre que usa el catch de `bootstrap-plataforma.js`, o sea el que un humano escribiria aqui. **Demostrado en vivo (rotura H):** con una fuga real de `err.message` metida en el archivo, el gate del plan **PASA**. Un gate que no puede fallar cuando el control falta es decoracion.
**Correccion:** `functions/test/crear-usuario-staff.contrato.test.js`, que rechaza `.message` y `.stack` con **cualquier** nombre de variable, ignorando comentarios. Con la rotura H puesta, cae con 2 casos.

**Tercer candidato revisado.** Los 3 supervivientes de la rotura S se auditaron uno a uno y los 3 sobreviven **con razon**: `sin autenticar` no depende de claims; `contraseña corta` valida el payload ANTES de autorizar (orden deliberado del plan); y `un mesero llamando` comparte mensaje con un llamador sin rol **por diseño** — los dos son "no eres un llamador valido" y darles textos distintos no aportaria nada. Se deja dicho: ese caso concreto no distingue mesero de sin-rol.

## Files Created/Modified

**Creados**
- `functions/src/auth-matrix.js` (157 lineas) — `autorizarAlta`, `ROLES_ASIGNABLES`, `ROLES_LLAMADORES`, `SLUG_RE`. Cabecera con la matriz, las dos prohibiciones, por que una sola callable y la regla de codigos.
- `functions/src/crear-usuario-staff.js` (251) — la callable. Cabecera con la no-atomicidad Auth/Firestore, las tres ramas del anti-secuestro y el riesgo residual aceptado.
- `functions/test/auth-matrix.test.js` (297) — 19 filas de tabla (4 marcadas `// ESCALADA`) + 4 tests de propiedad + invariantes.
- `functions/test/crear-usuario-staff.contrato.test.js` (102) — el gate real de no-fuga + 4 contratos estructurales.
- `scripts/test/functions/crear-usuario-staff.e2e.mjs` (543) — 14 casos con tokens reales.

**Modificados**
- `functions/index.js` — exporta `crearUsuarioStaff`; `initializeApp()` unico intacto; indice actualizado con `auth-matrix.js` como modulo de apoyo no desplegado.
- `functions/package.json` — `test` pasa de `node --test test/` al glob `test/*.test.js` (ver deviations).
- `scripts/test/functions/_emu.mjs` — `+llamarCrearStaff`, `+crearUsuarioConClaims`, `+crearRestaurante`; `limpiar()` cubre `restaurantes`.

## Decisions Made

- **La prohibicion de asignar `super_admin` es absoluta, no relativa al llamador.** Ni el propio super puede crear otro por esta via, y hay un caso e2e dedicado. Cierra el vector entero en vez de dejarlo condicionado a una comprobacion de rol que alguien podria relajar.
- **La tercera rama consulta el doc espejo, no los claims.** Es el unico modo de ver a un cliente auto-registrado (11-04).
- **Las denegaciones tienen mensajes DISTINTOS, al reves que en 11-07.** Alli los 5 motivos compartian texto para no ser un oraculo frente a un anonimo. Aqui el llamador ya es staff autenticado y T-11-08-06 acepta explicitamente la enumeracion, asi que un mensaje util gana; y ademas es lo que da dientes a los casos (ver verde nº1).
- **Se comprueba que el restaurante destino EXISTE antes de crear la cuenta.** Sin eso, un dedazo en el slug deja staff huerfano: claims validos para un rid inexistente, invisible en todos los paneles y sin forma de limpiarlo desde el producto.
- **`emailVerified: true` en el alta de staff.** Lo da de alta alguien autenticado que responde por esa persona; no hay flujo de verificacion de correo para el panel.
- **`maxInstances: 5`** como unico freno a la creacion masiva. App Check queda como deuda conocida (DIFERIDO, T-11-08-07).

## Deviations from Plan

**1. [Regla 3 — Bloqueante] El gate `node --test test/` del plan (y el `npm test` de functions) NO funciona en Node 24**

- **Found during:** Tarea 1, al montar el primer archivo en `functions/test/`.
- **Issue:** `node --test test/` intenta cargar el directorio como modulo: `Error: Cannot find module 'C:\...\functions\test'`, exit 1. Es exactamente el hallazgo que 11-01 registro para los scripts de `scripts/`, pero `functions/package.json` se habia quedado con la forma antigua. Falla ruidosamente (no es un falso verde), pero el gate del plan era inejecutable tal cual.
- **Fix:** `functions/package.json` pasa a `node --test test/*.test.js`, igual que hizo 11-01. El gate se ejecuto con esa forma.
- **Committed in:** `94f35f1`.

**2. [Regla 2 — Funcionalidad critica ausente] El gate de T-11-08-05 que pedia el plan no puede fallar**

- **Found during:** Tarea 2.
- **Issue:** `grep -c "e.message"` no ve `err.message` ni `err?.message`. Demostrado con los tres literales y en vivo con la rotura H. La mitigacion de una amenaza del threat model quedaba sin gate real.
- **Fix:** `functions/test/crear-usuario-staff.contrato.test.js`. Se conserva ADEMAS el gate del plan (ejecutado y verde), pero queda dicho que el que tiene dientes es el nuevo.
- **Verification:** rotura H — el gate del plan pasa, el nuevo cae con 2 casos.
- **Committed in:** `5761769`.

**3. [Regla 2 — Funcionalidad critica ausente] La asercion de ESCALADA HORIZONTAL no distinguia el control que decia probar**

- **Found during:** Tarea 3, rotura S.
- **Issue:** ver "verdes por el motivo equivocado" nº1. El caso que demuestra la prohibicion 2 del usuario podia estar verde sin ejercitarla.
- **Fix:** asercion de identidad literal del mensaje en las 4 denegaciones que comparten codigo con otro control.
- **Verification:** la rotura S pasa de 10 a 11 caidas, y la que se suma es ese caso.
- **Committed in:** `b7b59a8`.

**4. [Ampliacion, dentro de lo que el plan autoriza] `_emu.mjs` se extiende y `limpiar()` cubre `restaurantes`**

- **Issue:** `_emu.mjs` no estaba en `files_modified`, pero el plan ordena reutilizarlo y 11-07 dejo escrito el aviso de ampliar `limpiar()` si el nuevo plan sembraba otras colecciones. Sin `restaurantes` en la limpieza, un caso heredaria el restaurante del anterior y el caso `not-found` se pondria verde por el motivo equivocado.
- **Fix:** `+llamarCrearStaff`, `+crearUsuarioConClaims`, `+crearRestaurante` y `restaurantes` en `limpiar()`. `bootstrap.e2e.mjs` no usa esa coleccion, y sus 11 casos siguen verdes.
- **Committed in:** `b7b59a8`.

**5. [Discrepancia de conteo del plan, sin impacto en alcance] 19 filas, no 18; 14 casos e2e, no 9**

- **Issue:** el plan dice "18 casos" en la Tarea 1, pero su propia lista de comportamientos tiene **19** filas (una linea junta dos casos con un `·`). Igual en la Tarea 3: dice "los 9 comportamientos" y la lista enumera **11**.
- **Fix:** se implementaron **todas** las filas listadas, sin recortar ninguna. La tabla lleva una asercion `CASOS.length === 19` para que el conteo no derive en silencio. En el e2e se añadieron ademas 3 casos: el `admin` creando otro `admin` de su propio rid (es la decision BLOQUEADA del usuario y sin caso e2e quedaria solo afirmada), el super creando otro super (la prohibicion 1 desde el llamador maximo) y la contraseña de 7 caracteres (contrato con el formulario de 11-10). Total 14.

**6. [Estructural, no evitable] La Tarea 3 esta marcada `tdd="true"` pero su gate RED no existe**

- **Issue:** el plan crea la callable en la Tarea 2 y su e2e en la Tarea 3. Un RED exigiria que la implementacion no existiera, lo que contradice la secuencia del propio plan. Los 14 casos salieron **verdes en la primera ejecucion**. Es el mismo caso que 11-07 reporto en su deviation 4.
- **Fix:** se reporta tal cual, sin fabricar un RED artificial. El equivalente con dientes son las **10 roturas deliberadas** (K–S) de la tabla. La Tarea 1, que si podia, si hizo RED→GREEN (`ERR_MODULE_NOT_FOUND` → `27/27`).

**7. [Contexto de ejecucion] Reinicio por limite de sesion de la API a mitad de la Tarea 3**

- **Issue:** la ejecucion se corto con `_emu.mjs` modificado y el e2e sin seguimiento.
- **Fix:** al reanudar se verifico la integridad de los dos archivos (`node --check` en ambos, cola del archivo y presencia de las tres adiciones) antes de seguir escribiendo. Ninguno habia quedado truncado. Se ejecuto ademas 11-09 y 11-17 en paralelo en el mismo arbol: solo se stagearon archivos propios, nunca `git add -A`.

**8. [Trazabilidad] El `requirements: [BOOT-03]` del plan no existe en REQUIREMENTS.md**

- **Issue:** `.planning/REQUIREMENTS.md` no contiene ningun id `BOOT-*` (usa `PLAT-*`, `AUTH-*`, etc.). No se pudo marcar `BOOT-03` como completado porque no hay checkbox al que apuntar.
- **Fix:** no se invento ninguna entrada. El requisito que este plan satisface de hecho es **PLAT-03** ("Super-admin puede crear usuarios staff (admin restaurante, mesero, cocina) y asignarlos a un restaurante"), que ya figuraba como `[x]` desde la Fase 10 — y que hasta hoy solo era cierto **via `scripts/seed_firebase.mjs` con clave de servicio**, no desde el producto. Ahora si es cierto desde el producto, y ademas ampliado: tambien un `admin_restaurante` puede hacerlo dentro de su propio restaurante. Queda anotado para que quien reconcilie la trazabilidad decida si crear `BOOT-03` o reasignar el plan a `PLAT-03`.

---

**Total deviations:** 8 (1 bloqueante, 2 ampliaciones por funcionalidad critica ausente, 1 ampliacion autorizada, 1 de conteo del plan, 1 estructural reportada sin maquillar, 1 de contexto, 1 de trazabilidad). **Ninguna reduce alcance y ninguna asercion se relajo para poner algo en verde — dos se endurecieron.**

## Mitigaciones del threat model

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-08-01 (escalada vertical, asignar `super_admin`) | **Mitigado y verificado** | Allow-list sin `super_admin`; 2 filas ESCALADA + test de propiedad de 48 combinaciones + 2 casos e2e con token real. Roturas A (5 caidas) y K (2 caidas) |
| T-11-08-02 (escalada horizontal, admin de A creando en B) | **Mitigado y verificado** | `autorizarAlta` deriva el rid del claim; caso e2e con asercion de mensaje y comprobacion de que no queda cuenta creada. Roturas B (3), L (1) y M-bis (4) |
| T-11-08-03 (secuestro de cuenta de otro tenant o de plataforma) | **Mitigado y verificado** | Ramas (a) y (b) del paso 5; los casos e2e comprueban que los claims de la victima NO cambian. Roturas O y P (1 caida cada una) |
| T-11-08-09 (conversion no consentida de una cuenta de CLIENTE) | **Mitigado y verificado, con hueco declarado** | Rama (c) consultando el doc espejo; el e2e verifica que la victima **sigue sin claims** tras el rechazo. Rotura N lo pone en rojo. Hueco residual documentado abajo |
| T-11-08-04 (validacion de rol hecha en Flutter) | **Mitigado y verificado** | La decision vive en `auth-matrix.js`; el test de contrato falla si la callable reimplementa la matriz o si escribe el `restauranteId` del payload en los claims (rotura I) |
| T-11-08-05 (fuga del error crudo del Admin SDK) | **Mitigado y verificado — el gate del plan NO servia** | `HttpsError('internal', mensaje fijo, err?.code)`. Gate real en el test de contrato; rotura H demuestra que el gate del plan pasaba con la fuga puesta |
| T-11-08-06 (enumeracion de correos via `already-exists`) | **Aceptado (declarado)** | El llamador ya es staff autenticado. Ademas, los mensajes distintos son lo que da dientes a los casos de denegacion |
| T-11-08-07 (creacion masiva de usuarios) | **Parcial (declarado)** | `maxInstances: 5` presente en el codigo. **NO verificado**: el emulador no aplica limites de instancias. App Check DIFERIDO |
| T-11-08-08 (alta de staff sin trazabilidad) | **Mitigado, con matiz** | `logger.info('staff alta', {uid, rol, rid, por, creado})` — la salida real aparece en el log del emulador durante el e2e. El **contenido** del log no se afirma en ninguna asercion |

## Que esta VERIFICADO y que solo esta AFIRMADO

**VERIFICADO (ejecutado contra emuladores reales con tokens que portan claims reales, o contra la logica pura):**
- Que un `admin_restaurante` de `demo` crea un mesero sin mandar `restauranteId`, y que el usuario existe DE VERDAD en Auth (email, displayName) con claims `{role:'mesero', rid:'demo'}` y doc espejo coherente con `createdAt`.
- Que ese mismo admin **no puede** poner personal en `otro`, con el mensaje del control horizontal —no el de "no se quien eres"— y **sin que quede cuenta creada** en Auth.
- Que **nadie** asigna `super_admin`: ni un admin ni el propio super_admin.
- Que un super_admin con un `restauranteId` inexistente recibe `not-found` y no deja staff huerfano.
- Que un mesero no puede llamar la callable, y que una llamada anonima no crea ninguna cuenta.
- Que repetir el alta con el mismo correo converge: mismo uid, `creado: false`, **un solo** doc espejo, y el rol del segundo intento es el que queda (reparacion).
- Que el admin de `otro` **no puede apoderarse** de una cuenta que ya es staff de `demo`: claims intactos, `restauranteId` intacto y ni siquiera el nombre sobrescrito.
- Que una cuenta de cliente (sin claims, con espejo `role:'cliente'`/`restauranteId:null`) **sigue sin claims** tras el intento de convertirla en mesero.
- Que un correo de `super_admin` no se degrada, con mensaje literal `'Esa cuenta es de plataforma.'` y claims intactos.
- Que la contraseña minima del producto es 8, no el 6 de Firebase.
- Que `auth-matrix.js` no importa nada de Firebase (leyendo la fuente, no por confianza).
- Que la callable **realmente** consulta la matriz (rotura M-bis) y que ninguna linea lee `.message` ni `.stack` de un error.

**AFIRMADO, NO VERIFICADO — leer antes de confiar:**
- **`const rid = decision.rid;` no lo verifica el e2e** (rotura M: 0 caidas). Es equivalente semantico a la version "insegura" bajo la postcondicion de la matriz. Lo cubre el test de contrato estatico (rotura I).
- **El hueco residual de la rama (c):** una cuenta en Auth **sin claims Y sin doc espejo** se deja pasar, porque es indistinguible de un alta de staff incompleta. Un cliente cuyo `set()` del espejo hubiera fallado caeria ahi. No hay caso de test que lo cubra porque el comportamiento deseado ES dejarlo pasar; cerrarlo romperia la reparacion idempotente.
- **`maxInstances: 5`.** Declarado en el codigo, no ejercitado: el emulador no aplica limites.
- **El contenido del `logger.info` de auditoria.** Se emite y se ve en la salida del e2e; ninguna asercion lo comprueba.
- **El caso `un mesero llamando` no distingue mesero de sin-rol** (mismo codigo y mismo mensaje, por diseño).
- **El comportamiento contra el proyecto REAL `p-gri-b5b40`.** Todo esto corre contra `demo-gri`. **La funcion NO esta desplegada.** Hasta `firebase deploy --only functions`, el panel no puede dar de alta a nadie en produccion.
- **Que las dos cuentas de cliente auto-registradas que hoy existen en produccion queden protegidas.** La rama (c) las protege **en el codigo**; no lo estaran de hecho hasta el despliegue.
- **La experiencia de usuario del alta.** No hay pantalla todavia: llega en 11-10.

## Known Stubs

Ninguno en el codigo de este plan. La callable esta cableada de punta a punta y probada contra emuladores reales.

**Pendiente por diseño (no es stub):** no existe consumidor de esta callable todavia — la pantalla de gestion de equipo es el plan **11-10**, que ademas debe ampliar la regla de `usuarios` para que un `admin_restaurante` pueda LISTAR su equipo (hoy solo lee su propio doc o el super; anotado en 11-CONTEXT y en el caso `// AMPLIADO EN 11-10` de `usuarios.test.mjs`).

## Threat Flags

Ninguna superficie nueva fuera del `<threat_model>` del plan. La unica ampliacion es el test de contrato estatico, que no cruza ninguna frontera de confianza: lee un archivo del propio repo.

## Issues Encountered

- **La ejecucion se corto por un limite de sesion de la API** a mitad de la Tarea 3. Al reanudar se verifico la integridad de los archivos a medias antes de seguir; ninguno estaba truncado.
- **Se compartio el arbol con los ejecutores de 11-09 y 11-17.** Se stagearon exclusivamente archivos propios. El `+18` de `app_cliente` es suyo, no de este plan.
- **Cada rotura e2e cuesta un arranque de emuladores** (~40 s). Se uso un driver que corre solo `crear-usuario-staff.e2e.mjs` para acotar el ciclo.

## Next Phase Readiness

**Para 11-10 (pantalla de gestion de equipo):**
- La callable se invoca como `httpsCallable(fns, 'crearUsuarioStaff')` en `us-central1`, con `{email, password, nombre, rol, restauranteId?}` y devuelve `{uid, creado, rol, restauranteId}`.
- El formulario **debe exigir 8 caracteres** de contraseña: la funcion rechaza 7 con `invalid-argument` y hay un caso e2e que lo fija.
- El `restauranteId` es **opcional** para un `admin_restaurante` (se deriva de su claim) y **obligatorio** para un `super_admin`.
- Copy obligatorio: **"volver a crear con el mismo correo repara un alta incompleta"** — es la mitigacion de la no-atomicidad Auth/Firestore y esta probada (caso IDEMPOTENCIA).
- Codigos a traducir a mensaje de UI: `permission-denied`, `invalid-argument`, `failed-precondition`, `not-found`, `already-exists`, `unauthenticated`, `internal`.
- La UI debe **ocultar** lo que el llamador no puede hacer, pero eso es cortesia: la decision ya vive en el servidor y esta probada. Prohibido validar el rol en Flutter (decision bloqueada del usuario).

**Para quien toque `scripts/test/functions/_emu.mjs`:** `limpiar()` borra TODOS los usuarios de Auth y las colecciones `usuarios`, `plataforma` y `restaurantes`. Ampliar la lista si se siembran otras.

**PENDIENTE DE SELLADO HUMANO:** desplegar la funcion contra `p-gri-b5b40` (`firebase deploy --only functions`) junto con la de 11-07, y dar de alta un `admin_restaurante` real una vez.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `functions/src/auth-matrix.js`, `functions/src/crear-usuario-staff.js`, `functions/test/auth-matrix.test.js`, `functions/test/crear-usuario-staff.contrato.test.js`, `scripts/test/functions/crear-usuario-staff.e2e.mjs`.

Commits declarados — verificados en `git log`: `94f35f1`, `5761769`, `b7b59a8`.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
