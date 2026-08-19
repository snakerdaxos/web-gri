---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 21
subsystem: panel-admin (capa visual completa)
tags: [responsive, layout, renderflex, iconografia, material-icons, flutter, tdd]

# Dependency graph
requires:
  - plan: 11-11
    provides: "GriBreakpoints (750/1100), GriSpacing, GriColors y el gate de paridad token↔código"
  - plan: 11-10
    provides: "features/equipo/ y el ítem 'Equipo' del sidebar con su emoji provisional"
  - plan: 11-09
    provides: "not_found_screen.dart del panel (con su emoji camuflado en escape)"
  - plan: 11-07
    provides: "bootstrap_router_test.dart, el primer test que renderizó el AppShell entero — y el filtro de overflow que lo tapaba"
provides:
  - "panel_admin/lib/features/shared/responsive_page.dart — techo de contenido y breakpoints compartidos"
  - "panel_admin/lib/core/gri_icons.dart — 20 iconos semánticos del panel"
  - "7 desbordes de RenderFlex cerrados (4 del inventario del plan + 3 que no estaban)"
  - "Los 3 filtros de overflow del repo retirados (el plan solo conocía 1)"
  - "test/shared/sin_filtros_overflow_test.dart — gate que distingue filtro de detector"
  - "test/core/sin_emojis_test.dart — gate anti-emoji + paridad GriIcons↔doc"
  - "docs/ICONOS-panel_admin.md"
affects: [11-14, 11-19, 11-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toda pantalla del panel se envuelve en ResponsivePage; el ancho de decisión lo da LayoutBuilder, nunca MediaQuery (dentro del shell la ventana es el número equivocado)"
    - "Un test que recoge desbordes de RenderFlex se declara `// OVERFLOW-DETECTOR:` y afirma `isEmpty`; cualquier otro uso de esa cadena es un filtro y el gate lo caza"
    - "Los gates parametrizados por ruta llevan un texto marcador por ruta: un go() que falle en silencio dejaría todos los casos midiendo la misma pantalla"
    - "La tabla emoji→icono se verifica contra el código en las dos direcciones (nombres, Icons.* y archivo:línea), no solo se escribe"

key-files:
  created:
    - panel_admin/lib/features/shared/responsive_page.dart
    - panel_admin/lib/core/gri_icons.dart
    - panel_admin/test/shared/app_shell_layout_test.dart
    - panel_admin/test/shared/responsive_test.dart
    - panel_admin/test/shared/sin_filtros_overflow_test.dart
    - panel_admin/test/core/sin_emojis_test.dart
    - docs/ICONOS-panel_admin.md
  modified:
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/dashboard/widgets/stat_card.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_tile.dart
    - panel_admin/lib/features/mesas/mesas_screen.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/cocina/widgets/pedido_card.dart

key-decisions:
  - "11-21: los 85px y 33px del sidebar SÍ se reproducen, pero en el entorno de test, donde cada glifo ocupa 1 em. Con una fuente proporcional la aritmética dice que caben. Se arregla igual (el Expanded hace el sidebar correcto por construcción), pero la afirmación del plan «visible en producción a cualquier ancho» NO queda verificada"
  - "11-21: el sidebar COLAPSADO estaba roto por geometría pura (badge de 45px en 40px útiles → 5px, e icono de 25 en 12 → 13px × 8 ítems) y eso NO depende de la fuente: es el único desborde del sidebar con evidencia de ser visible en producción, y no estaba en el inventario del plan"
  - "11-21: el `childAspectRatio: 2.6` de las stat cards se sustituye por un alto FIJO. El alto salía del ancho del viewport: 188px a 1 columna, 129 a 2, 87 a 4 (roto) y 149 a 1920. Nunca fue una decisión de diseño"
  - "11-21: el gate del plan `grep -c 'RenderFlex overflowed' == 0` es DEFECTUOSO: no distingue un filtro que suprime de un detector que afirma. Se sustituye por un test que exige marcador + aserción de vacío"
  - "11-21: los grids de mesas pasan a maxCrossAxisExtent 325 (no 260, que habría cambiado las columnas); el grid de STATS no se convierte, porque su salto 2→4 no es reproducible con un delegate monótono y una quinta columna no significa nada con 4 tarjetas fijas"
  - "11-21: los casos que buscan `find.byIcon(GriIcons.mesas)` son tautológicos respecto a QUÉ icono se eligió. La protección real es el gate que compara GriIcons contra docs/ICONOS-panel_admin.md en las dos direcciones"

patterns-established:
  - "Antes de dar por bueno un arreglo de layout, sondear el shell a 450/500/550/600/900/1280/1440/1920: cuatro de los siete desbordes de este plan solo aparecen fuera de los dos anchos que el plan pedía medir"

requirements-completed: [DS-02, DS-03]

# Metrics
duration: ~4h
completed: 2026-08-19
---

# Phase 11 Plan 21: Todo lo visible del panel admin Summary

**El panel deja de desbordar por siete sitios, deja de estirarse de borde a borde en un monitor de 1920, y su interfaz deja de depender de la fuente de emoji del sistema operativo — con los tres filtros de overflow del repo retirados y sustituidos por detectores que afirman en vez de esconder.**

## Performance

- **Duración:** ~4 h
- **Tareas:** 3/3
- **Archivos:** 7 creados, 20 modificados
- **Roturas deliberadas:** 29 aplicadas y revertidas (26 rojas como se esperaba, 1 verde esperada, 2 mal diseñadas y rehechas)
- **Tests del panel:** 226 → **280** (+54). `flutter analyze`: **0 issues**

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Sidebar + StatCard + retirada de filtros — RED | 5 casos rojos con los px medidos | `4872666` (test) |
| 1 | Sidebar + StatCard — GREEN | `+235`, analyze 0 | `7e0d330` (fix) |
| 2 | ResponsivePage en las 12 pantallas — RED | suite sin compilar (`ResponsivePage` no existe) | `67859cc` (test) |
| 2 | ResponsivePage — GREEN | `+273`, analyze 0 | `dea78d7` (feat) |
| 3 | Emojis → iconos — RED | 33 líneas señaladas por el gate | `9c67d7e` (test) |
| 3 | Emojis → iconos — GREEN | `+280`, analyze 0 | `5e55e8b` (feat) |

## Gates ejecutados — salida real

| Gate | Resultado |
|---|---|
| `cd panel_admin && flutter analyze` | `No issues found!` |
| `cd panel_admin && flutter test` | `00:34 +280: All tests passed!` (base propia: 226) |
| `flutter test test/bootstrap/ test/dashboard/` (T1) | `+91: All tests passed!` |
| `flutter test test/shared/responsive_test.dart test/reservas/` (T2) | `+42: All tests passed!` |
| `flutter test test/core/sin_emojis_test.dart` (T3) | `+4: All tests passed!` |
| Cobertura responsive (`ADAPT` vs `TOT` del árbol) | `adaptan 12 de 12` · exit 0 |
| Tabla de iconos (`grep -c '^|' >= 10 && Conservados && GriIcons`) | `TABLA_ICONOS_OK` · 45 filas |
| **Gate T1 del plan, literal** (`grep -c "RenderFlex overflowed" test == 0`) | **7 ocurrencias · exit 1 — DEFECTUOSO, ver Hallazgo 2** |
| `git show --name-only` de los 6 commits ∩ `app_cliente` | **0 archivos** — el paralelismo con 11-13 se respetó |

## Accomplishments

- **Siete desbordes cerrados, no cuatro.** El plan inventariaba 4 (sidebar 85, ítem 33, StatCard 31, `_ReservaCard`). Sondando el shell real aparecieron **tres más**, todos con su medida:

  | # | Dónde | Cuánto | Cuándo | ¿En el plan? |
  |---|---|---|---|---|
  | 1 | logo del sidebar | 85 px derecha | cualquier ancho ≥ 750 | sí |
  | 2 | etiqueta del ítem de menú | 33 px derecha | cualquier ancho ≥ 750 | sí |
  | 3 | `StatCard` en grid de 4 columnas | 31 px abajo | ~1100–1400 px, **no** a 1920 | sí (con el rango mal) |
  | 4 | `_ReservaCard` | 60 px derecha | ≤ 650 px de tarjeta | sí |
  | 5 | **badge del logo, sidebar COLAPSADO** | **5 px derecha** | **todo ancho < 750** | **no** |
  | 6 | **cada ítem del menú colapsado (×8)** | **13 px derecha** | **todo ancho < 750** | **no** |
  | 7 | **cluster de usuario del topbar** | **77 px derecha** | 800 px de ventana | **no** |
  | 8 | **cabecera del mapa de mesas** | **148 px derecha** | 800 px de ventana | **no** |
  | 9 | **cabecera de `/cocina`** | **150/100/50/0.25 px** | 450/500/550/600 px | **no** |
  | 10 | **`DropdownButton` del super_admin** | fila interna de 288 px | al acotar el topbar | **no** (lo destapó el arreglo #7) |

- **Los TRES filtros de overflow retirados.** El plan solo conocía el de `bootstrap_router_test.dart:53`. Había dos más, copiados de él con el mismo comentario: `test/router_404_test.dart` (11-09) y `test/equipo/equipo_gating_test.dart` (11-10). Los tres fuera; los tres archivos siguen verdes sin ellos.

- **El defecto del sidebar colapsado no es de fuente, es de aritmética.** 70 px de ancho − 15 de padding a cada lado = 40 útiles, y el badge del logo mide 45. El ítem de menú deja 12 para un icono de 25. Ocurre a **cualquier** ancho por debajo de 750 y no depende de la tipografía. Es el único desborde del sidebar del que se puede afirmar que se ve en producción.

- **Las 12 pantallas del panel adaptan**, contadas del árbol y no contra una constante. El contenido tiene techo de 1200 px, así que en un monitor de 1920 deja de estirarse los ~1670 px que quedaban tras el sidebar. Login, bootstrap y 404 dejan de copiar a mano `Center + ConstrainedBox(400)` — y la tarjeta sigue midiendo **400 clavados**, afirmado por un test.

- **33 emojis fuera de la interfaz**, incluido uno que ningún `grep` de glifos podía ver: el 404 tenía `Text('\u{1F9ED}')`, un emoji escrito como secuencia de escape. Por eso el inventario del plan (~47 por `grep`) no lo listaba.

- **Dos sustituciones corrigen el SIGNIFICADO, no solo la fuente:** el `📷` de «Ver código QR» era una **cámara** (el panel *genera* el QR; escanearlo es de la app cliente), y el `👇` de «Selecciona un restaurante» apuntaba **hacia abajo** a un selector que está **arriba**.

## Deviations from Plan

### 1. [Rule 1 - Bug] Cuatro desbordes fuera del inventario del plan

- **Encontrado en:** Tareas 1 y 2, sondando el shell real a 450–1920 px.
- **Problema:** sidebar colapsado (5 px + 13 px × 8), topbar (77 px), cabecera del mapa de mesas (148 px) y cabecera de `/cocina` (hasta 150 px).
- **Resolución:** arreglados con el mismo patrón (`Expanded`/`Flexible` + `ellipsis`) y el padding del sidebar colapsado bajado de 15/14 a 10. Cubiertos por `app_shell_layout_test.dart` y por el bucle de 600 px de `responsive_test.dart`.
- **Commits:** `7e0d330`, `dea78d7`.

### 2. [Rule 3 - Bloqueante] El gate T1 del plan es defectuoso

- **Encontrado en:** Tarea 1, al escribir el detector.
- **Problema:** `test $(grep -rn "RenderFlex overflowed" test | wc -l) -eq 0` no distingue un **filtro** (se traga el desborde para quedarse verde) de un **detector** (lo recoge para afirmar que no hay ninguno). Los dos contienen la misma cadena. Tal cual, el único modo de pasarlo es quedarse sin detectores — lo contrario de lo que la fase quiere. **Ejecutado literalmente: 7 ocurrencias, exit 1.**
- **Resolución:** `test/shared/sin_filtros_overflow_test.dart`. Un archivo que mencione la cadena tiene que declararse `// OVERFLOW-DETECTOR:` **y** contener una aserción `isEmpty`; si no, es un filtro. Además exige que HAYA al menos 2 detectores, para que borrarlos no lo deje verde por vacuidad (rotura N).
- **Límite conocido y declarado:** el gate es textual. Un filtro escrito con el literal partido (`'A RenderFlex over' 'flowed'`) lo evade — se comprobó (rotura M). La reintroducción realista, que es copiar y pegar el filtro de antes, sí lo pone rojo (rotura M-bis).

### 3. [Rule 4 → resuelta sin usuario] El techo de 1200 y la «quinta columna» del plan son incompatibles

- **Encontrado en:** Tarea 2.
- **Problema:** la misma tarea pide (a) acotar el contenido a 1200 px y (b) que en pantallas ultraanchas «aparezca una quinta columna en vez de tarjetas gigantes». Con el techo puesto no hay pantallas ultraanchas: el contenido nunca pasa de 1200, así que no hay tarjetas gigantes que arreglar ni columna nueva que añadir. El `maxCrossAxisExtent: 260` que proponía el plan además **cambiaba** las columnas a 1280 y 1440, que la misma tarea prohíbe.
- **Resolución:** techo de 1200 (el objetivo que el usuario puede ver) + `maxCrossAxisExtent: 325` en los **grids de mesas**, valor elegido para reproducir el 4/3/2 anterior en los anchos reales (verificado a 950, 1050, 1280, 1440 y 1920 contra la regla histórica escrita en el propio test). El **grid de stats NO se convierte**: su salto 2→4 no es reproducible con un delegate monótono, y una quinta columna no significa nada con exactamente 4 tarjetas.
- **Límite declarado:** por debajo de ~500 px de contenido el delegate da 1 columna donde la regla vieja daba 2, y hay bandas de ≤5 px alrededor de 750 y 1100 donde el salto cae un pelo antes. Documentado en el doc comment de `mesaGridDelegate`.

### 4. [Rule 3 - Bloqueante] El gate de paridad de breakpoints de 11-11 se quedó sin objeto

- **Encontrado en:** Tarea 2, al ejecutar la suite completa.
- **Problema:** ese gate recogía los literales `maxWidth <|>= N` de las 3 pantallas de layout y exigía `{750, 1100}`. Al migrarlas a `GriBreakpoints.compact/.expanded` no queda ningún literal, y el gate se ponía rojo por haber **desaparecido su objeto**, no por una regresión.
- **Resolución:** reescrito, exactamente como pedía su propio mensaje de fallo («el gate quedó ciego y hay que reescribirlo, no borrarlo»). Ahora vigila lo que sí puede volver a pasar: que reaparezca un número suelto, o que las pantallas dejen de mirar el token.

### 5. [Rule 2] El `DropdownButton` del super_admin no encogía

- **Encontrado en:** Tarea 1, al acotar el topbar: el desborde se movió de la fila exterior al interior del dropdown (celda de 288 px).
- **Problema:** un `DropdownButton` se dimensiona por el ítem más ancho y no encoge. El nombre del restaurante lo escribe el operador y no tiene tope.
- **Resolución:** `isExpanded: true` + `ConstrainedBox(maxWidth: 260)` + `ellipsis` en los ítems. **Es un cambio visual declarado:** el selector pasa de tener el ancho de su nombre más largo a un máximo de 260 px.

### 6. El estado vacío de cocina pierde el `🎉` de dentro de la frase

- El plan lo dejaba «a decidir». `'No hay pedidos activos 🎉'` pasa a `Icon(GriIcons.todoAlDia, size: 18)` **encima** del texto, y el texto queda limpio. `cola_test.dart` cambia de finder, no de aserción.

## Hallazgos

### 1. Los 85 px del sidebar son del entorno de test, no necesariamente de producción

`flutter test` corre con `--use-test-fonts`: **cada glifo ocupa 1 em**. Con eso, `Gestión de Restaurante` a 11 px pide 22 × 11 = 242 px; con el badge (45) y el hueco (12) son ~299 px en 220 útiles → los 85 medidos. Con una fuente proporcional real, esas 22 letras piden ~121 px y el total ~178: **cabe**. La misma aritmética explica los 33 px del ítem (`Configuración` = 13 × 14 = 182 en 152 útiles; con Roboto ~91).

11-07 escribió que era «un defecto real visible en producción hoy, no un artefacto de test». **Esa afirmación no queda verificada por la evidencia que tengo.** El arreglo se aplica igual y es el correcto —`Expanded` + `ellipsis` hace el sidebar correcto por construcción, sea cual sea la fuente, el idioma o la escala de texto del sistema—, pero el SUMMARY no puede repetir una afirmación que la medición no sostiene.

Lo que **sí** es independiente de la fuente, y por tanto sí se ve en producción: el sidebar colapsado (#5 y #6, pura geometría de 45 en 40) y el desborde de `StatCard` (#3, alturas de línea sobre un alto de celda derivado del ancho).

### 2. El rango del desborde de `StatCard` que decía el plan es incorrecto

El plan decía «viewport ≥ 1100 px». Es una **banda**, no una cola: el alto de la celda es `ancho/2.6`, así que crece con el viewport. A 1200 px de ventana la celda mide 87 px para 115 de contenido (roto); a 1920 mide 149 y **cabe de sobra**. Por eso el caso a 1920 de la Tarea 1 pasó sin arreglar nada y hizo falta el caso a **1200**, que es justo el que el plan pedía añadir.

De paso: el `childAspectRatio: 2.6` daba 188 px de alto a 1 columna, 129 a 2, 87 a 4 y 149 a 1920. El alto de la tarjeta nunca fue una decisión de diseño; era un efecto colateral del ancho. Ahora es `mainAxisExtent: 130`, y un test afirma que ese número sigue siendo ≥ el alto natural medido de la tarjeta.

### 3. Un comentario de test llevaba dos planes mintiendo sobre lo que probaba

`stats_render_test.dart` decía «800 de ancho ⇒ el grid de stat cards cae a **1 columna**». Es falso: 800 ≥ `GriBreakpoints.compact` (750), así que el tramo ejercitado siempre fue el de **2 columnas**. Corregido, y añadido un caso que lo **afirma** midiendo las coordenadas de las 4 tarjetas.

### 4. Los casos que buscan por `find.byIcon(GriIcons.x)` son tautológicos

Rotura AG: cambiar `GriIcons.mesas` de `table_restaurant_outlined` a `chair_outlined` dejó **toda** la suite del sidebar en verde. Es lógico —el finder usa el mismo token que el código— y no es un fallo del caso: lo que ese caso afirma es que se renderiza un `Icon` y no un `Text`, y eso sí lo prueba.

Pero deja un hueco real: T-11-21-04 («pérdida de significado al mapear emoji → icono»). Se cierra con un gate que compara `lib/core/gri_icons.dart` contra `docs/ICONOS-panel_admin.md` en las dos direcciones (mismos nombres, mismo `Icons.*`) y comprueba además que los `archivo:línea` de la tabla apuntan de verdad a donde dicen. **Sin copiar el mapa a mano en ninguna tercera parte.** Roturas AG-bis, AM y AN.

### 5. `pumpAndSettle` con su timeout por defecto cuesta 10 minutos por caso

El primer intento del test del shell se quedó colgado 10 minutos por caso: `pumpAndSettle` tiene un timeout por defecto de 10 min y, si algo no se estabiliza, no dice nada hasta agotarlo. Peor: al fallar un `expect` con `FlutterError.onError` todavía sustituido, el harness aborta con «A test overrode FlutterError.onError…» y el motivo real se pierde. Los dos helpers de este plan pasan un timeout explícito de 30 s simulados y restauran el hook en un `finally`, **antes** de cualquier `expect`.

## Roturas deliberadas (29)

**Tarea 1 — geometría del shell (14)**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | quitar el `Expanded` del logo | rojo (85 px) | ✔ |
| B | quitar el `Expanded` de la etiqueta del ítem | rojo (33 px) | ✔ |
| C | padding del sidebar colapsado 10 → 15 | rojo (5 px) | ✔ |
| D | padding del ítem colapsado 10 → 14 | rojo (13 px × 8) | ✔ |
| E | quitar el `Flexible` del cluster de usuario | rojo (77 px) | ✔ |
| F | ancho del sidebar 250 → 260 | rojo | ✔ |
| G | punto de colapso 750 → 650 | rojo | ✔ |
| H | `isExpanded: false` en el dropdown | rojo | ✔ |
| I | volver a `childAspectRatio: 2.6` | rojo (a 1200) | ✔ |
| J | `alturaStatCard` 130 → 100 | rojo | ✔ |
| K | quitar `maxLines: 1` de la etiqueta de la card | rojo | ✔ |
| L | quitar el `Expanded` de «Estado de las mesas» | rojo (148 px) | ✔ |
| M | filtro reintroducido con el literal **partido** | **verde** — límite declarado del gate | — |
| M-bis | filtro reintroducido tal cual (copia-pega) | rojo | ✔ |
| N | borrar los dos archivos detectores | rojo (`detectores: 0`) | ✔ |

**Tarea 2 — responsive (12)**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| N2 | quitar `ResponsivePage` de `clientes_screen` | rojo (cobertura) | ✔ |
| O | `anchoMaxContenido` 1200 → 2000 | rojo (6 casos) | ✔ |
| P | `ConstrainedBox` sin techo | rojo (9 casos) | ✔ |
| Q | `maxCrossAxisExtent` 325 → 260 | rojo (columnas) | ✔ |
| R | `_anchoFilaUnica` 900 → 2000 | rojo (caso h) | ✔ |
| S | `_anchoFilaUnica` 900 → 100 | rojo (caso g) | ✔ |
| U | techo del login sin el padding sumado | rojo (tarjeta ≠ 400) | ✔ |
| V-bis | 404 con `maxWidth: double.infinity` | rojo | ✔ |
| X | el `go(ruta)` del helper apunta siempre a `/` | rojo (13 casos: los marcadores) | ✔ |
| Z | sembrar 3 mesas en vez de 8 | rojo (columnas) | ✔ |
| Y | `Expanded` → `Flexible + softWrap:false` en la cabecera de reservas | **verde** — rotura mal diseñada, `Flexible` también acota | — |
| Y-ter | quitar el `Expanded` entero | rojo | ✔ |
| AA | volver a `Row` en la fila estrecha de acciones | rojo (60 px a 420) | ✔ |
| AB-bis | quitar el `Expanded` de la cabecera de cocina | rojo (a 600) | ✔ |

**Tarea 3 — iconografía (9)**

| # | Rotura | Esperado | Real | ✔ |
|---|---|---|---|---|
| AC | emoji en un literal de `lib/` | rojo | rojo | ✔ |
| AD-bis | emoji en un **comentario** | verde | verde | ✔ |
| AE | emoji como `\u{1F389}` en un literal | rojo | rojo | ✔ |
| AF | emoji con `// EMOJI-OK:` | verde | verde | ✔ |
| AG | cambiar el valor de `GriIcons.mesas` | rojo | **verde** | Hallazgo 4 |
| AG-bis | ídem, con el gate doc↔código puesto | rojo | rojo | ✔ |
| AH / AK | `size` del icono 18→20 y 24→26 | rojo | rojo | ✔ |
| AI | quitar el `semanticLabel` al colapsar | rojo | rojo | ✔ |
| AJ | color del icono a un literal | rojo | rojo | ✔ |
| AL | `size` del icono de la stat card 25→20 | rojo | rojo | ✔ |
| AM | línea falseada en la tabla del doc | rojo | rojo | ✔ |
| AN | fila borrada de la tabla del doc | rojo | rojo | ✔ |

Las tres verdes inesperadas (M, AG, Y) están explicadas arriba y las tres tienen su rotura corregida al lado.

## Cambio visual: qué se movió y qué no

**No cambia:** ni un color, ni un breakpoint, ni el orden de un solo elemento, ni el ancho del sidebar (250/70), ni el número de columnas de ningún grid en los anchos en los que el panel se usa.

**Cambia, y aquí queda declarado:**

| Sitio | Antes | Ahora | Por qué |
|---|---|---|---|
| Contenido de las 8 pantallas de trabajo | hasta ~1670 px en un monitor de 1920 | tope de 1200 px, centrado | es el objetivo del plan |
| Alto de las stat cards | 188 / 129 / 87 / 149 px según el ancho | 130 px siempre | el de 87 estaba recortando |
| Padding del sidebar **colapsado** | 15 h (ítem 14) | 10 h (ítem 10) | con 15 el contenido no cabía en 70 px |
| Selector de restaurante (super_admin) | ancho del nombre más largo | máximo 260 px, con ellipsis | un nombre largo rompía el topbar |
| `_ReservaCard` a < 900 px de tarjeta | una fila que se salía | dos filas | el desborde #4 |
| Estado vacío de cocina | `No hay pedidos activos 🎉` | icono encima + texto limpio | emoji dentro de la frase |
| 404 | texto a lo ancho de todo el panel | tope de 400 px | no tenía techo |
| Toda la iconografía | emoji del sistema | `Icons.*` de Material | decisión del usuario |

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo):**
- Que el shell con sesión no produce ningún `RenderFlex` desbordado a 600, 700, 800, 900, 1280 y 1920 px, en las 8 rutas de trabajo.
- Que el punto de colapso sigue en 750 y los anchos del sidebar en 250/70.
- Que el dashboard a 1200 px no desborda y que las 4 stat cards van en una fila de alto `alturaStatCard`, que es ≥ el alto natural medido de la tarjeta.
- Que el grid de mesas da **exactamente** las columnas de la regla histórica a 950/1050/1280/1440/1920.
- Que las 12 pantallas del árbol adaptan, y que a 1920 el contenido está acotado y a 900 llena la caja.
- Que la tarjeta de login/bootstrap sigue midiendo 400 px exactos.
- Que `_ReservaCard` es una fila a 1200 y dos a 650, comprobado por coordenadas.
- Que ningún test del repo suprime desbordes, y que quedan al menos dos detectores.
- Que `lib/` no tiene emojis fuera de comentarios, ni como glifo ni como escape.
- Que `GriIcons` y `docs/ICONOS-panel_admin.md` dicen lo mismo, y que los `archivo:línea` de la tabla apuntan a donde dicen.
- Que el `size` de los iconos del sidebar (18/24) y de las stat cards (25) es el `fontSize` del `Text` que sustituyeron.

**Afirmado, NO verificado:**
- **Que las pantallas se VEAN bien.** Un test de widget demuestra geometría; no demuestra criterio. **Nadie ha visto renderizado** el panel con iconos de Material en lugar de emojis, ni con el contenido acotado a 1200 px.
- Que los 85 px y 33 px del sidebar se vieran en producción (Hallazgo 1): la evidencia dice que son del entorno de test.
- Que `Icons.badge_outlined` sea el icono correcto para «Equipo», o `Icons.arrow_upward` para «el selector está arriba». Son elecciones mías; el gate garantiza que están documentadas y que no derivan, no que sean las acertadas.
- Que 1200 px sea el techo correcto. Es un número razonado, no medido contra un diseño.
- Que 130 px sea el alto correcto de la stat card: está elegido para que quepa con margen y para parecerse al que ya tenía en el tramo de 2 columnas.

## Pendiente de verificación humana

1. **Abrir el panel y mirarlo.** Es el objetivo del plan y es lo único que un test no puede hacer.
2. El aspecto del **selector de restaurante** acotado a 260 px con un nombre largo.
3. Si el **techo de 1200 px** es el que el usuario quiere en su monitor, o prefiere más/menos.
4. Si el **estado vacío de cocina** sin el `🎉` sigue transmitiendo lo mismo.

## Notas para los planes que vienen

- **11-14 (accesibilidad):** los iconos que van SOLOS ya llevan `semanticLabel` (sidebar colapsado, badge de marca). Los que acompañan a un texto visible no lo llevan a propósito — anunciarlos duplicaría la lectura. `GriIcons` es el sitio donde ampliar, nunca la pantalla.
- **11-19 / 11-20:** `ResponsivePage.anchoMaxContenido` (1200) y `anchoMaxFormularioConPadding` (448) son los dos techos del panel; no inventar terceros.
- Quien toque `docs/ICONOS-panel_admin.md` o `lib/core/gri_icons.dart` tiene que tocar **los dos**: `test/core/sin_emojis_test.dart` los compara.
- El bucle de anchos de `responsive_test.dart` está a 600 px. Bajarlo a 550 pone rojo el `MesaTile` (ver `deferred-items.md`), que es una decisión de diseño pendiente.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco:
`panel_admin/lib/features/shared/responsive_page.dart`, `panel_admin/lib/core/gri_icons.dart`,
`panel_admin/test/shared/app_shell_layout_test.dart`, `panel_admin/test/shared/responsive_test.dart`,
`panel_admin/test/shared/sin_filtros_overflow_test.dart`, `panel_admin/test/core/sin_emojis_test.dart`,
`docs/ICONOS-panel_admin.md`.
Commits verificados en `git log`: `4872666`, `7e0d330`, `67859cc`, `dea78d7`, `9c67d7e`, `5e55e8b`.
