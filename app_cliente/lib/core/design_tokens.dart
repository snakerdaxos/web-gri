// lib/core/design_tokens.dart — tokens de diseño de la APP CLIENTE (11-11).
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║ SINCRONIZAR CON: `panel_admin/lib/core/design_tokens.dart`               ║
// ║                                                                          ║
// ║ IDÉNTICO en los dos archivos — si tocas uno, tienes que tocar el otro:   ║
// ║   · GriSpacing  (los 6 pasos de la escala 4-pt)                          ║
// ║   · GriRadius   (tile 10 / card 15 / chip 20)                            ║
// ║                                                                          ║
// ║ PROPIO de cada app — NO se sincroniza:                                   ║
// ║   · GriBreakpoints  (aquí 480/600/840; en el panel 750/1100)             ║
// ║   · GriText         (aquí cuerpoCompacto 14 y boton 15; en el panel      ║
// ║                      13 y 16 — vienen de dos mockups distintos)          ║
// ║                                                                          ║
// ║ La paridad la sostienen los tests: `test/core/theme_tokens_test.dart`    ║
// ║ existe en las DOS apps y afirma los mismos literales. No pueden          ║
// ║ importarse entre sí (son dos paquetes Dart independientes), así que si   ║
// ║ cambias un valor aquí, el que se pone rojo es el test del OTRO proyecto. ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// POR QUÉ DUPLICACIÓN Y NO UN PAQUETE COMPARTIDO (decisión del plan 11-11):
//   (a) Las paletas de las dos apps YA divergen a propósito y está
//       documentado en el código (`background` #F7F7F7 aquí vs #F5F6F8 en el
//       panel; `text` #222222 vs #252525). Son dos mockups.
//   (b) Los tokens específicos no se solapan: `contenidoMax` y `primaryTint`
//       solo existen aquí; `sidebar`, `mesa*` y `statIcon*` solo en el panel.
//       La intersección real son 9 constantes.
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
/// Antes de 11-11 no existía ninguna: el repo tenía 4, 5, 6, 8, 10, 12, 14,
/// 16, 18, 20, 24, 30, 32 mezclados sin criterio. Estos 6 pasos son los que
/// más se repiten; los intermedios (10, 14, 18, 20…) se irán absorbiendo en
/// los planes 11-12 / 11-19 / 11-13.
abstract final class GriSpacing {
  /// 4 — separación mínima (gap entre un icono y su etiqueta).
  static const double xs = 4;

  /// 8 — separación entre elementos hermanos de una misma fila/celda.
  static const double sm = 8;

  /// 16 — el paso por defecto. 22 usos como `EdgeInsets` y 55 como
  /// `SizedBox(height: 16)` en `lib/` antes de 11-11: es el valor dominante.
  static const double md = 16;

  /// 24 — separación entre bloques/secciones (10 usos como `EdgeInsets`).
  static const double lg = 24;

  /// 32 — padding de las tarjetas de pantalla completa
  /// (`login_screen.dart:103`, `register_screen.dart:127`).
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
  /// 10 — contenedores internos: filas de lista, tiles de sección, banners.
  /// 5 usos en la app cliente y 6 en el panel antes de 11-11.
  static const double tile = 10;

  /// 15 — tarjeta. Es el radio que ya declara el `cardTheme` de `griTheme`
  /// en LAS DOS apps (`core/theme.dart`) y el más usado del repo (8 usos
  /// aquí, 11 en el panel).
  static const double card = 15;

  /// 20 — píldora: chips de estado de pedido y de reserva
  /// (`pedido_estado_screen.dart:332`, `mis_reservas_screen.dart:305`).
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

/// Anchos de decisión de layout de la app cliente.
///
/// A diferencia del panel — que YA usaba 750/1100 y no puede moverlos sin un
/// cambio visual —, aquí no había NINGÚN `LayoutBuilder` que preservar, así
/// que [compact] y [expanded] adoptan los saltos de Material 3 (600/840).
/// El único valor heredado es [contenidoMax].
abstract final class GriBreakpoints {
  /// 480 — ancho máximo de la columna de contenido. Es el `BoxConstraints
  /// (maxWidth: 480)` que ya aplica `features/shared/app_shell.dart` para que
  /// la app no se estire en tablet/web. Un test de paridad afirma que el
  /// shell y este token siguen diciendo lo mismo.
  static const double contenidoMax = 480;

  /// 600 — por debajo, móvil en vertical (Material 3 "compact").
  static const double compact = 600;

  /// 840 — por encima, tablet/escritorio (Material 3 "expanded").
  static const double expanded = 840;

  /// 720 — ancho máximo de la columna de contenido a partir de [expanded]
  /// (11-13). El shell de la app cliente estaba encajado en [contenidoMax] a
  /// CUALQUIER ancho, así que en un navegador de escritorio la app se veía
  /// como una tira estrecha con dos bandas enormes. Por encima de 840 la
  /// columna se ensancha; por debajo NO cambia nada (el tramo 0–840 es
  /// idéntico al de antes de 11-13, que es la mitigación de T-11-13-01).
  ///
  /// Es el ÚNICO valor NUEVO de este archivo: no estaba vigente en el repo.
  /// 720 = 1.5 × [contenidoMax], y sigue por debajo de los 840 del salto
  /// "expanded" de M3, así que nunca deja el contenido más ancho que el
  /// viewport donde empieza a aplicarse.
  static const double contenidoMaxAmplio = 720;
}

/// Escala tipográfica REAL de la app cliente, con nombre por SIGNIFICADO.
///
/// ── Por qué esto y no solo `ThemeData.textTheme` ──────────────────────────
/// `griTheme.textTheme` declara también la escala, pero con los valores de
/// Material 3, porque esos slots los consumen widgets del framework:
/// `titleLarge` es el título de los 8 `AppBar` de esta app, `labelLarge` es
/// la etiqueta de TODOS los botones, `bodyLarge` es el título de los
/// `ListTile`. Meter ahí los 24-bold / 18-bold que usa GRI cambiaría el
/// tamaño y el peso de ese chrome — un cambio visual, prohibido por la
/// decisión BLOQUEADA de la fase. (Medido, no supuesto: ver 11-11-SUMMARY.md.)
///
/// [GriText] es el otro lado del contrato: cada constante es EXACTAMENTE el
/// `TextStyle` que hoy está escrito inline en las pantallas, así que 11-12 y
/// 11-19 pueden sustituir el literal por el token sin mover un píxel.
/// Ninguna fija `color`: el color lo pone quien lo usa.
abstract final class GriText {
  /// 24 bold — titular de pantalla / cifra destacada (4 usos inline).
  static const TextStyle tituloPantalla =
      TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

  /// 18 bold — título de sección dentro de una pantalla (5 usos inline).
  static const TextStyle tituloSeccion =
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  /// 16 bold — título de tarjeta / nombre de plato. El estilo MÁS repetido de
  /// la app: 12 usos inline.
  static const TextStyle tituloCard =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  /// 15 bold — 3 usos inline. OJO (medido en 11-19): solo UNO de los tres es
  /// de verdad la etiqueta de un botón (`calificacion_sheet.dart`); los otros
  /// dos son el contador de cantidad del carrito y el banner "Cuenta
  /// solicitada". El nombre viene de 11-11, que derivó la escala CONTANDO
  /// estilos repetidos, no de un diseño.
  static const TextStyle boton =
      TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  /// 16 bold — etiqueta del CTA principal. 9 usos inline, y los NUEVE son
  /// botones (login, registro, perfil, carrito, enviar pedido, pedir la
  /// cuenta, abrir mesa, confirmar reserva, reservar mesa).
  ///
  /// Vale lo MISMO que [tituloCard] a propósito: son el mismo par
  /// tamaño/peso con dos significados distintos, y en app_cliente no hay ni
  /// un solo título de tarjeta a 16 bold (el doc de [tituloCard] habla de
  /// "12 usos" que en esta app no existen — ver 11-19-SUMMARY.md). Se separan
  /// para que 11-14 pueda tocar la tipografía de los CTA sin arrastrar las
  /// tarjetas, no porque hoy rendericen distinto.
  static const TextStyle botonGrande =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  /// 16 — texto de lectura (13 usos inline de `fontSize: 16`).
  static const TextStyle cuerpo = TextStyle(fontSize: 16);

  /// 14 — texto de lectura compacto.
  static const TextStyle cuerpoCompacto = TextStyle(fontSize: 14);

  /// 12 — texto auxiliar: pies, ayudas, metadatos (9 usos inline).
  static const TextStyle auxiliar = TextStyle(fontSize: 12);

  /// 12 bold — etiqueta de chip de estado
  /// (`pedido_estado_screen.dart:337`).
  static const TextStyle chip =
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

  /// La escala completa por nombre — la usan los tests para comprobar
  /// invariantes que deben cumplir TODOS los estilos.
  static const Map<String, TextStyle> escala = <String, TextStyle>{
    'tituloPantalla': tituloPantalla,
    'tituloSeccion': tituloSeccion,
    'tituloCard': tituloCard,
    'boton': boton,
    'botonGrande': botonGrande,
    'cuerpo': cuerpo,
    'cuerpoCompacto': cuerpoCompacto,
    'auxiliar': auxiliar,
    'chip': chip,
  };
}
