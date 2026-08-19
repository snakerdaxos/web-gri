---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 04
subsystem: firestore-rules (capa de autorización completa)
tags: [firestore-rules, seguridad, escalada-de-privilegios, multi-tenant, maquina-de-estados, default-deny, node-test]

# Dependency graph
requires:
  - plan: 11-01
    provides: scripts/run_emulators.mjs, scripts/test/rules/_contexts.mjs, npm run test:rules
  - plan: 11-03
    provides: initEnv(namespace) — aislamiento por archivo de test (contrato ampliado)
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: firestore.rules
provides:
  - "7 suites de rules nuevas (mesas, sesiones, pedidos, reservas, calificaciones, usuarios, restaurantes) — 190 casos contra el emulador con las rules reales"
  - "Los 3 vectores de escalada de la fase con test dedicado Y verificado rompiendo la regla a propósito"
  - "Test de default-deny sobre plataforma/bootstrap escrito ANTES de que exista el match (contrato para 11-07)"
  - "Baseline de rules: 18 → 208 tests vía `cd scripts && npm run test:rules`"
affects: [11-07, 11-08, 11-10, 11-15, 11-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Todo gate de seguridad se verifica ROMPIENDO la regla que protege y comprobando que la suite se pone en rojo por los casos correctos"
    - "Un test que no puede fallar no es un test: los bordes se aíslan con fixtures dedicados (mesa de capacidad 30 para el tope de 20 personas)"
    - "Los casos de escalada se marcan con // ESCALADA para localizarlos en auditoría"
    - "Los cambios de veredicto previstos para un plan futuro se marcan // AMPLIADO EN <plan>"
    - "Un test de default-deny se escribe ANTES de que el match exista: pasa por el default y debe seguir pasando con la regla explícita"

key-files:
  created:
    - scripts/test/rules/mesas.test.mjs
    - scripts/test/rules/sesiones.test.mjs
    - scripts/test/rules/pedidos.test.mjs
    - scripts/test/rules/reservas.test.mjs
    - scripts/test/rules/calificaciones.test.mjs
    - scripts/test/rules/usuarios.test.mjs
    - scripts/test/rules/restaurantes.test.mjs
  modified: []

key-decisions:
  - "Cero cambios en firestore.rules: las 5 roturas deliberadas se aplicaron y revirtieron dentro del propio plan, y `git diff firestore.rules` queda vacío. Este plan escribe evidencia, no corrige la capa de autorización"
  - "El tope de 20 comensales se prueba sobre una mesa de capacidad 30: sobre la de 4 el caso habría pasado por la capacidad, no por el tope — un verde por la razón equivocada"
  - "Se añaden los casos de borde PERMITIDOS (50 items, 20 personas, 1 estrella) además de los denegados: sin ellos un `<=` convertido en `<` pasaría desapercibido"
  - "Los veredictos sobre super_admin (no cierra sesiones, no cancela reservas, no edita perfiles ajenos) se fijan por escrito porque son asimetrías reales de las rules, no descuidos del test"

patterns-established:
  - "Cualquier plan que toque firestore.rules debe correr `cd scripts && npm run test:rules` en el MISMO commit"
  - "11-07 debe mantener en verde el bloque 'colecciones no declaradas — default deny' de restaurantes.test.mjs al añadir el match de plataforma/"
  - "11-10 debe cambiar conscientemente el veredicto del caso // AMPLIADO EN 11-10 de usuarios.test.mjs"

requirements-completed: [TEST-01]

# Metrics
duration: ~13min
completed: 2026-08-19
---

# Phase 11 Plan 04: Suite completa de firestore.rules Summary

**La capa de autorización de GRI deja de depender de la lectura humana: las 9 colecciones tienen ahora 208 aserciones ejecutables contra el motor de rules del emulador, y los tres vectores de escalada de la fase están probados rompiendo a propósito la regla que los detiene.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-08-19T16:14:50Z
- **Completed:** 2026-08-19T16:28:17Z
- **Tasks:** 3/3
- **Files created:** 7 (2.303 líneas de test)

## Accomplishments

- **Cerrado el agujero de cobertura de la capa de autorización.** `firestore.rules` ES la autorización de GRI —no hay backend— y 7 de sus 9 `match` no tenían ni un test. Ahora hay 190 casos nuevos, uno por rama de cada regla.
- **Los tres vectores de escalada están probados, y las pruebas están probadas.** No basta con que un `assertFails` esté en verde: un test que pasa por construcción fabrica confianza falsa, que es exactamente cómo llegaron a producción tres bugs críticos en la Fase 10 detrás de 175 tests verdes. Por eso cada vector se verificó **rompiendo la regla que lo protege** y comprobando que la suite se pone en rojo por los casos correctos (5 roturas, todas revertidas).
- **Escalada vertical (`usuarios/{uid}`) documentada por primera vez.** Es el único documento que un cliente recién registrado escribe sobre sí mismo: sin la regla, cualquiera se da de alta como `admin_restaurante` desde la pantalla de registro del móvil. 10 marcas `// ESCALADA` en el archivo.
- **Matriz rol × transición de cocina fijada.** "El mesero puede servir pero no aceptar" solo existía dentro de la regla: `fake_cloud_firestore` no tiene motor de rules, así que ningún test de Flutter lo notaría si desapareciera.
- **Contrato adelantado para 11-07.** El bloque de default-deny sobre `plataforma/bootstrap` está escrito **antes** de que el documento y su `match` existan: hoy pasa por el default deny de Firestore y debe seguir pasando cuando 11-07 añada la regla explícita. Si se pone en rojo, es que el centinela del bootstrap quedó escribible desde el SDK cliente.
- **Sin regresiones:** rules 18 → 208, app_cliente 96, panel_admin 96, `flutter analyze` 0 issues en ambas. **`git diff firestore.rules` vacío** — este plan no toca la capa que prueba.

## Task Commits

| # | Tarea | Archivos | Casos | Commit |
|---|---|---|---|---|
| 1 | Rules de mesas y sesiones | `mesas.test.mjs`, `sesiones.test.mjs` | 55 | `0d2cafc` |
| 2 | Rules de pedidos, reservas y calificaciones | `pedidos.test.mjs`, `reservas.test.mjs`, `calificaciones.test.mjs` | 84 | `a0828f0` |
| 3 | Rules de usuarios y restaurantes + default deny | `usuarios.test.mjs`, `restaurantes.test.mjs` | 51 | `4825e26` |

No hay ciclo RED→GREEN: como en la Tarea 1 de 11-03, estas suites son **evidencia** sobre reglas que ya eran correctas, no la corrección de un defecto. El equivalente al gate RED es la verificación por rotura deliberada de la tabla siguiente.

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| **T1** | `node run_emulators.mjs --only firestore --project demo-gri -- node --test … mesas sesiones` | `tests 55 · suites 12 · pass 55 · fail 0` · `duration_ms 4061.2` · **exit 0** |
| **T1 rotura A** | quitar `transMesa(...)` de la rama staff de mesas | `tests 26 · pass 24 · fail 2` → `MESERO: disponible→limpieza …` y `MESERO: ocupada→disponible …`. Rules restauradas |
| **T2** | `node run_emulators.mjs … -- node --test … pedidos reservas calificaciones` | `tests 84 · suites 14 · pass 84 · fail 0` · **exit 0** |
| **T2 rotura B** | quitar el chequeo de rol de `enviado→aceptado\|rechazado` | `tests 36 · pass 34 · fail 2` → los 2 casos `MESERO … ESCALADA`. Rules restauradas |
| **T2 rotura C** | quitar el `get()` de `sesiones/{sesionId}.usuarioId == request.auth.uid` | `tests 36 · pass 35 · fail 1` → `CLIENTE usando el sesionId de OTRA persona … ESCALADA (anti-spoofing)`. Rules restauradas |
| **T3** | `node run_emulators.mjs … -- node --test … usuarios restaurantes` | `tests 51 · suites 11 · pass 51 · fail 0` · **exit 0** |
| **T3 rotura D** | quitar `role == 'cliente' && restauranteId == null` del create de usuarios | `tests 22 · pass 18 · fail 4` → los 4 casos `// ESCALADA` de auto-registro (admin_restaurante, super_admin, mesero, rid falso). Rules restauradas |
| **T3 rotura E** | quitar `hasOnly(['nombre'])` del update de usuarios | `tests 22 · pass 18 · fail 4` → auto-ascenso a admin, auto-asignación de rid, colar role junto al nombre, cambio de email. Rules restauradas |
| **Rotura F (cross-tenant, suite COMPLETA)** | quitar `r == rid()` de `staffOf`, `menuStaffOf` y `cocinaStaffOf` | `tests 208 · pass 196 · fail 12` en **6 colecciones** (mesas ×3, sesiones ×2, pedidos ×2, reservas ×2, categorias ×1, productos ×2). Rules restauradas |
| **Verificación final** | `cd scripts && npm run test:rules` | `tests 208 · suites 40 · pass 208 · fail 0` · `duration_ms 12106.2` · **exit 0** |
| Verificación final — en PARALELO | `node --test scripts/test/rules/*.test.mjs` (sin `--test-concurrency=1`) | `tests 208 · pass 208 · fail 0` — el aislamiento por namespace de 11-03 aguanta con 10 archivos |
| Conteo de archivos | `ls scripts/test/rules/*.test.mjs \| wc -l` | `10` (smoke + 9 colecciones) — lo que pide `<verification>` |
| No regresión — índices | `cd scripts && npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` · **exit 0** |
| No regresión — app_cliente | `flutter analyze` + `flutter test` | `No issues found! (ran in 3.6s)` · `00:04 +96: All tests passed!` |
| No regresión — panel_admin | `flutter analyze` + `flutter test` | `No issues found! (ran in 3.1s)` · `00:05 +96: All tests passed!` |
| Integridad de las rules | `git diff --name-only firestore.rules` | **vacío** tras las 6 roturas — ninguna sobrevive al plan |

**Conteo: rules 18 → 208 (+190). Apps 192 (96 + 96), sin cambio. Ninguna bajó.**

## Files Created

| Archivo | Casos | Líneas | Qué prueba |
|---|---|---|---|
| `scripts/test/rules/mesas.test.mjs` | 26 | 318 | Las 5 ramas del match. Máquina de estados `transMesa` como regla de servidor, no de Dart. `soloEstado()` como cortafuegos del cambio de estado |
| `scripts/test/rules/sesiones.test.mjs` | 29 | 340 | `create` con `get()` sobre la mesa del mismo doc ID, anti-suplantación de `usuarioId`, `set()` sobre sesión cerrada = update denegado, `delete` prohibido incluso al super_admin |
| `scripts/test/rules/pedidos.test.mjs` | 36 | 423 | **Anti-spoofing de sesión** y **matriz rol × transición** completa, más los límites de `items` (1..50) y `total is int >= 0` |
| `scripts/test/rules/reservas.test.mjs` | 27 | 351 | `fecha > request.time` con `Timestamp` real, capacidad releída del servidor, tope duro de 20 aislado con una mesa de capacidad 30, cancelación por dueño vs. no-show por staff |
| `scripts/test/rules/calificaciones.test.mjs` | 21 | 324 | La cadena `calificación → pedido → sesión` con el `get()` anidado, sembrada por `sembrarCadenaCalificable()`. Inmutabilidad probada también contra el admin del restaurante |
| `scripts/test/rules/usuarios.test.mjs` | 22 | 262 | **Escalada vertical**: 10 marcas `// ESCALADA`. Auto-registro y auto-ascenso. Caso `// AMPLIADO EN 11-10` |
| `scripts/test/rules/restaurantes.test.mjs` | 29 | 285 | `create`/`delete` exclusivos del super, las dos ramas de `update` acotadas al milímetro, y el **default deny** de `plataforma/bootstrap` desde los 4 roles |

Los 7 importan `./_contexts.mjs` y llaman `initEnv('<namespace>')` con su propio sufijo, como exige el contrato de 11-03.

## Decisions Made

- **El tope de 20 comensales se prueba sobre una mesa de capacidad 30.** Sobre la mesa de capacidad 4 del fixture, el caso `numPersonas: 21` habría sido denegado **por la capacidad**, no por el tope de negocio: verde por la razón equivocada, y borrar el `numPersonas <= 20` de la regla no lo habría puesto en rojo. La mesa grande aísla el límite que se quiere probar.
- **Se añaden los bordes PERMITIDOS, no solo los denegados** (50 items, 20 personas, 1 estrella). Un `<=` convertido en `<` no rompe ningún `assertFails` — solo lo detecta un caso que afirma que el borde exacto está permitido.
- **Cero cambios en `firestore.rules`.** Las roturas deliberadas se aplican sobre copia de seguridad y se revierten en el mismo paso; `git diff` del fichero queda vacío y se comprobó explícitamente tras cada una. Este plan produce evidencia; corregir la capa no era su alcance y no hizo falta.
- **Los veredictos sobre el `super_admin` se fijan por escrito.** No cierra sesiones, no cancela reservas y no edita perfiles ajenos, porque esas ramas usan `staffOf()`/`request.auth.uid == uid` y el super no tiene `rid`. Es una asimetría real de las rules (en `pedidos` sí está contemplado con `isSuper()`); dejarla sin test la habría hecho invisible. Ver Hallazgos.
- **El bloque de default deny va en `restaurantes.test.mjs`**, como pide el plan, y se generaliza con un caso extra sobre una colección inventada: lo que se afirma no es solo "el centinela está cerrado" sino "nada fuera de los 9 `match` es escribible desde el SDK cliente".

## Deviations from Plan

Ninguna desviación de alcance. Ninguna tarea reducida. Tres ajustes de **integridad de los tests**, todos hacia arriba:

**1. [Regla 2 — corrección necesaria] El caso `numPersonas: 21` del plan pasaba por construcción**
- **Found during:** Tarea 2 (`reservas`)
- **Issue:** El `<behavior>` pide "`numPersonas` 0 o 21 → DENEGADO" con el mismo fixture que el resto. Con la mesa de capacidad 4, el 21 lo deniega la comparación contra la capacidad, no el tope de 20: el test estaría verde aunque el tope no existiera en la regla.
- **Fix:** Fixture extra `GRI-MESA-demo-020` con `capacidad: 30`, y el caso de 21 se ejecuta sobre ella. Se añade además el borde permitido (20 sobre capacidad 30).
- **Committed in:** `a0828f0`

**2. [Regla 2] Faltaban los bordes permitidos de los límites numéricos**
- **Found during:** Tareas 2
- **Issue:** El plan enumera solo los rechazos (`items: []`, 51 items, `estrellas` 0 o 6). Un `<=` cambiado por `<` no rompe ninguno.
- **Fix:** Añadidos `items` con exactamente 50 → PERMITIDO, `numPersonas` 20 → PERMITIDO, `estrellas` 1 → PERMITIDO.
- **Committed in:** `a0828f0`

**3. [Regla 2] Verificación por rotura deliberada de los tres vectores**
- **Found during:** las tres tareas
- **Issue:** El plan pide los tests; no pide demostrar que detectan algo. Dado el precedente de la Fase 10 (3 bugs críticos detrás de 175 tests verdes), un `assertFails` en verde no es evidencia por sí solo.
- **Fix:** 6 roturas deliberadas de `firestore.rules` (tabla de gates), cada una revertida y comprobada con `git diff` vacío.
- **Committed in:** documentado aquí; no altera ningún fichero versionado.

### Aclaraciones de interpretación (sin cambio de alcance)

**4. "Cada `allow` tiene un test que lo permite y otro que lo deniega" no es alcanzable para las ramas incondicionales.** `allow read: if true` (`restaurantes`, `calificaciones`) no admite un caso denegado, y `allow delete: if false` (`usuarios`, `sesiones`, `pedidos`, `reservas`) no admite uno permitido: son constantes, no condiciones. Para esas ramas se cubre el único lado que existe, y desde varios roles (incluido el `super_admin`, que es quien más se acercaría a la excepción). Todas las ramas **condicionales** sí tienen ambos lados.

**5. `sesiones` create solo lo permite `isCliente()`.** El `<behavior>` del plan lo da por hecho, pero la cabecera de `_contexts.mjs` (heredada de 11-01) describe al mesero como quien "sirve, **abre sesiones**". La regla vigente no se lo permite. Se afirma el comportamiento REAL de la regla con un comentario que lo señala; no se ha tocado ni la regla ni el comentario. Ver Hallazgos.

**Total deviations:** 3 correcciones de integridad de test (todas amplían cobertura) + 2 aclaraciones. **Impact on plan:** ninguna reduce alcance; la nº 1 evita un falso verde que el plan habría producido tal cual estaba escrito.

## Hallazgos (no son bugs corregidos aquí — se reportan, no se silencian)

Estos son comportamientos REALES de `firestore.rules` que la suite ha dejado por escrito. **Ninguno se ha "arreglado" ni se ha reescrito la aserción para esquivarlo**: se afirman tal como son.

1. **El `super_admin` puede leer todo pero no puede operar.** `staffOf()` compara contra `rid()` y el super_admin no tiene `rid` (`seed_firebase.mjs:47`). Consecuencia: **no puede cerrar una sesión, ni cancelar una reserva, ni cambiar el estado de una mesa.** En `pedidos` sí está contemplado (`cocinaStaffOf` incluye `isSuper()`), lo que confirma que la omisión en `mesas`/`sesiones`/`reservas` es una asimetría, no un patrón. Impacto hoy: nulo, porque el panel del super_admin no ofrece esas acciones. **A decidir en 11-10/11-16**, que es cuando el panel de plataforma crece.
2. **El `super_admin` no puede editar el perfil de otro usuario.** La rama `read` de `usuarios` tiene excepción para `isSuper()`; la de `update` no. Cambiar un rol es trabajo del Admin SDK (callable de 11-08), así que es coherente — pero conviene saberlo antes de diseñar la pantalla de equipo.
3. **`allow read: if signedIn()` en `mesas` no acota por tenant.** Un `admin_restaurante` del restaurante B puede leer las mesas del A si conoce su doc ID (que es público: va impreso en el QR). Es una decisión declarada en el comentario de la regla ("leer la mesa no es sensible"), y queda fijada con un test para que un endurecimiento futuro sea consciente.
4. **Discrepancia doc↔regla sobre el mesero y las sesiones** (ver aclaración 5): el comentario de `_contexts.mjs` dice una cosa y la regla hace otra. Ninguna app depende hoy de ello; se deja anotado en el test.

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-04-01 (escalada vertical en `usuarios/{uid}`) | **Mitigado y verificado por rotura** | 10 marcas `// ESCALADA` en `usuarios.test.mjs`. Rotura D → 4 rojos en create; rotura E → 4 rojos en update |
| T-11-04-02 (matriz rol × transición de `pedidos`) | **Mitigado y verificado por rotura** | "mesero no puede aceptar/rechazar/preparar" + "salto ilegal enviado→servido" + "enviado→en_preparacion". Rotura B → 2 rojos |
| T-11-04-03 (lectura/escritura cruzada entre tenants) | **Mitigado y verificado por rotura** | Un caso `adminOtro → DENEGADO` por colección con datos de tenant. Rotura F sobre la suite completa → **12 rojos en 6 colecciones** |
| T-11-04-04 (`califProm`/`califCount` escribible por cliente) | **Aceptado, con el alcance FIJADO** | 7 casos en `restaurantes.test.mjs` que acotan el hueco: solo esas 2 claves, solo con `is number`/`is int`, y denegado colar `activo` o `nombre` junto a ellas. El gap sigue abierto (validación fuerte = Functions, DIFERIDA por decisión del usuario); lo que ya no puede es **crecer** en silencio |
| T-11-04-05 (`plataforma/bootstrap`) | **Mitigado por default deny, hoy** | 8 casos de lectura y escritura desde anónimo, cliente, admin y super_admin, más una colección inventada. Escritos antes de que el `match` exista: son el contrato que 11-07 debe respetar |

**Anti-spoofing de `pedidos`** (no estaba numerado en el registro pero es el tercer `get()` más caro de las rules): mitigado y verificado por rotura C.

## Qué queda VERIFICADO y qué NO — leer antes de dar la autorización por probada

### Verificado de verdad (automatizado, con `firestore.rules` real)

- **Los tres vectores de escalada están cerrados y la prueba de que lo están es reproducible.** Los 190 casos corren contra el **motor de rules del emulador de Firestore** cargando el `firestore.rules` real del repo. No es un mock: es el mismo evaluador que corre en producción. Y cada vector tiene, además, la demostración de que su test detecta la ausencia de la regla (roturas A–F).
- **Aislamiento multi-tenant:** un `admin_restaurante` del rid `otro` queda denegado en mesas, sesiones, pedidos, reservas, categorías y productos. Verificado quitando `r == rid()` de los tres helpers → 12 rojos.
- **Máquinas de estado (`transMesa` y la matriz de pedidos) viven en el servidor**, no solo en Dart.
- **Default deny** sobre colecciones sin `match`, desde los 4 roles.

### NO verificado — y hay que decirlo

- ⚠️ **Nada de esto prueba que las rules DESPLEGADAS en `p-gri-b5b40` sean estas.** El emulador carga el fichero del repo. Mientras no se ejecute `firebase deploy --only firestore:rules`, el proyecto real puede tener una versión distinta (más laxa). **La suite verde y el proyecto seguro son dos afirmaciones independientes** — el despliegue es el checkpoint humano de 11-15/11-16.
- ⚠️ **`fake_cloud_firestore` no tiene motor de rules.** Los 192 tests de las dos apps Flutter verifican FILTRADO, NAVEGACIÓN y ESTADO — **jamás AUTORIZACIÓN**. Un cambio que rompa las rules no pone en rojo ni uno solo de ellos. La única prueba de autorización de este repo es `npm run test:rules`.
- ⚠️ **Estos tests no prueban que las APPS usen las rules correctamente.** Prueban que la regla decide bien ante una petición dada. Que la app construya esa petición (con los `where` que la regla exige) es lo que cubre `audit_indexes.mjs` de 11-03, y solo de forma estática y heurística.
- **El hueco de `califProm`/`califCount` sigue abierto** (T-11-04-04, aceptado en v1). Los tests fijan su tamaño; no lo cierran. Un cliente puede seguir moviendo el agregado de un restaurante sin haber comido allí.
- **Cobertura ≠ exhaustividad.** 190 casos cubren las ramas y sus bordes conocidos; no son una prueba formal. No hay fuzzing ni verificación simbólica de las expresiones de las rules.

## Known Stubs

Ninguno. Las 3 tareas quedan completas. Los 2 marcadores de futuro (`// AMPLIADO EN 11-10` en `usuarios.test.mjs` y el bloque de default deny para 11-07) **no son stubs**: son aserciones vivas y en verde sobre el comportamiento ACTUAL, con la nota de qué plan las cambiará conscientemente.

## Threat Flags

Ninguna. Este plan no añade endpoints, ni rutas de auth, ni cambios de esquema, ni superficie de red. No modifica un solo fichero de producción: crea 7 archivos de test.

## Issues Encountered

- Las roturas deliberadas se aplicaron con `node -e` sobre copia de seguridad en el scratchpad, no con `sed` in-place, porque el fichero tiene acentos y las reglas ocupan varias líneas. Tras cada rotura se comprobó `git diff --name-only firestore.rules` **vacío** antes de continuar.
- Confirmada la trampa de cwd de Windows que documentó 11-03: todos los comandos de este plan usan rutas absolutas o un único `cd` por invocación.
- Los ficheros pendientes del árbol (`AndroidManifest.xml`, `documentos/`, `run_app.bat`, `res/xml/`) son PREVIOS a este plan y ajenos a él: no se han tocado ni commiteado.

## User Setup Required

Ninguno para los gates automatizados. **Pendiente e imprescindible para que esta suite signifique algo en producción:**
`firebase deploy --only firestore:rules` contra `p-gri-b5b40`. Hasta entonces, lo correcto es decir "las rules del repo están probadas", nunca "el proyecto está protegido". Es el paso del runbook de 11-15/11-16.

## Next Phase Readiness

- **11-07 (bootstrap del super_admin):** el bloque `colecciones no declaradas — default deny` de `restaurantes.test.mjs` es su contrato. Al añadir el `match /plataforma/{doc}` debe mantener esos 8 casos en verde — es decir, la regla nueva debe denegar TODO acceso desde el SDK cliente, incluido el del `super_admin`; el centinela solo lo toca el Admin SDK desde la función.
- **11-08 (callable de alta de staff):** `usuarios.test.mjs` fija lo que las rules NO permiten. La callable es la única vía legítima para crear un perfil de staff, y su propia suite debe cubrir la escalada del lado servidor (un `admin_restaurante` no puede tocar otro `rid` ni crear un `super_admin`).
- **11-10 (gestión de equipo):** debe cambiar el veredicto del caso `// AMPLIADO EN 11-10` de `usuarios.test.mjs`, acotando la lectura al `rid` del llamador, y actualizar `PARIDAD_RULES_QUERY` en el mismo commit (regla de 11-03).
- **11-15/11-16 (runbook E2E y checkpoint humano):** heredan lo único que no se puede automatizar aquí — desplegar estas rules y comprobar que el proyecto real corre esta versión.
- **Cualquier plan que toque `firestore.rules`:** `cd scripts && npm run test:rules` en el mismo commit. Son ~12 s.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco con su recuento real:
`mesas.test.mjs` (318 líneas / 26 casos), `sesiones.test.mjs` (340 / 29), `pedidos.test.mjs` (423 / 36 — el `min_lines: 60` del plan se supera con creces), `reservas.test.mjs` (351 / 27), `calificaciones.test.mjs` (324 / 21), `usuarios.test.mjs` (262 / 22, contiene `admin_restaurante` como exige el `must_have`), `restaurantes.test.mjs` (285 / 29). **Suma: 190 casos** = 208 totales − 18 previos. ✔

`key_links` del plan: los 7 archivos importan `./_contexts.mjs` (`grep -c "_contexts.mjs"` ≥ 1 en cada uno). ✔

`<verification>` del plan: `ls scripts/test/rules/*.test.mjs | wc -l` → **10**. ✔

Commits declarados — verificados en `git log`: `0d2cafc`, `a0828f0`, `4825e26`. ✔

`git diff --name-only firestore.rules` → **vacío**: ninguna de las 6 roturas deliberadas sobrevive. ✔

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
