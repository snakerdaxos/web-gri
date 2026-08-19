// test/core/theme_tokens_test.dart — gates del sistema de diseño del panel
// (11-11).
//
// GEMELO: `app_cliente/test/core/theme_tokens_test.dart`.
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
import 'package:gri_panel_admin/core/design_tokens.dart';
import 'package:gri_panel_admin/core/theme.dart';

String _leer(String ruta) {
  final f = File(ruta);
  expect(f.existsSync(), isTrue, reason: 'no se encontró $ruta');
  return f.readAsStringSync();
}

void main() {
  // ── Escala de espaciado ──────────────────────────────────────────────────
  group('GriSpacing — escala 4-pt', () {
    test('los 6 pasos valen 4/8/16/24/32/48', () {
      // IDÉNTICO en app_cliente/lib/core/design_tokens.dart.
      expect(GriSpacing.xs, 4.0);
      expect(GriSpacing.sm, 8.0);
      expect(GriSpacing.md, 16.0);
      expect(GriSpacing.lg, 24.0);
      expect(GriSpacing.xl, 32.0);
      expect(GriSpacing.xxl, 48.0);
    });

    test('la escala está ordenada y todo paso es múltiplo de 4', () {
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
      // IDÉNTICO en app_cliente/lib/core/design_tokens.dart.
      expect(GriRadius.tile, 10.0);
      expect(GriRadius.card, 15.0);
      expect(GriRadius.chip, 20.0);
    });

    test('GriRadius.card ES el radio que declara el cardTheme del tema', () {
      final shape = griTheme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final radius = (shape! as RoundedRectangleBorder).borderRadius
          as BorderRadius;
      expect(radius.topLeft.x, GriRadius.card);
      expect(radius, GriRadius.cardBorder);
    });

  });

  // ── Breakpoints ──────────────────────────────────────────────────────────
  group('GriBreakpoints — anchos VIGENTES, no los de Material 3', () {
    test('compact=750 y expanded=1100', () {
      // NO son los 600/840/1200 de M3 a propósito: el panel YA colapsa el
      // sidebar en 750 y salta a 4 columnas en 1100. Moverlos sería un
      // cambio VISUAL, prohibido por la decisión bloqueada de la fase.
      expect(GriBreakpoints.compact, 750.0);
      expect(GriBreakpoints.expanded, 1100.0);
    });

    test('los anchos del AppShell y del dashboard SON los del token', () {
      // Gate de paridad token↔código (patrón de 11-17). Recoge TODOS los
      // literales de `constraints.maxWidth <|>= N` de las 3 pantallas que
      // hoy deciden layout por ancho y exige que el conjunto sea exactamente
      // {compact, expanded}.
      final fuentes = [
        'lib/features/shared/app_shell.dart',
        'lib/features/dashboard/dashboard_screen.dart',
        'lib/features/mesas/mesas_screen.dart',
      ];
      final anchos = <double>{};
      for (final ruta in fuentes) {
        anchos.addAll(RegExp(r'maxWidth\s*(?:<|>=|<=|>)\s*([0-9.]+)')
            .allMatches(_leer(ruta))
            .map((m) => double.parse(m.group(1)!)));
      }
      expect(anchos, isNotEmpty,
          reason: 'ninguna de las 3 pantallas compara ya contra maxWidth: el '
              'gate quedó ciego y hay que reescribirlo, no borrarlo');
      expect(anchos, {GriBreakpoints.compact, GriBreakpoints.expanded},
          reason: 'el código usa $anchos; los tokens dicen '
              '{${GriBreakpoints.compact}, ${GriBreakpoints.expanded}}');
    });
  });

  // ── Escala tipográfica (constantes) ──────────────────────────────────────
  group('GriText — la escala real del panel', () {
    test('cada estilo es EXACTAMENTE el TextStyle inline que sustituye', () {
      // OJO: NO coincide con el de app_cliente en `cuerpoCompacto` (13 aquí,
      // 14 allá) ni en `boton` (16 aquí, 15 allá). Son mockups distintos y la
      // divergencia es deliberada — está declarada en la cabecera del
      // design_tokens.dart de las dos apps.
      expect(GriText.tituloPantalla,
          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
      expect(GriText.tituloSeccion,
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
      expect(GriText.tituloCard,
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
      expect(GriText.boton,
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
      expect(GriText.cuerpo, const TextStyle(fontSize: 14));
      expect(GriText.cuerpoCompacto, const TextStyle(fontSize: 13));
      expect(GriText.auxiliar, const TextStyle(fontSize: 12));
      expect(GriText.chip,
          const TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
    });

    test('ningún estilo fija color: el color lo pone quien lo usa', () {
      for (final s in GriText.escala.entries) {
        expect(s.value.color, isNull, reason: '${s.key} fija color');
        expect(s.value.inherit, isTrue,
            reason: '${s.key} con inherit:false dejaría de fusionarse con el '
                'DefaultTextStyle y cambiaría el render al migrar');
      }
    });
  });
}
