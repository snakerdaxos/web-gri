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
import 'package:flutter/rendering.dart';
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

    test('las pantallas de layout usan los TOKENS, no literales sueltos', () {
      // ── REESCRITO EN 11-21, tal y como pedía su propio mensaje de fallo ───
      // La versión de 11-11 recogía los literales de `maxWidth <|>= N` de las
      // 3 pantallas de layout y exigía que el conjunto fuese {750, 1100}. Ese
      // gate protegía contra que alguien tocara el número en la pantalla sin
      // tocar el token. En 11-21 las tres comparaciones pasaron a leer
      // `GriBreakpoints.compact` / `.expanded` directamente, así que ya NO
      // QUEDA ningún literal que comparar: el modo de fallo que vigilaba dejó
      // de existir por construcción, y el gate, tal cual, se ponía rojo por
      // haber DESAPARECIDO su objeto.
      //
      // Lo que se vigila ahora es lo que sí puede volver a pasar: que alguien
      // reintroduzca un número suelto, o que las pantallas dejen de mirar el
      // token.
      final fuentes = [
        'lib/features/shared/app_shell.dart',
        'lib/features/dashboard/dashboard_screen.dart',
        'lib/features/mesas/mesas_screen.dart',
      ];
      final literales = <String>[];
      var referenciasAToken = 0;
      for (final ruta in fuentes) {
        final src = _leer(ruta);
        literales.addAll(
          RegExp(r'maxWidth\s*(?:<|>=|<=|>)\s*([0-9][0-9.]*)')
              .allMatches(src)
              .map((m) => '$ruta: ${m.group(0)}'),
        );
        // Ojo: `ancho >= GriBreakpoints.x` también cuenta — desde 11-21 el
        // dashboard mira el ancho que le pasa ResponsivePage, no `maxWidth`.
        referenciasAToken +=
            RegExp(r'GriBreakpoints\.(compact|expanded)').allMatches(src).length;
      }
      expect(literales, isEmpty,
          reason: 'un ancho de layout escrito a mano vuelve a poder divergir '
              'del token: ${literales.join(", ")}');
      expect(referenciasAToken, greaterThanOrEqualTo(3),
          reason: 'las pantallas de layout han dejado de mirar '
              'GriBreakpoints: el gate se quedó ciego, hay que reescribirlo, '
              'no borrarlo (referencias encontradas: $referenciasAToken)');
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

  // ── Escala tipográfica en el TEMA ────────────────────────────────────────
  group('griTheme.textTheme — escala declarada, no heredada', () {
    test('los 15 slots están declarados con los valores MEDIDOS de M3', () {
      final slots = _slots(griTheme.textTheme);
      for (final e in escalaEsperada.entries) {
        final s = slots[e.key];
        expect(s, isNotNull, reason: '${e.key} sin declarar');
        expect(s!.fontSize, e.value.$1, reason: '${e.key} fontSize');
        expect(s.fontWeight, e.value.$2, reason: '${e.key} fontWeight');
      }
    });

    test('la escala no fija color: lo pone el ColorScheme', () {
      expect(griTextTheme.bodyMedium!.color, isNull);
      expect(griTextTheme.headlineSmall!.color, isNull);
    });

    testWidgets('el chrome de Material NO cambia de tamaño ni de peso',
        (tester) async {
      // Gate de la decisión BLOQUEADA de identidad visual. Los números se
      // MIDIERON con una sonda contra el griTheme ANTERIOR a 11-11.
      await tester.pumpWidget(MaterialApp(
        theme: griTheme,
        home: Scaffold(
          body: Column(children: [
            const ListTile(
                title: Text('TituloTile'), subtitle: Text('SubTile')),
            ElevatedButton(onPressed: () {}, child: const Text('BotonElev')),
            TextButton(onPressed: () {}, child: const Text('BotonTexto')),
            const Text('TextoPlano'),
          ]),
        ),
      ));
      await tester.pump();

      const medidoAntesDe1111 = <String, (double, FontWeight)>{
        'TituloTile': (16, FontWeight.w400), // bodyLarge
        'SubTile': (14, FontWeight.w400), // bodyMedium
        'BotonElev': (14, FontWeight.w500), // labelLarge
        'BotonTexto': (14, FontWeight.w500), // labelLarge
        'TextoPlano': (14, FontWeight.w400), // bodyMedium
      };
      for (final e in medidoAntesDe1111.entries) {
        final p = tester.renderObject<RenderParagraph>(find.text(e.key));
        expect(p.text.style?.fontSize, e.value.$1, reason: '${e.key} tamaño');
        expect(p.text.style?.fontWeight, e.value.$2, reason: '${e.key} peso');
      }
    });

    testWidgets('los 8 AlertDialog del panel siguen igual', (tester) async {
      // El título de un AlertDialog sale de `headlineSmall` y el contenido de
      // `bodyMedium`: son dos de los slots que este plan declara.
      await tester.pumpWidget(MaterialApp(
        theme: griTheme,
        home: Builder(
          builder: (c) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => const AlertDialog(
                title: Text('TituloDialogo'),
                content: Text('ContenidoDialogo'),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final t = tester.renderObject<RenderParagraph>(find.text('TituloDialogo'));
      expect(t.text.style?.fontSize, 24.0);
      expect(t.text.style?.fontWeight, FontWeight.w400);
      final c =
          tester.renderObject<RenderParagraph>(find.text('ContenidoDialogo'));
      expect(c.text.style?.fontSize, 14.0);
      expect(c.text.style?.fontWeight, FontWeight.w400);
    });
  });

  // ── Colores semánticos ───────────────────────────────────────────────────
  group('GriSemanticColors — una sola paleta de estado', () {
    test('griTheme REGISTRA la extensión (T-11-11-02)', () {
      expect(griTheme.extension<GriSemanticColors>(), isNotNull);
      expect(griTheme.extension<GriSemanticColors>(), GriSemanticColors.gri);
    });

    test('los colores de estado de pedido son los MISMOS de pedido_staff', () {
      // T-11-11-01. Son los hex que hoy devuelve
      // `PedidoEstadoX.color` en `models/pedido_staff.dart:180-187`.
      //
      // OJO — HALLAZGO de 11-11: el panel y la app cliente pintan el MISMO
      // estado con colores DISTINTOS (enviado #3478F6 aquí vs #2563EB allá;
      // aceptado #FF4C05 vs #D97706; en_preparacion #8E44AD vs #7C3AED…).
      // Unificarlos cambiaría píxeles en una de las dos apps y está fuera de
      // este plan; queda declarado aquí para que la divergencia sea visible.
      const c = GriSemanticColors.gri;
      expect(c.pedidoEnviado, const Color(0xFF3478F6));
      expect(c.pedidoAceptado, const Color(0xFFFF4C05));
      expect(c.pedidoEnPreparacion, const Color(0xFF8E44AD));
      expect(c.pedidoServido, const Color(0xFF20B26B));
      expect(c.pedidoRechazado, const Color(0xFFE74C3C));
      expect(c.pedidoPagado, const Color(0xFF20B26B));
    });

    test('los colores de chip de reserva son los MISMOS de la paleta de mesas',
        () {
      const c = GriSemanticColors.gri;
      expect(c.reservaBg('confirmada'), GriColors.mesaDisponibleBg);
      expect(c.reservaFg('confirmada'), GriColors.mesaDisponibleFg);
      expect(c.reservaBg('cancelada'), GriColors.mesaOcupadaBg);
      expect(c.reservaFg('cancelada'), GriColors.mesaOcupadaFg);
      expect(c.reservaBg('pendiente'), GriColors.mesaReservadaBg);
      expect(c.reservaFg('pendiente'), GriColors.mesaReservadaFg);
    });

    test('GriColors.gray sigue siendo #777777 — token de MARCA', () {
      // Guarda 1 de 2: el arreglo de contraste de 11-14 NO puede hacerse
      // cambiando el token de marca.
      expect(GriColors.gray, const Color(0xFF777777));
    });

    test('textoSecundarioAccesible es OTRO token, y hoy no está aplicado', () {
      // Guarda 2 de 2.
      expect(GriSemanticColors.gri.textoSecundarioAccesible,
          const Color(0xFF6E6E6E));
      expect(GriSemanticColors.gri.textoSecundarioAccesible,
          isNot(GriColors.gray));
    });

    test('copyWith respeta los campos no indicados', () {
      const base = GriSemanticColors.gri;
      final otro = base.copyWith(pedidoEnviado: const Color(0xFF000000));
      expect(otro.pedidoEnviado, const Color(0xFF000000));
      expect(otro.pedidoAceptado, base.pedidoAceptado);
      expect(otro.reservaConfirmadaBg, base.reservaConfirmadaBg);
      expect(otro.textoSecundarioAccesible, base.textoSecundarioAccesible);
      expect(base.copyWith(), base);
    });

    test('lerp devuelve valores intermedios', () {
      const a = GriSemanticColors.gri;
      final b = a.copyWith(
        pedidoEnviado: const Color(0xFF000000),
        reservaConfirmadaBg: const Color(0xFFFFFFFF),
      );
      final medio = a.lerp(b, 0.5);
      expect(medio.pedidoEnviado,
          Color.lerp(a.pedidoEnviado, b.pedidoEnviado, 0.5));
      expect(medio.pedidoEnviado, isNot(a.pedidoEnviado));
      expect(medio.pedidoEnviado, isNot(b.pedidoEnviado));
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      expect(a.lerp(null, 0.5), a);
    });
  });

  // ── Estilos centralizados del panel ──────────────────────────────────────
  group('griCardDecoration — la sombra que estaba copiada 7 veces', () {
    test('color, radio y sombra exactos', () {
      // `Color(0x0D000000), blur 12, offset (0,3)` está copiado en
      // stat_card, dashboard ×2, reportes, pedido_card, login y bootstrap.
      // Aquí se declara UNA vez; 11-12 borra las copias.
      expect(griCardDecoration.color, Colors.white);
      expect(griCardDecoration.borderRadius, GriRadius.cardBorder);
      final sombras = griCardDecoration.boxShadow!;
      expect(sombras, hasLength(1));
      expect(sombras.single.color, const Color(0x0D000000));
      expect(sombras.single.blurRadius, 12.0);
      expect(sombras.single.offset, const Offset(0, 3));
    });

    test('0x0D000000 ES lo que produce Colors.black.withValues(alpha: 0.05)',
        () {
      // Las 7 copias venían en DOS formas (`Color(0x0D000000)` en 5 sitios y
      // `Colors.black.withValues(alpha: 0.05)` en login y bootstrap). Este
      // caso demuestra que colapsarlas en una sola no cambia el píxel:
      // 0.05 × 255 = 12.75 → 13 = 0x0D.
      expect(Colors.black.withValues(alpha: 0.05).toARGB32(),
          const Color(0x0D000000).toARGB32());
    });
  });

  group('Temas de botón del panel', () {
    testWidgets('un ElevatedButton SIN style ya toma el naranja de marca',
        (tester) async {
      // CAMBIO VISUAL DELIBERADO Y ACOTADO (ver 11-11-SUMMARY.md):
      // 10 de los 12 ElevatedButton del panel ya declaran inline
      // `backgroundColor: primary, foregroundColor: white`. Los 2 que no
      // (reportes "Consultar" y reservas "Marcar ocupada") renderizaban
      // #FFF1ED sobre #8F4C37 — el derivado del seed, NO la marca. El tema
      // los alinea con los otros 10.
      await tester.pumpWidget(MaterialApp(
        theme: griTheme,
        home: Scaffold(
          body: ElevatedButton(onPressed: () {}, child: const Text('CTA')),
        ),
      ));
      await tester.pump();
      final mat = tester.widget<Material>(find.descendant(
          of: find.byType(ElevatedButton), matching: find.byType(Material)));
      expect(mat.color, GriColors.primary);
      final p = tester.renderObject<RenderParagraph>(find.text('CTA'));
      expect(p.text.style?.color, Colors.white);
    });

    test('griBotonPrimario es el estilo COMPLETO copiado en login/bootstrap',
        () {
      // El par de colores deshabilitados solo lo declaran 4 de los 12
      // sitios, así que NO va en el tema (cambiaría el estado deshabilitado
      // de los botones de cocina). Va aquí, para que 11-12 sustituya las 4
      // copias por una referencia.
      final s = griBotonPrimario;
      expect(s.backgroundColor?.resolve({}), GriColors.primary);
      expect(s.foregroundColor?.resolve({}), Colors.white);
      expect(s.backgroundColor?.resolve({WidgetState.disabled}),
          GriColors.primary.withValues(alpha: 0.4));
      expect(s.foregroundColor?.resolve({WidgetState.disabled}),
          Colors.white70);
    });

    test('griBotonPeligro* reproducen las variantes destructivas inline', () {
      // `.toARGB32()` y no `== Colors.red`: el token es un `Color` plano
      // (ver el doc de `peligro`), y `Color.==` compara el runtimeType. Lo
      // que importa es que pinte el MISMO rojo que hoy.
      expect(griBotonPeligroTexto.foregroundColor?.resolve({})?.toARGB32(),
          Colors.red.toARGB32());
      expect(griBotonPeligroContorno.foregroundColor?.resolve({}),
          GriColors.mesaOcupadaFg);
      expect(griBotonPeligroContorno.side?.resolve({})?.color,
          GriColors.mesaOcupadaDot);
    });

    test('el tema NO registra textButton/outlinedButton/inputDecoration', () {
      // GUARDA DELIBERADA, no un olvido. Motivos, medidos en 11-11:
      //
      //  · textButtonTheme:      0 de 26 TextButton declaran un estilo base;
      //    los 2 que llevan `style` son la variante DESTRUCTIVA (roja). No
      //    hay convención que centralizar, y registrar
      //    `foregroundColor: primary` teñiría 24 botones de diálogo de
      //    #8F4C37 a #FF4C05.
      //  · outlinedButtonTheme:  1 de 4 lleva estilo, y también es la
      //    variante destructiva.
      //  · inputDecorationTheme: 12 de los 16 campos del panel NO declaran
      //    `border`, así que hoy pintan el subrayado por defecto de M3.
      //    Registrar `OutlineInputBorder` les cambiaría la GEOMETRÍA (borde
      //    y contentPadding), y además toca el `suffixIconConstraints` del
      //    que depende el área táctil de 48×48 del ojo de PasswordField
      //    (aviso explícito de 11-06).
      //
      // Quien quiera unificarlos tiene que venir aquí, borrar esta guarda y
      // asumir el cambio visual de forma consciente.
      expect(griTheme.textButtonTheme.style, isNull);
      expect(griTheme.outlinedButtonTheme.style, isNull);
      expect(griTheme.inputDecorationTheme.border, isNull);
      expect(griTheme.inputDecorationTheme.suffixIconConstraints, isNull);
    });

    test('griInputOutline es el InputDecoration copiado en 4 pantallas', () {
      // login, bootstrap ×2 y password_field declaran
      // `border: OutlineInputBorder()`. Se nombra para que 11-12 pueda
      // referenciarlo sin decidir por los otros 12 campos.
      expect(griInputOutline.border, isA<OutlineInputBorder>());
    });
  });


}

/// Los valores que Material 3 resuelve HOY para cada slot, MEDIDOS con una
/// sonda contra `griTheme` antes de tocar nada (11-11). `griTheme` los declara
/// ahora explícitamente para que dejen de ser un default implícito del
/// framework: una actualización de Flutter que cambie la tipografía de M3 ya
/// no puede reflotar el panel en silencio.
///
/// NO llevan los 24-bold / 18-bold de GRI a propósito: estos slots los consume
/// el chrome de Material (`headlineSmall` es el título de los 8 AlertDialog,
/// `labelLarge` la etiqueta de todos los botones, `bodyLarge` el título de los
/// ListTile). La escala propia de GRI vive en `GriText`.
const Map<String, (double, FontWeight)> escalaEsperada = {
  'displayLarge': (57, FontWeight.w400),
  'displayMedium': (45, FontWeight.w400),
  'displaySmall': (36, FontWeight.w400),
  'headlineLarge': (32, FontWeight.w400),
  'headlineMedium': (28, FontWeight.w400),
  'headlineSmall': (24, FontWeight.w400),
  'titleLarge': (22, FontWeight.w400),
  'titleMedium': (16, FontWeight.w500),
  'titleSmall': (14, FontWeight.w500),
  'bodyLarge': (16, FontWeight.w400),
  'bodyMedium': (14, FontWeight.w400),
  'bodySmall': (12, FontWeight.w400),
  'labelLarge': (14, FontWeight.w500),
  'labelMedium': (12, FontWeight.w500),
  'labelSmall': (11, FontWeight.w500),
};

Map<String, TextStyle?> _slots(TextTheme t) => {
      'displayLarge': t.displayLarge,
      'displayMedium': t.displayMedium,
      'displaySmall': t.displaySmall,
      'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };
