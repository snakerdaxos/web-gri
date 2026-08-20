---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 12
subsystem: panel-admin (sistema de diseño — migración a tokens)
tags: [design-tokens, theme, refactor, gate, flutter, panel-admin]

# Dependency graph
requires:
  - plan: 11-11
    provides: "GriColors, GriSpacing, GriText, GriSemanticColors, griTheme, griCardDecoration, griBotonPrimario, griBotonPeligroTexto, griBotonPeligroContorno"
  - plan: 11-21
    provides: "ResponsivePage, GriIcons, docs/ICONOS-panel_admin.md y su gate de paridad doc↔código (el único test preexistente que se puso rojo con esta migración)"
  - plan: 11-19
    provides: "app_cliente/test/core/sin_hex_crudos_test.dart — el ORIGINAL del gate que este plan porta"
  - plan: 11-10
    provides: "features/equipo/, incluido en el inventario"
provides:
  - "panel_admin/lib/core/theme.dart es de verdad la fuente única de color: 0 Color(0x…) fuera de él"
  - "panel_admin/lib/features/shared/error_box.dart — la caja de error compartida (3 copias privadas retiradas)"
  - "panel_admin/test/core/sin_hex_crudos_test.dart — gate anti-regresión, gemelo del de app_cliente"
  - "panel_admin/test/core/colores_render_test.dart — los tokens migrados se RENDERIZAN, medido contra el hex literal"
  - "griTheme registra floatingActionButtonTheme"
affects: [11-14, 11-20, 11-25]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Un token de color se nombra por lo que ES, no por el color que tiene; dos roles distintos con el mismo hex se declaran por separado (divider vs imagenPlaceholderBg, badgeCategoriaInactiva vs advertencia)"
    - "Toda aserción de color compara contra el hex escrito a mano, NUNCA contra el token: comparar contra el token deja el caso verde justo cuando el token cambia"
    - "Antes de dar por buena una migración de token, romper cada token uno a uno y anotar qué se pone rojo — la cobertura que un plan da por hecha suele no existir"
    - "Un widget compartido que sustituye copias NO idénticas recibe la diferencia por parámetro, con el valor por defecto de la mayoría"

key-files:
  created:
    - panel_admin/lib/features/shared/error_box.dart
    - panel_admin/test/core/sin_hex_crudos_test.dart
    - panel_admin/test/core/colores_render_test.dart
  modified:
    - panel_admin/lib/core/theme.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/dashboard/widgets/stat_card.dart
    - panel_admin/lib/features/mesas/mesas_screen.dart
    - panel_admin/lib/features/mesas/mesa_form_dialog.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/cocina/widgets/pedido_card.dart
    - panel_admin/lib/features/menu/menu_screen.dart
    - panel_admin/lib/features/menu/producto_form_dialog.dart
    - panel_admin/lib/features/reportes/reportes_screen.dart
    - panel_admin/lib/features/configuracion/configuracion_screen.dart
    - panel_admin/lib/features/configuracion/restaurante_form_dialog.dart
    - panel_admin/lib/features/auth/login_screen.dart
    - panel_admin/lib/features/bootstrap/bootstrap_screen.dart
    - panel_admin/lib/features/shared/not_found_screen.dart
    - panel_admin/lib/features/clientes/clientes_screen.dart
    - panel_admin/lib/features/equipo/equipo_screen.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/lib/models/pedido_staff.dart
    - docs/ICONOS-panel_admin.md

key-decisions:
  - "11-12: dos roles visuales distintos que HOY comparten hex se declaran como DOS constantes, no como un alias. divider (#EEEEEE, separador del topbar) e imagenPlaceholderBg (#EEEEEE, fondo de imagen rota); badgeCategoriaInactiva (#E65100, estado del dato) y advertencia (#E65100, consecuencia de una acción). Aliasar afirmaría que son lo mismo y arrastraría un cambio futuro de uno al otro"
  - "11-12: se registra floatingActionButtonTheme porque el panel tiene UN solo FAB y declara exactamente ese par inline — es 1 de 1, no puede cambiar ningún píxel hoy. NO se registran textButtonTheme, outlinedButtonTheme ni inputDecorationTheme: la guarda de 11-11 que afirma su ausencia sigue intacta"
  - "11-12: la ErrorBox compartida recibe el `padding` por parámetro porque las tres copias NO eran iguales — cocina no llevaba el Padding vertical de 32. Medido después: dentro de un Expanded ese padding es un NO-OP, así que la unificación tampoco habría movido píxeles; se conserva EdgeInsets.zero por reproducir la estructura exacta"
  - "11-12: NO se migra ningún fontSize inline a textTheme.* (aviso de 11-19, con la tabla medida). Los dos únicos TextStyle que cambian son los que el doc comment de GriText.boton nombra por archivo:línea, y la sustitución es del MISMO constructor, no de un slot"
  - "11-12: los paddings de página que ya valían 24/32/16/8 pasan a GriSpacing; los de 30, 25 y 22 se DEJAN tal cual. Homogeneizarlos sería un cambio visual, que es lo que el plan prohíbe"

patterns-established:
  - "Todo color del panel sale de core/theme.dart; un Color(0x…) suelto lo caza sin_hex_crudos_test, con exención `// TOKEN-IGNORE: motivo`"
  - "Quien mueva líneas en lib/ del panel tiene que refrescar docs/ICONOS-panel_admin.md: el gate de paridad de 11-21 lo exige y se pone rojo solo"

requirements-completed: [DS-01]

# Metrics
duration: ~2h 40min
completed: 2026-08-19
---

# Phase 11 Plan 12: Migración del panel a los tokens de diseño Summary

**`core/theme.dart` deja de mentir: los 18 literales de color que vivían en 10 archivos, las 7 copias de la sombra de tarjeta, los 9 estilos de botón duplicados y las 3 `_ErrorBox` privadas quedan en un solo sitio — y ni un hex cambia de valor, medido sobre el diff y sobre el render.**

## Performance

- **Duración:** ~2 h 40 min
- **Tareas:** 2/2 (+1 commit de desviación)
- **Archivos:** 3 creados, 21 modificados
- **Roturas deliberadas:** 36 aplicadas y revertidas
- **Tests del panel:** 280 → **292** (+12). `flutter analyze`: **0 issues**

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Los 18 literales sueltos → `GriColors` + duplicados → tema | `+280`, analyze 0, `SIN_HEX_CRUDOS` | `49574cb` (refactor) |
| 2 | Gate `sin_hex_crudos_test.dart` (port del original de 11-19) | `+282`, 6 roturas | `1967dc4` (test) |
| — | **Desviación (Regla 2):** cobertura de render de los tokens | `+292`, 13 roturas | `7b58a40` (test) |

## Gates ejecutados — salida real

| Gate | Resultado |
|---|---|
| `cd panel_admin && flutter analyze` | `No issues found!` |
| `cd panel_admin && flutter test` | `00:14 +292: All tests passed!` (base propia medida: **280**) |
| `cd panel_admin && flutter test test/core/sin_hex_crudos_test.dart` | `00:00 +2: All tests passed!` |
| `cd panel_admin && flutter test test/core/colores_render_test.dart` | `00:01 +10: All tests passed!` |
| `<verify>` de la Tarea 1 (el `grep`), literal | `SIN_HEX_CRUDOS`, exit 0 — **pero es DEFECTUOSO, ver Hallazgo 3** |
| `cd scripts && npm run audit:branding` | `2 apps · 4 archivos · 0 rastros de plantilla`, exit 0 |
| `cd scripts && npm run audit:indexes` | `22 queries · 5 sujetas a paridad · 0 fallo(s)`, exit 0 |
| Auditoría del diff: hex que desaparecen vs. hex que aparecen | **0 valores cambiados** (tabla abajo) |

`test:rules` y `test:functions` **NO se ejecutaron**: dependen de los emuladores y este plan
no toca rules, índices ni functions.

## Inventario del ANTES (evidencia)

`git grep -c "Color(0x" 49574cb^ -- panel_admin/lib` excluyendo `core/theme.dart` →
**18 literales en 10 archivos** (no los 36 del plan: ese número es de la auditoría
PREVIA a 11-11, que ya se había llevado la paleta de pedido y había declarado la sombra).

| Archivo:línea | Literal | Token nuevo |
|---|---|---|
| `shared/app_shell.dart:105` | `0xFFEEEEEE` | `GriColors.divider` |
| `shared/app_shell.dart:258` | `0xFFAAAAAA` | `GriColors.sidebarSubtitulo` |
| `shared/app_shell.dart:314` | `0xFFCCCCCC` | `GriColors.sidebarItemInactivo` |
| `menu/menu_screen.dart:152` | `0xFFE65100` | `GriColors.badgeCategoriaInactiva` |
| `menu/menu_screen.dart:205` | `0xFFFF8F00` | `GriColors.badgeAgotado` |
| `menu/menu_screen.dart:208` | `0xFF9E9E9E` | `GriColors.badgeInactivo` |
| `menu/producto_form_dialog.dart:238` | `0xFFEEEEEE` | `GriColors.imagenPlaceholderBg` |
| `mesas/mesa_form_dialog.dart:241,249` | `0xFFE65100` ×2 | `GriColors.advertencia` |
| `reportes/reportes_screen.dart:385` | `0xFFE8F0FE` | `GriColors.reporteIconoBg` |
| `reportes/reportes_screen.dart:391` | `0xFF3478F6` | `GriColors.reporteIconoFg` |
| `configuracion/restaurante_form_dialog.dart:224` | `0xFF777777` | `GriColors.gray` (ya existía) |
| `models/pedido_staff.dart:183` | `0xFF8E44AD` | `GriColors.pedidoEnPreparacion` |
| `dashboard/widgets/stat_card.dart:44` | `0x0D000000` | `griCardDecoration` |
| `dashboard/dashboard_screen.dart:185,373` | `0x0D000000` ×2 | `griCardDecoration` |
| `cocina/widgets/pedido_card.dart:49` | `0x0D000000` | `griCardDecoration` |
| `reportes/reportes_screen.dart:355` | `0x0D000000` | `griCardDecoration` |

Además, **fuera del grep** porque no son hex: `login_screen.dart:99` y
`bootstrap_screen.dart:136` declaraban la MISMA sombra como
`Colors.black.withValues(alpha: 0.05)` (las 7 copias que 11-11 contó).

## Accomplishments

- **Cero `Color(0x…)` fuera del tema**, y un gate que lo mantiene así con exención
  documentada (`// TOKEN-IGNORE: motivo`).
- **11 constantes nuevas con nombre semántico**, cada una con el `archivo:línea` de donde
  salió en su doc comment, agrupadas por sección siguiendo la organización que ya tenía el
  archivo. La sección de colores de mesa (`theme.dart:37-61`) no se tocó, como pedía el plan.
- **Las 7 copias de la sombra de tarjeta** colapsadas en `griCardDecoration`.
- **9 estilos de botón duplicados** retirados: 6 borrados del todo (el par
  `primary`+`white` lo pone `elevatedButtonTheme` desde 11-11), 2 pasan a
  `griBotonPrimario` (con `padding`/`textStyle` propios por `merge`), 1 a
  `griBotonPeligroContorno` y 3 `Colors.red` a `griBotonPeligroTexto`. El único FAB del
  panel pasa a `floatingActionButtonTheme`.
- **Una sola `ErrorBox`** en `features/shared/`, con el `padding` por parámetro porque las
  tres copias NO eran iguales (Hallazgo 2).
- **12 paddings de página** que ya valían 24/32/16/8 pasan a `GriSpacing`. Los de 30, 25 y
  22 se dejan intactos: cambiarlos sería un cambio visual.
- **La cobertura que el plan daba por hecha se midió y no existía** — y ahora existe
  (Hallazgo 1, y el commit `7b58a40`).

## ¿Cambió algún píxel? — respuesta explícita

**NO cambia ningún color de la interfaz.** Demostrado de dos maneras independientes:

1. **Sobre el diff.** Los hex que desaparecen de `lib/features/**` y los que aparecen en
   `theme.dart`, contados por valor:

   | Hex | Desaparece | Aparece | Explicación |
   |---|---|---|---|
   | `0x0D000000` | 5 | 0 | absorbido por `griCardDecoration`, que ya existía con ese valor |
   | `0xFF777777` | 1 | 0 | pasa a `GriColors.gray`, que YA vale `#777777` |
   | `0xFF8E44AD` | 2 | 1 | dos literales (uno en `pedido_staff`, otro inline en `GriSemanticColors`) colapsan en uno |
   | `0xFFE65100` | 3 | 2 | tres usos → dos constantes con significado distinto |
   | los otros 6 | 1 c/u | 1 c/u | traslado literal |

2. **Sobre el render.** 10 casos nuevos montan las pantallas reales y comprueban que el
   color llega al árbol con el hex escrito a mano. Los 9 tokens que antes no tenía nadie
   mirando ahora ponen rojo su caso al cambiarles un dígito.

**Lo único que se mueve, medido y declarado:** las dos tarjetas de login y bootstrap
pasaban su sombra como `Colors.black.withValues(alpha: 0.05)` y ahora la sacan de
`griCardDecoration`, que la declara como `Color(0x0D000000)`.

| | `withValues(alpha: 0.05)` | `Color(0x0D000000)` |
|---|---|---|
| ARGB de 32 bits | `0x0D000000` | `0x0D000000` — **idéntico** |
| componente `.a` (float) | `0.05` | `0.050980392…` |
| `==` | `false` (el `runtimeType` y el float difieren) | |
| valor sobre blanco, 8 bits | **242** | **242** — mismo píxel |

La diferencia de alfa es **0,00098** y desaparece en la cuantización a 8 bits. Se declara
igualmente porque es el único valor del plan que no es bit a bit el mismo.

**Lo que NO se mueve, también medido:** los tres `TextButton.styleFrom(foregroundColor: Colors.red)`
pasan a `griBotonPeligroTexto` (`#F44336`). Sondeado: `Colors.red` y `Color(0xFFF44336)`
tienen los **cuatro componentes idénticos** (`a=1.0, r=0.95686…, g=0.26274…, b=0.21176…`);
lo único distinto es el `runtimeType` (`MaterialColor` vs `Color`), que no llega al pintor.

**Lo que cambia y NO es color:** nada. No se tocó un layout, un radio, un breakpoint, un
tamaño de fuente ni el orden de un elemento. El `ErrorBox` de cocina conserva su geometría
exacta vía `EdgeInsets.zero`.

## Hallazgos

### 1. La red de seguridad que el plan daba por hecha cubría 2 de 11 tokens (MEDIDO)

El registro de amenazas asigna a **T-11-12-01** («deriva visual durante la migración») la
mitigación «las 175+ pruebas existentes … como red de seguridad». Se midió cambiando el
último dígito de cada token nuevo y ejecutando la suite entera, una rotura por token:

| Token | Efecto de romperlo (ANTES del commit `7b58a40`) |
|---|---|
| `sidebarItemInactivo` | **ROJO** — `app_shell_layout_test.dart` (preexistente, de 11-21) |
| `pedidoEnPreparacion` | **ROJO** — `theme_tokens_test.dart` (preexistente, de 11-11) |
| `divider` | verde |
| `sidebarSubtitulo` | verde |
| `badgeCategoriaInactiva` | verde |
| `advertencia` | verde |
| `badgeAgotado` | verde |
| `badgeInactivo` | verde |
| `imagenPlaceholderBg` | verde |
| `reporteIconoBg` | verde |
| `reporteIconoFg` | verde |
| `griCardDecoration` **dentro de las pantallas** | verde (solo el token estaba afirmado) |
| `floatingActionButtonTheme` | verde |

Los dos rojos son la clase de evidencia que 11-11 estableció: **tests preexistentes que se
ponen rojos sin haber tocado ni un valor esperado**. Prueban que la migración es real en
esos dos puntos. Los once verdes prueban que en los demás la migración estaba **afirmada,
no verificada** — y una migración de color no verificada es exactamente la deriva que el
plan quería impedir.

Se cerró con `test/core/colores_render_test.dart`: 10 casos que **renderizan** el shell, el
menú con los tres badges, la pantalla de reportes con su tarjeta, el FAB de mesas bajo
`griTheme`, los dos diálogos y la `ErrorBox`. Todas las aserciones comparan contra el **hex
literal escrito a mano**, jamás contra el token —comparar contra el token dejaría el caso
verde precisamente cuando el token cambia—, y cada caso lleva una aserción anti-vacuidad
(que el badge / la tarjeta / el aviso esté en pantalla) para que no pueda pasar mirando un
árbol sin nada. Tras añadirlo, los 9 verdes pasan a **rojo, cada uno en su propio caso**.

### 2. Las tres `_ErrorBox` NO eran iguales… y unificarlas tampoco habría movido un píxel

El plan las describe como «`_ErrorBox` reimplementado en `dashboard_screen` y
`mesas_screen` y **el patrón equivalente** en `cocina_screen`». No es equivalente: las de
dashboard y mesas envuelven la caja en `Padding(EdgeInsets.symmetric(vertical: 32))` y la
de cocina **no**. Por eso la compartida recibe el `padding` por parámetro y cocina pasa
`EdgeInsets.zero`.

Al escribir el caso que lo mide apareció lo contrario de lo que se supone:

- En una caja de **alto libre** (dashboard, mesas: dentro de un `Column` que se mide por su
  contenido) el relleno añade **exactamente 64 px**. Medido.
- En una caja de **alto fijo** (cocina: `Expanded`) el relleno es un **NO-OP**. El `Center`
  reparte el sobrante a partes iguales, así que `(H−h)/2 == 32 + (H−64−h)/2`. Medido
  comparando la `dy` del botón «Reintentar» en los dos casos: **idéntica**.

Es decir: unificar las tres copias **sin** el parámetro no habría cambiado un píxel en
cocina. `EdgeInsets.zero` se conserva porque reproduce la estructura exacta que había y
porque el no-op depende del contenedor, no de la `ErrorBox`; hay un caso que lo mide y se
pondrá rojo si deja de ser un no-op. Mismo espíritu que el hallazgo del `SafeArea` de 11-13.

### 3. El `<verify>` de la Tarea 1 es defectuoso EN LAS DOS direcciones (octavo de la fase)

```
test $(grep -rn "Color(0x" lib --include=*.dart | grep -v "core/theme.dart" \
  | grep -v "core/design_tokens.dart" | wc -l) -eq 0 && echo "SIN_HEX_CRUDOS"
```

`grep -v` filtra por el **contenido de la línea**, no por el nombre del archivo. Probado en
vivo con tres inyecciones sobre `reservas_screen.dart`:

| Caso inyectado | gate `grep` | gate Dart |
|---|---|---|
| `const _x = Color(0xFF123456);` | FALLA ✔ | ROJO ✔ |
| `const _x = Color(0xFF123456); // ver core/theme.dart` | **PASA** ✗ falso negativo | ROJO ✔ |
| `/// usa el naranja Color(0xFFFF4C05) del tema` (doc comment legítimo) | **FALLA** ✗ falso positivo | pasa ✔ |

Se ejecutó igualmente tal cual (imprime `SIN_HEX_CRUDOS`, exit 0) y se deja constancia de
que no distingue una infracción real de una mención. Es el **octavo** gate de `grep`
defectuoso de la fase (11-06, 11-08 ×2, 11-13 ×2, 11-19, 11-21 y este). El gate bueno es el
de la Tarea 2, que sí mira el nombre del archivo y sí salta los comentarios.

### 4. El único test preexistente que la migración puso rojo no era de color

Al terminar la Tarea 1, la suite dio **279 −1**: el caso rojo era
`sin_emojis_test.dart: los archivo:línea de la tabla apuntan a donde dicen`, el gate de
paridad doc↔código que 11-21 escribió. La migración desplazó líneas en 8 pantallas y **19
filas** de `docs/ICONOS-panel_admin.md` quedaron apuntando a otro sitio. Se refrescaron con
un script que localiza cada `GriIcons.<nombre>` y respeta el orden dentro de cada archivo.

Ese gate hizo exactamente lo que 11-21 prometía. Pero deja una lección aparte: cuando en la
ronda de roturas se quitó el `EdgeInsets.zero` de cocina (un cambio de **geometría**), el
único rojo de toda la suite fue **otra vez ese mismo gate de líneas** — es decir, un rojo
por el motivo equivocado, que a un ejecutor con prisa le habría parecido cobertura. Es lo
que motivó el caso textual explícito del commit `7b58a40`.

### 5. Dos roles con el mismo hex no son el mismo token

`#EEEEEE` es a la vez el separador del topbar y el fondo del placeholder de una imagen
rota; `#E65100` es a la vez el badge «Inactiva» de una categoría y el aviso de que cambiar
el número de mesa regenera el QR. Se declaran como **cuatro constantes**, no dos con alias:
un alias afirmaría que son la misma decisión y arrastraría un cambio futuro de una a la
otra. La prueba de que la separación es real está en las roturas: romper `divider` pone
rojo el caso del shell y romper `imagenPlaceholderBg` pone rojo el del diálogo — casos
distintos.

## Roturas deliberadas (36)

**Ronda 1 — medición de la cobertura preexistente (14)**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | `sidebarItemInactivo` `CCCCCC`→`CCCCCD` | ROJO (`app_shell_layout_test`, preexistente) | ✔ |
| B–J | `divider`, `sidebarSubtitulo`, `badgeAgotado`, `badgeInactivo`, `badgeCategoriaInactiva`, `advertencia`, `imagenPlaceholderBg`, `reporteIconoBg`, `reporteIconoFg` | **verdes** — Hallazgo 1 | — |
| K | `pedidoEnPreparacion` `8E44AD`→`8E44AE` | ROJO (`theme_tokens_test`, preexistente) | ✔ |
| L | `griCardDecoration` blur 12→10 | ROJO (`theme_tokens_test`) | ✔ |
| M | cocina pierde `padding: EdgeInsets.zero` (+64 px) | ROJO **por el motivo equivocado** (gate de líneas del doc) — Hallazgo 4 | — |
| N | quitar `floatingActionButtonTheme` | **verde** | — |

**Ronda 2 — el gate de la Tarea 2 (6)**

| # | Rotura | Esperado | Real | ✔ |
|---|---|---|---|---|
| R1 | `Color(0xFF123456)` desnudo en `reservas_screen` | rojo | rojo, con `archivo:línea` y el literal | ✔ |
| R2 | el mismo, con `// TOKEN-IGNORE:` en su línea | pasa | pasa | ✔ |
| R3 | el mismo, con `// TOKEN-IGNORE:` en la anterior | pasa | pasa | ✔ |
| R4 | el hex dentro de un comentario | pasa | pasa | ✔ |
| R5 | `design_tokens.dart` renombrado | rojo | rojo: «la exención está colgando» | ✔ |
| R6 | la regexp saboteada (`ColorZZZ`) | rojo | rojo, cae el caso con dientes | ✔ |

**Ronda 3 — el `<verify>` de `grep` del plan (3):** las tres inyecciones de la tabla del
Hallazgo 3.

**Ronda 4 — dientes de los casos nuevos (13)**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| B′–J′ | los **nueve** tokens que en la ronda 1 quedaron verdes | ROJO, **cada uno en su propio caso** | ✔ |
| N′ | quitar `floatingActionButtonTheme` | ROJO (caso del FAB) | ✔ |
| Q′ | el FAB vuelve a declarar `backgroundColor` inline | ROJO (caso del FAB) | ✔ |
| O′ | `StatCard` vuelve a escribir la sombra a mano con `blur: 8` | ROJO (caso de la sombra) | ✔ |
| P′ | cocina pierde `EdgeInsets.zero` | ROJO (caso textual) | ✔ |

## Deviations from Plan

### 1. [Regla 2 — mitigación ausente] La red de seguridad de T-11-12-01 no existía

- **Encontrado en:** Tarea 1, al verificar por rotura en vez de dar el verde por bueno.
- **Problema:** ver Hallazgo 1 — 2 de 11 tokens cubiertos.
- **Resolución:** `panel_admin/test/core/colores_render_test.dart`, 10 casos que renderizan
  y miden contra el hex literal. Commit `7b58a40`.

### 2. [Regla 3 — bloqueante] El gate doc↔código de 11-21 se puso rojo por el desplazamiento de líneas

- **Encontrado en:** Tarea 1, al ejecutar la suite completa.
- **Problema:** ver Hallazgo 4. 19 filas de `docs/ICONOS-panel_admin.md` desactualizadas.
- **Resolución:** refrescadas en el MISMO commit que las movió (`49574cb`). El archivo está
  fuera de `files_modified` del plan, así que queda declarado aquí.

### 3. La `ErrorBox` compartida lleva un parámetro que el plan no contemplaba

- **Encontrado en:** Tarea 1, al comparar las tres copias.
- **Problema:** el plan manda tomar como base la de `dashboard_screen.dart:210-242` y
  sustituir «las tres copias». La de cocina no lleva el `Padding` de 32.
- **Resolución:** `padding` por parámetro con el valor de la mayoría por defecto. Ver
  Hallazgo 2 para lo que se midió después.

### 4. Se registra `floatingActionButtonTheme`, que el plan no pedía

- **Encontrado en:** Tarea 1, al buscar el «FAB de `mesas_screen.dart`» que el plan lista
  entre los estilos de botón duplicados.
- **Problema:** ese FAB ya usaba tokens (`GriColors.primary` + `Colors.white`), así que no
  había hex que migrar, pero seguía declarando el estilo primario por su cuenta — justo lo
  que el `must_have` «el estilo de los botones primarios se declara una sola vez» prohíbe.
- **Resolución:** registrado en `griTheme`. Es 1 de 1, así que no puede cambiar ningún
  píxel hoy; verificado por las roturas N′ y Q′.

### 5. Ejecutado antes que 11-14, que figura en `depends_on`

- El orquestador lo arrancó a propósito (11-21 liberó `panel_admin`). **No hizo falta nada
  de 11-14:** este plan no toca contraste, tamaños táctiles ni
  `GriSemanticColors.textoSecundarioAccesible`, que sigue declarado y sin aplicar tal y
  como 11-11 lo dejó. `GriColors.gray` sigue valiendo `#777777` y sus dos tests siguen
  verdes sin tocarse.

### 6. Alcance NO ejercido, con motivo

- **Tipografía:** solo se sustituyen los DOS `TextStyle(fontSize: 16, bold)` que el doc
  comment de `GriText.boton` nombra por `archivo:línea`. No se migra ningún otro `fontSize`
  inline — el aviso de 11-19 (Hallazgo 1 de su SUMMARY, con la tabla medida) demuestra que
  migrar a `textTheme.*` NO es pixel-neutral, y el `<action>` de la Tarea 1 de este plan no
  lo pide.
- **`griInputOutline`:** las 4 pantallas que declaran `border: OutlineInputBorder()` se
  dejan como están. `griInputOutline` es un `InputDecorationTheme`, así que usarlo en un
  campo suelto obliga a extraerle el `.border` — más indirección, no menos. La decisión de
  11-11 de NO registrarlo sigue vigente y su guarda sigue verde.

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo):**

- Que los **11 tokens nuevos** valen el hex exacto que sustituyen y que ese color **llega
  al árbol renderizado** de la pantalla que lo usa (9 casos nuevos + 2 preexistentes).
- Que **toda** sombra de tarjeta del dashboard renderizado es `0x0D000000` / blur 12 /
  `Offset(0,3)` / radio 15 — no solo que el token lo sea.
- Que el FAB **no declara color** y aun así pinta `#FF4C05` bajo `griTheme`.
- Que el relleno por defecto de `ErrorBox` vale 64 px de alto en una caja libre, y que
  dentro de un `Expanded` es un no-op.
- Que `cocina_screen.dart` sigue pasando `EdgeInsets.zero` (aserción **de fuente**,
  declarada como tal).
- Que el gate de hex detecta un literal nuevo, respeta comentarios, respeta las dos formas
  de `TOKEN-IGNORE`, exime `theme.dart`/`design_tokens.dart` y **falla** si su lista de
  exentos deja de existir o si su regexp se rompe.
- Que `docs/ICONOS-panel_admin.md` vuelve a apuntar a donde dice.
- Que ningún valor hex cambió (auditoría del diff, tabla arriba).

**Afirmado, NO verificado:**

- **Que el panel se VEA igual.** Los tests miden colores y cajas; no comparan capturas y
  este repo no tiene golden tests. La afirmación fuerte que sí está demostrada es *«los
  valores no cambiaron»*; *«el render es idéntico»* se sigue de ella por construcción, pero
  **nadie lo ha fotografiado ni abierto en un navegador**.
- Que la sombra de login y bootstrap se vea igual con `Color(0x0D000000)` en vez de
  `alpha: 0.05`. Lo medido es que el ARGB de 32 bits coincide y que sobre blanco los dos
  cuantizan a 242; la diferencia de 0,00098 en el alfa flotante existe.
- Que los 12 paddings sustituidos no cambien el layout: se demuestra que el valor es el
  mismo (`GriSpacing.lg == 24`, `xl == 32`, `md == 16`, `sm == 8`, con test propio de
  11-11), no se re-mide cada pantalla. Las 34 pruebas de geometría de 11-21 siguen verdes
  sin tocarse, lo cual es una red parcial.
- Que los nombres semánticos elegidos sean los correctos. `advertencia`,
  `badgeCategoriaInactiva` o `reporteIconoFg` son elecciones mías; los gates garantizan que
  el valor no deriva, no que el nombre sea el acertado.
- Que borrar el `style:` de 6 botones sea invisible **en producción**: lo es porque la app
  monta `griTheme` (`app.dart:133`), pero la mayoría de los tests del panel pumpean un
  `MaterialApp` sin tema, así que en ellos esos botones pasan a pintar el color por defecto
  de M3. Ningún caso lo asertaba, por eso la suite no se movió — pero el cambio de
  comportamiento en el entorno de test es real y queda dicho.

## Pendiente de verificación humana

1. **Abrir el panel y mirarlo.** Es el criterio de éxito del plan («la apariencia del
   producto no ha cambiado») y `flutter test` no puede cerrarlo.
2. En particular: las sombras de las tarjetas de **login** y **bootstrap**, que son el único
   valor del plan que no es bit a bit idéntico.
3. Sigue pendiente del plan **11-11**: el aspecto de «Consultar» (reportes) y «Marcar
   ocupada» (reservas) con el naranja de marca. Este plan **no** los tocó.

## Notas para los planes que vienen

- **11-14 / 11-25 (accesibilidad):** el gris de texto secundario del panel es
  `GriColors.gray` (`#777777`) y ya no hay ni un `Color(0xFF777777)` suelto — es un único
  símbolo buscable. Usa `GriSemanticColors.textoSecundarioAccesible` (`#6E6E6E`) y **no
  toques `GriColors.gray`**: hay dos tests que lo impiden. Ojo: al aplicarlo se pondrá rojo
  cualquier caso de `colores_render_test.dart` que dependa de un color que cambies — eso es
  lo que tiene que pasar, actualiza el hex esperado **conscientemente y en el mismo commit**.
- **Quien mueva líneas en `panel_admin/lib`** tiene que refrescar
  `docs/ICONOS-panel_admin.md`: el gate de 11-21 se pone rojo solo y no perdona.
- **El gate `sin_hex_crudos_test.dart` es el gemelo del de `app_cliente`.** Si tocas la
  exención, la regexp o el mensaje en uno, pórtalo al otro: son dos paquetes independientes
  y ninguna suite puede importar a la otra.
- **`colores_render_test.dart` compara contra hex literales a propósito.** Si alguien lo
  «simplifica» sustituyéndolos por `GriColors.x`, el archivo deja de valer para nada: pasaría
  verde justo cuando el token cambia. Está escrito en su cabecera.
- El `<verify>` de `grep` de cualquier plan futuro sobre hex debe probarse contra la forma
  real del fallo antes de fiarse (Hallazgo 3). Van ocho en esta fase.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco:
`panel_admin/lib/features/shared/error_box.dart` (68 líneas, mínimo del plan 25),
`panel_admin/test/core/sin_hex_crudos_test.dart` (158 líneas, mínimo del plan 20),
`panel_admin/test/core/colores_render_test.dart` (483 líneas).
Commits verificados en `git log`: `49574cb`, `1967dc4`, `7b58a40` — los tres FOUND, y los
tres con **0** archivos fuera de `panel_admin/` y `docs/ICONOS-panel_admin.md`.
`key_links` del plan: `GriColors.` aparece **144** veces en `panel_admin/lib/features/`.
