---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 14
subsystem: ui
tags: [accesibilidad, a11y, wcag, contraste, tap-target, semantics, flutter, app_cliente]

# Dependency graph
requires:
  - phase: 11-13
    provides: "los 54 emojis convertidos en `Icon` — sin eso no habría `semanticLabel` que poner, y el test que congelaba el botón QR en 45x45"
  - phase: 11-11
    provides: "GriSemanticColors.textoSecundarioAccesible (#6E6E6E) DECLARADO y sin aplicar, GriSpacing.xxl (48) y las dos guardas del token de marca"
  - phase: 11-19
    provides: "el rol de texto secundario reducido a un patrón buscable y la MEDICIÓN de que migrar a textTheme no es pixel-neutral"
  - phase: 11-06
    provides: "el área táctil de 48x48 del ojo de contraseña y su aviso"
provides:
  - "app_cliente/test/a11y/a11y_test.dart: 16 gates de accesibilidad del camino crítico"
  - "GriColors.textoSecundarioAccesible (#6E6E6E) como `static const`, APLICADO en 29 puntos de texto"
  - "Botón de escanear QR a 48x48 y con nodo de semántica propio"
  - "Etiqueta en los 6 controles de icono que no la tenían (+ el FAB que la auditoría no vio)"
  - "GATE ESTÁTICO: GriColors.gray prohibido en contexto de TEXTO en las 60+ fuentes de lib/"
  - "MEDICIÓN: androidTapTargetGuideline es CIEGA a un CTA pequeño si su InkWell no abre nodo propio"
affects: [11-25, 11-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Un control de icono construido con InkWell necesita `Semantics(container: true)` para EXISTIR como objetivo táctil ante las guías; sin él su tap se fusiona con el contenedor"
    - "El `tooltip` de un IconButton llega a `SemanticsData.tooltip`, NO a `.label` — `find.bySemanticsLabel` no lo ve y `labeledTapTargetGuideline` acepta los dos campos"
    - "El ratio de contraste se calcula con la fórmula WCAG DENTRO del test y se mide contra el color PINTADO, nunca contra el token"
    - "Un barrido de pantallas solo cubre lo que monta: se acompaña de un gate estático sobre las fuentes, con autocomprobación de cobertura"

key-files:
  created:
    - app_cliente/test/a11y/a11y_test.dart
  modified:
    - app_cliente/lib/core/theme.dart
    - app_cliente/lib/features/restaurantes/home_screen.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/pagos/calificacion_sheet.dart
    - app_cliente/lib/features/reservas/reserva_wizard_screen.dart
    - app_cliente/lib/features/reservas/mis_reservas_screen.dart
    - app_cliente/lib/features/auth/login_screen.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart
    - app_cliente/lib/features/sesion_qr/scan_screen.dart
    - app_cliente/lib/features/shared/app_shell.dart
    - app_cliente/lib/features/shared/empty_state.dart
    - app_cliente/lib/features/shared/google_boton.dart
    - app_cliente/lib/features/shared/not_found_screen.dart
    - app_cliente/test/restaurantes/iconos_test.dart
    - app_cliente/test/core/theme_tokens_test.dart
    - app_cliente/test/shared/app_shell_responsive_test.dart

key-decisions:
  - "11-14: HALLAZGO CENTRAL — `androidTapTargetGuideline` NO habría detectado el hallazgo de la auditoría. MEDIDO: con el código anterior al plan (botón QR de 45x45, sin `Semantics`), la guía pasa VERDE, porque el tap del `InkWell` se fusionaba con toda la fila de la cabecera en UN nodo de 800x77. La guía medía ese nodo. El arreglo real fue darle nodo propio; solo entonces la guía tiene dientes"
  - "11-14: el token NO se aplica a `bodySmall`/`labelSmall` del `textTheme` como pedía el plan. MEDIDO con sonda sobre login y home: NINGÚN texto de esta app se pinta a través de esos slots (todos heredan bodyMedium: ls=0.25, h=1.43; bodySmall traería 0.4/1.33). Hacerlo habría cambiado 0 píxeles, arreglado 0 fallos de contraste y reteñido de paso el `helperText` del framework"
  - "11-14: `GriColors.gray` conserva EXACTAMENTE #777777. Lo que cambia es DÓNDE se usa: 29 puntos de TEXTO pasan a `textoSecundarioAccesible` (#6E6E6E) y el gris de marca se queda en los 9 `Icon`, el fondo del SnackBar y el indicador de progreso, donde WCAG 1.4.3 no aplica"
  - "11-14: el `tooltip` de un `IconButton` NO acaba en `SemanticsData.label` sino en `.tooltip`. `labeledTapTargetGuideline` acepta los dos (accessibility.dart:263) pero `find.bySemanticsLabel` NO, así que una aserción de wording escrita con ese finder está rota aunque la etiqueta exista"
  - "11-14: sobre el fondo REAL de la app (#F7F7F7) el gris de marca da 4.180:1, peor que el 4.478:1 sobre blanco que citaba la auditoría. Por eso el token accesible se afirma contra los DOS fondos: #767676 pasaría la comprobación sobre blanco (4.54) y fallaría sobre el fondo real (4.24)"
  - "11-14: los `constraints: BoxConstraints(minWidth: 48, minHeight: 48)` de `PasswordField` (11-06) son REDUNDANTES. MEDIDO: borrándolos por completo el ojo sigue midiendo 48x48 — lo pone el `IconButton` de M3. El test de 11-06 afirma la DECLARACIÓN, no la geometría"

patterns-established:
  - "Antes de dar por bueno un gate de accesibilidad, romper lo que dice proteger: una guía de Flutter puede pasar verde por medir el nodo equivocado"
  - "Un gate que recorre pantallas montadas se complementa SIEMPRE con uno estático sobre las fuentes; el primero tiene puntos ciegos por cobertura de montaje"

requirements-completed: [DS-03]

# Metrics
duration: ~135min
completed: 2026-08-19
---

# Phase 11 Plan 14: Accesibilidad de la app cliente Summary

**Los controles de icono de la app cliente dejan de ser botones anónimos para un lector de
pantalla, el CTA principal deja de estar por debajo del mínimo táctil, el texto secundario pasa a
cumplir AA sin tocar ni un token de marca — y de paso queda demostrado que la guía de Flutter que
el plan prescribía para todo esto habría pasado verde con el bug puesto.**

## Performance

- **Duración:** ~135 min
- **Tareas:** 3/3
- **Archivos:** 19 (1 creado, 18 modificados) — **todos de `app_cliente`**
- **Roturas deliberadas:** 24 — **3 dejaron la suite verde** y las tres se convirtieron en
  hallazgo o en un gate nuevo

## Accomplishments

- **El gate que el plan prescribía era ciego, y está demostrado.** Con el código EXACTO anterior
  al plan (botón QR de 45×45, sin `Semantics`), `androidTapTargetGuideline` pasa **verde**. El
  `InkWell` del botón no abría nodo propio: su acción de tap se fusionaba con toda la fila de la
  cabecera en un único nodo de **800×77** etiquetado `"GRI / GRI / Escanear QR de la mesa"`. La
  guía medía ese nodo. El arreglo de verdad fue darle **nodo propio**; solo entonces la guía
  detecta los 45.
- **El plan pedía aplicar el contraste donde no habría cambiado nada.** Sonda sobre login y home:
  **ningún** texto de esta app se pinta a través de `textTheme.bodySmall`/`labelSmall`. Aplicar el
  token ahí habría movido 0 píxeles y arreglado 0 fallos. Se aplicó donde el texto está de verdad.
- **`GriColors.gray` sigue valiendo exactamente `#777777`.** La decisión BLOQUEADA se respeta al
  100%: lo que cambia es **dónde** se usa, no cuánto vale.
- **Se destapó un séptimo control sin etiqueta que la auditoría no contó.** El FAB de "mis
  reservas" es un `FloatingActionButton`, no un `IconButton`, así que no entraba en su recuento de
  "5 de 6". Lo encontró `labeledTapTargetGuideline`.
- **El barrido de pantallas tenía un punto ciego y se cerró con un gate estático.** Devolver a
  `#777777` el texto del 404 o el del escáner dejaba la suite ENTERA en verde: esas pantallas no
  están montadas. El gate estático lee las fuentes de `lib/` y no depende del montaje.
- **Ninguna pantalla del camino crítico hubo que excluir del gate de contraste**, al contrario de
  lo que preveía el plan. Las 7 pantallas de la suite pasan las tres guías.
- **Sin regresiones:** `flutter analyze` **0 issues**; **214 → 230 tests** (+16).
- **Cero archivos de `panel_admin` en los 6 commits** (comprobado commit a commit): 11-12 y 11-24
  corrieron en paralelo en el mismo árbol sin un solo conflicto.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Etiquetas y tamaños táctiles — RED | 1 verde, 5 rojos | `c732cda` |
| 1 | Etiquetas y tamaños táctiles — GREEN | `+221`, analyze 0 | `29c2078` |
| 2 | Contraste — RED | no compila (falta el token) | `defb8f5` |
| 2 | Contraste — GREEN | `+225`, analyze 0, `GRAY_INTACTO` | `5dc0398` |
| 3 | Suite a11y completa + FAB | `+229`, a11y `+15` | `950f3ae` |
| 3 | Gate estático anti-regresión | `+230`, a11y `+16` | `6d69637` |

## Gates ejecutados — salida real

| Gate | Resultado |
|---|---|
| `cd app_cliente && flutter analyze` (línea base) | `No issues found! (ran in 6.2s)` |
| `cd app_cliente && flutter test` (línea base) | `00:11 +214: All tests passed!` |
| `cd app_cliente && flutter analyze` (final) | `No issues found! (ran in 4.4s)` |
| `cd app_cliente && flutter test` (final) | `00:10 +229: All tests passed!` → `+230` tras el gate estático |
| `cd app_cliente && flutter test test/a11y/` | `00:01 +16: All tests passed!` |
| Tarea 2: `grep -q "0xFF777777" lib/core/theme.dart` | `GRAY_INTACTO` — **gate defectuoso**, ver Hallazgo 4 |
| `grep -rn "Semantics(\|tooltip:\|semanticLabel" app_cliente/lib \| wc -l` | **13** (11 sin comentarios). El mismo comando en `d89176f`, antes del plan: **1** |
| `git diff-tree` por commit buscando `^panel_admin/` | **0** en los 6 commits |
| `cd scripts && npm run audit:branding` | `2 apps · 4 archivos · 0 rastros de plantilla`, exit 0 |

`test:rules`, `test:functions` y `audit:indexes` **NO se ejecutaron**: este plan no toca rules,
índices ni functions, y había otro ejecutor (11-24) con `functions/` y `scripts/test/functions/`
abiertos en el mismo árbol.

## Qué se arregló, con evidencia file:line

| Hallazgo de la auditoría | Antes | Ahora |
|---|---|---|
| `home_screen.dart` `_QrButton` | `SizedBox(45, 45)`, sin nodo propio | `GriSpacing.xxl` (48×48) + `Semantics(container: true, button: true)` |
| `menu_mesa_screen.dart` +/− del carrito | sin `tooltip` | "Agregar una unidad" / "Quitar una unidad" |
| `calificacion_sheet.dart` 5 estrellas | sin etiqueta | "Calificar con 1 estrella" … "con 5 estrellas" |
| `reserva_wizard_screen.dart` +/− comensales | sin `tooltip` (no lo pedía el plan) | "Agregar/Quitar un comensal" |
| `mis_reservas_screen.dart` FAB | sin etiqueta (**la auditoría no lo vio**) | "Reservar una mesa" |
| `GriColors.gray` como color de texto | 4.478:1 sobre blanco, 4.180:1 sobre #F7F7F7 | 29 puntos a `#6E6E6E` (5.099:1 / 4.760:1) |

**Tamaño táctil: qué estaba corto de verdad.** MEDIDO sobre el árbol de semántica: los `IconButton`
del carrito ya miden **48×48** y las estrellas **52×52** por el mínimo que impone M3. El **único**
control por debajo era el botón QR. Por eso NO se añadió `constraints: BoxConstraints(minWidth:
48…)` a ninguno: habría sido una línea que no puede fallar. Lo que protege el tamaño es la guía,
que ahora sí mide el nodo correcto.

## Roturas deliberadas (24)

### Tarea 1 — etiquetas y táctil (5)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | botón QR de vuelta a 45×45 | caen 4: los dos casos del tamaño, la guía de la home y `iconos_test` | ✔ |
| B | quitar el `Semantics(container:)` del `_QrButton` (dejando los 48) | **solo** cae "nodo propio"; las DOS guías siguen verdes | ✗ → Hallazgo 1 |
| B2 | estado EXACTO anterior al plan (45×45 **y** sin `Semantics`) | **`androidTapTargetGuideline` VERDE** | ✗ → Hallazgo 1 |
| C | quitar el `tooltip` del `−` del carrito | caen 2 (wording + guía del menú) | ✔ |
| D | quitar el `tooltip` de las 5 estrellas | caen 2 | ✔ |

### Tarea 2 — contraste (3)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| F | `GriColors.gray` → `#6E6E6E` (el atajo prohibido) | caen 5, incluidas las dos guardas de 11-11. **Y el gate del plan sigue diciendo `GRAY_INTACTO`** | ✔ (+ Hallazgo 4) |
| G | texto secundario del login de vuelta a gray | caen 3 (color pintado, barrido y `textContrastGuideline`) | ✔ |
| I | token accesible → `#767676` (4.54 sobre blanco, 4.24 sobre #F7F7F7) | cae la aserción del SEGUNDO fondo | ✔ |

### Tarea 3 — suite y gate estático (16)

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| K | quitar el `tooltip` del FAB | cae "mis reservas" | ✔ |
| L | ojo de contraseña con `constraints` 24×24 | solo cae el caso de 11-06 (propiedad); la guía sigue verde | ✗ → Hallazgo 5 |
| L2 | ojo de contraseña **sin `constraints`** | mide **48×48 igual**; nada cae salvo 11-06 | ✗ → Hallazgo 5 |
| M | quitar el `tooltip` de los comensales | cae el caso del wizard | ✔ |
| N | `Icon` del `EmptyState` con otro color | **verde, como debe ser** (los iconos no son texto) | ✔ |
| O | "Calificar con 1 **estrellas**" | cae el caso del singular | ✔ |
| P | `tooltip: 'Mas'` en el `+` del carrito | cae el caso del wording | ✔ |
| S | `unselectedItemColor` de vuelta a gray | cae `app_shell_responsive_test` | ✔ |
| T | `disabledForegroundColor` del carrito de vuelta a gray | cae el barrido | ✔ |
| U | texto del **404** de vuelta a gray | **VERDE** — el barrido no monta el 404 | ✗ → Hallazgo 3 |
| W | texto del **escáner** de vuelta a gray | **VERDE** — mismo motivo | ✗ → Hallazgo 3 |
| X | `Icon` pintado con el token accesible | **verde, como debe ser** | ✔ |
| U2 | ídem U, ya con el gate estático | `not_found_screen.dart:51 — GriColors.gray como color de TEXTO` | ✔ |
| W2 | ídem W, ya con el gate estático | `scan_screen.dart:138 — …` | ✔ |
| Y | `restaurante_detalle` de vuelta a gray | `restaurante_detalle_screen.dart:168 — …` | ✔ |
| Z | `const _sonda = GriColors.gray;` en un contexto nuevo | `contexto DESCONOCIDO: clasifícalo` (no lo acepta en silencio) | ✔ |

## Hallazgos

### 1. La guía que el plan prescribía habría pasado verde con el bug puesto

El plan proponía `androidTapTargetGuideline` como el gate del hallazgo "el CTA principal mide
45×45". **No lo detecta.** La rotura **B2** reconstruyó el estado exacto anterior al plan y la
guía pasó:

```
00:00 +1: All tests passed!   (home cumple androidTapTargetGuideline y labeledTapTarget)
```

El motivo se midió con una sonda sobre el árbol de semántica:

```
#5 rect=Rect.fromLTRB(0.0, 0.0, 800.0, 77.0) tap=true label="GRI
GRI
Escanear QR de la mesa"
```

El `InkWell` del `_QrButton` no es un límite de semántica, así que su acción de tap se fusionaba
con **toda la fila de la cabecera**: el logo, el título "GRI" y el botón formaban **un solo nodo de
800×77**. La guía recorre nodos, no widgets — medía 800×77 y no veía los 45.

Consecuencias, las dos reales:

1. **Accesibilidad:** un lector de pantalla anunciaba la cabecera entera como un botón llamado
   "GRI GRI Escanear QR de la mesa".
2. **Verificación:** cualquier plan que hubiera "cerrado" este hallazgo con la guía del plan
   habría entregado un verde sin arreglar nada.

El arreglo es `Semantics(container: true, button: true, label: …)` alrededor del botón. Con él, el
nodo mide justo el botón, la rotura A lo tumba y la cabecera vuelve a ser texto, no un botón.

### 2. El `tooltip` no viaja en `label`, así que `find.bySemanticsLabel` no lo ve

La primera versión del caso de las estrellas usaba `find.bySemanticsLabel('Calificar con N
estrellas')` y salía en rojo **con la etiqueta ya puesta**. La sonda explicó por qué:

```
#12 rect=…(52.0, 52.0) tap=true label="" tooltip="Calificar con 1 estrella"
```

El `tooltip` de un `IconButton` acaba en `SemanticsData.tooltip`, un campo **distinto** de
`.label` (Android lo expone como `tooltipText`). `labeledTapTargetGuideline` acepta los dos de
forma explícita (`accessibility.dart:263`: `if ((data.label.isEmpty) && (data.tooltip.isEmpty))`),
pero `find.bySemanticsLabel` solo mira `label`. El helper del test replica el criterio de la guía
para que ambas aserciones hablen de lo mismo.

**Dato honesto para la verificación de la fase:** 6 de los 7 controles etiquetados por este plan
se anuncian por el campo `tooltip`, no por `label`. Es un nombre accesible válido en Android e
iOS, pero **no se ha oído a TalkBack ni a VoiceOver leerlo**.

### 3. Un barrido de pantallas solo ve lo que monta

El barrido de contraste recorre las 5 pantallas del camino crítico. Las roturas **U** y **W**
devolvieron a `#777777` el texto del 404 y el del escáner: la suite ENTERA siguió en verde, porque
esas dos pantallas no las monta ningún caso. De los 29 puntos migrados, **el barrido solo cubre
11**.

Por eso se añadió el **gate estático** (`GATE ESTÁTICO: GriColors.gray no aparece en ningún
contexto de TEXTO`), que lee las fuentes de `lib/` sin comentarios y clasifica cada aparición por
el marcador más cercano por delante (`Icon(` / `backgroundColor:` legítimos; `TextStyle(` /
`GriText.` / `unselectedItemColor:` / `disabledForegroundColor:` infracción). Un contexto que no
reconoce lo **reporta** en vez de aceptarlo (rotura Z). Lleva autocomprobación de cobertura
(archivos leídos y apariciones clasificadas) para que no pueda quedarse verde por no mirar.

### 4. El `<verify>` de la Tarea 2 del plan es defectuoso — noveno de la fase

`grep -q "0xFF777777" lib/core/theme.dart && echo "GRAY_INTACTO"` pretende blindar el token de
marca. **Pasa igual con el token cambiado**: bajo la rotura F (`GriColors.gray = #6E6E6E`) el gate
imprimió `GRAY_INTACTO`, porque el hex sigue apareciendo en `neutroFg: Color(0xFF777777)`, otra
constante del mismo archivo. Comprueba que *la cadena existe en el archivo*, no que *ese token
valga eso*.

Lo que sí tiene dientes es el test de 11-11 (`expect(GriColors.gray, const Color(0xFF777777))`),
que la rotura F sí tumba. Noveno gate de `grep` defectuoso de la fase (11-06, 11-08 ×2, 11-13 ×2,
11-19, 11-12, y este). 11-12, que corria en paralelo, encontro el octavo.

### 5. Los `constraints` de 48×48 del `PasswordField` son redundantes

Extiende el Hallazgo 3 de 11-11 ("el tema real no puede encoger el área táctil") con una medición
más fuerte: **tampoco los `constraints` la sostienen**. Con
`constraints: BoxConstraints(minWidth: 24, minHeight: 24)` el ojo sigue midiendo 48×48; y
**borrando la línea entera** también:

```
CAJA DEL OJO = Size(48.0, 48.0)
```

Los 48 los pone el `IconButton` de Material 3. El caso de 11-06 se pone rojo porque inspecciona la
**propiedad** `constraints`, no la geometría — afirma la declaración de intención, que es una cosa
legítima, pero **no** que el objetivo táctil haya encogido. No se toca nada: la línea documenta
intención y el coste es cero. Queda escrito para que nadie la cite como la prueba de los 48.

### 6. Sobre el fondo real de la app el contraste es peor que el que citaba la auditoría

La auditoría medía sobre blanco (4.48:1). El fondo de la app cliente es `#F7F7F7`
(`scaffoldBackgroundColor`), donde el mismo gris da **4.180:1**. Los cuatro números, calculados
con la fórmula WCAG dentro del test:

| Color | sobre `#FFFFFF` | sobre `#F7F7F7` |
|---|---|---|
| `GriColors.gray` `#777777` | 4.478 | 4.180 |
| `textoSecundarioAccesible` `#6E6E6E` | 5.099 | 4.760 |

Por eso el token se afirma contra los **dos** fondos. La rotura I lo demuestra: `#767676` pasa
sobre blanco (4.54) y falla sobre el fondo real (4.24) — un valor que una comprobación "sobre
blanco" habría dado por bueno.

## Deviations from Plan

### 1. [Rule 1 — el arreglo prescrito no arregla nada] El contraste NO se aplica en `textTheme`

- **Encontrado en:** Tarea 2.
- **Problema:** el plan mandaba aplicar `textoSecundarioAccesible` "solo en los slots de texto
  secundario pequeño del `textTheme` (`bodySmall` / `labelSmall`)". Sonda sobre login y home
  leyendo el `TextStyle` de **cada párrafo pintado**: todo el texto secundario sale con
  `ls=0.25, h=1.43`, que es `bodyMedium` heredado del `DefaultTextStyle` — `bodySmall` traería
  `0.4 / 1.33`. **Ni un solo texto de esta app pasa por esos slots.**
- **Resolución:** el token se aplica en los **29 puntos de uso reales** (14 archivos). Se respeta
  la INTENCIÓN escrita del plan al pie de la letra ("`gray` se queda para bordes, iconos y
  decoración; el accesible va al texto") con el mecanismo que esta app usa de verdad.
- **Por qué NO se hizo además "por si acaso":** teñir `bodySmall`/`labelSmall` habría cambiado el
  `helperText` y el contador del `InputDecoration` del framework — un cambio visual sin medir en
  una fase con la identidad BLOQUEADA. Y el plan mandaba "migrar ESE punto al slot
  correspondiente", cosa que 11-19 ya midió que **no es pixel-neutral** (12px pasaría de
  257.3×17 a 260.4×16).

### 2. [Rule 2 — funcionalidad crítica ausente] Alcance real de la migración de color

- **Encontrado en:** Tarea 2.
- **Problema:** el plan hablaba de "texto secundario pequeño". El barrido encontró que el gris de
  marca pinta **todo** el texto secundario de la app (12 y 14px), la etiqueta de los tabs
  inactivos del `AppShell` y dos etiquetas de botón deshabilitado.
- **Resolución:** los 29 puntos son TEXTO. Se dejan en `gray` los 9 `Icon`, el fondo del SnackBar
  y el `CircularProgressIndicator`: no son texto y el umbral de WCAG 1.4.3 no les aplica (los
  iconos, a 4.18:1, superan de sobra el 3:1 de 1.4.11 para objetos gráficos).
- **Archivos fuera de `files_modified`:** los 10 de pantalla que el plan no listaba, más
  `app_shell.dart`, `empty_state.dart`, `google_boton.dart` y `not_found_screen.dart`.

### 3. [Rule 2] `GriColors.textoSecundarioAccesible` como `static const`

- 11-11 lo declaró como **campo de instancia** de `GriSemanticColors`, que no sirve dentro de un
  `const TextStyle` (la mayoría de los puntos de uso lo son). El plan, de hecho, lo nombra como
  `GriColors.textoSecundarioAccesible`. Se añade la constante a `GriColors` y la extensión la
  **referencia**: un solo valor, dos caminos de acceso, con un test que afirma la igualdad.

### 4. [Rule 2] Cuatro controles etiquetados que el plan no listaba

- Los **+/− de comensales** del wizard de reserva y el **FAB** de "mis reservas". El FAB no estaba
  ni en la auditoría: contó `IconButton` y esto es un `FloatingActionButton`. Lo destapó la guía.

### 5. [Rule 3] Tests ajenos actualizados

- `test/restaurantes/iconos_test.dart`: el caso que congelaba el botón en 45×45 pasa a exigir 48.
  Lo dejó encargado el propio 11-13 (`AVISO PARA 11-14`).
- `test/shared/app_shell_responsive_test.dart`: `unselectedItemColor` pasa al token accesible, con
  el hex literal a la derecha (criterio de 11-19).
- `test/core/theme_tokens_test.dart`: el caso "…y hoy no está aplicado" ya no era cierto; se
  renombra y se le añade la igualdad entre los dos caminos de acceso al token.

### 6. [Rule 3] El archivo de tests se crea en la Tarea 1, no en la 3

El plan marcaba las Tareas 1 y 2 como `tdd="true"` pero no listaba ningún archivo de test en
ellas, y asignaba `test/a11y/a11y_test.dart` a la Tarea 3. Sin test no hay RED: el archivo se crea
en el paso rojo de la Tarea 1 y crece en cada tarea. El commit `test(...)` de cada tarea contiene
**solo** los tests, así que en ese punto de la historia la suite está de verdad en rojo.

### 7. Ninguna pantalla quedó fuera de `textContrastGuideline`

El plan preveía que la guía de contraste fuese "la más ruidosa" y autorizaba acotarla a login y
registro. No hizo falta: **login, registro, home, menú de la mesa, carrito, calificación y mis
reservas pasan las tres guías**. Lo que sí quedó fuera es deuda REAL, abajo.

## Deuda conocida (medida, NO corregida)

### 1. Blanco sobre el naranja de marca: 3.34:1 en etiquetas de botón de 14px

`textContrastGuideline` falla en **el wizard de reserva** ("Continuar", "Atrás") y en **el 404**
("Volver al inicio"):

```
Expected contrast ratio of at least 4.5 but found 3.34 for a font size of 14.0
```

Es `Colors.white` sobre `GriColors.primary` (`#FF4C05`). **No se puede arreglar sin tocar la
paleta**, que es una decisión BLOQUEADA del usuario. Las pantallas del camino crítico se libran
por un detalle: sus CTA usan **16 bold** (`GriText.botonGrande`) y la guía aplica el umbral de
3:1 al texto grande — 3.34 pasa por 0.34. O sea: **el mismo par de colores cumple o no según el
peso de la fuente**. Las dos pantallas afectadas NO se añadieron a la suite; hacerlo la dejaría
roja sin que nadie pueda arreglarlo. **Requiere decisión del usuario** (oscurecer el naranja de
los botones o poner las etiquetas en 16 bold como el resto).

### 2. `GriSemanticColors.neutroFg` sigue en `#777777`

Es el color del texto del chip de estado **desconocido** (`_ => neutroFg`). Es texto y no llega a
AA, pero cambiarlo tumbaría la aserción `pedidoFg('lo-que-sea') == #777777` de 11-11 y toca la
paleta semántica. Con los 5 estados del wire no debería renderizarse nunca.

### 3. Deuda heredada que este plan NO tocó

- `menu_mesa_screen.dart` y `reserva_wizard_screen.dart` siguen usando `Icons.add_circle_outline`
  y `Icons.remove_circle_outline` sueltos en vez de `GriIcons` (regla de 11-13).
- `docs/ICONOS-app_cliente.md` sigue con los `archivo:línea` desplazados (ya lo declaró 11-19);
  este plan mueve `_QrButton` unas líneas más, así que empeora ligeramente.
- `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart` **sigue regenerado y sin
  commitear**, sin que ningún plan lo reclame (declarado por 11-13 y 11-19). **Este plan tampoco
  lo estageó**: no ejecutó `build_runner` ni tocó ningún `@riverpod`.

## Cambio visual: qué se movió y qué no

**Deliberado y acotado:**

| Qué | Antes | Ahora |
|---|---|---|
| Botón de escanear QR | 45×45 | 48×48 (mismo tint, mismo radio, mismo icono a 22) |
| Texto secundario (29 puntos) | `#777777` | `#6E6E6E` |
| Etiqueta de los tabs inactivos | `#777777` | `#6E6E6E` |
| Etiqueta de los 2 botones deshabilitados | `#777777` | `#6E6E6E` |

**Lo que NO cambió:** `GriColors.gray` (sigue `#777777`), el naranja `#FF4C05`, el ámbar
`#F5A623`, los 9 iconos grises, el fondo del SnackBar, el indicador de progreso, los layouts, la
tipografía, los tamaños y el espaciado. Los `tooltip` no ocupan espacio: aparecen en un overlay al
mantener pulsado (o al pasar el ratón, en web).

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo):**

- Que el botón QR mide 48×48 y que su nodo de semántica **existe por separado** con esa medida.
- Que la cabecera de la home ya no es un botón gigante que arrastra el logo y el título.
- Que los +/− del carrito, las 5 estrellas, los +/− de comensales y el FAB tienen nombre
  accesible, **y con qué palabras exactas** (incluido el singular de "1 estrella").
- Que 7 pantallas cumplen `androidTapTargetGuideline`, `labeledTapTargetGuideline` y
  `textContrastGuideline`.
- Que el texto secundario del login se **pinta** con un color de ratio ≥ 4.5:1 sobre blanco.
- Que ninguno de los 53 párrafos de las 5 pantallas del camino crítico se pinta con `#777777`, con
  canario de cobertura (53 párrafos vistos, 11 con el token nuevo).
- Que `GriColors.gray` no aparece en ningún contexto de TEXTO en las fuentes de `lib/`, con
  autocomprobación de cobertura y reporte explícito de contextos no clasificados.
- Que el token accesible cumple sobre **los dos** fondos de la app, no solo sobre blanco.
- Que `GriColors.gray` sigue valiendo `#777777`.

**Afirmado, NO verificado:**

- **Que un lector de pantalla lea bien la app.** `meetsGuideline` mide geometría y ratios sobre el
  árbol de semántica; no ejecuta TalkBack ni VoiceOver. En particular **no está comprobado** que
  el orden de lectura tenga sentido, ni que las etiquetas suenen bien en voz alta, ni que los 6
  nombres que viajan por el campo `tooltip` se anuncien como se espera en un dispositivo real.
- **Que el nuevo gris se VEA bien.** Es el único cambio de color del plan y no se ha fotografiado
  ni visto en pantalla; este repo no tiene golden tests. `#6E6E6E` vs `#777777` es una diferencia
  de 9 niveles por canal.
- Que el botón QR a 48 no descoloque la cabecera en un móvil real. Crece 3px y el `Row` es
  `spaceBetween`, así que por construcción solo se acerca 3px al título; **no se ha visto**.
- Que el `tooltip` de las 5 estrellas sea buena UX en web, donde aparece al pasar el ratón.
- Que la app cumpla WCAG AA **entera**. Lo verificado son 7 pantallas y un gate de color sobre las
  fuentes. Quedan sin gate de guías: escáner, perfil, detalle de restaurante, estado del pedido y
  lista de restaurantes (esta última se sondeó y pasa las tres).

## Pendiente de verificación humana

1. **Que TalkBack (Android) y VoiceOver (iOS) lean los 7 controles etiquetados** y que lo hagan en
   un orden con sentido. Es lo único que cierra de verdad el hallazgo de la auditoría.
2. **Que el gris nuevo `#6E6E6E` se vea bien** junto al resto de la paleta, en las 14 pantallas.
3. **Decisión sobre la deuda 1:** blanco sobre `#FF4C05` a 14px normal no llega a AA. Hay que
   elegir entre oscurecer el naranja de los botones (toca la paleta BLOQUEADA) o poner esas dos
   etiquetas en 16 bold como las demás.
4. Que el botón QR a 48×48 se vea bien en la cabecera de un móvil real.

## Notas para quien siga

- **11-25 (accesibilidad del panel):** los tres hallazgos de aquí aplican tal cual. (1) Comprueba
  con una sonda si tus controles de icono abren nodo propio ANTES de confiar en
  `androidTapTargetGuideline`. (2) Usa el campo `tooltip` además de `label` al buscar nombres
  accesibles. (3) El panel tiene su propio `textoSecundarioAccesible` en `GriSemanticColors`, sin
  aplicar; añádele la constante en `GriColors` si tus puntos de uso son `const`. Y el fondo del
  panel es `#F5F6F8`, no `#F7F7F7`: recalcula el ratio, no copies el número.
- **Quien cierre la fase:** el `<verify>` `grep -q "0xFF777777"` de este plan no protege nada
  (Hallazgo 4). Y sigue en pie la discrepancia de contabilidad que señaló 11-19: 11-17 tiene
  SUMMARY pero no está en el checklist de `STATE.md`.

## Self-Check: PASSED

- `app_cliente/test/a11y/a11y_test.dart` — FOUND (699 líneas, mínimo exigido 40)
- Commits `c732cda`, `29c2078`, `defb8f5`, `5dc0398`, `950f3ae`, `6d69637` — FOUND
- `flutter test` **+230**, `flutter analyze` **0 issues**, `flutter test test/a11y/` **+16**
- 0 archivos de `panel_admin/` en los 6 commits
