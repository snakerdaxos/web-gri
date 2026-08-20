---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 19
subsystem: ui
tags: [design-tokens, refactor, tipografia, espaciado, gate, flutter, app_cliente]

# Dependency graph
requires:
  - phase: 11-11
    provides: "GriColors / GriSpacing / GriRadius / GriText / GriSemanticColors y griTheme"
  - phase: 11-13
    provides: "el shell reescrito, GriIcons y el test de iconos que sirve de red preexistente"
  - phase: 11-17
    provides: "google_boton.dart con su `// TODO(11-19)` explícito"
  - phase: 11-09
    provides: "EmptyState y not_found_screen (código nuevo de la fase, incluido en el inventario)"
provides:
  - "app_cliente sin un solo `Color(0x…)` fuera de core/theme.dart"
  - "GriColors.calificacionEstrella / gradienteInicio / gradienteFin / divisor / bordeBotonGoogle"
  - "griGradienteRestaurante: el degradado de cabecera, antes copiado en 4 sitios"
  - "GriText.botonGrande (16 bold): la etiqueta de los 9 CTA de la app"
  - "test/core/sin_hex_crudos_test.dart: gate anti-regresión con exención `// TOKEN-IGNORE:`"
  - "MEDICIÓN: migrar a ThemeData.textTheme NO es pixel-neutral salvo para bodyMedium"
affects: [11-12, 11-14]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Migración 1:1 DEMOSTRADA, no afirmada: sustituir cada token por su valor reproduce los 16 archivos de pantalla con el mismo multiconjunto de números, hex y pesos que antes del plan"
    - "Una aserción de render compara contra el HEX/NÚMERO literal, nunca contra el token: comparar contra el token la deja verde cuando el token cambia"
    - "Gate de código con dart:io + autocomprobación de cobertura (archivos, líneas y exentos vistos) para que no pueda quedarse verde por no mirar"
    - "Exención en línea `// TOKEN-IGNORE: motivo`, válida también en la línea anterior"

key-files:
  created:
    - app_cliente/test/core/sin_hex_crudos_test.dart
  modified:
    - app_cliente/lib/core/theme.dart
    - app_cliente/lib/core/design_tokens.dart
    - app_cliente/lib/features/auth/login_screen.dart
    - app_cliente/lib/features/auth/register_screen.dart
    - app_cliente/lib/features/pagos/calificacion_sheet.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/perfil/perfil_screen.dart
    - app_cliente/lib/features/reservas/mis_reservas_screen.dart
    - app_cliente/lib/features/reservas/reserva_wizard_screen.dart
    - app_cliente/lib/features/restaurantes/home_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart
    - app_cliente/lib/features/sesion_qr/scan_screen.dart
    - app_cliente/lib/features/shared/app_shell.dart
    - app_cliente/lib/features/shared/empty_state.dart
    - app_cliente/lib/features/shared/google_boton.dart
    - app_cliente/lib/features/shared/not_found_screen.dart
    - app_cliente/test/core/theme_tokens_test.dart

key-decisions:
  - "11-19: los TextStyle inline NO migran a `ThemeData.textTheme`. MEDIDO con sonda: coincidir en tamaño Y peso (el criterio de corte del plan) NO basta, porque el slot trae su propio letterSpacing y height mientras que el inline los hereda del DefaultTextStyle. 12/w400 pasaría de 257.3x17 a 260.4x16 px. El ÚNICO slot pixel-neutral es bodyMedium, y solo porque ES el DefaultTextStyle ambiente. Migran a GriText, que es literalmente el mismo TextStyle"
  - "11-19: se añade `GriText.botonGrande` (16 bold) en vez de reutilizar `tituloCard`. Los 9 usos de 16 bold de app_cliente son etiquetas de CTA y NO hay ni un título de tarjeta a 16 bold: el doc de `tituloCard` («12 usos») no describe este repo. Mismo valor, otro significado; hay un test que afirma la igualdad para que divergir sea una decisión consciente"
  - "11-19: el espaciado se migra a nivel de VALOR, no de expresión: en `EdgeInsets.fromLTRB(16, 8, 16, 12)` los tres primeros pasan a token y el 12 se queda como número suelto. El número desnudo entre tokens señala la deuda en vez de esconderla, y convertirlo al peldaño más cercano sería un cambio visual"
  - "11-19: `GriColors.divisor` (#E0E0E0) y `GriColors.bordeBotonGoogle` (#DADCE0) NO se colapsan en un solo gris aunque se parezcan: el segundo es del branding de Google, no de GRI"

patterns-established:
  - "Todo color de la app cliente sale de core/theme.dart; un `Color(0x…)` suelto lo caza sin_hex_crudos_test"
  - "Antes de dar por buena una migración de tipografía, medir el render de los DOS lados: tamaño y peso iguales no implican píxeles iguales"

requirements-completed: [DS-01]

# Metrics
duration: ~80min
completed: 2026-08-19
---

# Phase 11 Plan 19: Tokens en la app cliente Summary

**La app cliente deja de tener 20 colores escritos a mano en 6 pantallas, 34 `TextStyle` copiados y 103 números de espaciado sueltos — y está demostrado mecánicamente, no afirmado, que ni un solo valor se movió.**

## Performance

- **Duración:** ~80 min
- **Tareas:** 3/3
- **Archivos:** 20 (1 creado, 19 modificados) — **todos de `app_cliente`**
- **Roturas e inyecciones deliberadas:** 20 (14 debían poner rojo, 4 debían seguir verdes, 2 destaparon una aserción sin dientes)

## Accomplishments

- **Cero `Color(0x…)` fuera del tema.** 20 literales en 16 líneas → 5 constantes con nombre y una `LinearGradient` compartida. El ámbar de la calificación estaba NUEVE veces (una de ellas escondida tras un `static const _ambar` privado) y el degradado de cabecera, copiado íntegro en cuatro pantallas.
- **La prueba de que la migración es real no la escribí yo.** La rotura A (`#F5A623` → `#F5A624`, un dígito) tumba el caso **PREEXISTENTE** `test/restaurantes/iconos_test.dart:76` del plan 11-13, sin haber tocado su valor esperado. Antes de este plan ese test era insensible al token, porque la pantalla llevaba su propio literal.
- **Se midió que el plan pedía un cambio visual sin saberlo.** Su criterio para migrar a `textTheme` (que coincidan tamaño **y** peso) no garantiza nada: ver Hallazgo 1, con la tabla de píxeles.
- **La migración 1:1 está DEMOSTRADA.** Dos comprobaciones mecánicas, no dos opiniones: (a) sustituir cada `GriSpacing.*` por su número reproduce los 32 archivos **byte a byte**; (b) expandiendo todos los tokens a su valor, el multiconjunto de números, hex y `FontWeight` de los **16 archivos de pantalla** es **idéntico** al de antes del plan (0 diferencias).
- **El `// TODO(11-19)` de 11-17 queda cerrado**, incluido el `minimumSize` de 48 → `GriSpacing.xxl`, que resulta estar cableado a dos casos preexistentes del propio 11-17 (rotura K).
- **Sin regresiones:** `flutter analyze` **0 issues**; **206 → 214 tests** (+8), y ni una sola aserción existente se editó.

## Task Commits

| # | Tarea | Gate | Commit |
|---|---|---|---|
| 1 | Hex crudos → `GriColors` | `+211`, analyze 0, `SIN_HEX_CRUDOS` | `fa85e34` |
| 2 | `TextStyle` → `GriText`, espaciado → `GriSpacing` | `+212`, analyze 0 | `ac2328b` |
| 3 | Gate `sin_hex_crudos_test.dart` | `+214`, analyze 0 | `b72f221` |

## Gates ejecutados — salida real

| Gate | Resultado |
|---|---|
| `cd app_cliente && flutter analyze` (línea base) | `No issues found!` |
| `cd app_cliente && flutter test` (línea base) | `00:10 +206: All tests passed!` |
| `cd app_cliente && flutter analyze` (final) | `No issues found! (ran in 4.5s)` |
| `cd app_cliente && flutter test` (final) | `00:11 +214: All tests passed!` |
| `flutter test test/core/theme_tokens_test.dart` | `+27` (era `+21`) |
| `flutter test test/core/sin_hex_crudos_test.dart` | `+2` |
| Tarea 1: `test $(grep -rn "Color(0x" lib … \| wc -l) -eq 0` | `SIN_HEX_CRUDOS` (exit 0) |
| Tarea 2: `test $(grep -rn "textTheme" lib … \| wc -l) -gt 0` | `TEXTTHEME_EN_USO` — **gate defectuoso**, ver Hallazgo 2 |
| `grep -rn "TODO(11-19)" app_cliente/lib` | sin resultados (exit 1) |
| Auditoría numérica antes/después de los 16 archivos de pantalla | **0 diferencias de valor** |
| Reversibilidad del espaciado (32 archivos) | reproducción **byte a byte** |
| `git diff-tree` por commit buscando lo ajeno a `app_cliente/` | **0** en los 3 commits |
| `cd scripts && npm run audit:branding` | `2 apps · 4 archivos · 0 rastros de plantilla`, exit 0 |
| `cd scripts && npm run audit:indexes` | exit 0 |

`test:rules` y `test:functions` **NO se ejecutaron**: dependen de los emuladores y este plan no toca rules, índices ni functions.

**Re-medición tras el corte de sesión.** La ejecución se interrumpió por el límite de la API con
los 3 commits ya dentro y el SUMMARY a medias. Al reanudar, `11-21` había cerrado `panel_admin` en
el mismo árbol (`5e55e8b`, `9c67d7e`, `516da3a`), así que **los gates se volvieron a ejecutar en
vez de dar por buenos los números recordados**. Salida idéntica: `analyze` `No issues found!`,
`flutter test` `00:09 +214: All tests passed!`, `sin_hex_crudos_test` `+2`,
`theme_tokens_test` `+27`, `SIN_HEX_CRUDOS` exit 0, `grep TODO(11-19)` sin resultados, y la
auditoría numérica de los 16 archivos de pantalla otra vez en **0 diferencias de valor**.

Lo único sin commitear en `app_cliente` es
`lib/features/restaurantes/restaurantes_provider.g.dart`, regenerado por `build_runner` sin que
ningún plan lo reclame (ya declarado como AJENO por 11-13). **No se ha estageado**: este plan no
ejecutó `build_runner` ni tocó ningún `@riverpod`, así que nada de este trabajo lo justifica.

## Inventario del ANTES (evidencia)

`grep -rn "Color(0x" app_cliente/lib --include=*.dart | grep -v "core/theme.dart"` → **16 líneas, 20 literales**:

| Hex | Usos | Dónde | Token |
|---|---|---|---|
| `0xFFF5A623` | 9 | `calificacion_sheet:130` (como `_ambar`), `pedido_estado:317,321`, `home:396,402`, `restaurantes_list:158,164`, `restaurante_detalle:103,109` | `GriColors.calificacionEstrella` |
| `0xFFFF6B35` | 4 | `home:189,368`, `restaurantes_list:123`, `restaurante_detalle:68` | `GriColors.gradienteInicio` |
| `0xFFFF9B5A` | 4 | los mismos 4 sitios | `GriColors.gradienteFin` |
| `0xFFE0E0E0` | 2 | `google_boton:22,27` | `GriColors.divisor` |
| `0xFFDADCE0` | 1 | `google_boton:67` | `GriColors.bordeBotonGoogle` |

Las tres primeras filas coinciden con el inventario del plan. **Las dos últimas NO estaban en el plan**: son del código nuevo de 11-17, que el plan mandaba incluir pero no había contado.

## Hallazgos

### 1. El criterio de corte del plan para la tipografía NO es pixel-neutral (MEDIDO)

El plan manda migrar a `Theme.of(context).textTheme.*` «solo cuando tamaño y peso coincidan
exactamente con un slot». Ese criterio **no basta**, y no es una duda teórica: se midió con una
sonda bajo `griTheme`, en un `Scaffold`, con ocho cadenas del **mismo número de caracteres** para
que las anchuras fueran comparables entre sí.

| Estilo inline | Slot | letterSpacing | height | Caja renderizada |
|---|---|---|---|---|
| `TextStyle(fontSize: 12)` | — | 0.25 | 1.43 | **257.3 × 17** |
| — | `bodySmall` (12/w400) | 0.4 | 1.33 | **260.4 × 16** |
| `TextStyle(fontSize: 14)` | — | 0.25 | 1.43 | 299.3 × 20 |
| — | `bodyMedium` (14/w400) | 0.25 | 1.43 | **299.3 × 20** ✔ idéntico |
| `TextStyle(fontSize: 16)` | — | 0.25 | 1.43 | **341.3 × 23** |
| — | `bodyLarge` (16/w400) | 0.5 | 1.5 | **346.5 × 24** |
| `TextStyle(fontSize: 16, w500)` | — | 0.25 | 1.43 | **341.3 × 23** |
| — | `titleMedium` (16/w500) | 0.15 | 1.5 | **339.1 × 24** |

La causa: un `TextStyle` inline con `inherit: true` **hereda `letterSpacing` y `height` del
`DefaultTextStyle` ambiente**, que en el cuerpo de un `Scaffold` es `bodyMedium`. El slot, en
cambio, trae los suyos. Por eso el único caso pixel-neutral es `bodyMedium` — y lo es justamente
porque *es* el estilo ambiente, no porque coincida en tamaño y peso.

Resolución: los 34 estilos migran a **`GriText`**, que 11-11 creó precisamente para esto («cada
constante es EXACTAMENTE el `TextStyle` que hoy está escrito inline»). Es pixel-neutral **por
construcción**, y hay un test de 11-11 que lo afirma estilo a estilo.

Nota para 11-12: `griTextTheme` sigue siendo útil (declara los 15 slots para que Flutter no los
mueva en silencio), pero **no es un destino de migración**. Si el panel migra `fontSize` inline a
`textTheme.*`, moverá píxeles.

### 2. El `<verify>` de la Tarea 2 está verde por construcción desde 11-11

```
test $(grep -rn "textTheme" lib --include=*.dart | wc -l) -gt 0 && echo "TEXTTHEME_EN_USO"
```

Devuelve **3 coincidencias antes de tocar una sola línea de este plan**, y dos de las tres son
comentarios:

```
lib/core/design_tokens.dart:136:/// ── Por qué esto y no solo `ThemeData.textTheme` ──
lib/core/design_tokens.dart:137:/// `griTheme.textTheme` declara también la escala…
lib/core/theme.dart:443:  textTheme: griTextTheme,
```

Es decir: el gate **pasa igual si la Tarea 2 no se hace**, y también pasaría si se hiciera mal.
Se ejecutó tal cual (imprime `TEXTTHEME_EN_USO`) y se deja constancia de que no mide nada. Es el
**séptimo gate defectuoso de la fase** (11-06, 11-08 ×2, 11-13 ×2, y este). Confirma el patrón:
un gate de `grep` que no se ha probado contra la forma real del fallo no es un gate.

*(Añadido: el propio script de auditoría numérica que escribí para este SUMMARY salió mal la
primera vez porque `subprocess(shell=True)` en Windows lanza `cmd.exe`, donde `^` es el carácter
de escape y se comió el `^` de `fa85e34^`: comparaba contra el commit equivocado. Se detectó
porque el resultado no cuadraba y se volvió a correr con el SHA resuelto. Un gate que no se
cuestiona miente en silencio.)*

### 3. `GriText.boton` y `GriText.tituloCard` no describen esta app

Al inventariar los sitios reales:

- **`tituloCard` (16 bold, «título de tarjeta / nombre de plato, 12 usos»):** en `app_cliente` hay
  **9** usos de 16 bold y los **nueve son etiquetas de CTA** (login, registro, perfil, carrito,
  enviar pedido, pedir la cuenta, abrir mesa, confirmar reserva, reservar mesa). **Ni un solo
  título de tarjeta.**
- **`boton` (15 bold, «etiqueta de botón grande, 3 usos»):** solo **uno** de los tres es un botón
  (`calificacion_sheet`). Los otros dos son el contador de cantidad del carrito
  (`menu_mesa_screen`) y el banner «Cuenta solicitada» (`pedido_estado_screen`).

Es consecuencia directa de que 11-11 derivó la escala **contando estilos repetidos**, no de un
diseño — cosa que su propio SUMMARY declara. Se añade `GriText.botonGrande` con el mismo valor que
`tituloCard` y el significado correcto, y un test afirma que **hoy son iguales**, para que
divergirlos sea una decisión consciente y no un accidente. Los doc comments de `boton` y
`botonGrande` recogen la medición.

### 4. Romper un estilo de la escala no lo notaba ninguna pantalla

Las roturas G (`botonGrande` 16 → 17) y H (`tituloPantalla` 24 → 28) tumbaron **un solo caso**: la
aserción literal del propio token. La suite entera de pantallas siguió verde. Es decir, la
tipografía estaba afirmada **solo contra sí misma**.

Se añadió un caso que **renderiza la home y mide** el saludo (24/bold, `#222222`) y el CTA
«Reservar una mesa» (16/bold, dentro de un `Text.rich`, así que hay que ir al `RichText`), con los
números **escritos a mano**. Tras añadirlo, G y H pasan a tumbar **dos** casos cada una, y una
rotura extra (`tituloPantalla` sin `bold`) también cae. Mismo criterio en los colores: la
aserción de render compara contra el **hex literal**, nunca contra el token — comparar contra el
token la dejaría verde precisamente cuando el token cambia.

### 5. `GriSpacing.xxl` estaba cableado a dos casos preexistentes de 11-17

La rotura K (`xxl` 48 → 40) tumbó cuatro casos, y dos son de **11-17 sin tocar**: «el botón
"Continuar con Google" mide al menos 48 de alto» en login y en registro. Confirma que sustituir
el `Size.fromHeight(48)` por el token no fue cosmético: el área táctil del botón de Google depende
ahora de la escala, y quien la toque romperá el mínimo de Material de forma ruidosa.

## Lo que NO se migró, y por qué

**`TextStyle` (6 de 40) — ningún tamaño encaja en `GriText`:**

| Sitio | Estilo | Motivo |
|---|---|---|
| `home_screen.dart:67` | 22 bold | 22 no está en la escala (el slot `titleLarge` es 22/**w400**) |
| `home_screen.dart:367`, `restaurante_detalle_screen.dart:79` | 20 bold | 20 no está en la escala |
| `reserva_wizard_screen.dart:404` | 28 bold | 28 no está en la escala |
| `google_boton.dart:80` | 16 / **w500** | no hay slot de `GriText` con ese peso; `titleMedium` cambiaría el `letterSpacing` (Hallazgo 1) |
| `not_found_screen.dart:44` | 40 | es el emoji-brújula: tamaño de icono disfrazado de texto, no tipografía |

**Espaciado (44 literales) — el valor no cae en ningún peldaño:** `vertical: 14` ×13,
`height: 20` ×9, `height: 12` ×7, `height: 10` ×7, `all(20)` ×6, `height: 6` ×5,
`bottom: 12` ×3, `all(18)` ×3, `width: 10` ×2, `height: 28` ×2, `vertical: 10` ×2, y sueltos de
2, 5 y 15. **Un `SizedBox(height: 18)` no se convierte en `md` ni en `lg`**: cambiar un 18 por un
16 es un cambio visual.

Las expresiones mixtas conservan el número fuera de escala al lado del token
(`EdgeInsets.fromLTRB(GriSpacing.md, GriSpacing.sm, GriSpacing.md, 12)`), que es deliberado: el
número desnudo entre tokens señala la deuda.

**`GriRadius` en `google_boton.dart`:** el `TODO` pedía también radios, pero el `OutlinedButton`
**no declara `shape`**: usa el del framework. Ponerle uno le cambiaría el aspecto, así que no se
toca y queda escrito en el archivo.

## Roturas e inyecciones deliberadas (20)

**Tarea 1 — colores (6)**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| A | `calificacionEstrella` `#F5A623` → `#F5A624` | `-2`, y uno es el caso **PREEXISTENTE** de `iconos_test.dart` (11-13) | ✔ |
| B | `gradienteInicio` `#FF6B35` → `#FF6B36` | `-2` (token + render de la home) | ✔ |
| C | `divisor` `#E0E0E0` → `#E0E0E1` | `-2` | ✔ |
| D | `bordeBotonGoogle` `#DADCE0` → `#DADCE1` | `-2` | ✔ |
| E | `griGradienteRestaurante.begin` a `topRight` | `-2` | ✔ |
| F | `Size.fromHeight(GriSpacing.xxl)` → `xl` | `-1` | ✔ |

**Tarea 2 — escala (5 + 3)**

| # | Rotura | Efecto | ✔ |
|---|---|---|---|
| G | `GriText.botonGrande` 16 → 17 | **`-1`: solo su propia aserción** — ver Hallazgo 4 | ✗ |
| H | `GriText.tituloPantalla` 24 → 28 | **`-1`: ídem** | ✗ |
| I | `GriSpacing.md` 16 → 15 | `-2` (literal + múltiplo de 4) | ✔ |
| J | `GriSpacing.sm` 8 → 20 | `-2` (literal + orden creciente) | ✔ |
| K | `GriSpacing.xxl` 48 → 40 | `-4`, y **dos son de 11-17 sin tocar** (Hallazgo 5) | ✔ |
| G2 | ídem G, con el caso de render añadido | `-2` | ✔ |
| H2 | ídem H, con el caso de render añadido | `-2` | ✔ |
| L | `tituloPantalla` pierde el `bold` | `-2` | ✔ |

**Tarea 3 — gate (6 inyecciones, 4 de ellas deben seguir VERDES)**

| # | Inyección | Esperado | Real | ✔ |
|---|---|---|---|---|
| M | `Color(0xFF123456)` en `perfil_screen.dart` | FALLA | `+1 -1` | ✔ |
| N | el mismo hex dentro de un comentario | pasa | `+2` | ✔ |
| O | el mismo hex con `// TOKEN-IGNORE:` en su línea | pasa | `+2` | ✔ |
| P | el mismo hex con `// TOKEN-IGNORE:` en la línea ANTERIOR | pasa | `+2` | ✔ |
| Q | un hex NUEVO dentro de `core/theme.dart` | pasa (exento) | `+2` | ✔ |
| R | la exención apuntando a un archivo inexistente | FALLA | `+1 -1` | ✔ |

R es la que impide el modo de fallo silencioso: si alguien renombra `theme.dart`, la exención
quedaría colgando y el gate dejaría de mirar donde debe. La autocomprobación cuenta archivos,
líneas y exentos vistos.

## ¿Cambió algún píxel? — NO, y así se comprobó

**Ninguno.** Tres comprobaciones independientes, ninguna basada en mirar el diff a ojo:

1. **Reversibilidad del espaciado.** Se guardó una copia de `lib/` antes de la pasada, se
   aplicaron las 103 sustituciones y se sustituyó cada token por su número: **los 32 archivos
   vuelven a ser byte a byte los de antes**. (El único que "no revertía" era `google_boton.dart`,
   porque ya traía tokens de la Tarea 1; comprobado con `diff` que esa pasada no lo tocó.)
2. **Auditoría numérica de los 16 archivos de pantalla.** Expandiendo *todos* los tokens
   (`GriSpacing.*`, `GriText.*`, `GriColors.*`, `griGradienteRestaurante`) a su valor y comparando
   el multiconjunto de números, hex y `FontWeight` con el de `HEAD` antes del plan: **0
   diferencias**.
3. **Revisión del `git diff` de los hex.** Los 20 literales que desaparecen de las pantallas
   reaparecen **con el mismo ARGB** en `theme.dart`. No hay ni un hex nuevo que no sea uno de esos.

Lo único que cambia de forma (no de aspecto): **8 widgets pierden el `const`** de su constructor
porque `copyWith` no es una expresión constante. `const` es canonicalización en tiempo de
compilación: no altera el árbol renderizado.

## Deviations from Plan

### 1. [Rule 3 - Bloqueante] La tipografía no migra a `textTheme` sino a `GriText`

- **Encontrado en:** Tarea 2, antes de tocar nada, con una sonda.
- **Problema:** ver Hallazgo 1. El criterio del plan («tamaño y peso coinciden») habría movido
  píxeles en 8 de los 9 candidatos, que es exactamente lo que el plan prohíbe.
- **Resolución:** migrar a `GriText`, que es el mismo `TextStyle`. `textTheme` sigue declarado y
  sin usar como destino.
- **Archivos:** los 13 de `features/`.

### 2. [Rule 2 - Corrección de contrato] Se añade `GriText.botonGrande`

- **Encontrado en:** Tarea 2, al inventariar los 9 sitios de 16 bold.
- **Problema:** los nueve son CTA; usar `tituloCard` habría dejado el código diciendo algo falso.
- **Resolución:** constante nueva con el MISMO valor, doc comment con la medición, y un test que
  afirma la igualdad actual. Sin efecto visual.
- **Archivos:** `lib/core/design_tokens.dart`, `test/core/theme_tokens_test.dart`.

### 3. [Rule 2 - Deuda de verificación] Aserciones de render añadidas

- **Encontrado en:** Tarea 1 y Tarea 2, al comprobar que las roturas mordieran.
- **Problema:** el gradiente, los grises del botón de Google y toda la escala tipográfica estaban
  afirmados solo contra sí mismos (Hallazgo 4).
- **Resolución:** +6 casos en `theme_tokens_test.dart` que **renderizan y miden**, comparando
  siempre contra el literal, nunca contra el token.

### 4. El gemelo de `panel_admin` todavía no existe

- **Problema:** la Tarea 3 manda copiar el gate «que el plan 11-12 creó en `panel_admin`». **11-12
  no se ha ejecutado**: no hay `11-12-SUMMARY.md` ni
  `panel_admin/test/core/sin_hex_crudos_test.dart`.
- **Resolución:** este archivo es el ORIGINAL, con la cabecera de sincronización apuntando al
  gemelo futuro y un aviso explícito de que 11-12 debe **portar este**, no escribir otro.

### 5. Ejecutado antes que 11-14, que figura en `depends_on`

- El orquestador lo arrancó a propósito (11-13 liberó `app_cliente`, 11-21 tiene `panel_admin`).
  **No hizo falta nada de 11-14**: este plan no toca contraste ni áreas táctiles. El único punto
  de contacto es `GriSemanticColors.textoSecundarioAccesible`, que sigue **sin aplicarse**, tal y
  como 11-11 lo dejó.

## Verificado vs. afirmado

**Verificado (una rotura lo pone rojo, o una comprobación mecánica lo demuestra):**

- Que los 5 tokens nuevos valen el hex exacto que sustituyen, y que `gradienteInicio` ≠ `primary`.
- Que la home **pinta** el degradado con `#FF6B35`/`#FF9B5A` y los mismos extremos.
- Que el bloque de Google **pinta** `#E0E0E0` y `#DADCE0`, y que su alto mínimo sigue siendo 48.
- Que la estrella de calificación de la home sale del token (caso preexistente de 11-13).
- Que la home renderiza el saludo a 24/bold y el CTA a 16/bold.
- Que el gate detecta un hex nuevo, respeta comentarios y las dos formas de `TOKEN-IGNORE`, exime
  `theme.dart`, y **falla** si su lista de exentos deja de existir.
- Que **ningún valor numérico ni de color cambió** en los 16 archivos de pantalla.

**Afirmado, NO verificado:**

- **Que las pantallas se VEAN igual.** Los tests miden estilos y cajas, no comparan capturas. No
  hay golden tests en este repo. La afirmación fuerte de este plan es *«los valores no cambiaron»*,
  demostrada; *«el render es idéntico»* se sigue de ella por construcción, pero no se ha
  fotografiado.
- Que las **34** migraciones de `TextStyle` sean correctas **una a una**. La garantía es
  estructural: el token se eligió *programáticamente* a partir del `(fontSize, fontWeight)` leído
  del literal, y un test afirma que cada token vale ese par. Solo **2** de las 34 están medidas
  sobre el render (las de la home).
- Que las **103** sustituciones de espaciado no cambien el layout: se demuestra que el valor es el
  mismo, no se re-mide cada pantalla. Las suites de layout de 11-13 (17 casos de geometría del
  shell) siguen verdes sin tocarse, lo cual es una red parcial.
- Que los archivos de `docs/ICONOS-app_cliente.md` sigan apuntando a los `archivo:línea`
  correctos: este plan ha desplazado líneas en 13 pantallas (ver Notas).

## Pendiente de verificación humana

- Que la app se vea **exactamente igual** que antes del plan en un dispositivo real. Es el
  criterio de éxito del plan y `flutter test` no puede cerrarlo del todo.
- En particular: el degradado de cabecera en las 4 pantallas, las estrellas de calificación, el
  separador «o» y el borde del botón de Google, y los 9 CTA a 16 bold.

## Notas para los planes que vienen

- **11-12 (panel):** (a) **NO migres los `fontSize` inline a `textTheme.*`** — Hallazgo 1, con la
  tabla medida; usa `GriText`. (b) El gate `sin_hex_crudos_test.dart` de este plan es el original:
  pórtalo tal cual, con la misma exención y el mismo mensaje. (c) El `<verify>` de `textTheme` de
  tu plan, si lo lleva, está verde por construcción — no te fíes.
- **11-14 (accesibilidad):** el rol de texto secundario que tienes que cambiar vive ahora en
  `GriText.auxiliar.copyWith(color: GriColors.gray)` en 7 sitios de `app_cliente`: es un único
  patrón buscable, no 7 literales distintos. `GriColors.gray` sigue siendo `#777777` y hay dos
  tests que lo impiden cambiar. Ojo también con el botón QR de 45×45 que 11-13 congeló.
- **`docs/ICONOS-app_cliente.md`** contiene `archivo:línea` que este plan ha desplazado en 13
  pantallas (aviso que dejó el propio 11-13). No se actualizó aquí: no estaba en el alcance y
  tocarlo habría mezclado dos cosas. Queda anotado como deuda.
- **Quien toque `GriSpacing` o `GriText`** en una app tiene que mirar el gemelo: la cabecera de
  `design_tokens.dart` dice qué es común (`GriSpacing`, `GriRadius`) y qué es propio (`GriText`,
  `GriBreakpoints`). `botonGrande` es **propio de app_cliente**.

## Self-Check: PASSED

- `app_cliente/test/core/sin_hex_crudos_test.dart` — **FOUND** en disco.
- Commits verificados en `git log`: `fa85e34`, `ac2328b`, `b72f221` — **los 3 FOUND**, y los tres
  con **0** archivos fuera de `app_cliente/`.
- `flutter analyze` **0 issues** y `flutter test` **+214** en el árbol final.
