---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 27
subsystem: firestore-rules (lectura de documentos ausentes)
tags: [firestore-rules, p0, check-then-create, bug-critico, tdd, regresion, seguridad]

# Dependency graph
requires:
  - plan: 11-04
    provides: las 7 suites por coleccion de scripts/test/rules/ (208 casos) — el andamio que se amplia aqui
  - plan: 11-15
    provides: scripts/gates.mjs — el ejecutor unico de los 9 gates y sus baselines
  - plan: 11-26
    provides: el hallazgo registrado en STATE.md que dio pie a este plan (_diag_sesion.test.mjs)
provides:
  - "firestore.rules: sesiones, pedidos y reservas permiten leer el documento AUSENTE (resource == null)"
  - "39 casos nuevos de rules, TODOS sobre la AUSENCIA del documento, repartidos por las 9 suites por coleccion"
  - "4 casos que replican la transaccion COMPLETA de abrirSesion() y crearReserva() contra el motor de rules"
  - "Auditoria escrita de las 10 colecciones: cuales tenian el defecto, cuales no, y por que no se tocan"
  - "Baseline de rules 221 -> 260 en gates.mjs, con prueba de que el gate puede fallar de las dos formas"
affects: [despliegue de firestore:rules — checkpoint humano]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toda suite de rules debe tener un bloque `read de un doc AUSENTE`: el estado vacio es el primer uso real, no un borde"
    - "El fix se escribe `signedIn() && (resource == null || <cond>)`, NUNCA `resource == null || (signedIn() && ...)`"
    - "Cada colección que se DESCARTA en una auditoria deja un test que fija su veredicto, para que el descarte caduque solo"
    - "Un flujo check-then-create se prueba con la transaccion ENTERA (runTransaction real), no con el read y el write por separado"

key-files:
  created:
    - .planning/phases/11-.../11-27-SUMMARY.md
  modified:
    - firestore.rules
    - scripts/gates.mjs
    - scripts/test/rules/sesiones.test.mjs
    - scripts/test/rules/reservas.test.mjs
    - scripts/test/rules/pedidos.test.mjs
    - scripts/test/rules/mesas.test.mjs
    - scripts/test/rules/calificaciones.test.mjs
    - scripts/test/rules/usuarios.test.mjs
    - scripts/test/rules/categorias.test.mjs
    - scripts/test/rules/productos.test.mjs
    - scripts/test/rules/restaurantes.test.mjs
  deleted:
    - scripts/test/rules/_diag_sesion.test.mjs

key-decisions:
  - "Se arreglan TRES colecciones (sesiones, reservas, pedidos), no las cinco que desreferencian resource.data. usuarios queda intacta porque el cortocircuito del || ya resuelve su unico flujo real, y ampliarla regalaria un oraculo de existencia de cuentas. categorias y productos quedan intactas porque usan autoId y solo se leen por query"
  - "El fix va DENTRO del signedIn(), no fuera. Verificado por rotura: escrito al reves, los 3 casos de anonimo se ponen en rojo"
  - "Los 4 casos de transaccion completa se añaden porque los de read y los de create por separado no habrian detectado un fix parcial"

patterns-established:
  - "Antes de dar por buena una suite de autorizacion, preguntarse: ¿algun caso lee un documento que NO se ha sembrado?"

requirements-completed: []

# Metrics
duration: ~50min
completed: 2026-08-20
---

# Phase 11 Plan 27: El estado vacio — leer documentos que aun no existen Summary

**Ningun cliente podia abrir una mesa ni crear una reserva, NUNCA, porque las rules denegaban la lectura del documento que el flujo tiene que leer antes de crearlo; se arregla en tres colecciones y se blinda con 39 casos que hablan explicitamente de la AUSENCIA del documento.**

## El bug

Una rama de `read` que desreferencia `resource.data` **deniega los documentos que no existen**. Sobre un doc ausente `resource` es `null`, la expresion revienta, y la regla evalua a denegado. El SDK devuelve `permission-denied` — indistinguible de un fallo de autorizacion real, y por eso el usuario y el equipo estuvieron mirando a la cuenta y a los claims en vez de a la ausencia del documento.

Las dos apps usan **check-then-create con doc ID determinista** en cuatro sitios: leen el documento para saber si ya existe, y solo entonces lo crean.

| Flujo | Lectura | Estado antes |
|---|---|---|
| `abrirSesion()` — `sesion_provider.dart:100` | `tx.get(sesiones/{codigoQR})` | **ROTO** |
| `crearReserva()` — `reserva_controller.dart:103` | `tx.get(reservas/{mesaId}_{fecha}_{HH})` por candidata | **ROTO** |
| `crearMesa()` — `mesas_crud.dart:35` | `tx.get(mesas/{GRI-MESA-rid-NNN})` | OK (`read: if signedIn()`) |
| `_calificar()` — `calificacion_sheet.dart:82` | `tx.get(calificaciones/{pedidoId})` | OK (`read: if true`) |

La **primera** apertura de **cualquier** mesa y la **primera** reserva de **cualquier** franja leen un documento ausente. No era un borde: era el camino principal, para todos los usuarios, siempre.

## Auditoria completa — las 10 colecciones

No se asumio que fueran solo `sesiones` y `reservas`. Se reviso cada `match` y se cruzo con cada `getDoc`/`tx.get` por id de las dos apps (`grep` exhaustivo sobre `.doc(` en `app_cliente/lib` y `panel_admin/lib`).

| Coleccion | Rama de read | ¿Desreferencia? | Veredicto | Test que lo fija |
|---|---|---|---|---|
| **sesiones** | `signedIn() && (resource.data.usuarioId == uid \|\| staffOf(...) \|\| isSuper())` | **SI, primero** | **ARREGLADA** — P0 | 7 + 2 e2e |
| **reservas** | idem | **SI, primero** | **ARREGLADA** — P0 | 7 + 2 e2e |
| **pedidos** | idem | **SI, primero** | **ARREGLADA** — latente | 6 |
| **usuarios** | `signedIn() && (uid propio \|\| isSuper() \|\| (admin && resource.data.restauranteId == rid()))` | SI, pero **tras dos `\|\|`** | **NO se toca** | 5 |
| **categorias** | `resource.data.activo == true \|\| menuStaffOf(resource.data.restauranteId)` | **SI** | **NO se toca** | 2 |
| **productos** | idem + `disponible` | **SI** | **NO se toca** | 2 |
| **mesas** | `signedIn()` | NO | **Limpia** — y de ello viven 2 flujos | 3 |
| **calificaciones** | `true` | NO | **Limpia** — pero por motivo fragil | 2 |
| **restaurantes** | `true` | NO | **Limpia** | 1 |
| **plataforma** | `false` | NO | Denegado a proposito (11-07) | ya cubierto |

### Por que `usuarios` NO se toca (y no es un descuido)

La desreferencia esta a la **derecha de dos `||`**, y el motor de rules cortocircuita:

```
signedIn() && (request.auth.uid == uid || isSuper() || (admin && resource.data...))
```

El unico flujo real que lee `usuarios/{uid}` por id es el auto-registro (`auth_controller.dart:164`), que lee **su propio** doc antes de crearlo: `request.auth.uid == uid` corta antes de llegar a la desreferencia. **Verificado, no razonado**: el caso "el RECIEN REGISTRADO puede leer su propio doc antes de que exista" pasa hoy, sin tocar la regla.

Añadirle `resource == null` concederia a cualquier `admin_restaurante` un **oraculo de existencia de cuentas** (¿tiene perfil este uid?) que ningun flujo pide — el panel lista el equipo con una **query**, no con gets por uid. Se deja como esta, con 5 casos que fijan el cortocircuito **como contrato**: si alguien reordena la disyuncion, se ponen en rojo.

### Por que `categorias` y `productos` NO se tocan

Su read **si** desreferencia y **si** deniega el doc ausente — pero nada depende de ello:

- Los ids son **autoId** (`collection('categorias').add(...)`, `menu_provider.dart:126` y `:163`), no deterministas: no hay ni puede haber check-then-create.
- El menu se lee **siempre por query**, y las rules de `list` se evaluan **por documento devuelto**: una query sin resultados no desreferencia nada. Se afirma con un caso que hace la query real filtrada por un restaurante inexistente y comprueba `size == 0`.

Se deja un test que fija el veredicto denegado y explica por que es inocuo, para que el dia que alguien escriba un `getDoc('categorias/{id}')` tenga el aviso delante.

### Un hallazgo colateral en `pedidos`

`pedidos` no tenia check-then-create, pero **si tenia codigo inalcanzable que dependia de leer el hueco**: la rama

```dart
if (!pedidoSnap.exists) throw const CalificacionException('Pedido no encontrado');
```

de `_calificar()` (`calificacion_sheet.dart:60-63`) **no podia ejecutarse nunca**: el `tx.get` moria antes con `permission-denied` y el usuario veia el mensaje generico. Lo mismo le pasaba al `tx.get(sesiones/{sesionId})` de la linea 75. Se arregla junto a las otras dos porque es el mismo defecto, y dejarlo seria dejar la tercera cabeza esperando a que alguien escriba el primer `db.doc('pedidos/$id').snapshots()`.

## El cambio

Tres ramas de `read`, identicas:

```diff
-      allow read: if signedIn() && (resource.data.usuarioId == request.auth.uid
+      allow read: if signedIn() && (resource == null
+                  || resource.data.usuarioId == request.auth.uid
                   || staffOf(resource.data.restauranteId) || isSuper());
```

Mas una **nota transversal** en la cabecera del archivo que explica el modo de fallo, lista los cuatro check-then-create y fija la forma correcta del fix.

### Que concede EXACTAMENTE que antes no concedia

Un usuario **autenticado** puede aprender que un documento con un id dado **no existe**. Nada mas. El contenido sigue exactamente igual de protegido (dueño | staff del tenant | super).

| Coleccion | Lo que se filtra | Por que es aceptable |
|---|---|---|
| `sesiones` | "no hay sesion abierta en la mesa X" | El id **es** el codigo impreso en el QR de la mesa. La ocupacion se observa fisicamente desde la puerta |
| `reservas` | "esa franja esta libre" | Es la disponibilidad que cualquier sistema de reservas publica por diseño. Es literalmente lo que el flujo esta preguntando |
| `pedidos` | "ese id de pedido no existe" | Los ids son autoId de 20 caracteres aleatorios: no enumerable, no revela nada |

### Que NO concede

El **anonimo sigue fuera**. El `signedIn()` envuelve la disyuncion; no esta dentro de ella. Escrito al reves (`resource == null || (signedIn() && ...)`) los anonimos podrian sondear las tres colecciones. **Hay un caso por coleccion que lo vigila y esta demostrado que se pone en rojo** (rotura D).

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| **RED** | `cd scripts && npm run test:rules` (rules sin tocar) | `tests 256 · pass 245 · fail 11` · **exit 1**. Los 11 rojos: sesiones(4) + reservas(4) + pedidos(3) |
| **GREEN** | idem, tras el fix | `tests 256 · suites 47 · pass 256 · fail 0` · **exit 0** |
| **GREEN + e2e** | idem, tras añadir las transacciones completas | `tests 260 · suites 49 · pass 260 · fail 0` · **exit 0** |
| **Gates completos** | `cd scripts && npm run gates` | **9 gates · 9 OK · 0 fallos · 1.7 min · exit 0** |

Detalle de la pasada de gates:

```
 app_cliente: flutter test              OK     345       345 = baseline
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     445       445 (baseline 423, +22)
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     260       260 = baseline
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0
```

**Conteos: rules 221 -> 260 (+39). app_cliente 345, panel_admin 445, functions 149 + 50 e2e — sin cambio. Ninguno baja.**

## Verificacion por rotura deliberada (7 roturas, todas revertidas)

Un `assertSucceeds` en verde no es evidencia por si solo. Cada afirmacion importante se comprobo **rompiendo la regla que la sostiene**.

| # | Rotura aplicada | Resultado | Que demuestra |
|---|---|---|---|
| **A** | revertir SOLO `sesiones` al bug | `pass 252 · fail 4` — los 4 casos de sesion ausente | Los casos de `sesiones` detectan el bug, y **solo** los de sesiones |
| **B** | revertir SOLO `reservas` | `pass 252 · fail 4` — los 4 del slot ausente | idem para reservas |
| **C** | revertir SOLO `pedidos` | `pass 253 · fail 3` | idem para pedidos |
| **D** | escribir el fix **al reves**: `resource == null \|\| (signedIn() && ...)` en las 3 | `pass 253 · fail 3` — **los 3 casos de ANONIMO** | **La rotura mas importante.** Los 3 casos de anonimo estaban en verde ANTES del fix por la razon EQUIVOCADA (les denegaba el null-deref, no el `signedIn()`). Esta rotura prueba que ahora estan en verde por la razon correcta y que detectan la puerta que el fix podria haber abierto |
| **E** | `resource == null` -> `true` (read abierto de par en par) | `pass 244 · fail 12` | Las 6 aserciones de autorizacion preexistentes **y** las 6 nuevas de "en cuanto EXISTE, denegado" son portantes. El fix no puede degenerar en un read abierto sin que 12 casos griten |
| **F** | quitar `r == rid()` de `staffOf` / `menuStaffOf` / `cocinaStaffOf` (vector cross-tenant de 11-04) | `pass 239 · fail 17` en **6 colecciones** | El vector de escalada cross-tenant sigue vigilado **despues** del cambio. Eran 12 rojos en 11-04; ahora son **17** — los 5 extra son casos nuevos de este plan, asi que la red se hizo mas tupida, no mas laxa |
| **G** | revertir las 3 ramas al bug original, con los e2e ya escritos | `pass 247 · fail 13` — incluidos **los 2 casos de transaccion completa** | La prueba mas fuerte: la transaccion EXACTA de `abrirSesion()` y la de `crearReserva()` **fallan** con las rules viejas y **pasan** con las nuevas |

`git status --short firestore.rules` **vacio** tras las 7 roturas: ninguna sobrevive al plan.

### El gate puede fallar (comprobado, no supuesto)

Trece planes de esta fase enviaron un `<verify>` incapaz de fallar. El de este se probo de las **dos** formas en que puede fallar:

```
· rules revertidas al bug:   scripts: npm run test:rules  FALLO  255  5 test(s) en rojo
· borrando UN test:          scripts: npm run test:rules  FALLO  259  REGRESION: 259 tests < baseline 260
```

Por eso el baseline sube a 260 en el mismo trabajo: sin subirlo, los 39 casos nuevos se podrian borrar sin que nadie se entere.

## Los 39 casos nuevos

| Suite | Casos | Que afirman |
|---|---|---|
| `sesiones.test.mjs` | **9** | 7 de lectura del hueco (cliente, id inventado, mesero, adminOtro, anonimo denegado, y 2 de "cuando EXISTE vuelve a estar denegado") + **2 de la transaccion completa de abrirSesion()** |
| `reservas.test.mjs` | **9** | 7 de lectura del slot libre (incluido el sondeo de la 2ª candidata, que es el bucle de asignacion automatica) + **2 de la transaccion completa de crearReserva()** |
| `pedidos.test.mjs` | **6** | Hueco legible por cliente/cocina/adminOtro, anonimo denegado, y los 2 de "cuando EXISTE, denegado" |
| `usuarios.test.mjs` | **5** | El cortocircuito del `\|\|` como contrato: propio uid ausente OK, super OK, admin/otro-cliente/anonimo DENEGADOS |
| `mesas.test.mjs` | **3** | Mesa ausente legible por admin (de ahi vive `crearMesa()`) y por cliente (de ahi vive el mensaje "esa mesa no existe" del QR); anonimo denegado |
| `calificaciones.test.mjs` | **2** | El 1:1 de `_calificar()` sobre un doc que aun no existe |
| `categorias.test.mjs` | **2** | Veredicto denegado fijado + la query vacia si pasa |
| `productos.test.mjs` | **2** | idem |
| `restaurantes.test.mjs` | **1** | Ficha inexistente legible (de ahi vive el agregado `califProm` de `_calificar()`) |

`scripts/test/rules/_diag_sesion.test.mjs` **eliminado**: sus 2 casos viven ahora en `sesiones.test.mjs` y `reservas.test.mjs`, con `initEnv(namespace)` propio y el contexto de por que existen. Con eso se cierra el punto que STATE.md marcaba como **"11-26 BLOQUEA EL CIERRE LIMPIO DE LA FASE"**.

## Por que la suite de 11-04 no lo vio

11-04 escribio 190 casos correctisimos sobre **el contenido** de los documentos: quien puede leer el doc de quien, que transicion es legal, que campo se puede tocar. **Los 221 casos siembran el documento en el `beforeEach` antes de leerlo.** El estado vacio — que es el primer estado de todo documento y el que ve el primer usuario de cada mesa y de cada franja — no lo ejercitaba ni uno.

No fue un descuido de redaccion: fue una **categoria de caso que no estaba en el mapa**. La leccion es concreta y esta convertida en patron: *toda suite de autorizacion necesita un bloque que lea documentos que NO se han sembrado.*

Es el mismo modo de fallo de la Fase 10 con otro disfraz: tests verdes que prueban el camino que el autor tenia en la cabeza, no el que recorre el usuario.

## Commits

| # | Commit | Que |
|---|---|---|
| 1 | `a535055` | **RED** — 35 casos de lectura de docs ausentes en las 9 suites; borrado del diagnostico. `256 · pass 245 · fail 11` |
| 2 | `2fd1f40` | **GREEN** — `resource == null` en sesiones, reservas y pedidos + nota transversal. `256 · pass 256 · fail 0` |
| 3 | `3fd649d` | **e2e** — las 4 transacciones completas de abrirSesion() y crearReserva(). `260 · pass 260 · fail 0` |
| 4 | `32d1047` | baseline de rules `221 -> 260` en `gates.mjs`, con la prueba de que el gate puede fallar |

## Desviaciones

**1. [Regla 2] Se añaden 4 casos de transaccion COMPLETA que el diagnostico no pedia**
- **Encontrado en:** la verificacion, tras el GREEN.
- **Problema:** los casos de `read` y los de `create` estaban probados por separado. La app hace las dos cosas en la MISMA transaccion. Un fix parcial habria dejado el flujo roto y la suite en verde — exactamente el modo de fallo que este plan existe para cerrar.
- **Arreglo:** `runTransaction` real replicando paso a paso `_abrirSesion()` y `_crearReserva()`, con `assert.equal(snap.exists(), false)` sobre el doc ausente.
- **Verificado:** rotura G los pone en rojo.
- **Commit:** `3fd649d`

**2. [Regla 2] Se añaden 15 casos a colecciones que la auditoria DESCARTO**
- **Problema:** un descarte razonado en un SUMMARY caduca en cuanto alguien toca la regla. `mesas` esta limpia hoy porque su read es `if signedIn()`; el dia que alguien lo acote por tenant, `crearMesa()` y el mensaje "esa mesa no existe" del QR se rompen en silencio.
- **Arreglo:** cada coleccion descartada deja un test que fija su veredicto y explica de que flujo depende.
- **Commit:** `a535055`

**3. [Regla 2] Se sube el baseline de rules a 260**
- **Problema:** el gate solo falla si el conteo BAJA respecto al baseline. Con el baseline en 221, los 39 casos nuevos se podian borrar enteros sin que el gate se enterara.
- **Arreglo:** `221 -> 260` en `gates.mjs`, y se comprueba que el gate detecta el borrado de un solo test.
- **Commit:** `32d1047`

**Ninguna desviacion reduce alcance.**

## Hallazgos que NO se corrigen aqui (se reportan, no se silencian)

1. **El baseline de `panel_admin` en `gates.mjs` esta desactualizado: 423 frente a 445 reales.** Lo dejo asi 11-26 (+22 tests sin subir el baseline en el mismo commit, contra lo que pide el aviso de STATE.md). Consecuencia: **22 tests de `panel_admin` se pueden borrar hoy sin que el gate falle.** No se toca porque es el libro mayor de otro plan; **lo debe subir quien cierre 11-26**.
2. **`calificaciones` esta limpia por un motivo fragil.** Su `read: if true` no desreferencia nada simplemente porque no condiciona nada. Cualquier endurecimiento futuro (p.ej. acotar por `usuarioId`) rompe el check del 1:1 de `_calificar()`. Queda un test que lo detecta.
3. **`categorias` y `productos` siguen denegando el doc ausente.** Es inocuo HOY (autoId + solo queries). El primer `getDoc` por id que alguien escriba sobre ellas fallara con `permission-denied`. El test lo dice por escrito.
4. **`usuarios` deniega el doc ausente a `admin_restaurante` y a otros clientes.** Es el veredicto deseado (no dar un oraculo de existencia de cuentas), y ahora esta fijado por escrito en vez de ser un efecto lateral no documentado.

## Que queda VERIFICADO y que NO

### Verificado de verdad (automatizado, contra el motor de rules real del emulador)

- **El bug existia y esta corregido.** Medido: 11 casos en rojo antes, 0 despues, con `firestore.rules` cargado desde el repo en el evaluador real — el mismo que corre en produccion, no un mock.
- **La transaccion exacta de `abrirSesion()` y la de `crearReserva()` pasan.** No es una inferencia desde los casos de read: son las dos transacciones replicadas paso a paso, y **fallan** si se revierte la regla (rotura G).
- **Lo que antes estaba denegado por autorizacion real sigue denegado.** Probado en las dos direcciones: (a) los 6 casos nuevos "en cuanto el doc EXISTE, otro cliente / el admin de otro tenant vuelven a estar DENEGADOS" estan en verde; (b) la rotura E, que abre el read de par en par, pone **12** de esas aserciones en rojo — las 6 preexistentes y las 6 nuevas.
- **El anonimo sigue fuera de las tres colecciones**, y esa afirmacion no es un verde por la razon equivocada: la rotura D la pone en rojo.
- **El vector de escalada cross-tenant sigue vigilado tras el cambio:** rotura F -> 17 rojos en 6 colecciones (eran 12 en 11-04; los 5 extra son casos de este plan).
- **Los 221 casos preexistentes siguen todos en verde.** El modelo de autorizacion no se ha movido.
- **El gate puede fallar**, comprobado de las dos formas (test en rojo y test borrado).

### NO verificado — y hay que decirlo

- ⚠️ **Nada de esto prueba que las rules DESPLEGADAS en `p-gri-b5b40` sean estas.** El emulador carga el fichero del repo. **El bug sigue vivo en produccion hasta que se ejecute `firebase deploy --only firestore:rules`.** Es el checkpoint humano; este plan NO despliega por indicacion expresa.
- ⚠️ **No se ha reproducido el incidente contra el proyecto real.** El diagnostico (cuenta `daxossnaker@gmail.com` sin claims, `GRI-MESA-demo-001` disponible en rid `demo`) se recibio ya confirmado y se tomo como especificacion. Lo que este plan demuestra es que **el modo de fallo descrito es real en el motor de rules** y que la regla corregida lo elimina. La confirmacion de que el sintoma del usuario desaparece exige el despliegue y una prueba en el dispositivo.
- ⚠️ **`fake_cloud_firestore` no tiene motor de rules.** Los 790 tests de las dos apps Flutter no habrian detectado esto ni lo detectarian si volviera. La unica prueba de autorizacion del repo sigue siendo `npm run test:rules`.
- ⚠️ **No se ha probado el flujo de `pedidos` que motiva su arreglo.** `pedidos` se corrige por simetria y por el codigo inalcanzable de `_calificar()`; no hay hoy un `db.doc('pedidos/$id').get()` en produccion que estuviera fallando. Es prevencion documentada, no la reparacion de un sintoma observado.
- ⚠️ **`npm run verify:shell` no se ejecuto** (exige `flutter build web --release` en las dos apps). Este plan no toca UI ni assets.

## Self-Check: PASSED

- `firestore.rules` — 3 ramas con `resource == null`, verificado con `grep` (lineas 238, 272, 318).
- `scripts/test/rules/_diag_sesion.test.mjs` — **ausente**, verificado con `ls`.
- Commits `a535055`, `2fd1f40`, `3fd649d`, `32d1047` — presentes en `git log`.
- `git status --short firestore.rules scripts/test/rules/` — **vacio**: ninguna de las 7 roturas sobrevive.
- `npm run gates` — 9/9 OK, exit 0.
