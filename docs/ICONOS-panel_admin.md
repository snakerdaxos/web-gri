# Iconos del panel admin — equivalencia emoji → `Icons.*`

**Plan:** 11-21 · **Fecha:** 2026-08-19
**Gemelo:** [`ICONOS-app_cliente.md`](ICONOS-app_cliente.md) (plan **11-13**, ejecutado en
paralelo en la misma ola). Se documentan por separado porque los dos planes no pueden escribir el
mismo archivo. Los nombres que coinciden en los dos `GriIcons` significan lo mismo (`mesas`,
`reservas`, `clientes`, `marca`); los sets **NO** se sincronizan — el panel habla de cocina,
reportes y equipo, y la app cliente de descubrimiento y reservas.

**Fuente única:** `panel_admin/lib/core/gri_icons.dart`.

---

## Por qué

Hasta 11-21 la iconografía del panel eran **emojis pintados como `Text`**: los 8 ítems del
sidebar, las 4 stat cards, las acciones de mesa, el botón de imprimir el QR y los estados vacíos.
Un emoji no es un icono — su forma la decide la fuente del sistema operativo, así que el mismo
panel se ve distinto en Windows, en macOS y en cada navegador, y glifos modernos como `🪑` o `🪪`
ni siquiera existen en fuentes antiguas: salen como un rectángulo vacío. El usuario lo pidió
expresamente (`11-CONTEXT.md`, «Emojis como iconos», 2026-08-19), lo que **revierte** la
interpretación con la que se planificó la fase.

**Lo que NO cambia:** la paleta `#FF4C05`, los layouts, los anchos de los contenedores y el orden
de los elementos. Regla dura: el `size` del `Icon` **iguala el `fontSize`** del `Text` que
sustituye, y el color sale de `GriColors` o del `IconTheme` — nunca de un literal nuevo.

---

## Sustituciones

Una fila por punto de uso. Las líneas son las del árbol tras 11-21.

| Emoji | Archivo:línea | `Icons.*` | Nombre en `GriIcons` | `size` |
|---|---|---|---|---|
| 🏠 | `features/shared/app_shell.dart:152` | `home_outlined` | `dashboard` | 18 |
| 🪑 | `features/shared/app_shell.dart:153` | `table_restaurant_outlined` | `mesas` | 18 |
| 📋 | `features/shared/app_shell.dart:154` | `receipt_long_outlined` | `pedidos` | 18 |
| 📅 | `features/shared/app_shell.dart:155` | `calendar_today_outlined` | `reservas` | 18 |
| 👥 | `features/shared/app_shell.dart:156` | `people_outline` | `clientes` | 18 |
| 📊 | `features/shared/app_shell.dart:157` | `bar_chart` | `reportes` | 18 |
| 🪪 | `features/shared/app_shell.dart:158` | `badge_outlined` | `equipo` | 18 |
| ⚙️ | `features/shared/app_shell.dart:159` | `settings_outlined` | `configuracion` | 18 |
| 🍽️ | `features/shared/app_shell.dart:225` | `restaurant` | `marca` | 24 |
| 🍽️ | `features/auth/login_screen.dart:208` | `restaurant` | `marca` | 32 |
| 🍽️ | `features/bootstrap/bootstrap_screen.dart:290` | `restaurant` | `marca` | 32 |
| 🍽️ | `features/cocina/cocina_screen.dart:180` | `restaurant` | `marca` | 20 |
| 🍽️ | `features/cocina/cocina_screen.dart:295` | `restaurant` | `marca` | 14 |
| 🍽️ | `features/cocina/widgets/pedido_card.dart:247` | `restaurant` | `marca` | 14 |
| 🎉 | `features/cocina/cocina_screen.dart:108` | `celebration_outlined` | `todoAlDia` | 18 |
| 📝 | `features/cocina/widgets/pedido_card.dart:143` | `edit_note` | `notas` | 14 |
| 🪑 | `features/dashboard/dashboard_screen.dart:150` | `table_restaurant_outlined` | `mesas` | 25 |
| 👥 | `features/dashboard/dashboard_screen.dart:157` | `people_outline` | `clientes` | 25 |
| 📅 | `features/dashboard/dashboard_screen.dart:164` | `calendar_today_outlined` | `reservas` | 25 |
| 📋 | `features/dashboard/dashboard_screen.dart:171` | `receipt_long_outlined` | `pedidos` | 25 |
| 🏪 | `features/dashboard/dashboard_screen.dart:328` | `storefront_outlined` | `restaurante` | 34 |
| 👇 | `features/dashboard/dashboard_screen.dart:328` | `arrow_upward` | `selectorArriba` | 34 |
| 👥 | `features/dashboard/widgets/mesa_tile.dart:70` | `people_outline` | `clientes` | 12 |
| 🪪 | `features/equipo/equipo_screen.dart:138` | `badge_outlined` | `equipo` | 40 |
| 📷 | `features/mesas/mesa_actions_sheet.dart:124` | `qr_code_2` | `verQr` | 20 |
| ✏️ | `features/mesas/mesa_actions_sheet.dart:130` | `edit_outlined` | `editar` | 20 |
| ⚠️ | `features/mesas/mesa_form_dialog.dart:240` | `warning_amber_outlined` | `aviso` | 13 |
| 🖨️ | `features/mesas/qr_dialog.dart:50` | `print_outlined` | `imprimir` | 14 |
| 📅 | `features/reportes/reportes_screen.dart:132` | `calendar_today_outlined` | `reservas` | 14 |
| 📅 | `features/reportes/reportes_screen.dart:139` | `calendar_today_outlined` | `reservas` | 14 |
| 💵 | `features/reportes/reportes_screen.dart:252` | `payments_outlined` | `ventas` | 25 |
| 🧾 | `features/reportes/reportes_screen.dart:260` | `receipt_outlined` | `ticket` | 25 |
| 📅 | `features/reservas/reservas_screen.dart:99` | `calendar_today_outlined` | `reservas` | 18 |
| `\u{1F9ED}` (🧭) | `features/shared/not_found_screen.dart:52` | `explore_outlined` | `rutaDesconocida` | 40 |

**33 sustituciones** en 13 archivos. Rutas relativas a `panel_admin/lib/`.

### Dos cambios que van más allá de la fuente

| Antes | Ahora | Por qué |
|---|---|---|
| 📷 «Ver código QR» | `Icons.qr_code_2` | El glifo era una **cámara**. El panel *genera* el QR, no lo escanea; la cámara es de la app cliente. El icono nuevo corrige el significado, no solo la fuente. |
| 👇 «Selecciona un restaurante» | `Icons.arrow_upward` | El dedo apuntaba **hacia abajo** a un control que está **arriba** (el selector vive en el topbar). |

---

## Conservados

| Glifo | Dónde | Por qué NO se sustituye |
|---|---|---|
| ⚠️ | Doc comments de `core/design_tokens.dart`, `core/theme.dart`, `features/equipo/*.dart`, `features/configuracion/slug.dart`, `features/mesas/*.dart` | **No se renderiza.** Es señalización de comentario, uso nº 2 de los tres del plan. El gate salta las líneas de comentario. |
| ★★★ | `features/configuracion/slug.dart` (doc comment) y `test/configuracion/slug_test.dart:38` + `crear_restaurante_test.dart:231` | Es la **entrada de un caso de prueba**: un nombre que no produce ningún slug válido. Sustituirlo destruiría el caso. Uso nº 3. |
| → · — « » | Literales de UI («Ve a Configuración → Restaurantes…») | Es **puntuación**, no iconografía. Por eso el gate NO mira el rango U+2190–U+21FF: incluirlo lo convertiría en ruido. |

---

## Cómo añadir un icono nuevo

1. **Declararlo en `GriIcons`** (`panel_admin/lib/core/gri_icons.dart`), nombrado por
   **significado** y no por forma: `GriIcons.mesas`, nunca `GriIcons.silla`. Así, cambiar mañana
   de set de iconos toca un archivo y no 12 pantallas.
2. **Usarlo siempre como `Icon(GriIcons.x, ...)`**. Un `Icons.x` suelto en una pantalla es deuda:
   vuelve a repartir la decisión por el árbol.
3. **`size` = el `fontSize` del texto al que acompaña o que sustituye.** Es la regla que impide
   que la iconografía derive de tamaño (T-11-21-05).
4. **`color` de `GriColors` o del `IconTheme`**, jamás un literal nuevo.
5. **`semanticLabel` cuando el icono va SOLO**, sin texto visible al lado — es lo que consume el
   plan 11-14 de accesibilidad. En el sidebar colapsado ya se hace: el icono lleva la etiqueta del
   ítem.
6. **Añadir su fila a este archivo.**

---

## Gate

`panel_admin/test/core/sin_emojis_test.dart` recorre `lib/**/*.dart` y falla si encuentra un emoji
en una línea de **código** (salta comentarios) sin una exención `// EMOJI-OK: motivo` en la misma
línea. Busca las **dos formas**: el glifo y la secuencia de escape `\u{...}` — porque el 404 tenía
`Text('\u{1F9ED}')`, un emoji camuflado que ningún `grep` de glifos encontraba y que por eso
faltaba en el inventario del plan.
