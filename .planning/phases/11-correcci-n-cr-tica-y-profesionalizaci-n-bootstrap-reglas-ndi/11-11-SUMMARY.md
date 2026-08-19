---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 11
subsystem: ui
tags: [design-tokens, theme, ThemeExtension, typography, material3, flutter]

# Dependency graph
requires:
  - phase: 11-06
    provides: "PasswordField con área táctil 48x48 propia y el aviso de que centralizar inputDecorationTheme podía romperla"
  - phase: 11-09
    provides: "EmptyState y el patrón de widget compartido duplicado entre apps"
provides:
  - "GriSpacing / GriRadius / GriBreakpoints / GriText en las DOS apps (core/design_tokens.dart)"
  - "griTextTheme: los 15 slots de textTheme DECLARADOS, no heredados"
  - "GriSemanticColors: ThemeExtension registrada en griTheme en las dos apps"
  - "models/pedido.dart deja de tener una segunda paleta de colores"
  - "panel: elevatedButtonTheme + griCardDecoration + 4 estilos con nombre para 11-12"
affects: [11-12, 11-13, 11-14, 11-19, 11-21]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Duplicación deliberada de tokens entre las dos apps, con cabecera de SINCRONIZACIÓN cruzada que declara qué es idéntico y qué es propio de cada app"
    - "Paridad token<->código verificada con dart:io (patrón de 11-17): el token no vale nada si la pantalla sigue con su literal por su cuenta"
    - "Separación en DOS vehículos: ThemeData.textTheme lleva los valores que consume el chrome de Material; GriText lleva la escala propia de GRI"
    - "Los tokens de color NO se aplican por defecto: textoSecundarioAccesible se declara pero queda sin usar hasta 11-14"

key-files:
  created:
    - app_cliente/lib/core/design_tokens.dart
    - panel_admin/lib/core/design_tokens.dart
    - app_cliente/test/core/theme_tokens_test.dart
    - panel_admin/test/core/theme_tokens_test.dart
  modified:
    - app_cliente/lib/core/theme.dart
    - panel_admin/lib/core/theme.dart
    - app_cliente/lib/models/pedido.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart

key-decisions:
  - "11-11: ThemeData.textTheme NO puede llevar la escala de GRI. Esos slots los consume el chrome de Material (titleLarge = título de los 8 AppBar del cliente; headlineSmall = título de los 8 AlertDialog del panel; labelLarge = TODOS los botones; bodyLarge = título de los ListTile). MEDIDO con sonda, no supuesto. La escala propia vive en GriText, con nombre por significado y valores idénticos a los TextStyle inline que sustituye"
  - "11-11: el panel conserva 750/1100 como breakpoints en vez de los 600/840/1200 de M3, porque cambiarlos movería el colapso del sidebar y del grid. app_cliente, que no tenía ninguno, sí adopta los de M3"
  - "11-11: se registra elevatedButtonTheme (10 de 12 sitios ya lo declaraban inline: es convención) pero NO textButtonTheme, outlinedButtonTheme ni inputDecorationTheme (0 de 26 / 1 de 4 / 4 de 16: no hay convención y registrarlos cambiaría color o geometría en decenas de sitios). Hay un test que afirma esa ausencia"
  - "11-11: un MaterialColor (Colors.red) dentro de un ThemeExtension rompe el contrato de lerp — Color.lerp devuelve siempre un Color plano y Color.== compara el runtimeType, así que lerp(otro, 0) dejaba de ser igual a this. Los tokens de color se declaran como Color plano"
  - "11-11: GriSemanticColors.of() cae a la instancia canónica si el tema no la registra, y un test aparte afirma que griTheme SÍ la registra — el fallback no puede tapar un olvido"

patterns-established:
  - "Todo número de layout nuevo (padding, radio, breakpoint) sale de design_tokens.dart; los literales sueltos son deuda a migrar"
  - "Quien edite un design_tokens.dart tiene que portar GriSpacing y GriRadius al otro; el test del OTRO proyecto es el que se pone rojo"
  - "Un token que cambiaría un píxel al aplicarse se DECLARA pero no se aplica, con el motivo escrito y el plan que lo aplicará nombrado"

requirements-completed: [DS-01]

# Metrics
duration: ~95min
completed: 2026-08-19
---

# Phase 11 Plan 11: Base del sistema de diseño Summary

**Las dos apps pasan de tener cero escalas a tener espaciado, radios, breakpoints, tipografía y colores semánticos con nombre — y ni un solo valor de la identidad visual cambia, salvo dos botones del panel que renderizaban un derivado del seed en vez del naranja de marca.**

## Performance

- **Duración:** ~95 min
- **Tareas:** 2/2
- **Archivos modificados:** 8 (4 creados, 4 modificados)
- **Roturas deliberadas:** 17 aplicadas y revertidas

## Accomplishments

- **Existe una fuente única de verdad para el layout.** `GriSpacing` (4-pt), `GriRadius` (10/15/20) y `GriBreakpoints` en las dos apps, con el `archivo:línea` de dónde sale cada número en su doc comment. Ninguno es inventado salvo `GriSpacing.xxl = 48`, y su doc comment lo dice explícitamente.
- **La app cliente deja de tener dos sistemas paralelos de color de chip.** `models/pedido.dart` ya no contiene una paleta: los 10 hex se movieron LITERALMENTE al `ThemeExtension`. La prueba de que la migración es real y no cosmética es que el test PREEXISTENTE `estado_test.dart` («los 5 estados renderizan chips con labels y colores distintos») se pone rojo si se toca un hex de la extensión — sin haber editado sus valores esperados.
- **El panel puede estilar botones y tarjetas desde el tema.** `elevatedButtonTheme` registrado, `griCardDecoration` (la sombra que estaba copiada en 7 sitios, no 4) y 4 estilos con nombre para que 11-12 borre los duplicados.
- **Se detectó y se documentó la contradicción interna del plan** entre «que migrar un TextStyle inline a `textTheme.titleMedium` NO cambie el píxel» y «ningún texto de las pantallas actuales cambia de tamaño». Ver Deviación 1.
- **Sin regresiones:** `flutter analyze` **0 issues** en las dos apps; app_cliente **158 → 178**; panel_admin **163 → 189** (observado 226 con los +37 de 11-10, en vuelo en paralelo); `audit:indexes` **exit 0** y `audit:branding` **exit 0**.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Tokens: escala, radios, breakpoints, tipografía — RED | 2 suites sin compilar | `3e5f931` (test) |
| 1 | Tokens — GREEN | `+8 / +8`, analyze 0 | `6ad9a63` (feat) |
| 2 | textTheme + colores semánticos + estilos del panel — RED | 2 suites sin compilar | `808487b` (test) |
| 2 | textTheme + colores semánticos — GREEN | `+178 / +226`, analyze 0 | `7d0528a` (feat) |

## Gates ejecutados — salida real

| Gate | Resultado |
|---|---|
| `cd app_cliente && flutter analyze` | `No issues found!` |
| `cd app_cliente && flutter test` | `00:08 +178: All tests passed!` (base 158) |
| `cd panel_admin && flutter analyze` | `No issues found!` |
| `cd panel_admin && flutter test` | `00:15 +226: All tests passed!` (base 163 + 26 míos + 37 de 11-10) |
| `cd panel_admin && flutter test test/equipo` | `+37` — aislado, para poder restar lo del otro ejecutor |
| `cd scripts && npm run audit:indexes` | `22 queries · 5 sujetas a paridad · 0 fallo(s)`, exit 0 |
| `cd scripts && npm run audit:branding` | `2 apps · 4 archivos · 0 rastros de plantilla`, exit 0 |
| 48x48 de 11-06 (cliente) | `login: el ojo está etiquetado y es alcanzable (48x48)` ✔ y `PasswordField: los 48x48 los pone el widget…` ✔, sin tocar |
| 48x48 de 11-06 (panel) | los mismos dos casos ✔, sin tocar |

`test:rules` y `test:functions` NO se ejecutaron: dependen de los emuladores y 11-10
estaba en vuelo tocando `firestore.rules`. Este plan no toca rules, índices ni functions.

## Roturas deliberadas (17)

**Tarea 1 — tokens**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | `GriSpacing.md` 16 → 15 | app_cliente `+6 -2` (cae el literal y el «múltiplo de 4») | ✔ |
| B | `GriRadius.card` 15 → 14 | panel `+6 -2` (cae el literal y la paridad con `cardTheme`) | ✔ |
| C | `BoxConstraints(maxWidth: 480)` → 500 en el AppShell | app_cliente `+7 -1` | ✔ |
| D | `constraints.maxWidth < 750` → 760 en el AppShell | panel `+7 -1` | ✔ |
| E | `GriBreakpoints.expanded` 1100 → 1200 (los de M3) | panel `+6 -2` | ✔ |
| F | `GriText.tituloCard` 16 → 17 | app_cliente `+7 -1` | ✔ |
| G | `GriText.auxiliar` con `color:` | app_cliente `+6 -2` | ✔ |

C y D importan especialmente: son los que demuestran que el gate de paridad
token↔código **encuentra el literal de verdad** y no está verde porque su regexp no
case nada (el modo de fallo que 11-08 documentó para los gates de `grep`).

**Tarea 2 — tema**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| H | quitar `extensions:` de `griTheme` | app_cliente `+19 -1` (T-11-11-02) | ✔ |
| I | `pedidoEnviadoFg` `#2563EB` → `#2563EC` | app_cliente `+21 -3` — y uno de los 3 es el test **PREEXISTENTE** de `estado_test.dart` (T-11-11-01) | ✔ |
| J | `estadoColor` vuelve a devolver un literal | app_cliente `+19 -1` | ✔ |
| K | `titleLarge` 22/w400 → 24/bold | app_cliente `+18 -2` (cae el gate de identidad visual) | ✔ |
| L | `headlineSmall` a bold | panel `+24 -2` (cae el caso del AlertDialog) | ✔ |
| M | quitar `elevatedButtonTheme` | panel `+25 -1` | ✔ |
| N | meter `inputDecorationTheme` con `suffixIconConstraints: 0` | panel `+40 -1` — **solo cae la guarda nueva**; ver Hallazgo 2 | ✔ |
| O | `blurRadius` 12 → 10 en `griCardDecoration` | panel `+25 -1` | ✔ |
| P | `textoSecundarioAccesible` → `#777777` | panel `+25 -1` | ✔ |
| Q | `GriColors.gray` → `#6E6E6E` | panel `+24 -2` | ✔ |

**Roturas que NO rompieron nada (y por qué eso es el hallazgo, no el fallo):**
R (`iconButtonTheme` encogido en `griTheme`), S (ídem en el cliente) y una tercera con
`visualDensity(-4, -4)` dejaron las suites **enteras en verde**. Ver Hallazgo 3.

## Hallazgos

### 1. El plan se contradice a sí mismo sobre la escala tipográfica

La Tarea 2 pide dos cosas incompatibles: que migrar un `TextStyle` inline a
`Theme.of(context).textTheme.titleMedium` **no cambie el píxel** (⇒ los slots deben
valer lo que valen los estilos inline de GRI) y que **ningún texto de las pantallas
actuales cambie de tamaño** (⇒ los slots deben seguir valiendo lo que Material resuelve
hoy).

No es una duda teórica: se **midió** con una sonda contra el `griTheme` anterior a este
plan qué widget consume cada slot.

| Slot | Valor M3 hoy | Lo consume | Si llevara la escala de GRI |
|---|---|---|---|
| `titleLarge` | 22 / w400 | título de los **8 `AppBar`** del cliente | 24 / bold → +2 px y mucho más grueso en 8 pantallas |
| `headlineSmall` | 24 / w400 | título de los **8 `AlertDialog`** del panel | 24 / bold |
| `bodyLarge` | 16 / w400 | título de los `ListTile`, texto de los `TextField` | — |
| `bodyMedium` | 14 / w400 | `Text` sin estilo, contenido de los diálogos | — |
| `labelLarge` | 14 / w500 | etiqueta de **TODOS** los botones de las dos apps | 15/16 bold → todos los botones |
| `titleMedium` | 16 / w500 | `DropdownButton` del shell del panel | 18 / bold |

Resolución (la identidad visual es una decisión **BLOQUEADA** del usuario, así que gana
la segunda restricción):

- `griTextTheme` **declara** los 15 slots con los valores medidos de M3. No es
  redundante: dejan de ser un default implícito, así que una actualización de Flutter que
  cambie la tipografía de M3 ya no puede reflotar las apps en silencio, y 11-12 / 11-19
  tienen a dónde migrar todos los `fontSize: 16/14/13/12` de peso normal con garantía de
  cero píxeles.
- La escala **propia de GRI** vive en `GriText`, nombrada por significado
  (`tituloPantalla`, `tituloSeccion`, `tituloCard`, `boton`, `cuerpo`, `cuerpoCompacto`,
  `auxiliar`, `chip`) y con valores **idénticos** al `TextStyle` inline que sustituye. Un
  test lo afirma estilo a estilo, así que la migración de 11-12 / 11-19 es pixel-neutral
  por construcción, y otro afirma que ninguno fija `color` (un color dentro de la escala
  tipográfica sería otra paleta paralela).
- El gate que sostiene la decisión no es una promesa: renderiza `AppBar`, `ListTile`,
  botones y `AlertDialog` **de verdad** y compara contra los números medidos ANTES del
  plan. La rotura K lo confirma.

### 2. El aviso de 11-06 sobre el área táctil es correcto en el riesgo, pero su test no lo cubriría

11-06 dejó escrito que su caso «los 48x48 los pone el widget, no el default del
framework» detectaría la regresión de centralizar `inputDecorationTheme`. **No puede.**
Ese caso pumpea un `ThemeData` fabricado a mano, y **ningún** test de 48x48 de ninguna de
las dos apps monta `griTheme`. Demostrado en vivo (rotura N): con un
`inputDecorationTheme(border: OutlineInputBorder(), suffixIconConstraints: 0)` metido en
`griTheme`, la suite de login del panel siguió **entera en verde**; el único caso que cayó
fue la guarda nueva de este plan.

El caso de 11-06 sí prueba lo que dice su nombre (que el área la sostiene el widget y no
el default del framework). Lo que no prueba es que el tema real de la app no la esté
encogiendo.

### 3. …y resulta que el tema real **no puede** encogerla

Al intentar escribir el gate que faltaba, tres roturas seguidas lo dejaron verde:
`inputDecorationTheme(suffixIconConstraints: 0)`, `iconButtonTheme` con
`minimumSize: Size.zero + shrinkWrap`, y `visualDensity(-4, -4)`. El
`constraints: BoxConstraints(minWidth: 48, minHeight: 48)` explícito del `IconButton` de
`PasswordField` es un mínimo de `ConstrainedBox`: ningún tema ambiente puede bajarlo.

Consecuencia: **el test que escribí para cerrar el hueco no podía fallar nunca, así que
lo borré** en vez de dejar una aserción verde por construcción presumiendo de cobertura.
La protección real es estructural (el `constraints` del widget) más la guarda
`el tema NO registra textButton/outlinedButton/inputDecoration`, que sí tiene dientes
(rotura N).

### 4. El panel y la app cliente pintan el MISMO estado de pedido con colores DISTINTOS

| Estado | app_cliente | panel_admin |
|---|---|---|
| `enviado` | `#2563EB` | `#3478F6` |
| `aceptado` | `#D97706` | `#FF4C05` |
| `en_preparacion` | `#7C3AED` | `#8E44AD` |
| `servido` | `#168A52` | `#20B26B` |
| `rechazado` | `#C83C2E` | `#E74C3C` |

Un cliente ve su pedido «En preparación» en un morado y el cocinero lo ve en otro.
Unificarlos cambiaría píxeles en una de las dos apps, así que queda **fuera** de este
plan — pero ya no está escondido en dos modelos distintos: está declarado en el doc
comment de `GriSemanticColors` del panel y afirmado por un test en cada lado.

### 5. Un `MaterialColor` dentro de un `ThemeExtension` rompe el contrato de `lerp`

El token `peligro` empezó siendo `Colors.red`. El test de `lerp` cayó con
`Expected: <Instance of 'GriSemanticColors'> / Actual: <Instance of 'GriSemanticColors'>`:
`Color.lerp` devuelve siempre un `Color` plano y `Color.==` compara también el
`runtimeType`, así que `lerp(otro, 0)` dejaba de ser igual a `this`. Se declara como
`Color(0xFFF44336)` (el valor exacto de `Colors.red`, mismo ARGB, mismo render) y el test
compara por `toARGB32()`.

### 6. La sombra duplicada estaba en 7 sitios, no en 4, y en dos formas

El plan decía 4. Son 7: `stat_card.dart:39`, `dashboard_screen.dart:134` y `:310`,
`reportes_screen.dart:351`, `cocina/widgets/pedido_card.dart:47` con
`Color(0x0D000000)`, y `login_screen.dart:92` + `bootstrap_screen.dart:130` con
`Colors.black.withValues(alpha: 0.05)`. Hay un caso que demuestra que colapsarlas en una
sola no cambia el píxel: 0.05 × 255 = 12.75 → 13 = `0x0D`.

## Cambio visual: qué se movió y qué no

**No cambió ni un literal de color.** Comprobado sobre el `git diff` de los 4 archivos de
código: los 12 hex que desaparecen de `models/pedido.dart` reaparecen idénticos en
`GriSemanticColors`. Los únicos hex NUEVOS son tokens que **no se aplican en ningún
sitio** (`#6E6E6E`), o el traslado literal de la sombra (`0x0D000000`) y del rojo
(`#F44336`).

**Cambió UNA cosa, deliberada y acotada.** Registrar `elevatedButtonTheme` en el panel
afecta a los **2** `ElevatedButton` (de 12) que no declaraban estilo inline:

| Sitio | Antes (medido) | Después |
|---|---|---|
| `reportes_screen.dart:140` «Consultar» | fondo `#FFF1ED`, texto `#8F4C37` | fondo `#FF4C05`, texto blanco |
| `reservas_screen.dart:221` «Marcar ocupada» | fondo `#FFF1ED`, texto `#8F4C37` | fondo `#FF4C05`, texto blanco |

`#8F4C37` **no es la marca**: es lo que `ColorScheme.fromSeed(#FF4C05)` deriva. Los otros
10 CTA primarios del panel ya son naranja sólido, así que estos 2 eran los inconsistentes.
Encaja en «trabajo de consistencia, no rediseño», pero **es un cambio visible y aquí queda
declarado** para que el usuario pueda revertirlo si no lo quiere (basta borrar
`elevatedButtonTheme` de `griTheme`; la rotura M confirma que el test lo detecta).

**Lo que NO se centralizó, y por qué:**

| Tema | Sitios con estilo inline | Por qué no se registra |
|---|---|---|
| `textButtonTheme` | 0 de 26 con estilo base; los 2 con `style` son la variante destructiva | Registrar `foregroundColor: primary` teñiría 24 botones de diálogo de `#8F4C37` a `#FF4C05` |
| `outlinedButtonTheme` | 1 de 4, y también es la variante destructiva | Igual que arriba |
| `inputDecorationTheme` | 4 de 16 declaran `OutlineInputBorder` | Los otros **12** campos (diálogos de menú, mesas y restaurantes) pintan hoy el subrayado de M3; registrar el borde perfilado les cambia la GEOMETRÍA (borde y `contentPadding`) |

Los cuatro casos están cubiertos por constantes con nombre (`griBotonPrimario`,
`griBotonPeligroTexto`, `griBotonPeligroContorno`, `griInputOutline`) para que 11-12 borre
los duplicados sin decidir por los demás, y por un test que **afirma la ausencia** de esos
tres temas, con el motivo escrito: quien quiera unificarlos tiene que venir a borrar la
guarda y asumir el cambio conscientemente.

## Deviations from Plan

### 1. [Rule 3 - Bloqueante] La escala tipográfica no puede vivir solo en `textTheme`

- **Encontrado en:** Tarea 2
- **Problema:** ver Hallazgo 1 — las dos exigencias de `<behavior>` son incompatibles.
- **Resolución:** `griTextTheme` con los valores medidos de M3 + `GriText` en
  `design_tokens.dart` con la escala real de GRI. El plan asignaba la tipografía solo a
  `ThemeData.textTheme`; se añadió el segundo vehículo porque sin él era imposible cumplir
  «ningún texto cambia de tamaño».
- **Archivos:** `*/lib/core/design_tokens.dart`, `*/lib/core/theme.dart`

### 2. [Rule 3 - Bloqueante] Se tocó `pedido_estado_screen.dart`, que no estaba en `files_modified`

- **Encontrado en:** Tarea 2
- **Problema:** leer del `ThemeExtension` exige `BuildContext`, así que `estadoColor` y
  `estadoBg` pasaron de getters a métodos. Sus 2 únicos llamadores viven en
  `features/pedidos/pedido_estado_screen.dart`, que el plan no listaba.
- **Resolución:** el propio plan lo anticipaba en la acción («ajustar los llamadores»).
  Cambio de 2 líneas. Queda declarado aquí porque el archivo no estaba en el frontmatter.

### 3. [Rule 2 - Contrato aguas abajo] Se declara `textoSecundarioAccesible` sin aplicarlo

- **Encontrado en:** Tarea 2
- **Problema:** el acuerdo de la fase exige que el arreglo de contraste de 11-14 NO se
  haga cambiando `GriColors.gray` (token de marca). El plan 11-11 no mencionaba el token.
- **Resolución:** se declara `#6E6E6E` en `GriSemanticColors` de las dos apps, **sin
  aplicarlo en ningún sitio** (cero píxeles movidos), con dos tests por app: uno afirma
  que `GriColors.gray` sigue siendo `#777777` y otro que el token accesible es distinto.
  Roturas P y Q.

### 4. [Rule 1 - Bug] `Colors.red` rompía `lerp`

- **Encontrado en:** Tarea 2, por el test de `lerp` (no por inspección)
- **Resolución:** ver Hallazgo 5.

### 5. Test propio retirado por estar verde por construcción

- **Encontrado en:** Tarea 2, tras las roturas R y S
- **Problema:** el caso «el ojo mide 48x48 bajo `griTheme`» que escribí para cerrar el
  hueco del Hallazgo 2 no podía fallar nunca (Hallazgo 3).
- **Resolución:** se borró. Dejar una aserción que no puede ponerse roja es peor que no
  tenerla: presume de una cobertura que no existe.

## Nota sobre los números de la suite del panel

`flutter test` en `panel_admin` da **226**, no 189. La diferencia son los **+37** de
`test/equipo/`, del plan **11-10**, que se ejecutaba en paralelo. Medido por separado con
`flutter test test/equipo` para poder restarlo. La base atribuible a 11-11 es
**163 → 189 (+26)**.

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo):**
- Los valores de `GriSpacing`, `GriRadius`, `GriBreakpoints` y `GriText`.
- Que `GriRadius.card` ES el radio del `cardTheme` real (lee el `ThemeData`, no otro literal).
- Que el `AppShell` del cliente y las 3 pantallas de layout del panel usan **exactamente**
  los anchos de los tokens.
- Que `griTheme` registra `GriSemanticColors`.
- Que los 10 hex de estado de pedido del cliente son los de antes — y que el chip de la
  pantalla los saca **del tema**, no de un literal propio (test con extensión adulterada).
- Que declarar `griTextTheme` no mueve el tamaño ni el peso de `AppBar`, `ListTile`,
  botones ni `AlertDialog`.
- Que el panel NO registra `textButtonTheme` / `outlinedButtonTheme` /
  `inputDecorationTheme`.
- Que `GriColors.gray` sigue siendo `#777777` y `textoSecundarioAccesible` es otro token.

**Afirmado, NO verificado:**
- **Que las pantallas se VEAN bien.** Un test demuestra que un token resuelve a un hex; no
  demuestra que el resultado esté bien. Los dos botones del panel que cambian de aspecto
  («Consultar», «Marcar ocupada») **no se han visto renderizados**.
- Que `GriSpacing`/`GriRadius` valgan lo mismo en las dos apps se sostiene escribiendo los
  mismos literales en dos suites independientes. Si alguien edita los dos archivos **y**
  los dos tests a la vez, la paridad se pierde sin que nada avise.
- Que `xxl = 48` sea el paso correcto: hoy no lo usa nadie.
- Los `archivo:línea` de los doc comments se recogieron con `grep` en el momento de
  escribirlos; se desactualizarán en cuanto 11-12 mueva código.

## Pendiente de verificación humana

- El aspecto real de «Consultar» (reportes) y «Marcar ocupada» (reservas) con el naranja
  de marca. Es el ÚNICO cambio visual del plan y no es observable en `flutter test`.
- Que la escala `GriText` sea la correcta para el mockup: se derivó contando los
  `TextStyle` inline más repetidos, no de un diseño.

## Notas para los planes que vienen

- **11-12 (36 hex del panel):** tienes `griCardDecoration` (7 duplicados a borrar),
  `griBotonPrimario` (4), `griBotonPeligroTexto` (3), `griBotonPeligroContorno` (1) y
  `griInputOutline` (4). Los `fontSize` de peso normal migran a `textTheme`; los bold, a
  `GriText`. Si tocas `models/pedido_staff.dart`, sus colores ya están duplicados en
  `GriSemanticColors` — mueve el punto de uso, no los valores.
- **11-13 / 11-14:** los breakpoints del panel (750/1100) NO son los de M3 a propósito, y
  hay un test de paridad que se pondrá rojo si cambias el literal en la pantalla sin
  cambiar el token (o al revés). Si quieres los de M3, es un cambio visual: decídelo con
  el usuario.
- **11-14 (accesibilidad):** usa `GriSemanticColors.textoSecundarioAccesible` (#6E6E6E).
  **No toques `GriColors.gray`** — hay dos tests por app que lo impiden. Y ojo: aplicarlo
  a `bodySmall`/`labelSmall` del `textTheme` teñiría también los `Text` sin estilo, no
  solo los secundarios.
- **11-19 (cliente):** el aviso de 11-17 sobre el `padding` del `GoogleBoton` sigue
  vigente. Este plan NO tocó ningún `padding`.
- **11-21 (93 emoji → `Icon`):** los colores salen de `GriSemanticColors` y de
  `GriColors`; los tamaños de los emoji-como-icono (`fontSize: 40` ×10 en el cliente)
  **no** están en `GriText` a propósito: son iconos disfrazados de texto y su tamaño lo
  decide `Icon(size:)`, no la escala tipográfica.
- **Quien edite un `design_tokens.dart`** tiene que portar `GriSpacing` y `GriRadius` al
  gemelo; la cabecera de cada archivo lo dice y el test del OTRO proyecto es el que se
  pone rojo.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco:
`app_cliente/lib/core/design_tokens.dart`, `panel_admin/lib/core/design_tokens.dart`,
`app_cliente/test/core/theme_tokens_test.dart`, `panel_admin/test/core/theme_tokens_test.dart`.
Commits verificados en `git log`: `3e5f931`, `6ad9a63`, `808487b`, `7d0528a`.
