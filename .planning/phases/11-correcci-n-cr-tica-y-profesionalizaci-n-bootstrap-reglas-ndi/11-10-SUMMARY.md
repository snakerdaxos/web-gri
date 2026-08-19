---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 10
subsystem: panel-admin (gestión de equipo) + firestore-rules (lectura del equipo)
tags: [firestore-rules, multi-tenant, cloud-functions, riverpod, go-router, gating-por-rol, query-vs-rules, tdd]

# Dependency graph
requires:
  - plan: 11-04
    provides: "scripts/test/rules/usuarios.test.mjs con el caso marcado // AMPLIADO EN 11-10, y el hallazgo de que el admin_restaurante no podía listar su equipo"
  - plan: 11-05
    provides: "seleccionRestauranteProvider / ridActivoProvider — el restaurante activo del super_admin"
  - plan: 11-06
    provides: "PasswordField del panel"
  - plan: 11-07
    provides: "patrón de COSTURA inyectable (bootstrapAccionProvider / bootstrapCallableProvider) y bootstrap_router_test.dart"
  - plan: 11-08
    provides: "callable crearUsuarioStaff, su matriz de autorización y su contrato de errores"
  - plan: 11-09
    provides: "contrato del estado vacío GUIADO (EmptyState)"
provides:
  - "firestore.rules — tercera rama del read de usuarios: admin_restaurante acotado a su rid"
  - "panel_admin/lib/features/equipo/ — provider, controlador, pantalla y formulario de /equipo"
  - "Gating por rol de /equipo en sidebar y router (los dos, cortesía; no seguridad)"
  - "+13 casos de rules (208 → 221) y +37 tests de panel (163 → 200 atribuibles a este plan)"
affects: [11-15, 11-16, 11-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toda query nueva sobre una colección con rama de rules por-documento replica el filtro de la regla; audit_indexes.mjs lo vigila y su tabla PARIDAD_RULES_QUERY se actualiza en el mismo commit"
    - "Un cambio de veredicto en un test heredado se comprueba sobre el documento que EJERCITA la rama nueva: el doc que 11-04 usaba (un cliente con restauranteId null) habría seguido en verde sin ejercitarla"
    - "El refreshListenable del GoRouter escucha también claimsProvider cuando hay gating por rol: los claims resuelven DESPUÉS del evento de sesión"
    - "Cada caso de gating tiene su CONTRARIO en el mismo archivo: un redirect que expulsara a todo el mundo dejaría los negativos en verde"

key-files:
  created:
    - panel_admin/lib/features/equipo/equipo_provider.dart
    - panel_admin/lib/features/equipo/equipo_controller.dart
    - panel_admin/lib/features/equipo/equipo_screen.dart
    - panel_admin/lib/features/equipo/staff_form_dialog.dart
    - panel_admin/test/equipo/equipo_provider_test.dart
    - panel_admin/test/equipo/equipo_screen_test.dart
    - panel_admin/test/equipo/equipo_gating_test.dart
  modified:
    - firestore.rules
    - scripts/test/rules/usuarios.test.mjs
    - scripts/audit_indexes.mjs
    - panel_admin/lib/app.dart
    - panel_admin/lib/features/shared/app_shell.dart

key-decisions:
  - "El caso heredado // AMPLIADO EN 11-10 leía el doc de un CLIENTE (restauranteId null). Con la regla ampliada su assertFails habría SEGUIDO PASANDO sin ejercitar la ampliación ni una vez. Se parte en dos: el positivo lee un doc de STAFF del propio rid, y el negativo del cliente se conserva como aserción de ACOTAMIENTO"
  - "already-exists NO se traduce como 'ya está registrado en otro restaurante' (lo que pedía el plan): la callable usa ese mismo código para el correo de otro tenant Y para el correo de un CLIENTE, así que ese texto mentiría en la mitad de los casos"
  - "Se traduce también failed-precondition, que el plan no listaba: cae en 'resto → genérico' y el genérico dice 'Intenta de nuevo', cuando reintentar no puede arreglar una cuenta sin rid"
  - "El estado vacío se implementa INLINE en equipo_screen.dart y no reutilizando el widget EmptyState de 11-09: ese widget vive en app_cliente, que es otro proyecto Flutter, y crear su gemelo en panel_admin/lib/features/shared/ queda fuera de los files_modified de este plan (y colisionaría con el ejecutor de 11-11, que estaba tocando el tema del panel en paralelo)"
  - "El redirect NO decide mientras los claims están en AsyncLoading: expulsar ahí echaría a un admin legítimo. Se añade ref.listen(claimsProvider) al refreshListenable para que se re-evalúe al llegar el rol"

patterns-established:
  - "11-15/11-16: la pantalla /equipo NO sirve contra el proyecto real hasta que crearUsuarioStaff esté desplegada (firebase deploy --only functions) y las rules publicadas (firebase deploy --only firestore:rules)"

requirements-completed: []

# Metrics
duration: ~2h 10min
completed: 2026-08-19
---

# Phase 11 Plan 10: Gestión de equipo del panel Summary

**Un restaurante ya puede montar y ver su propio personal desde el panel: la regla de `usuarios` se abre por primera vez a docs ajenos —acotada al `rid` del llamador y solo al rol `admin_restaurante`— y la pantalla `/equipo` consume la callable de 11-08, con los dos permisos nuevos probados en sus dos direcciones y cada control verificado rompiéndolo.**

## Performance

- **Duration:** ~2h 10min
- **Tasks:** 3/3
- **Files created:** 7 · **modified:** 5

## Accomplishments

- **El último eslabón de la autosuficiencia.** 11-07 dejó nacer al primer `super_admin`, 11-05 dejó crear restaurantes y 11-08 dejó dar de alta staff **desde el servidor**. Faltaba la pantalla: hasta hoy, un `admin_restaurante` no podía ni siquiera **ver** a su equipo — la regla solo dejaba leer el propio doc o todo al `super_admin`.
- **El único permiso nuevo está acotado al milímetro y probado en las dos direcciones.** `role() == 'admin_restaurante' && resource.data.restauranteId == rid()`. Ni mesero, ni cocina, ni otro tenant, ni los clientes (que llevan `restauranteId: null` y por tanto quedan fuera por construcción). 13 casos nuevos, con la query sin filtro y el cruce de tenant en los DOS sentidos.
- **Se cazaron DOS verdes por el motivo equivocado, uno de ellos heredado.** El caso `// AMPLIADO EN 11-10` que dejó 11-04 habría seguido en verde tras la ampliación sin ejercitarla ni una vez, y el caso del payload del admin no ejercitaba el guard que decía probar (la rotura K no tumbaba nada). Los dos corregidos y la corrección verificada rompiéndola.
- **Un gate del propio plan era inejecutable** (`node --test test/rules/usuarios.test.mjs`): el `cwd` del wrapper es la raíz del repo, no `scripts/`. Falla ruidosamente, así que no es un falso verde, pero tal cual estaba escrito no se podía ejecutar. Demostrado en vivo.
- **La tabla de traducción de errores del plan mentía en un caso real.** `already-exists` cubre DOS ramas del anti-secuestro de la callable —correo de otro tenant y correo de un cliente— y el texto que pedía el plan afirmaba la primera. Corregido sin filtrar el texto del servidor.
- **21 roturas deliberadas** (A–Q, con N-bis y N-ter), todas revertidas y comprobadas con `cmp` byte a byte.
- **Sin regresiones.** rules 208 → **221**, functions e2e 25 y unitarios 34 estables, `flutter analyze` 0 issues en las dos apps, `audit:indexes` / `audit:branding` / `verify:shell` verdes.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Regla `read` de `usuarios` ampliada + sus tests | RED → GREEN | `7f3f9a2` (feat) |
| 2 | `equipo_provider` + `equipo_controller` + tests | — | `5ef72b6` (feat) |
| 3 | `/equipo`, formulario, gating de sidebar y router | RED → GREEN | `69799e8` (feat) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline propia — panel | `flutter analyze && flutter test` | `No issues found!` · `+163: All tests passed!` |
| Baseline propia — rules | `npm run test:rules` | `tests 208 · pass 208 · fail 0` |
| **T1 gate del PLAN, literal** | `node run_emulators.mjs … -- node --test test/rules/usuarios.test.mjs` | `Could not find 'test/rules/usuarios.test.mjs'` · **exit 1 — inejecutable, ver desviación 1** |
| **T1 RED** | `… -- node --test scripts/test/rules/usuarios.test.mjs` | `tests 35 · pass 33 · fail 2` — caen EXACTAMENTE los 2 casos positivos nuevos |
| **T1 GREEN** | idem, con la regla ampliada | `tests 35 · pass 35 · fail 0` |
| T1 suite completa | `npm run test:rules` | `tests 221 · suites 41 · pass 221 · fail 0` |
| T2 analyze | `flutter analyze` | `No issues found!` |
| T2 code-gen | `dart run build_runner build --delete-conflicting-outputs` | `Built with build_runner/aot in 6s; wrote 4 outputs.` |
| T2 índices | `npm run audit:indexes` | `22 queries analizadas · 5 sujetas a paridad · 0 fallo(s)` · exit 0 (era 21/4) |
| T2 tests | `flutter test test/equipo/` | `+15: All tests passed!` |
| **T3 RED** | `flutter test test/equipo/equipo_screen_test.dart test/equipo/equipo_gating_test.dart` | `Error when reading 'lib/features/equipo/equipo_screen.dart'` · `Undefined name 'StaffFormDialog'` · `Undefined name 'rolesAsignables'` |
| **T3 GREEN** | `flutter test test/equipo/` | `+37: All tests passed!` |
| Final — rules | `npm run test:rules` | `tests 221 · suites 41 · pass 221 · fail 0` · `Script exited successfully (code 0)` |
| Final — functions e2e | `npm run test:functions` | `tests 25 · suites 2 · pass 25 · fail 0` |
| Final — functions unitarios | `cd functions && npm test` | `tests 34 · pass 34 · fail 0` |
| Final — índices | `npm run audit:indexes` | `22 queries analizadas · 5 sujetas a paridad · 0 fallo(s)` |
| Final — branding | `npm run audit:branding` | `2 apps · 4 archivos revisados · 0 rastros de plantilla` |
| Final — shell de carga | `npm run verify:shell` | `OK app_cliente 1733ms · OK panel_admin 1230ms` |
| Final — panel | `flutter analyze && flutter test` | `No issues found!` · `+226: All tests passed!` |
| Final — cliente | `flutter analyze && flutter test` | `No issues found!` · `+178: All tests passed!` |

### Conteo de pruebas — qué es mío y qué no

| Suite | Baseline medida por mí | Final | Aportación de ESTE plan |
|---|---|---|---|
| rules | 208 | **221** | **+13** (todos míos) |
| panel_admin | 163 | 226 | **+37** (15 provider/controlador + 13 pantalla/formulario + 9 gating) |
| app_cliente | 158 | 178 | **0** — este plan no toca ni un archivo de `app_cliente` |
| functions e2e / unit | 25 / 34 | 25 / 34 | 0 |

El resto del crecimiento del panel (+26) y todo el de `app_cliente` (+20) es del **ejecutor de 11-11**, que corrió en paralelo en el mismo árbol. Se comprobó leyendo `git status` y `git log`: sus cambios llegan en `3e5f931` y en su rama de tokens. Solo se stagearon archivos propios; nunca `git add -A`.

## Verificación por ROTURA DELIBERADA (21 roturas, todas revertidas)

Tras cada bloque se comprobó con `cmp` que la fuente volvía a ser byte a byte la original.

### `firestore.rules` — la ampliación (contra el emulador real)

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| A | se quita `&& resource.data.restauranteId == rid()` (rama sin acotar) | **5**: query sin filtro, `where == 'otro'`, doc suelto de otro tenant, el admin de `otro` listando `demo`, y el ACOTAMIENTO del cliente | Sí (`cmp` OK) |
| B | `role() in ['admin_restaurante','mesero','cocina']` (abierta a todo el staff) | **3**: mesero listando, cocina listando, mesero leyendo el doc de su compañero | Sí (`cmp` OK) |

### Provider y controlador (`flutter test test/equipo/`)

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| C | la query pierde el `where('restauranteId')` | **`npm run audit:indexes` exit 1** — `FALTA where('restauranteId')` | Sí |
| D | idem, contra los tests de Dart | **2**: el equipo de `demo` y el del super sobre `norte` | Sí |
| E | el admin manda también `restauranteId` desde el controlador | 1: la forma del payload | Sí |
| F | se elimina el chequeo defensivo de rol del provider | 2: mesero y cocina | Sí |

### Pantalla, formulario y gating

| # | Rotura | Casos que caen | Revertida |
|---|---|---|---|
| G | el ítem 'Equipo' del sidebar SIEMPRE visible | 2: OCULTO para mesero y para cocina | Sí |
| H | el ítem 'Equipo' OCULTO para todos | 2: VISIBLE para admin y para super | Sí |
| I | se retira el `redirect` de `/equipo` | 2: mesero y cocina llegan a la pantalla | Sí |
| J | el `redirect` expulsa a TODOS | 2: los dos casos EL CONTRARIO (admin y super) | Sí |
| K | el diálogo manda `restauranteId` también siendo admin | **0 la primera vez — ver "verdes por el motivo equivocado" nº 2**; **1 tras endurecer el caso** | Sí |
| L | `super_admin` entra en `rolesAsignables` | 1: 'super_admin NUNCA aparece entre los roles asignables' | Sí |
| M | se quita el mínimo de 8 caracteres | 1: la contraseña de 7 no llega a la callable | Sí |
| N | se quita la guarda `if (_enviando) return` | **0** — el botón deshabilitado ya lo impedía (ver abajo) | Sí |
| N-bis | el botón siempre habilitado, con la guarda puesta | **0** — la guarda ya lo impedía | Sí |
| N-ter | **los DOS controles fuera a la vez** | **1**: 'doble envío imposible' | Sí |
| O | el estado vacío pierde su guía | 1: 'con el equipo vacío se GUÍA' | Sí |
| P | se quita el aviso de volver a entrar tras el alta | 1 | Sí |
| Q | el diálogo se cierra también cuando el alta FALLA | 1: 'un alta fallida … NO cierra el formulario' | Sí |

**Sobre N / N-bis / N-ter:** el doble envío está impedido por **dos controles independientes** (el botón deshabilitado y la guarda `if (_enviando) return`). Cualquiera de los dos basta, así que quitar uno solo no pone nada en rojo — no es un test flojo, es defensa en profundidad real, y la rotura N-ter demuestra que el caso SÍ detecta un doble envío verdadero. Queda dicho para que nadie lea "0 caídas" como "el test no sirve".

## Caza de verdes por el motivo equivocado

**Encontrados dos. Los dos corregidos y la corrección verificada rompiéndola.**

**1. El caso heredado `// AMPLIADO EN 11-10` habría seguido en verde SIN ejercitar la ampliación.**
11-04 lo escribió como `assertFails(getDoc(doc(adminDemo(env), 'usuarios', YO)))` con el título "el ADMIN del restaurante NO puede leer el perfil de su equipo". Pero `YO` es `uid-cliente`: un **cliente** con `restauranteId: null`. Con la regla nueva, `null == 'demo'` sigue siendo falso, así que **ese `assertFails` pasa igual antes y después del cambio** — el veredicto no habría cambiado, el título habría mentido, y la ampliación se habría dado por probada sin un solo caso que la tocara.
**Corrección:** el caso positivo pasa a leer el doc de un miembro de **STAFF** del propio rid (`UID_MESERO`), y el caso del cliente se conserva aparte, renombrado como aserción de **ACOTAMIENTO** (que es lo que de verdad afirma). **Verificación:** en el RED, los 2 casos que caen son exactamente los dos positivos nuevos; en la rotura A, el de acotamiento es uno de los 5 que se ponen en rojo.

**2. El caso del payload del admin no ejercitaba el guard que decía probar.**
'admin_restaurante: sin `restauranteId` en la llamada' pasaba porque `seleccionRestauranteProvider` valía `null` en ese test, no porque el diálogo tuviera el guard `esSuper ? _restauranteId : null`. **Demostrado en vivo (rotura K): con el guard quitado, el caso seguía en verde y no caía ni un test.**
**Corrección:** el caso siembra ahora una selección **ajena** (`'norte'`) además del claim `rid: 'demo'`. Quitar el guard hace viajar un rid de otro restaurante —exactamente el intento de escalada horizontal que la callable rechaza— y el caso se pone en rojo. **Verificación:** la rotura K repetida tumba 1 caso.

**Tercer candidato revisado y descartado con motivo.** Los casos 'OCULTO para mesero/cocina' pasarían también si los claims nunca llegaran al router (el ítem se oculta por defecto cuando `claims.value` es null). No es un hueco: sus **contrarios** —'VISIBLE para admin_restaurante' y 'VISIBLE para super_admin', y los dos 'EL CONTRARIO' del redirect— caen si el arnés de claims se rompe. El par se sostiene entre sí (roturas G/H y I/J lo demuestran).

## Files Created/Modified

**Creados**
- `panel_admin/lib/features/equipo/equipo_provider.dart` (102 líneas) — `equipoProvider` (query con el `where` obligatorio, orden en cliente), `MiembroEquipo`, `rolesQueGestionanEquipo`, `etiquetaRol`.
- `panel_admin/lib/features/equipo/equipo_controller.dart` (155) — `crearStaffAccion` + `crearStaffCallable` (costura inyectable), `EquipoException`, `mensajeAltaStaff`.
- `panel_admin/lib/features/equipo/equipo_screen.dart` (196) — pantalla adaptativa, estado vacío guiado, tabla.
- `panel_admin/lib/features/equipo/staff_form_dialog.dart` (306) — formulario, `rolesAsignables`, selector de restaurante solo para el super.
- `panel_admin/test/equipo/equipo_provider_test.dart` (15 casos) — **no estaba en el plan; ver desviación 3**.
- `panel_admin/test/equipo/equipo_screen_test.dart` (13 casos).
- `panel_admin/test/equipo/equipo_gating_test.dart` (9 casos, sobre el `GoRouter` REAL).

**Modificados**
- `firestore.rules` — la tercera rama del `read` de `usuarios` y su comentario (por qué se amplía, qué acota, que la query debe replicar el filtro y que el presupuesto de access-calls queda intacto). `create`, `update` y `delete` **sin tocar**.
- `scripts/test/rules/usuarios.test.mjs` — 22 → 35 casos; cabecera-contrato actualizada.
- `scripts/audit_indexes.mjs` — la nota de la entrada `usuarios` pasa de "llega en el plan 11-10" a "AMPLIADA en el plan 11-10" (**ver desviación 4**).
- `panel_admin/lib/app.dart` — ruta `/equipo`, `redirect` por rol y `ref.listen(claimsProvider)` en el `refreshListenable`.
- `panel_admin/lib/features/shared/app_shell.dart` — ítem 'Equipo' con visibilidad condicionada y título del topbar.

## Decisions Made

- **`already-exists` no se traduce como "otro restaurante".** La callable lanza ese código en **dos** ramas del anti-secuestro con mensajes distintos: `'Ese correo ya pertenece a otro restaurante.'` y `'Ese correo ya tiene una cuenta de cliente; pide a esa persona que use otro correo…'`. El texto que pedía el plan ("Ese correo ya está registrado en otro restaurante.") mandaría al operador a buscar un restaurante inexistente en la mitad de los casos. Se usa un texto que es cierto en las dos y que no filtra el del servidor (T-11-10-04 intacta).
- **Se traduce `failed-precondition`**, que el plan no listaba y por tanto caía en el genérico "Intenta de nuevo". Reintentar no puede arreglar una cuenta sin `rid`: el mensaje dice qué pedirle al super admin.
- **`invalid-argument` propaga el texto del servidor, como pide el plan** — con un matiz honesto: de los cinco mensajes que la función emite con ese código, tres están redactados para el usuario ("La contraseña debe tener al menos 8 caracteres.") y **dos vienen de `auth-matrix.js` y son de desarrollador** ("rol debe ser uno de: …", "restauranteId es obligatorio y debe ser un slug [a-z0-9-]."). Esos dos solo se alcanzan con la UI rota (el desplegable no ofrece roles inválidos y el selector del super es obligatorio), así que verlos sería un diagnóstico útil, no una fuga.
- **El estado vacío es INLINE, no el `EmptyState` de 11-09.** Ese widget vive en `app_cliente`, otro proyecto Flutter: no se puede importar. Lo que se conserva es su **contrato** — la guía es obligatoria — y su lenguaje visual. Crear el gemelo en `panel_admin/lib/features/shared/` habría salido de los `files_modified` y habría colisionado con el ejecutor de 11-11, que estaba reescribiendo el tema del panel en paralelo.
- **El redirect no decide mientras los claims cargan.** `.value` es null en `AsyncLoading` y expulsar ahí echaría a un `admin_restaurante` legítimo que abriera `/equipo` por URL. Se añade `ref.listen(claimsProvider, …)` al `refreshListenable` para que el redirect se re-evalúe al llegar el rol. El ítem del sidebar hace lo CONTRARIO (oculto mientras carga): ahí el coste de equivocarse es enseñar algo un instante a quien no debe, no bloquear a quien sí.
- **No hay "eliminar" ni "desactivar" staff, y no es un olvido.** `firestore.rules` prohíbe `delete` en `usuarios` (`allow delete: if false`) y el alcance del plan es crear. Anotado como deuda.
- **El ítem del sidebar usa 🪪 y no 👥**, que ya es el de 'Clientes'. Es provisional: la sustitución de emojis por `Icon` es otro plan de la fase (decisión DESBLOQUEADA del CONTEXT).

## Deviations from Plan

**1. [Regla 3 — Bloqueante] El gate de la Tarea 1 que pide el plan es inejecutable**

- **Found during:** Tarea 1.
- **Issue:** el plan pide `cd scripts && node run_emulators.mjs … -- node --test test/rules/usuarios.test.mjs`. `run_emulators.mjs` fija el `cwd` del proceso hijo en la **raíz del repo** (`run_emulators.mjs:220`, `cwd: RAIZ_REPO`), no en `scripts/`. El comando muere con `Could not find 'test/rules/usuarios.test.mjs'` y exit 1.
- **Ejecutado y demostrado:** sí, tal cual lo escribe el plan. Falla ruidosamente, así que **no es un falso verde** — pero el gate, tal cual, no se puede correr.
- **Fix:** se ejecutó con la ruta desde la raíz (`scripts/test/rules/usuarios.test.mjs`), que es la forma que usa el propio `npm run test:rules`.

**2. [Regla 2 — Funcionalidad crítica ausente] La traducción de `already-exists` del plan es falsa en una de sus dos ramas**

- **Found during:** Tarea 2, leyendo `functions/src/crear-usuario-staff.js`.
- **Issue:** ver "Decisions Made". El plan mapea `already-exists` → "Ese correo ya está registrado en otro restaurante.", pero la callable usa ese código también cuando el correo pertenece a una **cuenta de cliente**, que es un caso con acción distinta.
- **Fix:** texto cierto en las dos ramas, sin propagar el del servidor. Hay un caso de test que exige que el mensaje mencione ambas posibilidades, para que nadie lo "simplifique" de vuelta.
- **Committed in:** `5ef72b6`.

**3. [Ampliación] La Tarea 2 está marcada `tdd="true"` pero el plan no le da ningún archivo de test**

- **Issue:** los `<files>` de la Tarea 2 son solo los dos de `lib/`, y sus `<verify>` son `flutter analyze` y `audit:indexes`. Los **siete** comportamientos de su `<behavior>` —incluido "un `admin_restaurante` NO incluye `restauranteId` en el payload", que es la mitigación de la escalada horizontal del lado cliente— habrían quedado **afirmados y no verificados**. Los tests de la Tarea 3 no los cubren: prueban la pantalla, no la forma del payload ni el filtro de la query.
- **Fix:** `panel_admin/test/equipo/equipo_provider_test.dart` (15 casos). Es el único archivo fuera de `files_modified` que añado en el panel.
- **Committed in:** `5ef72b6`.

**4. [Ampliación menor, fuera de `files_modified`] `scripts/audit_indexes.mjs`**

- **Issue:** su tabla `PARIDAD_RULES_QUERY` ya traía la entrada `usuarios` con el campo `restauranteId`, y su cabecera exige actualizarla "en el mismo commit en que se toque la rama pública de `firestore.rules`". Lo único desalineado era la nota `(llega en el plan 11-10)`, que dejaba de ser cierta.
- **Fix:** un carácter de texto en un comentario. La lógica no cambia. **La entrada ya tenía dientes:** la rotura C la puso en exit 1 con `FALTA where('restauranteId')`.
- **Committed in:** `5ef72b6`.

**5. [Discrepancia del plan, sin impacto] El plan dice sustituir el comentario `// AMPLIADO EN 11-08`**

- **Issue:** el `<action>` de la Tarea 1 dice «Sustituir el comentario `// AMPLIADO EN 11-08` que dejó ese plan». El comentario que existe en `usuarios.test.mjs` es `// AMPLIADO EN 11-10` (lo dejó **11-04**, no 11-08, y apuntando a este plan). Es un dedazo del plan.
- **Fix:** se trató el comentario real. Ver además "verdes por el motivo equivocado" nº 1: sustituirlo tal cual habría producido un verde vacío.

**6. [Estructural, reportado sin maquillar] La Tarea 2 no tiene ciclo RED→GREEN de comportamiento**

- **Issue:** los 15 casos de `equipo_provider_test.dart` salieron verdes a la primera, porque el archivo de test se escribió **después** del provider (el plan no lo contemplaba y no había implementación previa que romper). Las Tareas 1 y 3 sí hicieron RED de verdad (`fail 2` y error de compilación, respectivamente).
- **Fix:** se reporta tal cual. El equivalente con dientes son las roturas C–F.

**7. [Contexto de ejecución] Árbol compartido con el ejecutor de 11-11**

- **Issue:** durante la ejecución, `flutter analyze` del panel llegó a dar **31 issues** y la suite **2 fallos**, todos en `test/core/theme_tokens_test.dart` y `lib/core/theme.dart` — archivos del plan 11-11, que estaba a media escritura. Ninguno es mío.
- **Fix:** se verificó filtrando por archivo (`flutter analyze | grep -v theme_tokens` → `No issues found!`) y re-ejecutando tras su commit `3e5f931`. Se stagearon exclusivamente archivos propios; `git diff --cached --name-only` se revisó antes de cada commit. El diff de `app_shell.dart` se auditó línea a línea para confirmar que no arrastraba nada suyo.

---

**Total deviations:** 7 (1 bloqueante, 1 corrección de funcionalidad crítica, 2 ampliaciones, 1 dedazo del plan, 1 estructural, 1 de contexto). **Ninguna reduce alcance. Ninguna aserción se relajó para poner algo en verde — dos se endurecieron.**

## Mitigaciones del threat model

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-10-01 (Information Disclosure — ampliación del `read` de `usuarios`) | **Mitigado y verificado por rotura** | La regla exige rol `admin_restaurante` Y `restauranteId == rid()`. 13 casos nuevos: query sin filtro DENEGADA, cruce de tenant en los dos sentidos DENEGADO, mesero y cocina DENEGADOS, clientes fuera por construcción. Roturas A (5 caídas) y B (3 caídas) |
| T-11-10-02 (Elevation of Privilege — rol del desplegable) | **Transferido, como decía el plan, y con gate propio** | La decisión vive en `autorizarAlta` (11-08, 27 casos unitarios + 14 e2e). Aquí la allow-list `rolesAsignables` es UX: la rotura L la tumba, pero incluso sin ella la callable rechaza |
| T-11-10-03 (Spoofing — `/equipo` por URL) | **Mitigado y verificado por rotura, y declarado como NO-seguridad** | `redirect` del router + ítem oculto. Roturas G–J: cada dirección del gating tiene su contrario. Dicho en el código, en los tests y aquí: la frontera son las rules y la callable |
| T-11-10-04 (Information Disclosure — mensajes de error) | **Mitigado y verificado** | 8 casos de traducción; dos afirman explícitamente que ni el texto crudo del servidor ni el de un error no-Functions se filtran. Solo `invalid-argument` propaga, con el matiz declarado en "Decisions Made" |
| T-11-10-05 (Tampering — alta a medias) | **Mitigado** | El copy del formulario dice que reintentar con el mismo correo repara, y el aviso posterior distingue `creado: true` de `creado: false`. Roturas P y el caso de reparación lo fijan |

## Qué está VERIFICADO y qué solo está AFIRMADO

**VERIFICADO (contra el motor de rules real del emulador, o contra la suite de widgets):**
- Que un `admin_restaurante` de `demo` **puede** listar `usuarios where restauranteId == 'demo'` y leer el doc suelto de un miembro de su equipo.
- Que **no puede**: sin el `where`, con `where == 'otro'`, el doc suelto de un usuario de `otro`, ni el perfil de un **cliente**.
- Que el admin de `otro` **no puede** listar el equipo de `demo` (la dirección contraria).
- Que `mesero` y `cocina` **no pueden** listar el equipo ni leer el doc de un compañero, pero **sí siguen leyendo el suyo**.
- Que el `super_admin` sigue listando `usuarios` sin filtro, y que **ninguna rama de escritura cambió** (los 8 casos de auto-registro y los 7 de update siguen verdes).
- Que la query del panel lleva el `where` que la regla exige, y que quitarlo pone `audit:indexes` en exit 1.
- Que un `admin_restaurante` **no manda** `restauranteId` ni aunque haya una selección de otro restaurante viva, y que un `super_admin` **sí** manda el elegido.
- Que los 8 códigos de error se traducen y que ni el texto crudo del servidor ni el de un error ajeno a Functions llegan a la UI.
- Que `super_admin` no aparece en el desplegable, que 7 caracteres de contraseña no gastan una llamada, que el doble envío no ocurre, que un fallo no cierra el formulario y que un alta que repara lo dice.
- Que el ítem del sidebar y el `redirect` se comportan en las **dos** direcciones para los cuatro roles, sobre el `GoRouter` REAL.

**AFIRMADO, NO VERIFICADO — leer antes de confiar:**
- **Nada de esto prueba que las rules DESPLEGADAS en `p-gri-b5b40` sean estas.** El emulador carga el fichero del repo. Hasta `firebase deploy --only firestore:rules`, el proyecto real puede tener la versión vieja — y con la vieja, `/equipo` mostraría el error de carga en producción aunque aquí esté todo verde.
- **La callable `crearUsuarioStaff` sigue SIN DESPLEGAR** (declarado ya por 11-08). Hasta `firebase deploy --only functions`, el formulario no puede dar de alta a nadie en producción: fallará con un error de red o `internal`.
- **`fake_cloud_firestore` no tiene motor de rules.** Los 37 tests del panel verifican FILTRADO, NAVEGACIÓN y ESTADO — **jamás AUTORIZACIÓN**. Un cambio que rompa la regla de `usuarios` no pone en rojo ni uno solo de ellos. La única prueba de autorización es `npm run test:rules`.
- **La pantalla nunca se ha ejecutado contra la callable real.** El controlador se prueba con la callable sustituida por un doble; que `httpsCallable('crearUsuarioStaff').call()` devuelva exactamente `{uid, creado, rol, restauranteId}` está tomado del contrato de 11-08, no observado desde Flutter.
- **La normalización de `Map<Object?, Object?>` a `Map<String, dynamic>`** (`_comoMapa`) está puesta por el comportamiento conocido del plugin en Web vs móvil; **no hay ningún test que la ejercite con la forma de Web**, porque no hay callable real en `flutter test`.
- **La lista del equipo no es en vivo.** Es un `get()` que se invalida tras un alta, no un `snapshots()`. Si otro admin da de alta a alguien, esta pantalla no lo ve hasta recargar. Es deliberado (coste), no un descuido.
- **El `redirect` con claims en `AsyncLoading` deja pasar un instante.** Un `mesero` que escriba `/equipo` verá la pantalla durante los milisegundos que tardan los claims, y entonces será expulsado. El listado le fallará igualmente (las rules lo deniegan). Documentado en el código.
- **Nadie ha usado esta pantalla con un humano delante.** El sellado E2E es el checkpoint de la fase.

## Known Stubs

Ninguno. La pantalla está cableada de punta a punta: el listado sale de Firestore con el filtro real, y el alta invoca la callable real a través de una costura que solo se sustituye en tests.

**Deuda declarada (no es stub):**
- **No se puede desactivar ni eliminar staff** desde el panel. `firestore.rules` prohíbe `delete` en `usuarios` y el alcance del plan es crear. Hoy, revocar el acceso de alguien exige la consola de Firebase o el Admin SDK — anotarlo como riesgo operativo real: **un restaurante puede dar de alta a un empleado pero no puede darlo de baja desde el producto**.
- **No hay correo de invitación:** la contraseña temporal la teclea y la dicta quien da el alta (decisión del plan). El cambio de contraseña ya existe en `app_cliente/lib/features/perfil/perfil_screen.dart`.
- **El emoji 🪪 del sidebar** es provisional: la sustitución de emojis por `Icon` es otro plan de la fase.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: information-disclosure | `firestore.rules` | Superficie NUEVA declarada en el propio `<threat_model>` del plan (T-11-10-01), pero conviene que quede también aquí: **es la primera vez que un rol distinto del `super_admin` puede leer documentos de `usuarios` que no son suyos.** Cualquier plan futuro que añada campos a `usuarios/{uid}` debe recordar que a partir de ahora el `admin_restaurante` del mismo `rid` los ve. |

## Issues Encountered

- **Árbol compartido con el ejecutor de 11-11** durante toda la ejecución: `flutter analyze` y `flutter test` del panel dieron resultados transitorios inconsistentes (31 issues, luego 2 fallos, luego verde) por sus archivos a medio escribir. Se resolvió filtrando por archivo y re-midiendo tras su commit. Ninguna medida de este SUMMARY procede de una ejecución contaminada.
- **La lección de 11-09 se repitió con signo contrario:** el crecimiento de `app_cliente` (158 → 178) NO es de este plan, que no toca ni un archivo de esa app.
- **Cada rotura de rules cuesta un arranque de emuladores** (~40 s). Se usó un driver acotado a `usuarios.test.mjs` para las roturas A y B, y la suite completa solo para la verificación final.

## Next Phase Readiness

**Para 11-15 / 11-16 (despliegue y E2E):**
- Hay que desplegar **las rules** (`firebase deploy --only firestore:rules`) además de las funciones. Sin las rules nuevas, `/equipo` falla con `permission-denied` para todo `admin_restaurante`.
- Guion mínimo de humo de esta pantalla, en orden: (1) super_admin entra en `/equipo`, elige restaurante en el formulario y crea un `admin_restaurante`; (2) esa persona inicia sesión en el panel, ve 'Equipo' en el sidebar y a sí misma en la tabla; (3) crea un mesero **sin** tocar ningún selector de restaurante; (4) el mesero inicia sesión y **no** ve 'Equipo' ni llega escribiendo `/equipo` en la barra de direcciones.
- Comprobar en real el caso que ningún test puede cubrir: **repetir el alta con el mismo correo** y ver que el mensaje dice "quedó reparada" y no "creado".

**Para quien toque `firestore.rules`:** la rama del `admin_restaurante` en `usuarios` obliga a que **toda** query sobre esa colección lleve `where('restauranteId', isEqualTo: rid)`. `scripts/audit_indexes.mjs` lo vigila y su tabla `PARIDAD_RULES_QUERY` debe actualizarse en el mismo commit.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `panel_admin/lib/features/equipo/equipo_provider.dart`, `equipo_controller.dart`, `equipo_screen.dart`, `staff_form_dialog.dart`, `panel_admin/test/equipo/equipo_provider_test.dart`, `equipo_screen_test.dart`, `equipo_gating_test.dart`.

Commits declarados — verificados en `git log`: `7f3f9a2`, `5ef72b6`, `69799e8`.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
