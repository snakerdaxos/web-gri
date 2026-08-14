import 'package:flutter/material.dart';

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

/// [ThemeData] de la app cliente — fondo #f7f7f7, seed naranja #ff4c05
/// (Material 3), cards radius 15 + shadow sutil (estilo mockup).
final ThemeData griTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: GriColors.primary),
  scaffoldBackgroundColor: GriColors.background,
  cardTheme: const CardThemeData(
    elevation: 0.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(15)),
    ),
  ),
);
