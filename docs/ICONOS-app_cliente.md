# Iconos de la app cliente — equivalencia emoji → `Icons.*`

**Plan:** 11-13 · **Fecha:** 2026-08-19
**Gemelo:** [`ICONOS-panel_admin.md`](ICONOS-panel_admin.md) (plan **11-21**, ejecutado en
paralelo). Se documentan por separado porque los dos planes corren en la misma ola y no pueden
escribir el mismo archivo. Los nombres que coinciden en los dos `GriIcons` deben significar lo
mismo; los sets NO se sincronizan (las dos apps tienen vocabularios distintos).

**Fuente única:** `app_cliente/lib/core/gri_icons.dart`.

---

## Por qué

Hasta 11-13 la iconografía de esta app eran **emojis pintados como `Text`**: `🏠 🔍 📅 👤` en la
barra inferior, `🍽️` como marca, `⭐` en la calificación… Un emoji no es un icono — su forma la
decide la fuente del sistema, así que el mismo glifo se ve distinto en Android, en iOS y en cada
navegador, y puede no existir. El usuario lo pidió expresamente
(`11-CONTEXT.md`, «Emojis como iconos», 2026-08-19), lo que **revierte** la interpretación con la
que se planificó la fase.

**Lo que NO cambia:** la paleta `#FF4C05`, los layouts, los tamaños de los contenedores y el orden
de los elementos. Regla dura del plan: el `size` del `Icon` **iguala el `fontSize`** del `Text` que
sustituye, y el color sale de `GriColors` o del `IconTheme`.

---

## Inventario de partida

| Medición | Resultado |
|---|---|
| Apariciones totales en `lib/` (comentarios incluidos) | **54** |
| Líneas con emoji en literal **renderizado** | **42** (43 glifos) |
| Sustituidas por `Icon` (uso 1, iconografía) | **37** |
| Conservadas por ser texto expresivo (uso 3) | **5** |
| Conservadas por vivir en comentarios (uso 2) | **12** |

> ⚠️ El `grep` que proponía el plan
> (`[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]`) **no cubre `U+2B50`**, así que se dejaba fuera las 4
> apariciones de `⭐` — una de las filas de su propia tabla de equivalencias. El gate
> `test/core/sin_emojis_test.dart` añade `U+2B00–U+2BFF` y `U+1F000–U+1F2FF`.

---

## Tabla de sustituciones

`archivo:línea` corresponde al estado **posterior** a la sustitución (el `Icon` ya puesto).

| Emoji | archivo:línea | `Icons.*` elegido | Nombre en `GriIcons` | size |
|---|---|---|---|---|
| 🏠 | `features/shared/app_shell.dart:51` | `Icons.home_outlined` | `inicio` | 20 |
| 🔍 | `features/shared/app_shell.dart:52` | `Icons.search` | `buscar` | 20 |
| 📅 | `features/shared/app_shell.dart:53` | `Icons.calendar_today_outlined` | `reservas` | 20 |
| 👤 | `features/shared/app_shell.dart:54` | `Icons.person_outline` | `perfil` | 20 |
| 🍽️ | `features/auth/login_screen.dart:235` | `Icons.restaurant` | `menu` | 32 |
| 🍽️ | `features/pedidos/menu_mesa_screen.dart:70` | `Icons.restaurant` | `menu` | 40 |
| 📋 | `features/pedidos/menu_mesa_screen.dart:105` | `Icons.receipt_long_outlined` | `resumenPedido` | 40 |
| 📋 | `features/pedidos/menu_mesa_screen.dart:132` | `Icons.receipt_long_outlined` | `resumenPedido` | 40 (`EmptyState`) |
| 📡 | `features/pedidos/pedido_estado_screen.dart:109` | `Icons.sensors` | `enVivo` | 40 |
| 🧑‍🍳 | `features/pedidos/pedido_estado_screen.dart:127` | `Icons.soup_kitchen_outlined` | `cocinando` | 40 |
| ✓ | `features/pedidos/pedido_estado_screen.dart:220` | `Icons.check` | `confirmado` | 15 |
| 📅 | `features/reservas/mis_reservas_screen.dart:49` | `Icons.calendar_today_outlined` | `reservas` | 40 |
| 📅 | `features/reservas/mis_reservas_screen.dart:69` | `Icons.calendar_today_outlined` | `reservas` | 40 |
| 📅 | `features/reservas/mis_reservas_screen.dart:216` | `Icons.calendar_today_outlined` | `reservas` | 14 (inline) |
| 🪑 | `features/reservas/mis_reservas_screen.dart:221` | `Icons.table_restaurant_outlined` | `mesa` | 14 (inline) |
| 👥 | `features/reservas/mis_reservas_screen.dart:223` | `Icons.people_outline` | `personas` | 14 (inline) |
| 📷 | `features/restaurantes/home_screen.dart:131` | `Icons.qr_code_scanner` | `escanearQr` | 30 (`_ActionCard`) |
| 📅 | `features/restaurantes/home_screen.dart:140` | `Icons.calendar_today_outlined` | `reservas` | 30 (`_ActionCard`) |
| 🪑 | `features/restaurantes/home_screen.dart:198` | `Icons.table_restaurant_outlined` | `mesa` | 20 |
| 📍 | `features/restaurantes/home_screen.dart:215` | `Icons.place_outlined` | `direccion` | 14 (inline) |
| ✓ | `features/restaurantes/home_screen.dart:227` | `Icons.check` | `confirmado` | 14 (inline) |
| 🍽️ | `features/restaurantes/home_screen.dart:304` | `Icons.restaurant` | `menu` | 22 (logo) |
| 📷 | `features/restaurantes/home_screen.dart:328` | `Icons.qr_code_scanner` | `escanearQr` | 22 |
| 🍽️ | `features/restaurantes/home_screen.dart:372` | `Icons.restaurant` | `menu` | 60 |
| ⭐ | `features/restaurantes/home_screen.dart:395` | `Icons.star` | `calificacion` | 14 |
| 📅 | `features/restaurantes/home_screen.dart:425` | `Icons.calendar_today_outlined` | `reservas` | 16 (inline) |
| 📅 | `features/restaurantes/home_screen.dart:531` | `Icons.calendar_today_outlined` | `reservas` | 14 (inline) |
| 🪑 | `features/restaurantes/home_screen.dart:536` | `Icons.table_restaurant_outlined` | `mesa` | 14 (inline) |
| 👥 | `features/restaurantes/home_screen.dart:538` | `Icons.people_outline` | `personas` | 14 (inline) |
| 📍 | `features/restaurantes/home_screen.dart:543` | `Icons.place_outlined` | `direccion` | 14 (inline) |
| 🍽️ | `features/restaurantes/restaurantes_list_screen.dart:42` | `Icons.restaurant` | `menu` | 40 (`EmptyState`) |
| 🍽️ | `features/restaurantes/restaurantes_list_screen.dart:84` | `Icons.restaurant` | `menu` | 40 |
| 🍽️ | `features/restaurantes/restaurantes_list_screen.dart:127` | `Icons.restaurant` | `menu` | 44 |
| ⭐ | `features/restaurantes/restaurantes_list_screen.dart:157` | `Icons.star` | `calificacion` | 14 |
| 🍽️ | `features/restaurantes/restaurante_detalle_screen.dart:40` | `Icons.restaurant` | `menu` | 40 |
| 🍽️ | `features/restaurantes/restaurante_detalle_screen.dart:72` | `Icons.restaurant` | `menu` | 52 |
| ⭐ | `features/restaurantes/restaurante_detalle_screen.dart:102` | `Icons.star` | `calificacion` | 14 |
| 📋 | `features/restaurantes/restaurante_detalle_screen.dart:153` | `Icons.receipt_long_outlined` | `resumenPedido` | 40 (`EmptyState`) |

### Ajustes respecto a la tabla propuesta en el plan

| Propuesta | Aplicado | Motivo |
|---|---|---|
| 🏠 → `home_outlined` / `home` al activar | Solo `home_outlined` | La `BottomNavigationBar` de esta app usa **un solo** `icon` por item (no declara `activeIcon`). Alternar la variante rellena exigiría añadir `activeIcon` a los 4 tabs — es un cambio de aspecto, no una sustitución, y la identidad visual está BLOQUEADA. El estado activo lo comunica el color (`GriColors.primary`), igual que antes |
| ⚠ → `warning_amber_outlined` | **Sin uso** | Todos los `⚠️` de esta app viven en comentarios. `GriIcons.aviso` queda declarado para cuando haga falta |
| 📷 → `qr_code_scanner` | Igual | `escanearQr` describe lo que el botón HACE; una cámara sugeriría hacer una foto |

---

## Conservados

### Uso 2 — comentarios y documentación (12 apariciones, no se renderizan)

`⚠️` encabezando avisos en `core/theme.dart:156`, `features/restaurantes/restaurantes_provider.dart:33`
(y sus 5 copias en `restaurantes_provider.g.dart`, que es **generado**), `models/producto.dart:10` y
`features/restaurantes/restaurante_detalle_screen.dart:186`.

No se tocan: no llegan a la pantalla y el `⚠️` de un comentario es una convención de este repo para
marcar «no toques esto sin leer». El gate los salta por ser líneas de comentario.

### Uso 3 — texto expresivo (5 apariciones, con `// EMOJI-OK:`)

| Emoji | archivo:línea | Texto | Por qué se conserva |
|---|---|---|---|
| 🙌 | `features/pagos/calificacion_sheet.dart:164` | «¡Gracias por calificar! 🙌» | Celebración en un `SnackBar`. No es el icono de ningún control |
| 🙌 | `features/pedidos/pedido_estado_screen.dart:182` | «Sesión cerrada — ¡gracias por tu visita! 🙌» | Despedida |
| ✅ | `features/perfil/perfil_screen.dart:58` | «Perfil actualizado ✅» | Aviso transitorio de tono amable |
| 👋 | `features/restaurantes/home_screen.dart:97` | «¡Hola, Ana! 👋» | Saludo |
| 😕 | `features/sesion_qr/scan_screen.dart:156` | «No pudimos iniciar la cámara 😕» | Tono empático en un mensaje de error |

**La regla que separa los dos usos** (y que explica por qué `✓` sí se sustituye y `✅` no):
si el glifo pertenece a un elemento **persistente** que comunica estado o affordance (tab, botón,
tarjeta, chip, estado vacío, metadatos de una fila) → es iconografía y se sustituye. Si vive en un
mensaje **transitorio o conversacional** → es texto y se queda.

---

## Decisiones de color y tamaño

- **El `size` iguala siempre al `fontSize`** del `Text` que sustituyó. Está afirmado en los tests
  para los casos representativos (tabs a 20, botón QR a 22, estrella a 14).
- **Los tabs NO fijan color**: lo sigue poniendo `selectedItemColor` / `unselectedItemColor` de la
  `BottomNavigationBar`. Hay un test que afirma que `Icon.color` es `null`, porque un color propio
  ganaría al de la barra y el tab activo dejaría de pintarse de naranja.
- **La estrella conserva su ámbar `#F5A623`** (el que ya tenía el `Text` del `⭐`). No se estrena
  color.
- **Sobre gradiente naranja o fondo de marca**, el icono va en `Colors.white`, que es donde antes el
  emoji ponía sus propios colores.
- **En estados vacíos y ramas de error**, el icono va en `GriColors.gray`, alineado con el texto
  guía. ⚠️ **Este es el único punto donde el color es una decisión NUEVA**: un emoji trae sus
  colores de la fuente y no había nada que preservar. Queda **pendiente de verificación humana**.

---

## Cómo añadir un icono nuevo

1. **Declararlo en `GriIcons`**, nombrado por **significado** y no por forma (`mesa`, no `silla`),
   con su doc comment.
2. En la pantalla, **siempre** `Icon(GriIcons.x, ...)`. Un `Icons.x` suelto es deuda: rompe la
   promesa de que cambiar el set toca un solo archivo.
3. **`semanticLabel`** cuando el icono NO va acompañado de texto visible. Es lo que consume el
   plan **11-14** de accesibilidad. (Con texto al lado, la etiqueta duplicada es ruido para el
   lector de pantalla.)
4. Si el icono va **dentro de una frase**, usar `iconoInline()` de
   `features/shared/icono_inline.dart` (un `WidgetSpan`), no un `Row`: mantiene el salto de línea
   del párrafo, que es lo que hacía el emoji.
5. **Añadir su fila a este documento.**

---

## Gates

| Gate | Qué garantiza |
|---|---|
| `flutter test test/core/sin_emojis_test.dart` | Que no reaparezca un emoji en un literal renderizado sin exención. Verificado por rotura: caza un emoji nuevo, ignora los de comentarios y respeta `// EMOJI-OK:` |
| `flutter test test/shared/app_shell_responsive_test.dart` | Los 4 tabs son `Icon`, con `size` 20 y sin color propio; en la barra solo quedan los 4 `Text` de las etiquetas |
| `flutter test test/restaurantes/iconos_test.dart` | Icono, tamaño y color del botón QR, la estrella y el logo de la home |

## Lo que NO está verificado

Que los iconos **se vean bien**. Un widget test compara `IconData` y mide cajas; no ve la pantalla.
En concreto siguen pendientes de verificación humana: el gris de los estados vacíos, si
`Icons.soup_kitchen_outlined` se lee como «la cocina está preparando tu pedido», y si
`Icons.sensors` se lee como «en vivo».
