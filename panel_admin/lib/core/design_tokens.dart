// lib/core/design_tokens.dart — tokens de diseño del PANEL ADMIN (11-11).
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║ SINCRONIZAR CON: `app_cliente/lib/core/design_tokens.dart`               ║
// ║                                                                          ║
// ║ IDÉNTICO en los dos archivos — si tocas uno, tienes que tocar el otro:   ║
// ║   · GriSpacing  (los 6 pasos de la escala 4-pt)                          ║
// ║   · GriRadius   (tile 10 / card 15 / chip 20)                            ║
// ║                                                                          ║
// ║ PROPIO de cada app — NO se sincroniza:                                   ║
// ║   · GriBreakpoints  (aquí 750/1100; en el cliente 480/600/840)           ║
// ║   · GriText         (aquí cuerpoCompacto 13 y boton 16; en el cliente    ║
// ║                      14 y 15 — vienen de dos mockups distintos)          ║
// ║                                                                          ║
// ║ La paridad la sostienen los tests: `test/core/theme_tokens_test.dart`    ║
// ║ existe en las DOS apps y afirma los mismos literales. No pueden          ║
// ║ importarse entre sí (son dos paquetes Dart independientes), así que si   ║
// ║ cambias un valor aquí, el que se pone rojo es el test del OTRO proyecto. ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// POR QUÉ DUPLICACIÓN Y NO UN PAQUETE COMPARTIDO (decisión del plan 11-11):
//   (a) Las paletas de las dos apps YA divergen a propósito y está
//       documentado en el código (`background` #F5F6F8 aquí vs #F7F7F7 en el
//       cliente; `text` #252525 vs #222222). Son dos mockups.
//   (b) Los tokens específicos no se solapan: `sidebar`, `mesa*` y
//       `statIcon*` solo existen aquí; `contenidoMax` y `primaryTint` solo en
//       el cliente. La intersección real son 9 constantes.
//   (c) Un `pubspec` extra con `path:` añade `flutter pub get` en cascada y
//       riesgo en `flutter build web`.
//
// ALCANCE: este archivo NO cambia ningún valor. Pone NOMBRE a números que ya
// estaban vigentes de facto en el repo (la referencia de cada uno está en su
// doc comment). La identidad visual es una decisión BLOQUEADA de la fase 11.
import 'package:flutter/material.dart';

/// Escala de espaciado de 4 pt — la única fuente de verdad para paddings,
/// márgenes y `SizedBox` de separación.
///
/// Antes de 11-11 no existía ninguna: el repo tenía 4, 6, 8, 10, 12, 14, 16,
/// 18, 20, 22, 24, 25, 30, 32 mezclados sin criterio. Estos 6 pasos son los
/// que más se repiten; los intermedios se irán absorbiendo en 11-12 / 11-13.
abstract final class GriSpacing {
  /// 4 — separación mínima (gap entre un icono y su etiqueta).
  static const double xs = 4;

  /// 8 — separación entre elementos hermanos de una misma fila/celda.
  static const double sm = 8;

  /// 16 — el paso por defecto. 38 usos como `SizedBox(height: 16)` en `lib/`
  /// antes de 11-11.
  static const double md = 16;

  /// 24 — separación entre bloques/secciones. El `EdgeInsets` dominante del
  /// panel: 18 usos (padding de las pantallas del shell).
  static const double lg = 24;

  /// 32 — padding de las tarjetas de pantalla completa
  /// (`login_screen.dart:87`, `bootstrap_screen.dart:125`).
  static const double xl = 32;

  /// 48 — el ÚNICO paso que no estaba vigente: hoy no hay ningún padding de
  /// 48 en `lib/`. Cierra la escala (2×[xl]) y es además el mínimo táctil de
  /// Material, que es lo que va a necesitar el plan 11-14.
  static const double xxl = 48;

  /// La escala completa, en orden. La usan los tests para comprobar que sigue
  /// siendo creciente y múltiplo de 4.
  static const List<double> escala = <double>[xs, sm, md, lg, xl, xxl];
}

/// Radios de borde vigentes en el repo. Tres, no más: cualquier otro valor
/// que aparezca en el código es deuda a migrar, no un token nuevo.
abstract final class GriRadius {
  /// 10 — contenedores internos: filas de lista, tiles de sección, item del
  /// sidebar (`app_shell.dart:258`). 6 usos aquí y 5 en la app cliente.
  static const double tile = 10;

  /// 15 — tarjeta. Es el radio que ya declara el `cardTheme` de `griTheme`
  /// en LAS DOS apps (`core/theme.dart`) y el más usado del repo (11 usos
  /// aquí, 8 en el cliente). También el de [griCardDecoration].
  static const double card = 15;

  /// 20 — píldora: chip de estado de pedido en cocina
  /// (`cocina/widgets/pedido_card.dart:221`).
  static const double chip = 20;

  /// `BorderRadius` listo para `BoxDecoration` — evita repetir
  /// `BorderRadius.circular(GriRadius.tile)` en cada sitio.
  static const BorderRadius tileBorder =
      BorderRadius.all(Radius.circular(tile));

  /// Ídem para [card]. Es el valor que declara el `cardTheme` del tema.
  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));

  /// Ídem para [chip].
  static const BorderRadius chipBorder =
      BorderRadius.all(Radius.circular(chip));
}

/// Anchos de decisión de layout del panel.
///
/// ⚠ NO son los 600/840/1200 de Material 3, y es DELIBERADO: el panel ya
/// colapsa el sidebar en 750 y salta a 4 columnas en 1100 desde la fase 8.
/// Adoptar los de M3 movería el punto de colapso del sidebar y del grid, que
/// es un cambio VISUAL — prohibido por la decisión bloqueada de la fase 11.
/// Un test de paridad afirma que el código y estos tokens siguen diciendo lo
/// mismo, así que la deuda queda visible en vez de olvidada.
abstract final class GriBreakpoints {
  /// 750 — por debajo, el sidebar se colapsa a 70 px
  /// (`features/shared/app_shell.dart:72`) y los grids bajan de columnas
  /// (`dashboard_screen.dart:60,64`, `mesas_screen.dart:43`).
  static const double compact = 750;

  /// 1100 — por encima, el grid de stats pasa a 4 columnas y el de mesas a 4
  /// (`dashboard_screen.dart:58,62`, `mesas_screen.dart:41`).
  static const double expanded = 1100;
}

/// Escala tipográfica REAL del panel, con nombre por SIGNIFICADO.
///
/// ── Por qué esto y no solo `ThemeData.textTheme` ──────────────────────────
/// `griTheme.textTheme` declara también la escala, pero con los valores de
/// Material 3, porque esos slots los consumen widgets del framework:
/// `headlineSmall` es el título de los 8 `AlertDialog` del panel,
/// `labelLarge` es la etiqueta de TODOS los botones, `bodyLarge` es el título
/// de los `ListTile`, `titleMedium` el del `DropdownButton` del shell. Meter
/// ahí los 24-bold / 18-bold que usa GRI cambiaría el tamaño y el peso de ese
/// chrome — un cambio visual, prohibido por la decisión BLOQUEADA de la fase.
/// (Medido, no supuesto: ver 11-11-SUMMARY.md.)
///
/// [GriText] es el otro lado del contrato: cada constante es EXACTAMENTE el
/// `TextStyle` que hoy está escrito inline en las pantallas, así que 11-12
/// puede sustituir el literal por el token sin mover un píxel. Ninguna fija
/// `color`: el color lo pone quien lo usa.
abstract final class GriText {
  /// 24 bold — titular de pantalla / cifra de una `StatCard` (4 usos inline).
  static const TextStyle tituloPantalla =
      TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

  /// 18 bold — título de sección dentro de una pantalla (6 usos inline).
  static const TextStyle tituloSeccion =
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  /// 16 bold — título de tarjeta / cabecera de tabla (5 usos inline).
  static const TextStyle tituloCard =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  /// 16 bold — etiqueta del botón de envío a ancho completo
  /// (`login_screen.dart:159`, `bootstrap_screen.dart:252`). OJO: en la app
  /// cliente este token vale 15, no 16.
  static const TextStyle boton =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  /// 14 — texto de lectura.
  static const TextStyle cuerpo = TextStyle(fontSize: 14);

  /// 13 — texto de lectura compacto. El estilo MÁS repetido del panel (17
  /// usos inline): filas de tabla y listados densos. OJO: en la app cliente
  /// este token vale 14, no 13.
  static const TextStyle cuerpoCompacto = TextStyle(fontSize: 13);

  /// 12 — texto auxiliar: pies, ayudas, metadatos (15 usos inline).
  static const TextStyle auxiliar = TextStyle(fontSize: 12);

  /// 12 bold — etiqueta de chip de estado
  /// (`cocina/widgets/pedido_card.dart:226`, `reservas_screen.dart:263`).
  static const TextStyle chip =
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

  /// La escala completa por nombre — la usan los tests para comprobar
  /// invariantes que deben cumplir TODOS los estilos.
  static const Map<String, TextStyle> escala = <String, TextStyle>{
    'tituloPantalla': tituloPantalla,
    'tituloSeccion': tituloSeccion,
    'tituloCard': tituloCard,
    'boton': boton,
    'cuerpo': cuerpo,
    'cuerpoCompacto': cuerpoCompacto,
    'auxiliar': auxiliar,
    'chip': chip,
  };
}
