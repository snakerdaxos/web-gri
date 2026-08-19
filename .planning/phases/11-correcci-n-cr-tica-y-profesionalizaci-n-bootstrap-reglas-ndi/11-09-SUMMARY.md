---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 09
subsystem: ui (app_cliente + panel_admin)
tags: [estados-vacios, 404, go-router, ux, seguridad, tdd]

# Dependency graph
requires:
  - plan: 11-02
    provides: buildFakeFirestoreVacio() y base_vacia_test.dart con el TODO(11-09)
  - plan: 11-05
    provides: estado vacío guiado del tab Restaurantes del panel (no duplicado aquí)
  - phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
    provides: goRouterProvider de las dos apps, restauranteDetalleProvider, sesionActualProvider
provides:
  - "app_cliente/lib/features/shared/empty_state.dart — widget de estado vacío guiado, resistente al desbordamiento"
  - "Guard de menú vacío en menu_mesa_screen (la pantalla post-escaneo del QR)"
  - "NotFoundScreen + errorBuilder cableado en los DOS GoRouter"
  - "app_cliente/test/pedidos/menu_vacio_test.dart y test/router_404_test.dart"
  - "panel_admin/test/router_404_test.dart"
affects: [11-10, 11-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Estado vacío como WIDGET compartido con guía obligatoria: constatar el vacío sin explicarlo deja al usuario sin saber si la app falló"
    - "Estado vacío resistente al desbordamiento: scrollable con altura acotada, rígido con altura libre (un viewport vertical sin acotar lanza dentro de un ListView)"
    - "404 propio que muestra SOLO Uri.path — nunca query params ni fragmento"
    - "El redirect del guard se evalúa ANTES que el errorBuilder: el 404 no sirve para sondear rutas internas"
    - "Par vacío/contrario en el mismo archivo de test: un guard invertido rompe el segundo caso"

key-files:
  created:
    - app_cliente/lib/features/shared/empty_state.dart
    - app_cliente/lib/features/shared/not_found_screen.dart
    - app_cliente/test/pedidos/menu_vacio_test.dart
    - app_cliente/test/router_404_test.dart
    - panel_admin/lib/features/shared/not_found_screen.dart
    - panel_admin/test/router_404_test.dart
  modified:
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/app.dart
    - app_cliente/test/base_vacia_test.dart
    - panel_admin/lib/app.dart

key-decisions:
  - "El botón de salida del 404 va a '/inicio' en la app cliente, NO a '/' como decía el plan: esa app no tiene ruta raíz y el botón habría caído en otro 404"
  - "NotFoundScreen NO reutiliza EmptyState: necesita una cuarta ranura (la ruta pedida, aislable por los tests) y el panel no tiene ese widget compartido — las dos pantallas 404 deben ser simétricas"
  - "EmptyState decide entre scrollable y rígido con un LayoutBuilder: dentro de un ListView (altura no acotada) un SingleChildScrollView lanza"
  - "El CTA de la lista vacía se llama 'Actualizar' y no 'Reintentar' porque 'Reintentar' es la etiqueta de la rama de ERROR, y confundirlas le diría al usuario que algo falló"

requirements-completed: [UX-02, UX-04]

# Metrics
duration: ~50min (con una interrupción por límite de sesión de la API)
completed: 2026-08-19
---

# Phase 11 Plan 09: Estados vacíos guiados y 404 propio Summary

**La pantalla en blanco que el cliente veía justo después de escanear el QR de su mesa ya explica qué pasa y qué hacer, las listas mudas de la app dejaron de serlo, y una URL inválida da una pantalla propia en las dos apps en vez del volcado rojo de Flutter.**

## Performance

- **Duration:** ~50 min de trabajo efectivo
- **Started:** 2026-08-19T18:34Z
- **Completed:** 2026-08-19T20:47Z (con una interrupción por límite de sesión de la API en medio)
- **Tasks:** 2/2
- **Files created/modified:** 12 — exactamente los `files_modified` del plan, ni uno más

## Accomplishments

- **Cerrado el agujero crítico.** `menu_mesa_screen.dart` construía el `children` de su `ListView` entero a partir de `for (cat in detalle.categorias)`. Con un restaurante de 0 categorías el cuerpo quedaba **literalmente en blanco** — y esa es la pantalla a la que se llega *después* de escanear el QR, con el cliente ya sentado en la mesa. Ahora hay un guard con titular, guía y sin perder el AppBar de la mesa ni la barra del carrito.
- **Las tres formas distintas de resolver "no hay datos" pasaron a ser una.** `EmptyState` extrae el patrón que ya era bueno (`mis_reservas_screen`, `pedido_estado_screen`) y sustituye a los `Text` grises sueltos de `restaurantes_list_screen` y `restaurante_detalle_screen`. Sin un color ni una tipografía nueva: la identidad visual está BLOQUEADA por decisión del usuario.
- **404 propio y seguro en las dos apps.** `errorBuilder` cableado en los dos `GoRouter`, con las dos mitigaciones del threat model verificadas por test: solo se pinta `Uri.path` (nunca el query string, donde viajan tokens) y el guard de sesión sigue mandando sobre el 404 (sin sesión, una ruta que existe y una que no dan la **misma** respuesta).
- **El `TODO(11-09)` que 11-02 dejó apuntando aquí queda resuelto**, endureciendo: se añadieron aserciones, no se relajó ninguna.
- **11 roturas deliberadas** aplicadas y revertidas para comprobar que cada gate tiene dientes.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | EmptyState y listas sin guía | RED | `b1719ca` (test) |
| 1 | EmptyState y listas sin guía | GREEN | `e5c921b` (feat) |
| 2 | Pantalla 404 en los dos routers | — | `2840752` (feat) |

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline propia — cliente | `cd app_cliente && flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Baseline propia — panel | `cd panel_admin && flutter analyze && flutter test` | `No issues found!` · `+157: All tests passed!` |
| T1 RED (compilación) | `flutter test test/pedidos/menu_vacio_test.dart` | `Error when reading 'lib/features/shared/empty_state.dart'` · `+0 -1: Some tests failed` |
| T1 RED (compilación) | `flutter test test/base_vacia_test.dart` | `Undefined name 'EmptyState'` ×2 · `+0 -1: Some tests failed` |
| **T1 RED de COMPORTAMIENTO** | widget creado, guards SIN aplicar | `+4 -3: Some tests failed` — fallan exactamente los 3 casos que exigen los guards; los otros 4 pasan y fijan la no-regresión |
| T1 GREEN | `flutter analyze` (mis 6 items) | `No issues found!` |
| T1 GREEN | `flutter test test/pedidos/ test/restaurantes/ test/base_vacia_test.dart test/reservas/` | `+50: All tests passed!` |
| T2 | `flutter test test/router_404_test.dart` (cliente) | `+5: All tests passed!` |
| T2 | `flutter test test/router_404_test.dart` (panel) | `+6: All tests passed!` |
| Verificación del plan | `grep -rn "errorBuilder" app_cliente/lib/app.dart panel_admin/lib/app.dart` | presente en los dos (`app_cliente:46`, `panel_admin:37`) |
| Suite final — panel | `cd panel_admin && flutter analyze && flutter test` | `No issues found!` · `+163: All tests passed!` (157 → 163) |
| Suite final — cliente (mi alcance) | `flutter test` sobre todo menos `test/auth` | `+99: All tests passed!` (89 → 99) |
| Suite final — cliente (`test/auth`) | `flutter test test/auth` | `+50: All tests passed!` |
| Índices | `cd scripts && npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` · exit 0 |
| Branding | `cd scripts && npm run audit:branding` | `AUDIT BRANDING OK · 2 apps · 4 archivos · 0 rastros de plantilla` · exit 0 |

**Conteo de pruebas atribuible a este plan: +16.** app_cliente 112 → 122 (+10: 4 de `menu_vacio_test`, +1 en `base_vacia_test`, 5 de `router_404_test`), panel_admin 157 → 163 (+6). Sin regresión: ninguna prueba preexistente de mi alcance cambió de estado.

### Roturas deliberadas (11) — cada gate verificado, no supuesto

| # | Qué rompí | Qué debía caer | Cayó |
|---|---|---|---|
| 1 | Quitada la rama scrollable del `LayoutBuilder` de `EmptyState` | los 3 casos de desbordamiento | ✔ 3 fallos |
| 2 | Guard del menú vacío desactivado (`if (false)`) | el caso crítico | ✔ 2 fallos |
| 3 | Guard del menú **invertido** (`isNotEmpty`) | el caso crítico Y su contrario | ✔ 3 fallos (incluido `EL CONTRARIO`) |
| 4 | CTA de la lista renombrado a `Reintentar` | la aserción de 11-02 `find.text('Reintentar') findsNothing` | ✔ 2 fallos |
| 5 | Guía de la lista duplicando el titular | `findsOneWidget` del titular (trampa del doble match) | ✔ 2 fallos |
| 6 | `errorBuilder` retirado del router del cliente | 3 de los 5 casos de 404 | ✔ `+2 -3` |
| 7 | `uri.toString()` en vez de `uri.path` (cliente) | T-11-09-02 | ✔ 1 fallo |
| 8 | `context.go('/')` — **tal como decía el plan** | el botón de salida | ✔ 1 fallo |
| 9 | `errorBuilder` retirado del router del panel | 3 casos | ✔ 3 fallos |
| 10 | Guard de sesión del panel desactivado | los 2 casos de T-11-09-03 | ✔ 2 fallos |
| 11 | `uri.toString()` en el panel | T-11-09-02 | ✔ 1 fallo |

## Files Created/Modified

**Creados**
- `app_cliente/lib/features/shared/empty_state.dart` — `EmptyState({icono, titulo, guia, accion})`. `guia` es **obligatoria** a propósito.
- `app_cliente/lib/features/shared/not_found_screen.dart` y `panel_admin/lib/features/shared/not_found_screen.dart` — 404 gemelos, con los tokens de cada app.
- `app_cliente/test/pedidos/menu_vacio_test.dart` — 4 casos: el crítico, la no-regresión del AppBar/carrito, el desbordamiento en viewport corto y EL CONTRARIO.
- `app_cliente/test/router_404_test.dart` (5) y `panel_admin/test/router_404_test.dart` (6) — sobre el `GoRouter` REAL, no sobre la pantalla suelta.

**Modificados**
- `app_cliente/lib/features/pedidos/menu_mesa_screen.dart` — el guard crítico, ocupando solo el `body`.
- `app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart` — `EmptyState` + CTA `Actualizar`; `SliverFillRemaining` conservado.
- `app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart` — homogeneizado, copy del titular conservado.
- `app_cliente/lib/app.dart` y `panel_admin/lib/app.dart` — `errorBuilder`.
- `app_cliente/test/base_vacia_test.dart` — `TODO(11-09)` resuelto por endurecimiento.

## Decisions Made

- **`'/inicio'` y no `'/'` en el 404 del cliente.** Ver desviación 1. Es el único cambio respecto a la letra del plan y está cubierto por un test que falla si se revierte (rotura 8).
- **`NotFoundScreen` no reutiliza `EmptyState`.** `EmptyState` tiene tres ranuras; el 404 necesita una cuarta —la ruta pedida— con estilo propio y aislable por `find.text`. Además el panel no tiene `EmptyState` (crearlo allí queda fuera de mis `files_modified`) y las dos pantallas 404 deben ser simétricas. Lo que sí se conserva es el lenguaje visual: emoji a 40, gris de apoyo, botón primario.
- **`Actualizar`, no `Reintentar`.** `Reintentar` es la etiqueta del `_ErrorView`. Reutilizarla borraría la diferencia entre "no pude leer los datos" y "no hay datos", y además rompería la aserción de 11-02 (comprobado: rotura 4).
- **`mis_reservas_screen` y `pedido_estado_screen` NO se migraron.** El plan lo permitía solo si el cambio era 1:1 y sus tests seguían pasando sin editar aserciones. No es 1:1: `pedido_estado_screen` mete su acción en un `Center` con otra estructura, y migrarlos habría tocado archivos fuera de mis `files_modified` con dos ejecutores corriendo en paralelo. Se dejan como están.
- **Las dos apps se verificaron con el `GoRouter` REAL.** Pumpear `NotFoundScreen` suelta habría dado 11 tests verdes sin probar lo único que importaba: que el `errorBuilder` esté cableado y que el guard mande sobre él.

## Deviations from Plan

### 1. [Regla 1 - Bug en la instrucción del plan] `context.go('/')` habría dejado al usuario atrapado en la app cliente

- **Found during:** Tarea 2
- **Issue:** El plan indicaba, para las dos apps, «un botón que vuelve al inicio (`context.go('/')`)». Verificado en `app_cliente/lib/app.dart`: **esa app no tiene ninguna ruta `/`** — su `initialLocation` es `/inicio` y sus rutas son `/login`, `/register`, `/sesion/scan`, `/mesa`, `/restaurantes/:id`, `/reservas/wizard` y las 4 ramas del shell. El botón de salida del 404 habría caído en **otro 404**, que es peor que no tener botón. En el panel `/` sí existe (es el dashboard) y ahí el plan es correcto.
- **Fix:** `context.go('/inicio')` en el cliente, `context.go('/')` en el panel, con un test por app que afirma que tras el tap se llega a una pantalla REAL (`HomeScreen` / `DashboardScreen`) y que `NotFoundScreen` ya no está.
- **Verification:** Rotura 8 — restaurado el `context.go('/')` del plan, el caso «el botón de salida devuelve a una ruta REAL, no a otro 404» se pone en rojo.
- **Committed in:** `2840752`

### 2. [Regla 1 - Bug introducido por mí] `EmptyState` desbordaba el viewport

- **Found during:** Tarea 1, fase GREEN
- **Issue:** Al sustituir el `Text` gris suelto de la lista por un `EmptyState` (icono + titular + guía de varias líneas + botón), `base_vacia_test` empezó a fallar con `A RenderFlex overflowed by 4.0 pixels on the bottom`. Medido con una sonda temporal: en `flutter test` la fuente por defecto pinta cada carácter como un cuadro del tamaño de la fuente, así que el titular ocupa 144px y la guía 288px → 548px de contenido en 544 disponibles. El artefacto es de la fuente de test, **pero el defecto de fondo es real**: el widget nuevo es mucho más alto que el `Text` al que sustituye y en un teléfono corto, en landscape o con el texto ampliado por accesibilidad, desbordaría de verdad. Cambiar una pantalla en blanco por una banda amarilla y negra no arregla nada.
- **Fix:** `EmptyState` decide con un `LayoutBuilder`: con la altura **acotada** (body de un `Scaffold`, `SliverFillRemaining`) envuelve en `SingleChildScrollView`; con la altura **libre** (hijo de un `ListView`, que es el caso de `restaurante_detalle_screen`) no puede hacerlo, porque un viewport vertical con altura no acotada lanza. Se añadió el caso de test dedicado en viewport 360×480.
- **Verification:** Rotura 1 — quitada la rama scrollable, caen los 3 casos. La aserción **no** se relajó: `takeException()` sigue exigiéndose `isNull`.
- **Committed in:** `e5c921b`

### Fuera de alcance (NO tocado)

- **`app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart`** aparece modificado en el árbol: es un artefacto de `build_runner` regenerado por el ejecutor de 11-17. No está en mis `files_modified` y **no lo he stageado**.
- **`test/auth/*` y `lib/features/auth/*`** están siendo editados en vuelo por 11-17. Ver «Issues Encountered».

---

**Total deviations:** 2 auto-corregidas (ambas Regla 1). Ninguna reduce alcance; las dos amplían la cobertura.

## Mitigaciones del threat model aplicadas

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-09-02 (Information Disclosure — la URI en el 404) | **Mitigado y verificado** | Se pinta `uri.path` y nada más. Test por app que navega a `/no-existe?token=SECRETO-...&rid=demo#frag-SECRETO`, junta el `data` de **todos** los `Text` del árbol y afirma `contains('/no-existe')` + `isNot(contains('SECRETO'))` + `isNot(contains('token='))` + `isNot(contains('frag'))`. Roturas 7 y 11 lo confirman |
| T-11-09-03 (Spoofing — 404 alcanzable sin sesión) | **Mitigado y verificado** | El `redirect` se evalúa antes que el `errorBuilder`: sin sesión, `/ruta-que-no-existe` → `LoginScreen` en las dos apps. El panel añade el caso de **indistinguibilidad**: `/mesas` (existe) y `/ruta-que-no-existe` (no existe) dan la misma respuesta. Rotura 10 tumba los dos casos |

## Known Stubs

Ninguno. Los tres puntos que el plan señalaba sin guía quedan cubiertos y el `TODO(11-09)` heredado de 11-02 queda resuelto (era el último vivo: 11-05 ya había cerrado el del panel).

## Threat Flags

Ninguna superficie de seguridad nueva fuera del `<threat_model>` del plan. No se abre ningún endpoint, ninguna consulta a Firestore ni ninguna ruta nueva: el `errorBuilder` solo cambia qué se pinta cuando **ninguna** ruta casa, y queda por detrás del guard de sesión existente.

## Verificado vs. afirmado

**Verificado (por ejecución):**
- Que `menu_mesa_screen` con 0 categorías renderiza titular y guía, conserva AppBar y barra del carrito, y no deja excepción pendiente.
- Que el guard no se dispara cuando SÍ hay menú (caso contrario).
- Que `EmptyState` se hace scrollable con la altura acotada y no desborda en 360×480.
- Que el `errorBuilder` está cableado en los dos routers y que el guard de sesión manda sobre él.
- Que el query string y el fragmento no aparecen en ningún `Text` del árbol del 404.
- Que el botón de salida del 404 lleva a una pantalla real en las dos apps.

**Afirmado, NO verificado (requiere ojo humano):**
- **Que los textos se lean bien.** Un widget test prueba que una cadena se renderiza; no prueba que esté bien escrita, que el tono sea el adecuado ni que el usuario entienda qué hacer. Los copies nuevos no los ha leído nadie más que yo.
- **Que el estado vacío se VEA bien en un dispositivo real.** El espaciado se heredó del patrón existente y el desbordamiento está cubierto, pero nadie ha visto estas pantallas en un teléfono.
- **Que el emoji `🧭` del 404 se renderice** en Android/Chrome reales. En `flutter test` la fuente por defecto lo pinta como un cuadro, así que el test pasaría igual si el glifo faltara.
- **Que el 404 se alcance de verdad escribiendo una URL en el navegador** del panel. Los tests navegan con `router.go()`, que no ejercita la barra de direcciones ni el `<base href>` de Flutter Web.

## Issues Encountered

- **Ejecución en paralelo con 11-08 y 11-17.** La suite completa de `app_cliente` (`flutter test` a secas) sale en rojo con `+142 -7`, y `flutter analyze` llegó a reportar 22 issues. **Ninguno es mío**: los 22 issues estaban al 100% en `test/auth/google_signin_test.dart` y los 7 fallos en `test/auth/*`, archivos que 11-17 está editando en vuelo (`git status` confirma que no he tocado ni `lib/features/auth/` ni `test/auth/`). Ejecutados por separado, `test/auth` da `+50: All tests passed!` y todo lo demás `+99: All tests passed!`. Por eso el gate del cliente se reporta en dos mitades: es la medición honesta disponible mientras otro ejecutor tiene esos archivos abiertos. `panel_admin`, que nadie más toca, sí se pudo medir entero: `+163`.
- **`test:rules` y `test:functions` no se ejecutaron.** Dependen de los emuladores (puertos compartidos) y 11-08 está corriendo su suite e2e de Cloud Functions contra ellos: lanzarlos habría provocado colisión de puertos y ruido en los dos planes. Este plan **no toca** `firestore.rules`, `firestore.indexes.json` ni `functions/`, así que no tiene superficie sobre esos gates. Los dos gates estáticos que sí son seguros de correr en paralelo (`audit:indexes`, `audit:branding`) se ejecutaron y salen en 0.
- **`verify:shell` no se ejecutó**: exige `flutter build web --release` previo en las dos apps y, según 11-18, hay un `.dart_tool/flutter_build/` obsoleto que rompe ese build. Este plan no toca `web/`, ni el shell de carga, ni ningún asset.

## Next

- **11-10** hereda el `EmptyState` ya disponible por si necesita más estados vacíos en la app cliente.
- **Si el bloque de responsive/tokens corrige el desbordamiento del sidebar del `AppShell`**, hay que retirar el filtro de `A RenderFlex overflowed` de `panel_admin/test/router_404_test.dart` (mismo aviso que ya tenía `bootstrap_router_test.dart`).
- **Pendiente de verificación humana:** leer los copies nuevos y ver las pantallas en un dispositivo real.

## Self-Check: PASSED

- 12/12 archivos de `files_modified` existen en disco.
- 3/3 commits existen en el historial (`b1719ca`, `e5c921b`, `2840752`).
- `must_haves.artifacts`: `empty_state.dart` 96 líneas (min 30) ✔ · `not_found_screen.dart` 82 líneas (min 25) ✔.
- `must_haves.key_links`: `errorBuilder` en `app_cliente/lib/app.dart` ✔ · `categorias.isEmpty` en `menu_mesa_screen.dart` ✔.
