---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 13
subsystem: ui
tags: [responsive, safe-area, overflow, iconografia, material-icons, flutter, app_cliente]

# Dependency graph
requires:
  - phase: 11-09
    provides: "EmptyState (su parámetro `icono` pasa aquí de String a IconData) y el 404 propio"
  - phase: 11-11
    provides: "GriBreakpoints / GriColors / griTheme y el gate de paridad token↔código del AppShell"
  - phase: 11-17
    provides: "el botón de Google en las pantallas de auth (no se toca)"
provides:
  - "AppShell del cliente con SafeArea(bottom: false) — cierra el bug del espacio superior"
  - "Ancho adaptativo: <480 libre / 480-839 contenidoMax / >=840 contenidoMaxAmplio (720)"
  - "GriBreakpoints.contenidoMaxAmplio = 720 (único valor nuevo de design_tokens.dart)"
  - "GriIcons: 15 iconos semánticos de la app cliente en un solo archivo"
  - "iconoInline(): WidgetSpan para los iconos que viven DENTRO de una frase"
  - "test/core/sin_emojis_test.dart: gate contra la reaparición de emojis"
  - "test/shared/app_shell_responsive_test.dart: primera red de seguridad del shell del cliente"
  - "docs/ICONOS-app_cliente.md"
affects: [11-14, 11-19]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "El techo de ancho del shell es ADAPTATIVO, no una jaula fija: el tramo 0-840px queda idéntico al anterior y solo se relaja por encima"
    - "Iconografía centralizada en GriIcons, nombrada por SIGNIFICADO; el `size` del Icon iguala el `fontSize` del Text sustituido"
    - "Emoji dentro de una frase -> WidgetSpan (iconoInline), no Row: conserva el salto de línea del párrafo"
    - "Gate de código con dart:io que salta comentarios y admite exención en línea `// EMOJI-OK: motivo`"
    - "La geometría del shell se afirma midiendo rectángulos reales (getRect), no buscando widgets"

key-files:
  created:
    - app_cliente/lib/core/gri_icons.dart
    - app_cliente/lib/features/shared/icono_inline.dart
    - app_cliente/test/shared/app_shell_responsive_test.dart
    - app_cliente/test/core/sin_emojis_test.dart
    - app_cliente/test/restaurantes/iconos_test.dart
    - docs/ICONOS-app_cliente.md
  modified:
    - app_cliente/lib/features/shared/app_shell.dart
    - app_cliente/lib/core/design_tokens.dart
    - app_cliente/lib/features/reservas/reserva_wizard_screen.dart
    - app_cliente/lib/features/shared/empty_state.dart
    - app_cliente/lib/features/restaurantes/home_screen.dart
    - app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/features/reservas/mis_reservas_screen.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/auth/login_screen.dart
    - app_cliente/lib/features/perfil/perfil_screen.dart
    - app_cliente/lib/features/pagos/calificacion_sheet.dart
    - app_cliente/lib/features/sesion_qr/scan_screen.dart
    - app_cliente/test/core/theme_tokens_test.dart
    - app_cliente/test/reservas/wizard_form_test.dart
    - app_cliente/test/pedidos/cuenta_test.dart

key-decisions:
  - "11-13: `SafeArea(bottom: true)` en el AppShell es un NO-OP, no un bug. MEDIDO con sonda: el Scaffold ya pone `padding.bottom` a 0 en el MediaQuery del body cuando hay bottomNavigationBar. El `bottom: false` se conserva como documentación de intención, y la aserción que lo 'protegía' se reescribió porque no podía fallar"
  - "11-13: el ConstrainedBox del shell NO se borra, se convierte en techo adaptativo. De 0 a 840px el ancho es idéntico al de antes (mitigación de T-11-13-01); solo por encima de 840 pasa de 480 a 720"
  - "11-13: el gate de paridad token↔código de 11-11 se REESCRIBE (su propio comentario lo pedía): ya no hay literal que comparar, así que ahora afirma que NO vuelve ninguno y que los tres tokens se usan. El gate fuerte es el que renderiza y mide"
  - "11-13: la fuente por defecto de `flutter test` pinta cada glifo como un cuadrado de fontSize, así que el texto mide ~2x lo que mide en Roboto real. Un barrido de overflow a 320px produce FALSOS POSITIVOS y hay que medir el texto antes de creerlos"
  - "11-13: la regla que separa 'icono' de 'texto expresivo' es la PERSISTENCIA del elemento: chip/tab/tarjeta/estado vacío/metadatos de fila -> icono; SnackBar o frase conversacional -> texto. Es lo que explica que `✓` se sustituya y `✅` no"
  - "11-13: un emoji dentro de una frase se traduce con `WidgetSpan`, no con `Row`. El Row cambia el comportamiento del salto de línea y con dos iconos en la misma frase exigiría anidar"

patterns-established:
  - "Todo `Icon` de la app cliente sale de `GriIcons`; un `Icons.x` suelto es deuda"
  - "Antes de dar por bueno un desbordamiento medido en `flutter test`, comprobar el ancho del texto con un TextPainter: la fuente de test infla ~2x"
  - "Una aserción que sobrevive a la rotura de lo que dice proteger se reescribe o se borra; no se deja verde"

requirements-completed: [DS-02, DS-03]

# Metrics
duration: ~110min
completed: 2026-08-19
---

# Phase 11 Plan 13: Todo lo visible de la app cliente Summary

**El contenido del cliente deja de arrancar debajo del notch, deja de vivir encajado en una
columna de 480px a cualquier ancho, deja de desbordar con nombres de restaurante largos y deja de
dibujar su interfaz con glifos que cambian de forma según el sistema operativo.**

## Performance

- **Duración:** ~110 min
- **Tareas:** 3/3
- **Archivos:** 23 (6 creados, 17 modificados)
- **Roturas deliberadas:** 21 aplicadas y revertidas — **2 dejaron la suite en verde** y las dos
  se convirtieron en hallazgo (una en aserción reescrita, otra en decisión documentada)

## Accomplishments

- **El bug que reportó el usuario está cerrado con una medición, no con una impresión.** El
  `AppShell` monta el body dentro de `SafeArea(bottom: false)`; con un `padding.top` de 44px el
  contenido arranca en `dy >= 44` y con `padding.top: 0` arranca en `dy == 0` (no se inventa
  margen en los dispositivos sin notch).
- **La app deja de ser una tira de 480px en el navegador.** El `ConstrainedBox` fijo pasa a techo
  adaptativo, con el tramo **0–840px idéntico al anterior** — afirmado a 360, 600 y **839**, el
  borde exacto.
- **El shell tiene por primera vez red de seguridad.** Ninguno de los 178 tests previos montaba
  `AppShell`: pumpeaban pantallas sueltas. Ahora hay 17 casos de geometría real sobre él.
- **El desbordamiento del wizard está cerrado y el barrido encontró dos más.** Y el barrido no se
  quedó en las pantallas que el plan pedía: **la suite ENTERA corre a 320px sin un solo
  `RenderFlex overflowed`** (validado con un canario, para que «cero desbordes» no signifique
  «el barrido no miraba»).
- **La interfaz del cliente ya no depende de la fuente de emoji del sistema.** 37 sustituciones en
  10 pantallas, con el `size` de cada icono igual al `fontSize` del `Text` que sustituyó, 5
  emojis expresivos conservados con su motivo escrito al lado y un gate que impide que vuelvan.
- **Sin regresiones:** `flutter analyze` **0 issues**; **178 → 206 tests** (+28).
- **Cero archivos de `panel_admin` en los 7 commits** (comprobado commit a commit): el plan gemelo
  11-21 pudo correr en paralelo sin conflicto.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Zona segura + shell adaptativo — RED | no compila (falta el token) | `85f0f45` |
| 1 | Zona segura + shell adaptativo — GREEN | `+193`, analyze 0 | `81323f5` |
| 2 | Overflow del wizard — RED | 3 casos rojos, 41/616/776px medidos | `6207ded` |
| 2 | Overflow del wizard — GREEN | `+196`, analyze 0 | `f5b6049` |
| 2 | Dientes para el `textAlign.end` | rotura N pasa a tumbar el caso | `a0a83d9` |
| 3 | Gate anti-emojis — RED | 42 líneas infractoras | `da167b8` |
| 3 | Emojis → iconos — GREEN | `+206`, analyze 0 | `65c1c17` |

## Gates ejecutados — salida real

| Gate | Resultado |
|---|---|
| `cd app_cliente && flutter analyze` | `No issues found!` |
| `cd app_cliente && flutter test` | `00:10 +206: All tests passed!` (base 178) |
| `flutter test test/shared/app_shell_responsive_test.dart` | `+17` |
| `flutter test test/reservas/` | `+20` |
| `flutter test test/core/sin_emojis_test.dart` | `+2` |
| `flutter test test/restaurantes/iconos_test.dart` | `+4` |
| Suite COMPLETA forzada a 320px (`flutter_test_config.dart` temporal) | `+206`, **0** `overflowed by` |
| `test $(grep -c "^\|" docs/ICONOS-app_cliente.md) -ge 10 && …` | `TABLA_ICONOS_OK` (64 filas) |
| `git diff-tree` por commit, buscando `^panel_admin/` | **0** en los 7 commits |

`test:rules`, `test:functions`, `audit:indexes` y `audit:branding` **NO se ejecutaron**: este plan
no toca rules, índices, functions ni assets de marca, y `panel_admin` estaba en vuelo con 11-21.

## Roturas deliberadas (21)

### Tarea 1 — shell (11)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | quitar el `SafeArea` (estado anterior al plan) | cae «con notch de 44px el contenido NO empieza en y=0» | ✔ |
| B | `bottom: false` → `bottom: true` | **suite ENTERA en verde** — ver Hallazgo 1 | ✗ |
| C | techo fijo de 480 otra vez | caen el caso de 1200px y la paridad | ✔ |
| D | sin techo (equivale a borrar el `ConstrainedBox`) | caen 600, 839, 1200, 1600 y la paridad | ✔ |
| E | salto en `compact` (600) en vez de `expanded` (840) | caen 600 y 839 | ✔ |
| F | `contenidoMaxAmplio` igualado a `contenidoMax` | caen el caso de 1200 y el del token | ✔ |
| G | margen fijo de 44 en vez de `SafeArea` | caen «padding.top 0 no inventa hueco» y la no-duplicación | ✔ |
| H | literal `480` de vuelta en el `ConstrainedBox` | cae la paridad reescrita | ✔ |
| I | `Scaffold` ENTERO envuelto en `SafeArea` | caen «el inset se lo queda la barra» y «sin banda muerta» | ✔ |
| J | banda muerta de 34px bajo el contenido | cae «sin banda muerta» | ✔ |
| K | quitar la `BottomNavigationBar` | cae el caso MEDIDO del inset inferior + los 3 de navegación | ✔ |

D y H son los que demuestran que el gate de paridad reescrito **encuentra el literal de verdad** y
no está verde porque su regexp no case nada.

### Tarea 2 — wizard (5)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| L | sin `Expanded` (estado anterior) | caen los 3 casos nuevos | ✔ |
| M | `Expanded` pero sin `ellipsis` | caen 2 | ✔ |
| N | sin `textAlign.end` | **suite ENTERA en verde** — ver Hallazgo 2 | ✗ → ✔ tras reescribir |
| O | dropdown sin `isExpanded` | caen los 2 casos de 320px | ✔ |
| P | controles de vuelta a `Row` | caen los 2 casos de 320px | ✔ |

### Tarea 3 — iconos (8, incluidas 2 que NO deben romper)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| Q | botón QR encogido a 40x40 | cae el caso de los 45x45 | ✔ |
| R | icono QR de 22 a 18 | cae el mismo caso | ✔ |
| S | `escanearQr` → `Icons.camera_alt` | cae «no una cámara» | ✔ |
| T | estrella con `#F5A624` (1 dígito de diferencia) | cae el caso del color de marca | ✔ |
| U | logo sin `semanticLabel` | cae el caso de la etiqueta accesible | ✔ |
| V | tab con `color: pink` propio | cae «el color lo pone la barra» | ✔ |
| W | tab con otro `IconData` | caen 3 casos del shell | ✔ |
| X | emoji NUEVO en un literal renderizado | cae `sin_emojis_test` | ✔ |
| Y | emoji nuevo en un COMENTARIO | **verde, como debe ser** | ✔ |
| Z | emoji nuevo con `// EMOJI-OK:` | **verde, como debe ser** | ✔ |

## Hallazgos

### 1. `SafeArea(bottom: true)` es un NO-OP aquí: la premisa «no negociable» del plan es falsa

El plan lo declaraba innegociable: *«`SafeArea(bottom: false)` — la `BottomNavigationBar` del
`Scaffold` ya gestiona el inset inferior; duplicarlo añade un hueco visible»*. La primera mitad es
cierta; la segunda **no**.

La rotura **B** (`bottom: false` → `bottom: true`) dejó la suite entera en verde. En vez de
aceptar el verde, se midió con una sonda:

```
PADDING EN EL BODY -> top=44.0 bottom=0.0
```

El `Scaffold` **ya pone `padding.bottom` a 0** en el `MediaQuery` del body cuando declara
`bottomNavigationBar`. Un `SafeArea(bottom: true)` ahí dentro no tiene inset que aplicar: no puede
añadir hueco. `bottom: false` es **documentación de intención**, no un arreglo.

Consecuencia: la aserción «no hay hueco extra por abajo» **no podía fallar por el motivo que
decía**. Se sustituyó por tres casos que sí tienen dientes:

1. no hay banda muerta entre el contenido y la barra (rotura J ✔);
2. la barra **crece exactamente el inset** de la barra de gestos — se rompe si alguien envuelve el
   `Scaffold` entero en un `SafeArea` (rotura I ✔);
3. **MEDIDO**: dentro del body el inset inferior ya viene consumido. Este caso es el que convierte
   el hallazgo en protección: si el shell perdiera la `BottomNavigationBar`, `bottom: false`
   pasaría a ser un bug real (contenido bajo la barra de gestos) y el caso se pone rojo
   (rotura K ✔).

### 2. Una aserción que no veía el `textAlign` porque medía la caja, no los glifos

Quitar `textAlign: TextAlign.end` del resumen del wizard (rotura **N**) dejó la suite en verde.
Motivo: con el `Expanded`, la **caja** del párrafo ocupa todo el hueco libre tanto si el texto se
alinea a la derecha como a la izquierda, así que ni `getRect` del `Text` ni el de la fila lo ven.

Se corrigió leyendo la posición de los **glifos** dentro de la caja
(`RenderParagraph.getBoxesForSelection`) y afirmando que terminan donde termina la caja. La misma
rotura ahora tumba el caso. *(De paso, corrige lo que yo mismo había escrito en un comentario: un
widget test **sí** puede afirmar la posición de un glifo.)*

### 3. La fuente de `flutter test` infla el texto ~2x y produce falsos desbordamientos

El barrido a 320px destapó dos overflows más allá del `_ResumenRow`. Antes de darlos por buenos se
midieron con un `TextPainter`:

| Texto | Ancho en `flutter test` | Roboto real (aprox.) |
|---|---|---|
| «Elige una hora» @16 | **224px** | ~105px |
| «Continuar» @14 | **126px** | ~68px |
| Nombre de 60 caracteres @14 | **840px** | ~420px |

La fuente de test pinta cada glifo como un cuadrado de `fontSize` exacto. Conclusión honesta:

- el desbordamiento de `_ResumenRow` es **REAL con cualquier fuente** (840px de texto en ~170px de
  hueco a 320, y ~330px a 480): es el que veía el usuario;
- los otros dos (`DropdownButtonFormField` de la hora, 82px; controles del `Stepper`, 41px)
  **NO son reproducibles con Roboto a 320px hoy**, pero sí aparecen con el texto ampliado por
  accesibilidad. Se arreglaron igualmente (`isExpanded: true` y `Wrap`), y aquí queda escrito que
  no eran visibles todavía. **No se han «arreglado» inflando la afirmación.**

### 4. El `grep` de inventario que proponía el plan se dejaba fuera `⭐`

`[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]` **no cubre `U+2B50`**, así que no veía las 4 apariciones
de `⭐` — una de las filas de la propia tabla de equivalencias del plan. El total real es **54**
apariciones, no las ~46 que estimaba. `sin_emojis_test.dart` añade `U+2B00–U+2BFF` y
`U+1F000–U+1F2FF`, y tiene un caso que afirma explícitamente que `⭐` entra y que la flecha `→` de
los mensajes de dominio **no**.

Es el cuarto gate de `grep` defectuoso que encuentra esta fase (11-06, 11-08 ×2, y este).

### 5. El gate `<verification>` del plan da un falso positivo

`grep -rn "RenderFlex overflowed" app_cliente/test` **encuentra un resultado** y aun así no hay
ningún filtro activo: lo que casa es un comentario explicativo dentro de un `reason:` del test
nuevo. El gate confunde «hay un filtro» con «alguien menciona la frase». La comprobación que sí
vale es buscar `FlutterError.onError`, `takeException()` usados para tragar, o
`startsWith('A RenderFlex')` — de los cuales `app_cliente` no tiene ninguno.

### 6. El gate de paridad de 11-11 se rompía con el cambio, y su autor lo había previsto

`theme_tokens_test.dart` afirmaba que el `AppShell` contenía **exactamente**
`BoxConstraints(maxWidth: 480)`. Al pasar el ancho a un `LayoutBuilder` ya no hay literal, así que
el gate quedaba ciego («no se encontró ningún `BoxConstraints`»). El propio comentario del test
decía qué hacer: *«hay que reescribirlo, no borrarlo»*. Reescrito: ahora afirma que **no vuelve
ningún literal** y que los tres tokens se mencionan (roturas D y H ✔). El gate fuerte —el que
renderiza y mide el ancho efectivo a 3 anchos— es el nuevo del shell.

## Deviations from Plan

### 1. [Rule 3 — Bloqueante] `GriBreakpoints.contenidoMaxAmplio` añadido a `design_tokens.dart`

- **Encontrado en:** Tarea 1
- **Problema:** el plan escribía `720` como literal en el `app_shell`, pero 11-11 dejó un gate que
  prohíbe literales de ancho en ese archivo.
- **Resolución:** el 720 se declara como token. `GriBreakpoints` es explícitamente **propio de cada
  app** (la cabecera del archivo lo dice), así que no rompe la sincronización con el panel.
  `design_tokens.dart` no estaba en `files_modified`.

### 2. [Rule 3 — Bloqueante] `test/core/theme_tokens_test.dart` reescrito (archivo de 11-11)

- **Encontrado en:** Tarea 1 — ver Hallazgo 6. No estaba en `files_modified`.

### 3. [Rule 1 — Aserción sin dientes] La comprobación del inset inferior, reescrita

- **Encontrado en:** Tarea 1, por la rotura B — ver Hallazgo 1.
- **Resolución:** 1 caso sustituido por 3, uno de ellos con el hallazgo escrito en el `reason`.
  **No se rebajó ninguna afirmación para que pasara**: se cambió lo que se afirma por algo que la
  rotura puede tumbar.

### 4. [Rule 1 — Bug] Dos desbordamientos más en el wizard, fuera del `_ResumenRow`

- **Encontrado en:** Tarea 2, en el barrido.
- **Resolución:** `isExpanded: true` en el `DropdownButtonFormField` de la hora y `Wrap` en lugar
  de `Row` para los controles del `Stepper` (un `Row` no puede encoger un botón, así que no
  bastaba un `Expanded`). Los dos son del mismo tipo que el plan autorizaba a arreglar. Su alcance
  real está acotado en el Hallazgo 3.

### 5. [Rule 3] `tester.view.padding` en vez de un `MediaQuery` envolvente

- **Encontrado en:** Tarea 1
- **Problema:** el plan pedía `MediaQuery(data: MediaQueryData(padding: …), …)`, pero
  `MaterialApp.router` reconstruye el `MediaQuery` desde la `FlutterView`, así que uno colocado por
  fuera no llega al shell: el inset se perdería y el test pasaría por el motivo equivocado.
- **Resolución:** `tester.view.padding = FakeViewPadding(...)`, que es el mecanismo real. El
  motivo está escrito en la cabecera del test.

### 6. [Rule 3] Archivos tocados fuera de `files_modified`

`empty_state.dart` (su `icono` pasa de `String` a `IconData`; el plan lo implicaba al listar los
`EmptyState` con emoji pero no nombraba el archivo), `test/pedidos/cuenta_test.dart` (finder del
`✓`), y los tres creados que el plan no listaba: `features/shared/icono_inline.dart`,
`test/restaurantes/iconos_test.dart`.

### 7. `_ActionCard.emoji` renombrado a `icono`

Cambio de tipo `String` → `IconData` en un widget privado de `home_screen.dart`. Sin él, el
parámetro seguiría llamándose `emoji` conteniendo un `IconData`.

### 8. Los tabs NO alternan icono relleno al activarse

El plan proponía `Icons.home_outlined` / `Icons.home` según el estado. La
`BottomNavigationBar` de esta app declara **un solo** `icon` por item (sin `activeIcon`); añadirlo
sería un cambio de aspecto, no una sustitución, y la identidad visual está BLOQUEADA. El estado
activo lo sigue comunicando el color, exactamente como antes. Documentado en
`docs/ICONOS-app_cliente.md`.

## Cambio visual: qué se movió y qué no

**Deliberado y acotado:**

| Qué | Antes | Ahora |
|---|---|---|
| Origen vertical del contenido | y=0 (bajo el notch) | por debajo del inset del sistema |
| Ancho del contenido a **≥840px** | 480 | 720 |
| Ancho del contenido de **0 a 839px** | igual | **igual** (afirmado a 360/600/839) |
| Valor largo del resumen del wizard | desbordaba (banda amarilla) | ellipsis, misma tipografía y espaciado |
| 37 emojis de interfaz | glifo de la fuente del sistema | `Icon` de Material, mismo tamaño y color |

**El único color NUEVO de todo el plan** es el `GriColors.gray` de los iconos de estado vacío y de
las ramas de error. Un emoji trae sus colores de la fuente y no había nada que preservar, así que
*cualquier* color habría sido una decisión. Se eligió el del texto guía que ya estaba al lado.
Queda **pendiente de verificación humana** (declarado también en `docs/ICONOS-app_cliente.md`).

**Lo que NO cambió:** la paleta `#FF4C05`, el ámbar `#F5A623` de la calificación, los layouts, el
orden de los elementos, los tamaños de los contenedores, el `padding` del `GoogleBoton` de 11-17 y
las 3 pantallas que ya traían `SafeArea` propio (no se tocó ninguna: el test demuestra que no
duplican).

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo):**

- Que el contenido no arranca bajo un `padding.top` de 44px, y que con 0 no se inventa hueco.
- Que una pantalla con `SafeArea` propio dentro del shell empieza en 44 y no en 88.
- Que la barra inferior absorbe el inset de gestos (crece exactamente 34px) y que no queda banda
  muerta entre contenido y barra.
- Que el ancho efectivo es 360 / 480 / 480 / 720 / <1600 a 360 / 600 / 839 / 1200 / 1600px.
- Que el `goBranch` y el índice activo funcionan en los tres anchos.
- Que `_ResumenRow` no desborda a 320 con 60 caracteres, que recorta con ellipsis, que no invade la
  etiqueta y que los **glifos** siguen pegados a la derecha.
- Que la **suite entera** corre a 320px sin un solo `RenderFlex overflowed` (con canario que
  demuestra que el barrido no está ciego).
- Que los 4 tabs son `Icon` de `GriIcons`, a `size` 20, sin color propio, y que en la barra solo
  quedan los 4 `Text` de las etiquetas.
- Que el botón QR conserva 45x45 e icono a 22, que la estrella es `#F5A623` a 14 y que el logo
  lleva `semanticLabel`.
- Que no reaparece un emoji en un literal renderizado, que los de comentarios no cuentan y que la
  exención `// EMOJI-OK:` funciona.

**Afirmado, NO verificado:**

- **Que las pantallas se VEAN bien.** Un widget test mide rectángulos y compara `IconData`; no ve
  la pantalla. Ni el shell ni un solo icono se han visto renderizados en un dispositivo o
  navegador real.
- Que 720 sea el ancho correcto para escritorio. Es 1.5 × `contenidoMax` y queda por debajo del
  salto `expanded`; **no** sale de un diseño.
- Que `Icons.soup_kitchen_outlined` se lea como «la cocina está preparando tu pedido» y
  `Icons.sensors` como «en vivo». Son las dos equivalencias menos evidentes de la tabla.
- Que los `archivo:línea` de `docs/ICONOS-app_cliente.md` sigan siendo correctos: se recogieron con
  `grep` al escribirlos y se desactualizarán en cuanto 11-19 mueva código.
- Que las 3 pantallas del flujo de pedido/QR (`MenuMesaScreen`, `PedidoEstadoScreen`,
  `ScanScreen`) no desborden en **estados que la suite no ejercita**. Lo que sí está cubierto es
  todo lo que la suite monta, a 320px.

## Pendiente de verificación humana

1. El **espacio superior** en un móvil real con notch — es literalmente lo que reportó el usuario y
   `flutter test` no puede cerrarlo del todo.
2. El aspecto de la app a **≥840px** en un navegador (la columna de 720).
3. Los **37 iconos**: que cada uno se entienda y que el gris de los estados vacíos quede bien.
4. Que el `Wrap` de los controles del `Stepper` se vea igual que el `Row` cuando los dos botones
   caben (debería, por construcción, pero no se ha visto).

## Notas para los planes que vienen

- **11-14 (accesibilidad):** el botón QR de la home sigue midiendo **45x45**, por debajo del mínimo
  de 48 de Material, y hay un test que lo **congela** en 45 — al subirlo hay que actualizar
  `test/restaurantes/iconos_test.dart`. Además, los iconos que van SIN texto al lado ya llevan
  `semanticLabel` (`GRI`, `Escanear QR de la mesa`); los que van con texto no, a propósito.
- **11-19 (cliente):** todos los `Icon` salen de `GriIcons`; si mueves código, actualiza los
  `archivo:línea` de `docs/ICONOS-app_cliente.md`. Y el `size` de cada icono está atado al
  `fontSize` del `Text` que sustituyó: cambiar uno sin el otro rompe la razón de ser de la regla.
- **Quien toque el `AppShell`:** el gate de paridad de `theme_tokens_test.dart` prohíbe volver a
  poner un literal en `BoxConstraints(maxWidth:)`, y `app_shell_responsive_test.dart` mide el ancho
  efectivo a 5 anchos. Los dos son intencionadamente redundantes.
- **Quien mida overflow en `flutter test`:** la fuente por defecto infla el texto ~2x (Hallazgo 3).
  Mide el ancho real con un `TextPainter` antes de declarar un bug.

## Notas de coordinación con 11-21 (paralelo)

- Ninguno de los 7 commits de este plan toca `panel_admin` (comprobado commit a commit).
- Durante la ejecución aparecieron en el árbol de trabajo cambios **ajenos** que NO se han
  estageado: los 13 archivos de `panel_admin` de 11-21, `.planning/config.json`
  (`parallelization: 1 → 3`, del orquestador) y
  `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart`, que apareció regenerado
  por `build_runner` sin que este plan lo ejecutara. **Ese último queda sin commitear y sin
  explicación**: no lo produjo este plan.
- `panel_admin/lib/core/gri_icons.dart` y `docs/ICONOS-panel_admin.md` son de 11-21. Este documento
  los enlaza en su cabecera.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco:
`app_cliente/lib/core/gri_icons.dart`, `app_cliente/lib/features/shared/icono_inline.dart`,
`app_cliente/test/shared/app_shell_responsive_test.dart`,
`app_cliente/test/core/sin_emojis_test.dart`, `app_cliente/test/restaurantes/iconos_test.dart`,
`docs/ICONOS-app_cliente.md`.
Commits verificados en `git log`: `85f0f45`, `81323f5`, `6207ded`, `f5b6049`, `a0a83d9`,
`da167b8`, `65c1c17`.
