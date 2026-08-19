import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Paleta EXACTA del mockup `documentos/indexcliente.html` (:root vars).
///
/// Fuente única de verdad visual de la app cliente. Ojo: difiere del panel
/// admin en `background` (#f7f7f7 vs #f5f6f8 del panel) y `text` (#222 vs
/// #252525) — son mockups distintos.
///
/// NOTA: hex con alpha opaco `0xFF…` (8 dígitos ARGB — lección 04-02: 6
/// dígitos tras `0x` se interpretan como alpha 0x00 transparente).
class GriColors {
  GriColors._();

  // ── App chrome ──────────────────────────────────────────────────────────
  /// #ff4c05 — botones, active tab, logo icon bg.
  static const Color primary = Color(0xFFFF4C05);

  /// #d93d00 — hover de botones primarios.
  static const Color primaryDark = Color(0xFFD93D00);

  /// #f7f7f7 — fondo de página (mockup cliente, NO el #f5f6f8 del panel).
  static const Color background = Color(0xFFF7F7F7);

  /// #222 — texto principal.
  static const Color text = Color(0xFF222222);

  /// #777 — texto secundario (labels de tabs inactivos incluidos).
  static const Color gray = Color(0xFF777777);

  /// #20b26b — success (confirmada).
  static const Color green = Color(0xFF20B26B);

  /// #fff0e9 — tint del botón QR y card "Próxima reserva".
  static const Color primaryTint = Color(0xFFFFF0E9);

  /// #ffd6c7 — borde de la card "Próxima reserva".
  static const Color primaryTintBorder = Color(0xFFFFD6C7);

  // ── Chips de estado de reserva ──────────────────────────────────────────
  /// #dff7eb / #168a52 — chip "Confirmada" (mockup .status).
  static const Color chipConfirmadaBg = Color(0xFFDFF7EB);
  static const Color chipConfirmadaFg = Color(0xFF168A52);

  /// Rojo suave — chip "Cancelada".
  static const Color chipCanceladaBg = Color(0xFFFFE9E6);
  static const Color chipCanceladaFg = Color(0xFFC83C2E);

  // ── Helpers de estado ───────────────────────────────────────────────────
  /// Fondo del chip según el estado de la reserva.
  static Color estadoChipBg(String estado) => switch (estado) {
        'confirmada' => chipConfirmadaBg,
        'cancelada' => chipCanceladaBg,
        _ => const Color(0xFFEEEEEE),
      };

  /// Texto del chip según el estado de la reserva.
  static Color estadoChipFg(String estado) => switch (estado) {
        'confirmada' => chipConfirmadaFg,
        'cancelada' => chipCanceladaFg,
        _ => GriColors.gray,
      };
}

/// Colores SEMÁNTICOS de dominio de la app cliente — estado de pedido y
/// estado de reserva.
///
/// POR QUÉ EXISTE (11-11). Hasta ahora estos colores vivían en DOS sitios: la
/// paleta de chips de reserva en [GriColors] y una segunda paleta paralela
/// dentro de `models/pedido.dart:78-95`, con sus propios literales. Un modelo
/// de datos no es sitio para una paleta, y tener dos hacía imposible saber
/// cuál mandaba. Esta extensión las unifica en el tema.
///
/// NINGÚN valor cambia respecto a lo que había: los hex se copiaron
/// literalmente (la identidad visual es una decisión BLOQUEADA de la fase 11).
///
/// Se lee con [of], que cae a [gri] si el `ThemeData` no la registrase. Ese
/// fallback existe porque hay suites que pumpean un `MaterialApp` sin `theme`;
/// que `griTheme` la registre de verdad lo garantiza un test aparte, para que
/// el fallback no pueda tapar un olvido.
@immutable
class GriSemanticColors extends ThemeExtension<GriSemanticColors> {
  const GriSemanticColors({
    required this.pedidoEnviadoFg,
    required this.pedidoEnviadoBg,
    required this.pedidoAceptadoFg,
    required this.pedidoAceptadoBg,
    required this.pedidoEnPreparacionFg,
    required this.pedidoEnPreparacionBg,
    required this.pedidoServidoFg,
    required this.pedidoServidoBg,
    required this.pedidoRechazadoFg,
    required this.pedidoRechazadoBg,
    required this.reservaConfirmadaFg,
    required this.reservaConfirmadaBg,
    required this.reservaCanceladaFg,
    required this.reservaCanceladaBg,
    required this.neutroFg,
    required this.neutroBg,
    required this.exito,
    required this.textoSecundarioAccesible,
  });

  // ── Estado de pedido (5 estados del wire) ───────────────────────────────
  /// #2563EB — azul de `enviado` (era `pedido.dart:79`).
  final Color pedidoEnviadoFg;

  /// #E3ECFD — fondo del chip `enviado` (era `pedido.dart:89`).
  final Color pedidoEnviadoBg;

  /// #D97706 — ámbar de `aceptado` (era `pedido.dart:80`).
  final Color pedidoAceptadoFg;

  /// #FCF0DE — fondo del chip `aceptado` (era `pedido.dart:90`).
  final Color pedidoAceptadoBg;

  /// #7C3AED — morado de `en_preparacion` (era `pedido.dart:81`).
  final Color pedidoEnPreparacionFg;

  /// #EFE6FC — fondo del chip `en_preparacion` (era `pedido.dart:91`).
  final Color pedidoEnPreparacionBg;

  /// #168A52 — verde de `servido` (era `pedido.dart:82`).
  final Color pedidoServidoFg;

  /// #DFF7EB — fondo del chip `servido` (era `pedido.dart:92`).
  final Color pedidoServidoBg;

  /// #C83C2E — rojo de `rechazado` (era `pedido.dart:83`).
  final Color pedidoRechazadoFg;

  /// #FFE9E6 — fondo del chip `rechazado` (era `pedido.dart:93`).
  final Color pedidoRechazadoBg;

  // ── Estado de reserva ───────────────────────────────────────────────────
  /// #168A52 / #DFF7EB — chip "Confirmada" (== [GriColors.chipConfirmadaFg]).
  final Color reservaConfirmadaFg;
  final Color reservaConfirmadaBg;

  /// #C83C2E / #FFE9E6 — chip "Cancelada" (== [GriColors.chipCanceladaFg]).
  final Color reservaCanceladaFg;
  final Color reservaCanceladaBg;

  // ── Comunes ─────────────────────────────────────────────────────────────
  /// #777777 / #EEEEEE — estado desconocido. El MISMO par servía de comodín
  /// en las dos paletas antiguas, así que aquí es uno solo.
  final Color neutroFg;
  final Color neutroBg;

  /// #20B26B — verde de éxito (== [GriColors.green]).
  final Color exito;

  /// #6E6E6E — gris de texto secundario que SÍ alcanza 4.5:1 sobre #F7F7F7.
  ///
  /// ⚠ HOY NO ESTÁ APLICADO EN NINGÚN SITIO, y es deliberado. Aplicarlo es
  /// trabajo del plan 11-14 (accesibilidad). Existe aquí para que ese plan
  /// NO tenga que tocar [GriColors.gray] (#777777), que es un token de MARCA
  /// y no puede cambiar de valor. Dos tests guardan esa separación.
  final Color textoSecundarioAccesible;

  /// La instancia canónica de GRI. Es la que registra [griTheme] y la que
  /// devuelve [of] cuando el tema no trae ninguna.
  static const GriSemanticColors gri = GriSemanticColors(
    pedidoEnviadoFg: Color(0xFF2563EB),
    pedidoEnviadoBg: Color(0xFFE3ECFD),
    pedidoAceptadoFg: Color(0xFFD97706),
    pedidoAceptadoBg: Color(0xFFFCF0DE),
    pedidoEnPreparacionFg: Color(0xFF7C3AED),
    pedidoEnPreparacionBg: Color(0xFFEFE6FC),
    pedidoServidoFg: Color(0xFF168A52),
    pedidoServidoBg: Color(0xFFDFF7EB),
    pedidoRechazadoFg: Color(0xFFC83C2E),
    pedidoRechazadoBg: Color(0xFFFFE9E6),
    reservaConfirmadaFg: GriColors.chipConfirmadaFg,
    reservaConfirmadaBg: GriColors.chipConfirmadaBg,
    reservaCanceladaFg: GriColors.chipCanceladaFg,
    reservaCanceladaBg: GriColors.chipCanceladaBg,
    neutroFg: Color(0xFF777777),
    neutroBg: Color(0xFFEEEEEE),
    exito: GriColors.green,
    textoSecundarioAccesible: Color(0xFF6E6E6E),
  );

  /// Lee la extensión del tema. Cae a [gri] si no está registrada.
  static GriSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<GriSemanticColors>() ?? gri;

  /// Color del TEXTO del chip según el estado del pedido.
  Color pedidoFg(String estado) => switch (estado) {
        'enviado' => pedidoEnviadoFg,
        'aceptado' => pedidoAceptadoFg,
        'en_preparacion' => pedidoEnPreparacionFg,
        'servido' => pedidoServidoFg,
        'rechazado' => pedidoRechazadoFg,
        _ => neutroFg,
      };

  /// Fondo del chip según el estado del pedido.
  Color pedidoBg(String estado) => switch (estado) {
        'enviado' => pedidoEnviadoBg,
        'aceptado' => pedidoAceptadoBg,
        'en_preparacion' => pedidoEnPreparacionBg,
        'servido' => pedidoServidoBg,
        'rechazado' => pedidoRechazadoBg,
        _ => neutroBg,
      };

  /// Color del TEXTO del chip según el estado de la reserva.
  Color reservaFg(String estado) => switch (estado) {
        'confirmada' => reservaConfirmadaFg,
        'cancelada' => reservaCanceladaFg,
        _ => neutroFg,
      };

  /// Fondo del chip según el estado de la reserva.
  Color reservaBg(String estado) => switch (estado) {
        'confirmada' => reservaConfirmadaBg,
        'cancelada' => reservaCanceladaBg,
        _ => neutroBg,
      };

  @override
  GriSemanticColors copyWith({
    Color? pedidoEnviadoFg,
    Color? pedidoEnviadoBg,
    Color? pedidoAceptadoFg,
    Color? pedidoAceptadoBg,
    Color? pedidoEnPreparacionFg,
    Color? pedidoEnPreparacionBg,
    Color? pedidoServidoFg,
    Color? pedidoServidoBg,
    Color? pedidoRechazadoFg,
    Color? pedidoRechazadoBg,
    Color? reservaConfirmadaFg,
    Color? reservaConfirmadaBg,
    Color? reservaCanceladaFg,
    Color? reservaCanceladaBg,
    Color? neutroFg,
    Color? neutroBg,
    Color? exito,
    Color? textoSecundarioAccesible,
  }) {
    return GriSemanticColors(
      pedidoEnviadoFg: pedidoEnviadoFg ?? this.pedidoEnviadoFg,
      pedidoEnviadoBg: pedidoEnviadoBg ?? this.pedidoEnviadoBg,
      pedidoAceptadoFg: pedidoAceptadoFg ?? this.pedidoAceptadoFg,
      pedidoAceptadoBg: pedidoAceptadoBg ?? this.pedidoAceptadoBg,
      pedidoEnPreparacionFg:
          pedidoEnPreparacionFg ?? this.pedidoEnPreparacionFg,
      pedidoEnPreparacionBg:
          pedidoEnPreparacionBg ?? this.pedidoEnPreparacionBg,
      pedidoServidoFg: pedidoServidoFg ?? this.pedidoServidoFg,
      pedidoServidoBg: pedidoServidoBg ?? this.pedidoServidoBg,
      pedidoRechazadoFg: pedidoRechazadoFg ?? this.pedidoRechazadoFg,
      pedidoRechazadoBg: pedidoRechazadoBg ?? this.pedidoRechazadoBg,
      reservaConfirmadaFg: reservaConfirmadaFg ?? this.reservaConfirmadaFg,
      reservaConfirmadaBg: reservaConfirmadaBg ?? this.reservaConfirmadaBg,
      reservaCanceladaFg: reservaCanceladaFg ?? this.reservaCanceladaFg,
      reservaCanceladaBg: reservaCanceladaBg ?? this.reservaCanceladaBg,
      neutroFg: neutroFg ?? this.neutroFg,
      neutroBg: neutroBg ?? this.neutroBg,
      exito: exito ?? this.exito,
      textoSecundarioAccesible:
          textoSecundarioAccesible ?? this.textoSecundarioAccesible,
    );
  }

  @override
  GriSemanticColors lerp(ThemeExtension<GriSemanticColors>? other, double t) {
    if (other is! GriSemanticColors) return this;
    return GriSemanticColors(
      pedidoEnviadoFg:
          Color.lerp(pedidoEnviadoFg, other.pedidoEnviadoFg, t)!,
      pedidoEnviadoBg:
          Color.lerp(pedidoEnviadoBg, other.pedidoEnviadoBg, t)!,
      pedidoAceptadoFg:
          Color.lerp(pedidoAceptadoFg, other.pedidoAceptadoFg, t)!,
      pedidoAceptadoBg:
          Color.lerp(pedidoAceptadoBg, other.pedidoAceptadoBg, t)!,
      pedidoEnPreparacionFg:
          Color.lerp(pedidoEnPreparacionFg, other.pedidoEnPreparacionFg, t)!,
      pedidoEnPreparacionBg:
          Color.lerp(pedidoEnPreparacionBg, other.pedidoEnPreparacionBg, t)!,
      pedidoServidoFg:
          Color.lerp(pedidoServidoFg, other.pedidoServidoFg, t)!,
      pedidoServidoBg:
          Color.lerp(pedidoServidoBg, other.pedidoServidoBg, t)!,
      pedidoRechazadoFg:
          Color.lerp(pedidoRechazadoFg, other.pedidoRechazadoFg, t)!,
      pedidoRechazadoBg:
          Color.lerp(pedidoRechazadoBg, other.pedidoRechazadoBg, t)!,
      reservaConfirmadaFg:
          Color.lerp(reservaConfirmadaFg, other.reservaConfirmadaFg, t)!,
      reservaConfirmadaBg:
          Color.lerp(reservaConfirmadaBg, other.reservaConfirmadaBg, t)!,
      reservaCanceladaFg:
          Color.lerp(reservaCanceladaFg, other.reservaCanceladaFg, t)!,
      reservaCanceladaBg:
          Color.lerp(reservaCanceladaBg, other.reservaCanceladaBg, t)!,
      neutroFg: Color.lerp(neutroFg, other.neutroFg, t)!,
      neutroBg: Color.lerp(neutroBg, other.neutroBg, t)!,
      exito: Color.lerp(exito, other.exito, t)!,
      textoSecundarioAccesible: Color.lerp(
          textoSecundarioAccesible, other.textoSecundarioAccesible, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GriSemanticColors &&
          other.pedidoEnviadoFg == pedidoEnviadoFg &&
          other.pedidoEnviadoBg == pedidoEnviadoBg &&
          other.pedidoAceptadoFg == pedidoAceptadoFg &&
          other.pedidoAceptadoBg == pedidoAceptadoBg &&
          other.pedidoEnPreparacionFg == pedidoEnPreparacionFg &&
          other.pedidoEnPreparacionBg == pedidoEnPreparacionBg &&
          other.pedidoServidoFg == pedidoServidoFg &&
          other.pedidoServidoBg == pedidoServidoBg &&
          other.pedidoRechazadoFg == pedidoRechazadoFg &&
          other.pedidoRechazadoBg == pedidoRechazadoBg &&
          other.reservaConfirmadaFg == reservaConfirmadaFg &&
          other.reservaConfirmadaBg == reservaConfirmadaBg &&
          other.reservaCanceladaFg == reservaCanceladaFg &&
          other.reservaCanceladaBg == reservaCanceladaBg &&
          other.neutroFg == neutroFg &&
          other.neutroBg == neutroBg &&
          other.exito == exito &&
          other.textoSecundarioAccesible == textoSecundarioAccesible;

  @override
  int get hashCode => Object.hashAll(<Object>[
        pedidoEnviadoFg,
        pedidoEnviadoBg,
        pedidoAceptadoFg,
        pedidoAceptadoBg,
        pedidoEnPreparacionFg,
        pedidoEnPreparacionBg,
        pedidoServidoFg,
        pedidoServidoBg,
        pedidoRechazadoFg,
        pedidoRechazadoBg,
        reservaConfirmadaFg,
        reservaConfirmadaBg,
        reservaCanceladaFg,
        reservaCanceladaBg,
        neutroFg,
        neutroBg,
        exito,
        textoSecundarioAccesible,
      ]);
}

/// Escala tipográfica DECLARADA del tema.
///
/// ── Por qué lleva los valores de Material 3 y no los 24-bold de GRI ───────
/// Estos slots NO son un catálogo libre: los consume el chrome del framework.
/// Medido con una sonda contra el tema anterior a 11-11: `titleLarge` es el
/// título de los 8 `AppBar` de esta app, `bodyLarge` el título de los
/// `ListTile`, `bodyMedium` el `Text` sin estilo y el contenido de los
/// diálogos, `labelLarge` la etiqueta de TODOS los botones. Meter aquí los
/// 24-bold / 18-bold que GRI usa inline cambiaría el tamaño y el peso de ese
/// chrome — un cambio visual, prohibido por la decisión BLOQUEADA de la fase.
///
/// Declararlos explícitamente sí aporta: dejan de ser un default implícito
/// del framework, así que una actualización de Flutter que cambie la
/// tipografía de M3 ya no puede reflotar la app en silencio, y 11-12 / 11-19
/// tienen un objetivo estable al que migrar los `fontSize: 16/14/12` inline.
///
/// La escala PROPIA de GRI (la de los pesos y tamaños del mockup) vive en
/// `GriText`, en `core/design_tokens.dart`.
///
/// Ningún slot fija `color`: se fusiona con la tipografía del [ColorScheme].
const TextTheme griTextTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
  displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
  displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
  headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
  headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
  titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
);

/// [ThemeData] de la app cliente — fondo #f7f7f7, seed naranja #ff4c05
/// (Material 3), cards radius 15 + shadow sutil (estilo mockup).
final ThemeData griTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: GriColors.primary),
  scaffoldBackgroundColor: GriColors.background,
  textTheme: griTextTheme,
  extensions: const <ThemeExtension<dynamic>>[GriSemanticColors.gri],
  cardTheme: const CardThemeData(
    elevation: 0.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(GriRadius.card)),
    ),
  ),
);
