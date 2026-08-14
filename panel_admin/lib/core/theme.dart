import 'package:flutter/material.dart';

import '../models/mesa.dart';

/// Paleta EXACTA del mockup `documentos/index.html` (:root vars).
///
/// Fuente única de verdad visual para TODO el panel — Phase 8 debe reutilizar
/// estas constantes, nunca re-descubrirlas del mockup.
///
/// NOTA: los hex del plan venían como 6 dígitos (`0xff4c05`), que en Dart es
/// alpha=0x00 (transparente). Aquí van con alpha opaco `0xFF…` (desviación
/// Rule 1 documentada en 04-02-SUMMARY.md).
class GriColors {
  GriColors._();

  // ── App chrome ──────────────────────────────────────────────────────────
  /// #ff4c05 — botones, active menu, avatar bg, logo icon bg.
  static const Color primary = Color(0xFFFF4C05);

  /// #d93d00 — hover de botones/acciones primarias.
  static const Color primaryDark = Color(0xFFD93D00);

  /// #f5f6f8 — fondo de página.
  static const Color background = Color(0xFFF5F6F8);

  /// #1f2329 — barra lateral.
  static const Color sidebar = Color(0xFF1F2329);

  /// #252525 — texto principal.
  static const Color text = Color(0xFF252525);

  /// #777777 — texto secundario.
  static const Color gray = Color(0xFF777777);

  // ── Mesa: disponible (verde) ────────────────────────────────────────────
  static const Color mesaDisponibleBg = Color(0xFFE7F8F0);
  static const Color mesaDisponibleFg = Color(0xFF168A52);
  static const Color mesaDisponibleDot = Color(0xFF20B26B);

  // ── Mesa: ocupada (rojo) ────────────────────────────────────────────────
  static const Color mesaOcupadaBg = Color(0xFFFFE9E6);
  static const Color mesaOcupadaFg = Color(0xFFC83C2E);
  static const Color mesaOcupadaDot = Color(0xFFE74C3C);

  // ── Mesa: reservada (amarillo) ──────────────────────────────────────────
  static const Color mesaReservadaBg = Color(0xFFFFF5D8);
  static const Color mesaReservadaFg = Color(0xFFAA7A00);
  static const Color mesaReservadaDot = Color(0xFFF5B82E);

  // ── Mesa: limpieza (azul) ───────────────────────────────────────────────
  static const Color mesaLimpiezaBg = Color(0xFFE9F0FF);
  static const Color mesaLimpiezaFg = Color(0xFF3167C9);
  static const Color mesaLimpiezaDot = Color(0xFF3478F6);

  // ── Stat card icon backgrounds (tint del dot) ───────────────────────────
  static const Color statIconDisponibleBg = Color(0xFFE7F8F0);
  static const Color statIconOcupadaBg = Color(0xFFFFF0E9);
  static const Color statIconReservasBg = Color(0xFFFFF7DF);
  static const Color statIconPedidosBg = Color(0xFFE9F0FF);
}

/// Fondo del tile según [EstadoMesa] — switch exhaustivo sobre los 4 estados
/// (defensa pixel-perfect del ADMN-02). Tile disponible: #e7f8f0.
Color mesaTileBg(EstadoMesa e) => switch (e) {
      EstadoMesa.disponible => GriColors.mesaDisponibleBg,
      EstadoMesa.ocupada => GriColors.mesaOcupadaBg,
      EstadoMesa.reservada => GriColors.mesaReservadaBg,
      EstadoMesa.limpieza => GriColors.mesaLimpiezaBg,
    };

/// Texto del tile según [EstadoMesa].
Color mesaTileFg(EstadoMesa e) => switch (e) {
      EstadoMesa.disponible => GriColors.mesaDisponibleFg,
      EstadoMesa.ocupada => GriColors.mesaOcupadaFg,
      EstadoMesa.reservada => GriColors.mesaReservadaFg,
      EstadoMesa.limpieza => GriColors.mesaLimpiezaFg,
    };

/// Dot/indicador del estado según [EstadoMesa] (leyenda + stat icons).
Color mesaDot(EstadoMesa e) => switch (e) {
      EstadoMesa.disponible => GriColors.mesaDisponibleDot,
      EstadoMesa.ocupada => GriColors.mesaOcupadaDot,
      EstadoMesa.reservada => GriColors.mesaReservadaDot,
      EstadoMesa.limpieza => GriColors.mesaLimpiezaDot,
    };

/// [ThemeData] del panel — card radius 15 + shadow sutil, fondo #f5f6f8,
/// seed naranja #ff4c05 (Material 3).
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
