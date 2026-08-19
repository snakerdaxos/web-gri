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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/design_tokens.dart';
import 'package:gri_cliente/core/theme.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';

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

    test('el AppShell no reintroduce un ancho literal (paridad token↔código)',
        () {
      // Gate de paridad token↔código (patrón de 11-17,
      // firebase_options_coherencia_test.dart). El token no vale nada si el
      // shell sigue con su literal por su cuenta.
      //
      // REESCRITO EN 11-13, tal y como su versión anterior pedía que se
      // hiciera ("si el shell dejó de acotar el contenido, este gate quedó
      // ciego y hay que reescribirlo, no borrarlo"). Hasta 11-13 el shell
      // tenía UN literal (`BoxConstraints(maxWidth: 480)`) y el gate lo
      // comparaba con el token. Ahora el ancho se CALCULA en un LayoutBuilder,
      // así que ya no hay literal que comparar: lo que se afirma aquí es que
      // no ha vuelto ninguno y que los dos tokens se usan de verdad.
      //
      // El gate que mide el ancho EFECTIVO (360 → libre, 600 → contenidoMax,
      // 1200 → contenidoMaxAmplio) es `test/shared/app_shell_responsive_test
      // .dart`, y es estrictamente más fuerte que este: renderiza y mide en
      // vez de leer el fuente.
      final src = _leer('lib/features/shared/app_shell.dart');

      final literales = RegExp(r'BoxConstraints\(maxWidth:\s*([0-9.]+)')
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toList();
      expect(literales, isEmpty,
          reason: 'el AppShell volvió a acotar el contenido con el literal '
              '$literales en vez de con GriBreakpoints');

      for (final token in const [
        'GriBreakpoints.contenidoMax',
        'GriBreakpoints.contenidoMaxAmplio',
        'GriBreakpoints.expanded',
      ]) {
        expect(src, contains(token),
            reason: 'el AppShell ya no menciona $token: o dejó de acotar el '
                'contenido, o volvió a decidir el ancho por su cuenta');
      }
    });

    test('contenidoMaxAmplio ensancha de verdad y no se pasa de expanded', () {
      // 11-13. Las dos aserciones son la definición del token:
      //  · si alguien lo iguala a contenidoMax, el arreglo del ancho fijo
      //    desaparece sin que nada más se ponga rojo;
      //  · si alguien lo sube por encima de `expanded`, a 840px el techo sería
      //    más ancho que el propio viewport y no acotaría nada.
      expect(GriBreakpoints.contenidoMaxAmplio, 720.0);
      expect(GriBreakpoints.contenidoMaxAmplio,
          greaterThan(GriBreakpoints.contenidoMax));
      expect(GriBreakpoints.contenidoMaxAmplio,
          lessThanOrEqualTo(GriBreakpoints.expanded));
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

  // ── Escala tipográfica en el TEMA ────────────────────────────────────────
  group('griTheme.textTheme — escala declarada, no heredada', () {
    test('los 15 slots están declarados con los valores MEDIDOS de M3', () {
      // Ver `escalaEsperada` al final del archivo: por qué NO lleva los
      // 24-bold/18-bold de GRI. Esos viven en GriText (design_tokens.dart),
      // porque estos slots los consume el chrome de Material y moverlos
      // sería un cambio visual.
      final slots = _slots(griTheme.textTheme);
      for (final e in escalaEsperada.entries) {
        final s = slots[e.key];
        expect(s, isNotNull, reason: '${e.key} sin declarar');
        expect(s!.fontSize, e.value.$1, reason: '${e.key} fontSize');
        expect(s.fontWeight, e.value.$2, reason: '${e.key} fontWeight');
      }
    });

    test('la escala no fija color: lo pone el ColorScheme', () {
      // Si un slot trajera color, el texto dejaría de reaccionar al
      // foregroundColor del AppBar o al color del ListTile.
      expect(griTextTheme.bodyMedium!.color, isNull);
      expect(griTextTheme.titleLarge!.color, isNull);
    });

    testWidgets('el chrome de Material NO cambia de tamaño ni de peso',
        (tester) async {
      // ESTE es el gate de la decisión BLOQUEADA de identidad visual.
      // Los números de abajo se MIDIERON con una sonda contra el griTheme
      // ANTERIOR a 11-11 (sin textTheme). Si declarar la escala moviera el
      // título de los 8 AppBar, el título/subtítulo de los ListTile o la
      // etiqueta de los botones, esto se pone rojo.
      await tester.pumpWidget(MaterialApp(
        theme: griTheme,
        home: Scaffold(
          appBar: AppBar(title: const Text('TituloAppBar')),
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
        'TituloAppBar': (22, FontWeight.w400), // titleLarge
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
  });

  // ── Colores semánticos ───────────────────────────────────────────────────
  group('GriSemanticColors — una sola paleta de estado', () {
    test('griTheme REGISTRA la extensión (T-11-11-02)', () {
      // Sin `extensions: [...]` en el ThemeData, `extension<T>()` devuelve
      // null en runtime.
      expect(griTheme.extension<GriSemanticColors>(), isNotNull);
      expect(griTheme.extension<GriSemanticColors>(), GriSemanticColors.gri);
    });

    test('los colores de estado de pedido son los MISMOS hex de antes', () {
      // T-11-11-01. Estos son literalmente los valores que tenía
      // `models/pedido.dart:78-95` antes de 11-11. Está PROHIBIDO
      // "aprovechar y ajustar" un color en esta migración.
      const c = GriSemanticColors.gri;
      expect(c.pedidoFg('enviado'), const Color(0xFF2563EB));
      expect(c.pedidoFg('aceptado'), const Color(0xFFD97706));
      expect(c.pedidoFg('en_preparacion'), const Color(0xFF7C3AED));
      expect(c.pedidoFg('servido'), const Color(0xFF168A52));
      expect(c.pedidoFg('rechazado'), const Color(0xFFC83C2E));
      expect(c.pedidoFg('lo-que-sea'), const Color(0xFF777777));

      expect(c.pedidoBg('enviado'), const Color(0xFFE3ECFD));
      expect(c.pedidoBg('aceptado'), const Color(0xFFFCF0DE));
      expect(c.pedidoBg('en_preparacion'), const Color(0xFFEFE6FC));
      expect(c.pedidoBg('servido'), const Color(0xFFDFF7EB));
      expect(c.pedidoBg('rechazado'), const Color(0xFFFFE9E6));
      expect(c.pedidoBg('lo-que-sea'), const Color(0xFFEEEEEE));
    });

    test('los colores de chip de reserva son los MISMOS de GriColors', () {
      // La extensión NO inventa una tercera paleta: reproduce exactamente
      // lo que ya devuelve `GriColors.estadoChipBg/Fg`.
      const c = GriSemanticColors.gri;
      for (final estado in ['confirmada', 'cancelada', 'pendiente']) {
        expect(c.reservaBg(estado), GriColors.estadoChipBg(estado),
            reason: 'bg de $estado');
        expect(c.reservaFg(estado), GriColors.estadoChipFg(estado),
            reason: 'fg de $estado');
      }
    });

    test('GriColors.gray sigue siendo #777777 — token de MARCA', () {
      // Guarda 1 de 2 del acuerdo de accesibilidad de la fase: el arreglo de
      // contraste de 11-14 NO puede hacerse cambiando el token de marca.
      expect(GriColors.gray, const Color(0xFF777777));
    });

    test('textoSecundarioAccesible es OTRO token, y hoy no está aplicado', () {
      // Guarda 2 de 2. Existe para que 11-14 lo aplique a los roles de texto
      // pequeño; declararlo aquí no cambia ningún píxel hoy.
      expect(GriSemanticColors.gri.textoSecundarioAccesible,
          const Color(0xFF6E6E6E));
      expect(GriSemanticColors.gri.textoSecundarioAccesible,
          isNot(GriColors.gray));
    });

    test('of() cae a la instancia canónica si el tema no la registra', () {
      // Suites como test/pedidos/estado_test.dart pumpean un MaterialApp SIN
      // theme. El fallback evita que el chip se quede sin color ahí, y el
      // test "griTheme REGISTRA la extensión" es el que impide que el
      // fallback tape un olvido en el ThemeData real.
      expect(GriSemanticColors.gri.pedidoFg('enviado'),
          const Color(0xFF2563EB));
    });

    test('copyWith respeta los campos no indicados', () {
      const base = GriSemanticColors.gri;
      final otro = base.copyWith(pedidoEnviadoFg: const Color(0xFF000000));
      expect(otro.pedidoEnviadoFg, const Color(0xFF000000));
      expect(otro.pedidoAceptadoFg, base.pedidoAceptadoFg);
      expect(otro.pedidoServidoBg, base.pedidoServidoBg);
      expect(otro.textoSecundarioAccesible, base.textoSecundarioAccesible);
      expect(base.copyWith(), base);
    });

    test('lerp devuelve valores intermedios', () {
      const a = GriSemanticColors.gri;
      final b = a.copyWith(
        pedidoEnviadoFg: const Color(0xFF000000),
        pedidoServidoBg: const Color(0xFFFFFFFF),
      );
      final medio = a.lerp(b, 0.5);
      expect(medio.pedidoEnviadoFg,
          Color.lerp(a.pedidoEnviadoFg, b.pedidoEnviadoFg, 0.5));
      expect(medio.pedidoEnviadoFg, isNot(a.pedidoEnviadoFg));
      expect(medio.pedidoEnviadoFg, isNot(b.pedidoEnviadoFg));
      // t=0 y t=1 son los extremos exactos.
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      // lerp contra otro tipo de extensión devuelve `this` (contrato de
      // ThemeExtension).
      expect(a.lerp(null, 0.5), a);
    });
  });

  // ── El chip de pedido LEE del tema, no de una segunda paleta ─────────────
  group('PedidoEstadoX — cableado real al ThemeExtension', () {
    testWidgets('el chip toma el color de la extensión REGISTRADA en el tema',
        (tester) async {
      // Con dientes: el tema lleva una extensión ADULTERADA. Si
      // `estadoColor` siguiera devolviendo su propio literal, el chip
      // pintaría #2563EB y este test caería. Es la prueba de que la segunda
      // paleta de models/pedido.dart ya no existe.
      const marcador = Color(0xFF00FF00);
      const marcadorBg = Color(0xFF00AA00);
      await tester.pumpWidget(MaterialApp(
        theme: griTheme.copyWith(extensions: <ThemeExtension<dynamic>>[
          GriSemanticColors.gri.copyWith(
            pedidoEnviadoFg: marcador,
            pedidoEnviadoBg: marcadorBg,
          ),
        ]),
        home: Builder(builder: (context) {
          return Column(children: [
            Container(color: _pedidoFalso.estadoBg(context), height: 4),
            Text('X',
                style: TextStyle(color: _pedidoFalso.estadoColor(context))),
          ]);
        }),
      ));
      await tester.pump();
      final txt = tester.renderObject<RenderParagraph>(find.text('X'));
      expect(txt.text.style?.color, marcador);
      final cont = tester.widget<Container>(find.byType(Container));
      expect(cont.color, marcadorBg);
    });
  });


}

// ═════════════════════════════════════════════════════════════════════════
// Tarea 2 — escala tipográfica en el tema y colores semánticos unificados
// ═════════════════════════════════════════════════════════════════════════

/// Los valores que Material 3 resuelve HOY para cada slot, MEDIDOS con una
/// sonda contra `griTheme` antes de tocar nada (11-11). `griTheme` los declara
/// ahora explícitamente para que dejen de ser un default implícito del
/// framework: una actualización de Flutter que cambie la tipografía de M3 ya
/// no puede reflotar la app en silencio.
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

/// Pedido mínimo en estado `enviado` — solo para comprobar de dónde saca el
/// color el chip.
const Pedido _pedidoFalso = Pedido(
  id: 'p1',
  restauranteId: 'demo',
  mesaId: 'GRI-MESA-demo-001',
  sesionId: 'GRI-MESA-demo-001',
  usuarioId: 'u1',
  estado: 'enviado',
  total: 1000,
  items: <PedidoItem>[],
);
