---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 25
subsystem: panel-admin (accesibilidad)
tags: [accesibilidad, a11y, wcag, contraste, semantics, shell-route, block-semantics, flutter, panel-admin]

# Dependency graph
requires:
  - plan: 11-21
    provides: "los 33 emojis del panel convertidos en `Icon` (un `Icon` acepta `semanticLabel`), `GriIcons`, `docs/ICONOS-panel_admin.md` y su gate de paridad archivo:línea"
  - plan: 11-12
    provides: "`core/theme.dart` como fuente única de color y `sin_hex_crudos_test.dart` (ningún arreglo puede introducir un hex suelto)"
  - plan: 11-11
    provides: "`GriSemanticColors.textoSecundarioAccesible` (#6E6E6E) DECLARADO y sin aplicar, y las dos guardas del token de marca"
  - plan: 11-24
    provides: "las filas de baja y readmisión de `/equipo`, que también necesitaban etiqueta"
  - plan: 11-14
    provides: "el gemelo en `app_cliente`: el método (romper el gate antes de confiar en él), el criterio `label` O `tooltip`, y el aviso de recalcular el ratio contra el fondo real"
provides:
  - "panel_admin/test/a11y/a11y_test.dart: 41 gates de accesibilidad del panel"
  - "MEDICIÓN Y ARREGLO: el sidebar y el topbar del panel NO existían en el árbol de semántica — `BlockSemantics` del `ModalBarrier` del Navigator interno del `ShellRoute` los descartaba enteros"
  - "GriColors.textoSecundarioAccesible (#6E6E6E) como `static const`, APLICADO en 57 puntos de TEXTO de 20 archivos"
  - "El tile del mapa de mesas se anuncia como BOTÓN con 'Mesa N, Estado, C personas'"
  - "Tooltip en los 8 ítems del sidebar COLAPSADO (y solo colapsado)"
  - "GATE ESTÁTICO: GriColors.gray prohibido en contexto de TEXTO en las fuentes de lib/"
  - "CENSO de contraste: el único fallo que queda en las 8 rutas es blanco sobre #FF4C05 (3.34)"
  - "MEDICIÓN: `textContrastGuideline` es CIEGA a todo nodo cuya etiqueta sea la fusión de varios `Text`"
affects: [11-16, 11-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toda pantalla montada dentro de un ShellRoute necesita un límite de semántica (`Semantics(container: true)`) alrededor del child, o el `BlockSemantics` de la barrera modal del Navigator interno se lleva por delante el chrome del shell"
    - "Antes de confiar en una guía de accesibilidad, comprobar que los nodos que dice juzgar EXISTEN: una guía verde sobre un árbol vacío no dice nada"
    - "Para dar nombre propio a un control cuyo texto visible es ambiguo (`Desactivar` en una tabla), `Semantics(label:…, excludeSemantics: true)` DENTRO del botón: se funde en el nodo del botón y no duplica el anuncio"
    - "El ratio de contraste se calcula con la fórmula WCAG dentro del test, contra el HEX literal y contra los DOS fondos de la app"
    - "Un censo de fallos ('los únicos que quedan son de este ratio') es más fuerte que excluir pantallas ruidosas: detecta el fallo NUEVO sin bloquear la deuda conocida"

key-files:
  created:
    - panel_admin/test/a11y/a11y_test.dart
  modified:
    - panel_admin/lib/core/theme.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_tile.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_legend.dart
    - panel_admin/lib/features/dashboard/widgets/stat_card.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/equipo/equipo_screen.dart
    - panel_admin/lib/features/equipo/staff_form_dialog.dart
    - panel_admin/lib/features/menu/menu_screen.dart
    - panel_admin/lib/features/mesas/mesas_screen.dart
    - panel_admin/lib/features/auth/login_screen.dart
    - panel_admin/lib/features/bootstrap/bootstrap_screen.dart
    - panel_admin/lib/features/clientes/clientes_screen.dart
    - panel_admin/lib/features/clientes/historial_dialog.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/cocina/widgets/pedido_card.dart
    - panel_admin/lib/features/configuracion/configuracion_screen.dart
    - panel_admin/lib/features/configuracion/restaurante_form_dialog.dart
    - panel_admin/lib/features/reportes/reportes_screen.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/lib/features/shared/error_box.dart
    - panel_admin/lib/features/shared/not_found_screen.dart
    - panel_admin/test/core/theme_tokens_test.dart
    - docs/ICONOS-panel_admin.md

key-decisions:
  - "11-25: HALLAZGO CENTRAL — el sidebar y el topbar del panel NO EXISTÍAN en el árbol de semántica. No es que estuvieran sin etiqueta: los 8 ítems de navegación, el logo, el título de la pantalla y el nombre del restaurante no producían ni un nodo. Causa medida: el `ShellRoute` monta el contenido sobre un Navigator propio, cuya ruta emite un `ModalBarrier` envuelto en `BlockSemantics`, que descarta la semántica de todo lo pintado ANTES y sube hasta el primer límite de semántica — y no había ninguno. Las TRES guías pasaban verdes sobre ese estado"
  - "11-25: el token NO se aplica a `bodySmall`/`labelSmall` del `textTheme` como pedía el plan. MEDIDO con dos colores testigo sobre las 8 pantallas: 0 de 277 párrafos se pintan por esos slots. Se aplica en los 57 puntos de TEXTO reales (20 archivos)"
  - "11-25: `GriColors.gray` conserva EXACTAMENTE #777777. Lo que cambia es DÓNDE se usa: 57 puntos de TEXTO pasan a #6E6E6E y el gris de marca se queda en los 7 `Icon`, donde WCAG 1.4.3 no aplica"
  - "11-25: `textContrastGuideline` solo evalúa un nodo si `find.text(etiqueta_del_nodo)` encuentra un `Text` con ESE contenido exacto (`accessibility.dart`). Todo nodo cuya etiqueta sea la fusión de varios `Text` —stat cards, tiles de mesa, filas de tabla— queda FUERA de la guía, antes y después de este plan"
  - "11-25: `androidTapTargetGuideline` SALTA todo nodo que toque el borde de un scrollable. Medido: los tiles de mesa que quedan a medio cortar miden 293×21 y la guía los ignora — no es un fallo, es su regla `_isAtBoundary`, pero significa que la guía no puede probar el tamaño de un elemento de lista"
  - "11-25: la paleta de MESAS no llega a AA para su etiqueta de estado (13px normal): disponible 3.98, ocupada 4.36, reservada 3.51; solo limpieza (4.69) cumple. Es la parte del sistema de diseño que la auditoría señalaba como bien ejecutada y el plan PROHÍBE tocarla: se mide, se fija en un test y se reporta como deuda"
  - "11-25: los `ListTile` del sheet de acciones de mesa YA tenían nombre accesible (su `title`). La premisa del plan («sin etiqueta») era falsa: se comprueba con la guía y se deja como gate de regresión en vez de envolverlos en `Semantics` por envolver"

patterns-established:
  - "Un gate de accesibilidad que solo mira conformidad puede estar mirando un árbol al que le falta media aplicación: los primeros casos de una suite a11y deben afirmar PRESENCIA"
  - "Comparar el color pintado contra el HEX literal, nunca contra el token: así cada caso falla por su propio motivo (el barrido por un punto de uso, la guarda por el token)"

requirements-completed: [DS-03]

# Metrics
duration: ~3h
completed: 2026-08-20
---

# Phase 11 Plan 25: Accesibilidad del panel admin Summary

**La barra de navegación del panel dejó de ser invisible para un lector de pantalla — literalmente:
los 8 ítems, el logo y el topbar no producían ni un nodo de semántica, y las tres guías oficiales de
Flutter pasaban verdes sobre ese estado. Además el mapa de mesas se anuncia ya como botón, el texto
secundario cumple AA sin mover un token de marca, y el único fallo de contraste que queda en las 8
rutas es el naranja de la marca, que requiere decisión del usuario.**

## Performance

- **Duración:** ~3 h
- **Tareas:** 3/3
- **Archivos:** 24 (1 creado, 23 modificados) — **23 de `panel_admin` + `docs/ICONOS-panel_admin.md`**
- **Roturas deliberadas:** 23 — **20 rojas como se esperaba, 1 verde esperada y 2 verdes
  INESPERADAS**, y las dos se convirtieron en corrección de código o de un comentario que afirmaba
  de más
- **Tests del panel:** 313 → **354** (+41). `flutter analyze`: **0 issues**

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Etiquetas — RED | 8 rojos, 6 verdes de partida | `66af0f7` |
| 1 | Etiquetas — GREEN | `+330`, analyze 0 | `90fa418` |
| 2 | Contraste — RED | no compila (falta la constante) | `1997ed0` |
| 2 | Contraste — GREEN | `+346`, analyze 0, `GRAY_INTACTO` | `f9cecf7` |
| 3 | Censo de contraste | `+354`, a11y `+41` | `4394136` |

## Gates ejecutados — salida REAL

| Gate | Resultado |
|---|---|
| `cd panel_admin && flutter analyze` (línea base) | `No issues found! (ran in 2.6s)` |
| `cd panel_admin && flutter test` (línea base) | `00:14 +313: All tests passed!` |
| `cd panel_admin && flutter analyze` (final) | `No issues found! (ran in 2.2s)` |
| `cd panel_admin && flutter test` (final) | `00:16 +354: All tests passed!` |
| `cd panel_admin && flutter test test/a11y/` | `00:03 +41: All tests passed!` |
| **T1 `<verify>` 2 del plan**, literal (`grep … \| wc -l` > 10) | `CUENTA CRUDA=12` → `ETIQUETAS_OK` — **defectuoso, ver Hallazgo 6** |
| **T2 `<verify>` 2 del plan**, literal (`grep -q "0xFF777777"`) | `GRAY_INTACTO` — y aquí **sí tiene dientes** (rotura M lo pone rojo), al revés que en 11-14 |
| `grep -rn "Semantics(\|tooltip:\|semanticLabel" panel_admin/lib \| wc -l` | **12** (9 sin comentarios). El mismo comando en `d71e403`, antes del plan: **7** |
| `git show --name-only` de los 5 commits ∩ `app_cliente/` | **0 archivos en los 5** |
| `cd scripts && npm run audit:branding` | `2 apps · 4 archivos · 0 rastros de plantilla`, exit 0 |
| `cd scripts && npm run audit:indexes` | `22 queries · 5 sujetas a paridad · 0 fallo(s)`, exit 0 |

`test:rules` y `test:functions` **NO se ejecutaron**: este plan no toca rules, índices ni functions.
`verify:shell` tampoco: exige `flutter build web --release` de LAS DOS apps y `app_cliente` estaba
siendo modificada por el ejecutor de 11-23 en el mismo árbol.

## Qué se arregló, con evidencia file:line

| Hallazgo | Antes | Ahora |
|---|---|---|
| `app_shell.dart` sidebar + topbar | **NO existían en el árbol de semántica** (0 nodos) | 8 ítems con nombre y acción, logo, título, subtítulo y nombre del restaurante |
| `app_shell.dart:415` sidebar colapsado | icono de 18px sin nada que lo identifique | `Tooltip` con el nombre, SOLO colapsado |
| `dashboard/widgets/mesa_tile.dart:52` | `InkWell` sin `Semantics`; se anunciaba «Mesa 4 / Ocupada / 4 personas» sin marca de botón | `Semantics(button: …, label: 'Mesa 4, Ocupada, 4 personas')` |
| `equipo_screen.dart:340` (filas de 11-24) | 10 botones «Desactivar» idénticos | «Desactivar a Zoe Mesera» / «Reactivar a Beto DeBaja» |
| `menu_screen.dart:168` | `tooltip: 'Editar categoría'` repetido por categoría | «Editar la categoría Platos fuertes» |
| `GriColors.gray` como color de texto | 4.478:1 sobre blanco, 4.141:1 sobre #F5F6F8 | 57 puntos a `#6E6E6E` (5.099:1 / 4.715:1) |

## Hallazgos

### 1. La navegación entera del panel era invisible para un lector de pantalla

No es «el sidebar colapsado no tiene etiqueta», que es lo que decía la auditoría. Es que **el
sidebar y el topbar no producían NI UN NODO** de semántica. Sonda sobre `GriApp` con el router
real, a 1280×900:

```
#13  size=1280.0x900.0  label=""          ← la ruta (scopesRoute)
 #14 size=1030.0x790.0  label=""          ← SOLO el contenido
   … 4 stat cards, la leyenda, 8 tiles de mesa …
```

Los 250px del sidebar y los 110 del topbar no aparecen. `tester.getSemantics(find.text('Mesas'))`
sobre el ítem del menú devolvía el nodo **raíz**: ese `Text` no tenía ningún nodo propio ni ninguno
por encima hasta la ruta.

Montando **el mismo `AppShell` suelto** (sin router) sí aparecen los 8 ítems, con su etiqueta y su
acción. La diferencia es el `ShellRoute`.

**Causa, medida y localizada en el SDK:** `ShellRoute` monta el `child` sobre un **Navigator
propio**. Toda ruta modal de un Navigator emite un `ModalBarrier`, que se construye dentro de
`BlockSemantics`. Ese widget pone
`SemanticsConfiguration.isBlockingSemanticsOfPreviouslyPaintedNodes = true`, y en
`rendering/object.dart` (`_RenderObjectSemantics.isBlockingPreviousSibling`) el bloqueo **sube por
el árbol hasta el primer `isSemanticBoundary`**:

```dart
if (configProvider.effective.isSemanticBoundary) {
  return false;   // aquí para de subir
}
```

Entre la barrera y la raíz no había ninguno, así que el descarte se llevó por delante a los
hermanos pintados antes: el sidebar (primer hijo del `Row`) y el topbar (hermano previo dentro del
`Column`).

El arreglo es un `Semantics(container: true)` alrededor de `widget.child`. No pinta, no ocupa
espacio y no cambia un píxel.

**Lo grave para la verificación:** con la navegación entera ausente, `androidTapTargetGuideline`,
`labeledTapTargetGuideline` y —en `/configuracion`— `textContrastGuideline` pasaban **VERDES**. Una
guía solo puede juzgar los nodos que existen. Es el mismo tipo de verde falso que documentó 11-14,
pero al revés: allí la guía medía **el nodo equivocado**; aquí medía **medio árbol**.

### 2. `textContrastGuideline` es ciega a todo nodo con etiqueta fusionada

La guía no evalúa un nodo por su rectángulo: primero busca un widget de texto cuyo contenido sea
**exactamente** la etiqueta del nodo (`accessibility.dart`):

```dart
final String text = data.label.isEmpty ? data.value : data.label;
final Iterable<Element> elements = find.text(text).hitTestable().evaluate();
```

Un nodo cuya etiqueta es `"Mesas disponibles\n3"` (stat card) o `"Mesa 4\nOcupada\n4 personas"`
(tile) no corresponde a ningún `Text`, así que `elements` sale vacío y **el nodo se salta entero**.
Esto era así antes de este plan y lo sigue siendo: los 4 stat cards, los 8 tiles y las filas de las
tablas nunca han pasado por la guía de contraste.

Consecuencia práctica para este plan: envolver el tile en `excludeSemantics` **no ocultó nada** que
la guía estuviera midiendo. Y consecuencia general: **un verde de `textContrastGuideline` no
significa que toda la pantalla cumpla**, solo que cumple lo que la guía sabe mirar.

### 3. `androidTapTargetGuideline` salta los elementos que tocan el borde de un scrollable

En el dashboard, tres tiles de mesa quedaban a medio cortar por el scroll y medían **293×21**. La
guía pasó verde: su regla `_isAtBoundary` descarta todo nodo cuyo rectángulo toque el borde de un
ancestro con `hasImplicitScrolling`, para no acusar a un elemento medio salido de pantalla.

Es una decisión razonable del SDK, pero significa que **esta guía no puede probar el tamaño táctil
de un elemento de lista**: basta con que el scroll lo corte. En el panel no había ningún control
por debajo de 48×48 (medido: los ítems del sidebar colapsado miden 50×54, el editar de categoría
48×48, los botones 48–56), así que **no se añadió ningún `constraints: BoxConstraints(minWidth: 48…)`
a nada** — habría sido una línea que no puede fallar.

### 4. `bodySmall` y `labelSmall` también son slots muertos en el panel

El plan mandaba aplicar el token accesible «solo en los slots de texto secundario pequeño del
`textTheme` (`bodySmall` / `labelSmall`)». Sonda con dos colores testigo (`#FF00FF` en `bodySmall`,
`#00FFFF` en `labelSmall`) recorriendo cada `RenderParagraph` de las 8 pantallas:

```
PARRAFOS /              total=55 bodySmall=0 labelSmall=0 gray777777=10
PARRAFOS /mesas         total=40 bodySmall=0 labelSmall=0 gray777777=3
… (8 rutas)
```

**0 de 277 párrafos.** Hacerlo habría cambiado 0 píxeles y arreglado 0 fallos de contraste. Es el
mismo resultado que midió 11-14 en `app_cliente`, por la misma razón: todo el texto del panel
declara su color inline.

### 5. La paleta de MESAS no llega a AA para su etiqueta de estado

Medido por primera vez en la fase, con la fórmula WCAG:

| Estado | Texto | Fondo | Ratio | ¿AA a 13px normal? |
|---|---|---|---|---|
| disponible | `#168A52` | `#E7F8F0` | **3.983** | ✗ |
| ocupada | `#C83C2E` | `#FFE9E6` | **4.358** | ✗ |
| reservada | `#AA7A00` | `#FFF5D8` | **3.514** | ✗ |
| limpieza | `#3167C9` | `#E9F0FF` | **4.694** | ✓ |

El «Mesa N» del tile (25 bold) sí cumple: su umbral es 3.0. La etiqueta de estado es de 13 normal y
tres de los cuatro estados no llegan. El «N personas» va con `alpha: 0.8`, lo que baja el ratio
efectivo a 2.64–3.32 en los cuatro.

La auditoría señala estos colores como la única parte del sistema de diseño bien ejecutada y el
plan **prohíbe tocarlos**. Se miden, se fijan en un test (si la paleta se mueve, el test se pone
rojo y obliga a revisar esta deuda) y se reportan abajo. **Requiere decisión del usuario.**

### 6. El `<verify>` de la Tarea 1 del plan es defectuoso — décimo de la fase

```
test $(grep -rn "Semantics(\|tooltip:\|semanticLabel" lib | wc -l) -gt 10 && echo "ETIQUETAS_OK"
```

Dos defectos, los dos comprobados:

1. **Cuenta comentarios.** De las 12 líneas que hacen `ETIQUETAS_OK`, **3 son comentarios** que
   nombran `Semantics(` al explicar el arreglo. Un plan que añadiera 5 líneas de comentario y ni un
   control pasaría el gate.
2. **No cuenta el entregable principal de la tarea.** El patrón busca `tooltip:` (minúscula, con
   dos puntos), así que **no ve** `Tooltip(message: label, child: item)` — que es justo lo que la
   tarea pedía poner en el sidebar colapsado.

Décimo gate de `grep` defectuoso de la fase (11-06, 11-08 ×2, 11-13 ×2, 11-19, 11-12, 11-14 y este).

En cambio el `<verify>` de la **Tarea 2** (`grep -q "0xFF777777" lib/core/theme.dart`) **sí tiene
dientes aquí**: la rotura M lo puso rojo. No por mérito del gate sino por casualidad del repo — en
`panel_admin/lib/core/theme.dart` ese hex aparece **una sola vez**, mientras que en `app_cliente`
aparecía también en `neutroFg` y por eso 11-14 lo declaró inútil. El gate comprueba «la cadena
existe en el archivo», no «ese token vale eso»; lo que protege de verdad es
`expect(GriColors.gray, const Color(0xFF777777))`.

### 7. Dos afirmaciones del plan y una mía que la medición no sostiene

- **«Los `ListTile` de acciones de mesa no tienen etiqueta»** (`mesa_actions_sheet.dart:122-132`):
  **falso**. Su `title` es un `Text` que se funde en el nodo del `ListTile`, así que ya se
  anunciaban «Marcar en limpieza», «Ver código QR», «Editar mesa». No se envolvieron en
  `Semantics`; se añadió el gate de regresión, y la rotura L (quitar el `title`) lo pone rojo.
- **`explicitChildNodes: true`** en el `Semantics` del shell: lo escribí y luego lo quité. La
  rotura B (quitarlo) deja los 41 casos en verde: el contenido de la ruta ya forma sus propios
  nodos, así que no hay nada que absorber. Era una línea que no puede fallar.
- **Mi propio comentario en `mesa_tile.dart`** decía que poner el `Semantics` **fuera** del
  `InkWell` dejaría el nodo pulsable sin etiqueta. La rotura I lo probó y es **falso**: con
  `container: true` por fuera, la acción de tap del `InkWell` se absorbe en ese contenedor y sale
  el mismo nodo único. El comentario se corrigió para decir lo que se midió.

## Roturas deliberadas (23)

### Tarea 1 — etiquetas (12)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | quitar el `Semantics(container:)` del shell | caen **5**: los 8 ítems (expandido y colapsado), los 7 pulsables, el topbar y los tooltips | ✔ |
| B | quitar solo `explicitChildNodes` | **verde** — línea que no puede fallar, se elimina | ✗ → Hallazgo 7 |
| C | quitar el `Tooltip` del sidebar colapsado | cae 1 | ✔ |
| D | `Tooltip` SIEMPRE (también expandido) | cae el caso anti-duplicación | ✔ |
| E | tile sin `button:` | cae «se anuncia como BOTÓN» | ✔ |
| F | tile sin `label:` (con `excludeSemantics`) | caen **4**: los dos del tile **y `labeledTapTargetGuideline` en `/` y `/mesas`** | ✔ |
| G | `/equipo` sin el nombre de la persona | cae 1 | ✔ |
| H | etiqueta del tile solo «Mesa 4» | caen 2 | ✔ |
| I | `Semantics` FUERA del `InkWell` | **verde** — el comentario afirmaba de más | ✗ → Hallazgo 7 |
| J | `tooltip: 'Editar categoría'` genérico | cae 1 | ✔ |
| K | `IconButton` de categoría **sin** `tooltip` | caen 2, incluida `labeledTapTargetGuideline` del menú | ✔ |
| L | `ListTile` del sheet sin `title` | cae el caso del sheet | ✔ |

### Tarea 2 — contraste (9)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| M | `GriColors.gray` → `#6E6E6E` (el atajo prohibido) | caen 12 — **y reveló que el barrido comparaba contra el TOKEN**; se cambió a hex literal (criterio de 11-12) | ✔ |
| M-bis | ídem, ya con hex literal | caen **exactamente 3**: las tres guardas del token. El barrido sigue verde, que es lo correcto | ✔ |
| N | token accesible → `#767676` (4.54 sobre blanco, 4.24 sobre el fondo) | caen 10, incluida la aserción del SEGUNDO fondo | ✔ |
| O | leyenda de mesas (pantalla MONTADA) de vuelta a gray | caen 2: barrido de `/` **y** gate estático | ✔ |
| P | 404 (pantalla NO montada) de vuelta a gray | cae **solo el gate estático** — el barrido es ciego | ✔ (reproduce el Hallazgo 3 de 11-14) |
| Q | `Icon` pintado con el token accesible | **verde, como debe ser** (un icono no es texto) | ✔ |
| R | `const sondaGrisSuelta = GriColors.gray;` en un contexto nuevo | `contexto DESCONOCIDO: clasifícalo` | ✔ |
| S | cambiar `mesaDisponibleFg` | cae el caso que fija la deuda de la paleta de mesas | ✔ |
| T | quitar el marcador `Icon(` del clasificador | **8 infracciones** — la clasificación no es decorativa | ✔ |

### Tarea 3 — censo (2)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| U | leyenda de vuelta a gray | `ratios de fallo en /: {3.34, 4.48}` → rojo | ✔ |
| V | texto del login de vuelta a gray | caen 2: gate estático **y** `textContrastGuideline` del login | ✔ |

## Deviations from Plan

### 1. [Rule 1 — el defecto real era mucho mayor que el descrito] `app_shell.dart` recibe un límite de semántica

- **Encontrado en:** Tarea 1, sondando el árbol antes de tocar nada.
- **Problema:** el plan pedía «Tooltip + etiqueta semántica» en el sidebar colapsado. Con el
  sidebar ausente del árbol, un `Tooltip` no habría llegado a ninguna parte: el arreglo prescrito
  habría sido invisible y la suite lo habría dado por bueno.
- **Resolución:** `Semantics(container: true)` alrededor del child del shell (Hallazgo 1), y
  ENCIMA el `Tooltip` que pedía el plan.
- **Commit:** `90fa418`.

### 2. [Rule 1 — el arreglo prescrito no arregla nada] El contraste NO se aplica en `textTheme`

- **Encontrado en:** Tarea 2.
- **Problema:** 0 de 277 párrafos se pintan por `bodySmall`/`labelSmall` (Hallazgo 4).
- **Resolución:** el token se aplica en los **57 puntos de uso reales** (20 archivos). Se respeta
  la INTENCIÓN escrita del plan al pie de la letra («`gray` se queda para bordes, iconos y
  decoración; el accesible va al texto»).
- **Archivos fuera de `files_modified`:** los 16 archivos de pantalla y diálogo que el plan no
  listaba. El plan asignaba la Tarea 2 a `core/theme.dart` **solo**.

### 3. [Rule 2] `GriColors.textoSecundarioAccesible` como `static const`

- 11-11 lo declaró como **campo de instancia** de `GriSemanticColors`, que no se puede leer dentro
  de un `const TextStyle` — y la mayoría de los 57 puntos lo son. Se añade la constante a
  `GriColors` y la extensión la **referencia**: un solo valor, dos caminos, con un test que afirma
  la igualdad. Misma desviación que 11-14 en `app_cliente`.

### 4. [Rule 2] Controles etiquetados que el plan no listaba

- El **editar de categoría** de `menu_screen` ya tenía `tooltip`, pero genérico: con dos categorías
  en pantalla no dice cuál. Pasa a nombrarla.
- Las **filas de acción de `/equipo`** (11-24) pasan a nombrar a la persona. El plan pedía
  «etiqueta»; tenerla no era el problema, distinguirlas sí.

### 5. [Rule 3] El archivo de tests se crea en la Tarea 1, no en la 3

El plan marca las Tareas 1 y 2 como `tdd="true"` pero no lista ningún archivo de test en ellas, y
asigna `test/a11y/a11y_test.dart` a la Tarea 3. Sin test no hay RED: el archivo se crea en el paso
rojo de la Tarea 1 y crece en cada tarea. Cada commit `test(...)` contiene **solo** tests, así que
en ese punto de la historia la suite está de verdad en rojo. Misma desviación que 11-14.

### 6. [Rule 3] `docs/ICONOS-panel_admin.md` refrescado

El gate de paridad de 11-21 comprueba que los `archivo:línea` de la tabla de iconos apuntan a donde
dicen. Mis cambios en `app_shell.dart` y `mesa_tile.dart` desplazaron 10 referencias y el gate se
puso rojo, como debe. Actualizadas.

### 7. `textContrastGuideline` no se acotó al camino crítico: se censó

El plan preveía que fuese «el gate más ruidoso» y autorizaba aplicarlo solo a login, dashboard,
mesas y equipo. Tras la Tarea 2 **no queda ni un fallo de gris en ninguna de las 8 rutas**, así que
acotar no habría servido de nada: lo que impide que la guía pase dentro del shell es el ítem ACTIVO
del sidebar, blanco sobre el naranja de marca, presente en **todas** las rutas.

En vez de excluir pantallas, la suite **censa**: recorre las 8 rutas y afirma que el conjunto de
ratios de fallo es exactamente `{3.34}`. Es más fuerte que excluir —un gris nuevo cambia el
conjunto y pone el caso rojo (rotura U)— y no bloquea la fase por una deuda que nadie puede
arreglar sin decisión del usuario. `textContrastGuideline` en su forma estricta se aplica al
**login**, que vive fuera del `ShellRoute` y pasa limpio.

## Deuda conocida (medida, NO corregida)

### 1. Blanco sobre el naranja de marca: 3.34:1 — en TODAS las rutas del panel

```
Expected contrast ratio of at least 4.5 but found 3.34 for a font size of 14.0.
```

Es `Colors.white` sobre `GriColors.primary` (`#FF4C05`). Aparece en:

- el **ítem activo del sidebar** (14 normal) — en las 8 rutas;
- el FAB **«Nueva mesa»** de `/mesas`;
- **«Consultar»** de `/reportes` y **«Nuevo usuario»** de `/equipo` (`ElevatedButton`, 14 normal).

Es exactamente la misma deuda que midió 11-14 en `app_cliente`, así que **es de plataforma, no de
app**. Pasa el umbral de texto GRANDE (3.0) y no el de normal (4.5): el botón del login, que usa
`GriText.boton` (16 bold), cumple. **Requiere decisión del usuario**: oscurecer el naranja de los
fondos de botón (toca la paleta BLOQUEADA) o subir esas etiquetas a 16 bold.

### 2. La paleta de mesas no llega a AA para su etiqueta de estado

Ver Hallazgo 5. Tres de los cuatro pares se quedan entre 3.51 y 4.36 para un texto de 13px normal,
y el «N personas» con `alpha: 0.8` baja a 2.64–3.32. Los cuatro superan el 3:1 de WCAG 1.4.11 para
objetos gráficos, así que **el punto de color de la leyenda sí cumple**. **Requiere decisión del
usuario**: oscurecer los cuatro `…Fg` (toca la paleta) o subir la etiqueta de estado a 18px / 14
bold.

### 3. Pantallas sin gate de guías

Ninguna de estas se monta en la suite, así que las guías no las cubren (el gate estático de color
sí, porque lee las fuentes): **bootstrap**, **404**, y los 7 diálogos —`mesa_form`, `qr_dialog`,
`categoria_form`, `producto_form`, `staff_form`, `restaurante_form`, `historial`—. `/cocina`,
`/reservas`, `/clientes`, `/reportes` y `/configuracion` sí entran en el censo de contraste y en el
barrido, pero no en las dos guías táctiles.

### 4. Deuda heredada que este plan NO tocó

- `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart` sigue regenerado y sin
  commitear (lo declararon 11-13, 11-19 y 11-14). **Este plan tampoco lo estageó**: no es suyo.
- Sigue en pie la discrepancia de contabilidad que señaló 11-19: 11-17 tiene SUMMARY pero no está
  en el checklist de `STATE.md`.

## Cambio visual: qué se movió y qué no

**Deliberado y acotado:**

| Qué | Antes | Ahora |
|---|---|---|
| Texto secundario (57 puntos, 20 archivos) | `#777777` | `#6E6E6E` |

**Lo que NO cambió:** `GriColors.gray` (sigue `#777777`), el naranja `#FF4C05`, los 12 colores de
mesa, los badges, los 7 iconos grises, los layouts, la tipografía, los tamaños y el espaciado.
`Semantics` no pinta ni ocupa espacio; los `Tooltip` aparecen en un overlay al pasar el ratón o
mantener pulsado.

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo):**

- Que los 8 ítems del sidebar, el logo, el título, el subtítulo y el nombre del restaurante
  **existen** en el árbol de semántica, expandido (1280) y colapsado (700).
- Que los 7 ítems no activos exponen acción de pulsar, y que el activo no (a propósito).
- Que colapsado cada ítem lleva `Tooltip` con su nombre, y que expandido **no** lo lleva.
- Que el tile del mapa de mesas se anuncia como **botón** y con «Mesa N, Estado, C personas», con
  el mapa **sembrado en tres estados distintos** para que ninguna aserción pase por construcción.
- Que las acciones de `/equipo` nombran a la persona y que el editar del menú nombra la categoría.
- Que el sheet de acciones de mesa anuncia sus tres acciones.
- Que `/`, `/mesas`, `/equipo`, el panel colapsado, el menú y el sheet cumplen
  `androidTapTargetGuideline` y `labeledTapTargetGuideline`.
- Que el login cumple **las tres** guías.
- Que ningún párrafo de las 8 rutas se pinta con `#777777` (con canario de párrafos vistos y de
  párrafos con el token nuevo, por ruta).
- Que `GriColors.gray` no aparece en ningún contexto de TEXTO en las fuentes de `lib/`, con
  autocomprobación de cobertura y reporte de contextos no clasificados.
- Que el token accesible cumple sobre **los dos** fondos del panel, no solo sobre blanco.
- Que `GriColors.gray` sigue valiendo `#777777` y que los dos caminos al token accesible dan el
  mismo valor.
- Que el único ratio de fallo de contraste que queda en las 8 rutas es `3.34`.

**Afirmado, NO verificado:**

- **Que un lector de pantalla lea bien el panel.** `meetsGuideline` mide geometría y ratios sobre
  el árbol; no ejecuta NVDA, JAWS ni VoiceOver. En particular **no está comprobado** que el orden
  de lectura tenga sentido ahora que el sidebar vuelve a existir, ni que el nombre que viaja por el
  campo `tooltip` (los 8 ítems colapsados y el editar de categoría) se anuncie como se espera en un
  navegador real.
- **Que el gris nuevo se VEA bien.** Es el único cambio de color del plan, afecta a 57 puntos y no
  se ha fotografiado: este repo no tiene golden tests. `#6E6E6E` vs `#777777` son 9 niveles por
  canal.
- Que el `Tooltip` del sidebar colapsado sea buena UX con ratón (aparece al pasar por encima).
- Que el panel cumpla WCAG AA **entero**. Lo verificado son 8 rutas más login, menú y sheet, con
  las salvedades de los Hallazgos 2 y 3: la guía de contraste no mira los nodos con etiqueta
  fusionada y la táctil no mira lo que toca el borde de un scroll.

## Pendiente de verificación humana

1. **Que un lector de pantalla recorra el panel en un orden con sentido** ahora que el sidebar y el
   topbar vuelven a estar en el árbol. Es lo único que cierra de verdad el hallazgo.
2. **Decisión sobre la deuda 1:** blanco sobre `#FF4C05` a 14 normal no llega a AA, y afecta al
   ítem activo del sidebar en todas las pantallas. Es la MISMA deuda que reportó 11-14 en la app
   cliente.
3. **Decisión sobre la deuda 2:** la etiqueta de estado del tile de mesa (13px) no llega a AA en 3
   de los 4 estados.
4. **Que el gris nuevo `#6E6E6E` se vea bien** en las 12 pantallas del panel.

## Notas para quien siga

- **Quien monte una pantalla nueva dentro del `ShellRoute`:** el `Semantics(container: true)` de
  `app_shell.dart` es lo que mantiene vivo el chrome del shell en el árbol de semántica. No lo
  quites; si tienes que mover ese `Expanded`, comprueba con una sonda que los 8 ítems siguen
  apareciendo antes de fiarte de que las guías estén verdes.
- **Quien escriba un test de contraste:** `textContrastGuideline` no mira los nodos con etiqueta
  fusionada (Hallazgo 2). Si necesitas cubrir una tarjeta o una fila de tabla, calcula el ratio con
  la fórmula WCAG, como hacen los casos de la paleta de mesas.
- **Quien cierre la fase:** el `<verify>` `grep … | wc -l -gt 10` de la Tarea 1 de este plan no
  protege nada (Hallazgo 6). El de la Tarea 2 sí funciona aquí, pero por casualidad del repo.

## Self-Check: PASSED

- `panel_admin/test/a11y/a11y_test.dart` — FOUND (872 líneas, mínimo exigido 40)
- Commits `66af0f7`, `90fa418`, `1997ed0`, `f9cecf7`, `4394136` — FOUND
- `flutter test` **+354**, `flutter analyze` **0 issues**, `flutter test test/a11y/` **+41**
- 0 archivos de `app_cliente/` en los 5 commits
