@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/design_tokens.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/dashboard/dashboard_screen.dart';
import 'package:gri_panel_admin/features/dashboard/widgets/mesa_tile.dart';
import 'package:gri_panel_admin/features/dashboard/widgets/stat_card.dart';
import 'package:gri_panel_admin/features/shared/responsive_page.dart';

import '../helpers/firebase_fakes.dart';

/// Responsive del panel (11-21, Tarea 2).
///
/// ── QUÉ SE AFIRMA AQUÍ ────────────────────────────────────────────────────
/// 1. TODAS las pantallas del árbol adaptan — contadas del disco, no de una
///    constante escrita a mano (una versión anterior del plan comparaba contra
///    `>= 9` cuando el panel ya tenía 10 pantallas: habría pasado en verde con
///    una rota).
/// 2. A 1920 ninguna pantalla estira su contenido más allá de su techo.
/// 3. A 900 el contenido ocupa TODO el ancho disponible (el techo no recorta
///    de más).
/// 4. Ninguna ruta produce un desborde de RenderFlex a ninguno de los dos
///    anchos.
/// 5. El grid de mesas, ahora fluido, da EXACTAMENTE las mismas columnas que
///    la regla histórica 4/3/2 en los anchos en los que el panel se usa.
/// 6. El alto declarado de la stat card sigue siendo suficiente para su
///    contenido real.
///
/// Las rutas se visitan sobre `GriApp` (router y shell REALES). Pumpear cada
/// pantalla suelta mediría el ancho de la ventana, no el del contenido — que
/// es justo el error que `ResponsivePage` existe para evitar.
void main() {
  // ── 1. Cobertura contada del árbol ──────────────────────────────────────

  test('todas las pantallas de lib/features adaptan (contadas del disco)', () {
    final dir = Directory('lib/features');
    expect(dir.existsSync(), isTrue,
        reason: 'ejecutar desde la raíz de panel_admin');

    final pantallas = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.replaceAll(r'\', '/').endsWith('_screen.dart'))
        .toList();

    final sinAdaptar = <String>[
      for (final f in pantallas)
        if (!f.readAsStringSync().contains('LayoutBuilder') &&
            !f.readAsStringSync().contains('ResponsivePage'))
          f.path,
    ];

    expect(pantallas.length, greaterThanOrEqualTo(12),
        reason: 'si el árbol encoge, revisar que no se haya movido nada');
    expect(sinAdaptar, isEmpty,
        reason: 'estas pantallas no adaptan:\n  ${sinAdaptar.join("\n  ")}');
  });

  // ── Montaje común ───────────────────────────────────────────────────────

  late List<String> desbordes;

  /// Monta `GriApp` con sesión de `admin_restaurante` y navega a [ruta].
  /// Devuelve el container por si el caso necesita navegar otra vez.
  Future<ProviderContainer> montar(
    WidgetTester tester,
    Size tamano, {
    String ruta = '/',
    bool conSesion = true,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    desbordes = <String>[];
    final onErrorPrevio = FlutterError.onError;
    // OVERFLOW-DETECTOR: se recogen para AFIRMAR que la lista queda vacía; no
    // es un filtro. Ver test/shared/sin_filtros_overflow_test.dart.
    FlutterError.onError = (details) {
      final txt = details.exceptionAsString();
      if (txt.contains('A RenderFlex overflowed')) {
        desbordes.add('$ruta: ${txt.split('\n').first}');
        return;
      }
      onErrorPrevio?.call(details);
    };

    final ctrl = StreamController<User?>.broadcast();
    final db = await buildFakeFirestoreConSeed();
    // 8 mesas: con las 3 del seed no se distingue un grid de 4 columnas de uno
    // de 5, así que el caso de columnas sería verde por falta de datos.
    for (var i = 4; i <= 8; i++) {
      await db.doc('mesas/GRI-MESA-demo-00$i').set({
        'restauranteId': 'demo',
        'numero': i,
        'capacidad': 4,
        'estado': 'disponible',
      });
    }
    final container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => ctrl.stream),
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: true)),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ]);
    addTearDown(() {
      container.dispose();
      ctrl.close();
    });

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const GriApp()),
      );
      if (conSesion) {
        ctrl.add(MockUser(uid: 'u-admin', email: 'admin@demo.gri.dev'));
      }
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      if (ruta != '/') {
        container.read(goRouterProvider).go(ruta);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }
    } finally {
      FlutterError.onError = onErrorPrevio;
    }
    return container;
  }

  /// (ancho de la caja, ancho del contenido, techo declarado) de cada
  /// [ResponsivePage] montada.
  List<(double, double, double)> medir(WidgetTester tester) {
    final paginas = find.byType(ResponsivePage);
    final n = tester.widgetList(paginas).length;
    return <(double, double, double)>[
      for (var i = 0; i < n; i++)
        (
          tester.getSize(paginas.at(i)).width,
          tester
              .getSize(find
                  .descendant(
                    of: paginas.at(i),
                    matching: find.byType(ConstrainedBox),
                  )
                  .first)
              .width,
          (tester.widget(paginas.at(i)) as ResponsivePage).maxWidth,
        ),
    ];
  }

  /// Ruta → un texto que SOLO aparece en esa pantalla.
  ///
  /// Sin esto, un `go(ruta)` que fallara en silencio dejaría todos los casos
  /// midiendo el dashboard y todos en verde: el modo de fallo clásico de un
  /// test parametrizado por ruta.
  const rutasDeTrabajo = <String, String>{
    '/': 'Estado de las mesas',
    '/mesas': 'Crea, edita y gestiona los códigos QR de tus mesas',
    '/cocina': 'Cola de pedidos activos (en vivo)',
    '/reservas': 'En vivo — al llegar el cliente marca la mesa ocupada',
    '/clientes': 'Clientes del restaurante',
    '/reportes': 'Sin rango: se consultan los últimos 7 días',
    '/equipo': 'Equipo del restaurante',
    '/configuracion': 'Categorías y productos',
  };

  // ── 2 y 4. A 1920 nada se estira ni desborda ────────────────────────────

  rutasDeTrabajo.forEach((ruta, marcador) {
    testWidgets('a 1920x1080 $ruta acota su contenido y no desborda',
        (tester) async {
      await montar(tester, const Size(1920, 1080), ruta: ruta);

      expect(find.text(marcador), findsWidgets,
          reason: 'no se llegó a $ruta: falta «$marcador»');

      expect(desbordes, isEmpty,
          reason: 'desbordes en $ruta a 1920:\n  ${desbordes.join("\n  ")}');

      final medidas = medir(tester);
      expect(medidas, isNotEmpty, reason: '$ruta no monta ninguna '
          'ResponsivePage — ¿se navegó de verdad a esa ruta?');
      for (final (caja, contenido, techo) in medidas) {
        // El contrato entero en una línea: el contenido es lo disponible o el
        // techo, lo que sea menor. Nunca más, nunca menos.
        expect(contenido, caja < techo ? caja : techo,
            reason: '$ruta: caja $caja, techo $techo, contenido $contenido');
        expect(contenido, lessThanOrEqualTo(ResponsivePage.anchoMaxContenido),
            reason: '$ruta: el contenido se estira más de 1200');
      }
      // Y a 1920 el techo TIENE que estar mordiendo en alguna: si no, este
      // caso estaría verde sin haber ejercitado el recorte. (En
      // /configuracion hay dos ResponsivePage anidadas —el tab y el menú de
      // dentro—: la de dentro ya recibe una caja de 1200 y no muerde.)
      expect(medidas.any((m) => m.$1 > m.$3), isTrue,
          reason: '$ruta: a 1920 ninguna página llegó a recortar');
    });
  });

  // ── 3. A 900 el contenido ocupa lo disponible ───────────────────────────

  rutasDeTrabajo.forEach((ruta, marcador) {
    testWidgets('a 900x900 $ruta ocupa el ancho disponible y no desborda',
        (tester) async {
      await montar(tester, const Size(900, 900), ruta: ruta);

      expect(find.text(marcador), findsWidgets,
          reason: 'no se llegó a $ruta: falta «$marcador»');

      expect(desbordes, isEmpty,
          reason: 'desbordes en $ruta a 900:\n  ${desbordes.join("\n  ")}');

      final medidas = medir(tester);
      expect(medidas, isNotEmpty);
      for (final (caja, contenido, techo) in medidas) {
        expect(caja, lessThan(techo),
            reason: '$ruta: a 900 el techo no debería morder');
        expect(contenido, caja,
            reason: '$ruta: a 900 el contenido debe llenar la caja');
      }
    });
  });

  // ── Pantallas de tarjeta única ──────────────────────────────────────────

  testWidgets('login a 1920: la tarjeta sigue midiendo 400 exactos',
      (tester) async {
    await montar(tester, const Size(1920, 1080),
        ruta: '/login', conSesion: false);

    expect(desbordes, isEmpty, reason: desbordes.join(' | '));
    final medidas = medir(tester);
    expect(medidas.length, 1);
    expect(medidas.single.$2, ResponsivePage.anchoMaxFormularioConPadding);
    // La tarjeta = techo − 24 de padding a cada lado; el Form vive dentro del
    // Container de padding 32, así que 400 − 64.
    expect(tester.getSize(find.byType(Form)).width, 400 - 64);
  });

  testWidgets('bootstrap a 1920: la tarjeta sigue midiendo 400 exactos',
      (tester) async {
    await montar(tester, const Size(1920, 1080),
        ruta: '/bootstrap', conSesion: false);

    expect(desbordes, isEmpty, reason: desbordes.join(' | '));
    expect(medir(tester).single.$2,
        ResponsivePage.anchoMaxFormularioConPadding);
    expect(tester.getSize(find.byType(Form)).width, 400 - 64);
  });

  testWidgets('404 a 1920: el texto deja de estirarse a lo ancho del panel',
      (tester) async {
    await montar(tester, const Size(1920, 1080), ruta: '/no-existe-esta-ruta');

    expect(desbordes, isEmpty, reason: desbordes.join(' | '));
    expect(find.text('Página no encontrada'), findsOneWidget);
    final medidas = medir(tester);
    expect(medidas, isNotEmpty);
    expect(medidas.last.$2, ResponsivePage.anchoMaxFormularioConPadding);
  });

  // ── 5. El grid de mesas da las columnas de siempre ──────────────────────

  /// La regla que regía ANTES de 11-21, escrita tal cual estaba en
  /// `dashboard_screen.dart` y `mesas_screen.dart`. Es la referencia contra la
  /// que se compara el grid fluido; si alguien la cambia aquí, el caso deja de
  /// probar lo que dice.
  int columnasHistoricas(double ancho) => ancho >= GriBreakpoints.expanded
      ? 4
      : (ancho >= GriBreakpoints.compact ? 3 : 2);

  for (final ventana in const <double>[950, 1050, 1280, 1440, 1920]) {
    testWidgets(
        'el grid de mesas a ${ventana.toInt()}px da las columnas de siempre',
        (tester) async {
      await montar(tester, Size(ventana, 1400), ruta: '/mesas');

      final tiles = find.byType(MesaTile);
      expect(tiles, findsNWidgets(8));
      final xs = <double>{
        for (var i = 0; i < 8; i++) tester.getTopLeft(tiles.at(i)).dx,
      };

      // Ancho REAL del contenido = lo que ve el LayoutBuilder de la pantalla,
      // que es la ventana menos el sidebar y, por encima de 1200, el techo.
      final anchoContenido = medir(tester).first.$1;
      final esperadas = columnasHistoricas(
        anchoContenido.clamp(0, ResponsivePage.anchoMaxContenido),
      );
      expect(xs.length, esperadas,
          reason: 'ventana $ventana ⇒ contenido $anchoContenido ⇒ '
              'se esperaban $esperadas columnas');
    });
  }

  // ── 6. El alto declarado de la stat card basta ──────────────────────────

  testWidgets('alturaStatCard sigue siendo suficiente para el contenido real',
      (tester) async {
    // Alto NATURAL de una card al ancho más estrecho en el que puede tocarle
    // ir a 4 columnas: contenido 1100 − 60 de padding − 60 de spacing, /4.
    const anchoMasEstrecho = (GriBreakpoints.expanded - 60 - 60) / 4;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: anchoMasEstrecho,
                child: StatCard(
                  label: 'Mesas disponibles',
                  value: 12,
                  iconBg: Color(0xFFEEEEEE),
                  iconFg: Color(0xFF000000),
                  emoji: 'X',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final natural = tester.getSize(find.byType(StatCard)).height;
    expect(
      alturaStatCard,
      greaterThanOrEqualTo(natural),
      reason: 'la card necesita ${natural}px y el grid le da $alturaStatCard: '
          'volvería a recortarse',
    );
  });

  // ── 7. Anchos estrechos: el panel también se abre en media pantalla ─────
  //
  // 600px de ventana = 530 de contenido con el sidebar colapsado. Medido
  // ANTES del arreglo: la cabecera de /cocina desbordaba 150px a 450, 100 a
  // 500, 50 a 550 y 0.25 a 600 — el subtítulo pedía su ancho intrínseco.
  rutasDeTrabajo.forEach((ruta, marcador) {
    testWidgets('a 600x900 $ruta no desborda', (tester) async {
      await montar(tester, const Size(600, 900), ruta: ruta);
      expect(find.text(marcador), findsWidgets,
          reason: 'no se llegó a $ruta');
      expect(desbordes, isEmpty,
          reason: 'desbordes en $ruta a 600: ${desbordes.join(" | ")}');
    });
  });
}
