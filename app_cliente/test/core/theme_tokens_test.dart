// test/core/theme_tokens_test.dart — gates del sistema de diseño de la app
// cliente (11-11).
//
// GEMELO: `panel_admin/test/core/theme_tokens_test.dart`.
//
// POR QUÉ EXISTE. Este plan NO rediseña: pone nombre a valores que YA están
// vigentes en el repo. Por eso casi todas las aserciones son literales — el
// número está escrito a mano aquí para que cambiarlo en `design_tokens.dart`
// obligue a venir a este archivo y hacerlo conscientemente.
//
// Las dos suites (cliente y panel) son INDEPENDIENTES: `flutter test` no puede
// importar el otro proyecto. Por eso la comprobación "GriSpacing y GriRadius
// valen lo mismo en las dos apps" se implementa afirmando los MISMOS literales
// a los dos lados. Si alguien toca un valor en un archivo, el test del OTRO
// proyecto es el que se pone rojo.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/design_tokens.dart';
import 'package:gri_cliente/core/theme.dart';

String _leer(String ruta) {
  final f = File(ruta);
  expect(f.existsSync(), isTrue, reason: 'no se encontró $ruta');
  return f.readAsStringSync();
}

void main() {
  // ── Escala de espaciado ──────────────────────────────────────────────────
  group('GriSpacing — escala 4-pt', () {
    test('los 6 pasos valen 4/8/16/24/32/48', () {
      // IDÉNTICO en panel_admin/lib/core/design_tokens.dart.
      expect(GriSpacing.xs, 4.0);
      expect(GriSpacing.sm, 8.0);
      expect(GriSpacing.md, 16.0);
      expect(GriSpacing.lg, 24.0);
      expect(GriSpacing.xl, 32.0);
      expect(GriSpacing.xxl, 48.0);
    });

    test('la escala está ordenada y todo paso es múltiplo de 4', () {
      // Con dientes: un paso fuera de la rejilla de 4 (p. ej. 15) o un paso
      // que rompa el orden cae aquí aunque el test literal de arriba siguiera
      // pasando por haberse actualizado a la vez.
      expect(GriSpacing.escala, hasLength(6));
      for (var i = 0; i < GriSpacing.escala.length; i++) {
        final v = GriSpacing.escala[i];
        expect(v % 4, 0, reason: 'paso $i ($v) no es múltiplo de 4');
        if (i > 0) {
          expect(v, greaterThan(GriSpacing.escala[i - 1]),
              reason: 'la escala debe ser estrictamente creciente');
        }
      }
    });
  });

  // ── Radios ───────────────────────────────────────────────────────────────
  group('GriRadius — radios vigentes', () {
    test('tile=10, card=15, chip=20', () {
      // IDÉNTICO en panel_admin/lib/core/design_tokens.dart.
      expect(GriRadius.tile, 10.0);
      expect(GriRadius.card, 15.0);
      expect(GriRadius.chip, 20.0);
    });

    test('GriRadius.card ES el radio que declara el cardTheme del tema', () {
      // Con dientes de verdad: no compara dos literales, lee el ThemeData
      // REAL. Si alguien cambia el 15 del cardTheme y no el token (o al
      // revés), esto se pone rojo.
      final shape = griTheme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final radius = (shape! as RoundedRectangleBorder).borderRadius
          as BorderRadius;
      expect(radius.topLeft.x, GriRadius.card);
      expect(radius, GriRadius.cardBorder);
    });
  });

  // ── Breakpoints ──────────────────────────────────────────────────────────
  group('GriBreakpoints — anchos', () {
    test('contenidoMax=480 y los saltos de M3 (600/840)', () {
      expect(GriBreakpoints.contenidoMax, 480.0);
      // app_cliente no tenía NINGÚN breakpoint que preservar, así que aquí
      // sí se adoptan los de Material 3 (a diferencia del panel, que ya
      // usaba 750/1100 y no puede moverlos sin cambio visual).
      expect(GriBreakpoints.compact, 600.0);
      expect(GriBreakpoints.expanded, 840.0);
    });

    test('contenidoMax ES el maxWidth que aplica hoy el AppShell', () {
      // Gate de paridad token↔código (patrón de 11-17,
      // firebase_options_coherencia_test.dart). El token no vale nada si el
      // shell sigue con su literal por su cuenta.
      final src = _leer('lib/features/shared/app_shell.dart');
      final anchos = RegExp(r'BoxConstraints\(maxWidth:\s*([0-9.]+)')
          .allMatches(src)
          .map((m) => double.parse(m.group(1)!))
          .toSet();
      expect(anchos, isNotEmpty,
          reason: 'no se encontró ningún BoxConstraints(maxWidth: …) en el '
              'AppShell — si el shell dejó de acotar el contenido, este gate '
              'quedó ciego y hay que reescribirlo, no borrarlo');
      expect(anchos, {GriBreakpoints.contenidoMax},
          reason: 'el AppShell usa $anchos pero el token dice '
              '${GriBreakpoints.contenidoMax}');
    });
  });

  // ── Escala tipográfica (constantes) ──────────────────────────────────────
  group('GriText — la escala real de la app', () {
    test('cada estilo es EXACTAMENTE el TextStyle inline que sustituye', () {
      // La garantía que necesitan 11-12/11-19: migrar un
      // `TextStyle(fontSize: 16, fontWeight: FontWeight.bold)` inline a
      // `GriText.tituloCard` NO puede mover un píxel.
      expect(GriText.tituloPantalla,
          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
      expect(GriText.tituloSeccion,
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
      expect(GriText.tituloCard,
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
      expect(GriText.boton,
          const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
      expect(GriText.cuerpo, const TextStyle(fontSize: 16));
      expect(GriText.cuerpoCompacto, const TextStyle(fontSize: 14));
      expect(GriText.auxiliar, const TextStyle(fontSize: 12));
      expect(GriText.chip,
          const TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
    });

    test('ningún estilo fija color: el color lo pone quien lo usa', () {
      // Un color dentro de la escala tipográfica sería una segunda paleta
      // paralela — justo lo que este plan viene a eliminar.
      for (final s in GriText.escala.entries) {
        expect(s.value.color, isNull, reason: '${s.key} fija color');
        expect(s.value.inherit, isTrue,
            reason: '${s.key} con inherit:false dejaría de fusionarse con el '
                'DefaultTextStyle y cambiaría el render al migrar');
      }
    });
  });
}
