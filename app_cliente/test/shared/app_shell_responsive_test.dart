// test/shared/app_shell_responsive_test.dart — red de seguridad del ÚNICO
// cambio estructural del shell de la app cliente (11-13).
//
// POR QUÉ EXISTE. Antes de este plan NINGÚN test montaba `AppShell`: todas las
// suites pumpean pantallas sueltas dentro de `MaterialApp(home: ...)`. Es decir,
// el shell —el widget que decide dónde EMPIEZA y cuánto MIDE todo el contenido
// de la app— no tenía ni una aserción. Este archivo la pone.
//
// QUÉ SE MIDE Y QUÉ NO. Todo lo de aquí es GEOMETRÍA REAL (`getRect`,
// `getTopLeft`), no estructura: no se busca "hay un SafeArea", se comprueba
// "el contenido empieza por debajo del notch". Un widget test prueba geometría;
// NO prueba que la pantalla se vea bien. Eso sigue siendo verificación humana.
//
// POR QUÉ `tester.view.padding` Y NO UN `MediaQuery` ENVOLVENTE (el plan pedía
// lo segundo): `MaterialApp.router` reconstruye el `MediaQuery` a partir de la
// FlutterView (`MediaQuery.fromView`), así que un `MediaQuery` colocado por
// fuera del `MaterialApp` NO llega al shell — el inset se perdería y el test
// pasaría por el motivo equivocado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/design_tokens.dart';
import 'package:gri_cliente/core/gri_icons.dart';
import 'package:gri_cliente/core/theme.dart';
import 'package:gri_cliente/features/shared/app_shell.dart';

/// Sonda que ocupa TODO lo que el shell le conceda. Su `Rect` es, por tanto,
/// el rectángulo efectivo del contenido: origen = dónde empieza, ancho = cuánto
/// le deja el `ConstrainedBox`.
const _kSonda = Key('sonda-contenido');
const _kSondaSafe = Key('sonda-contenido-con-safearea');

/// Último `MediaQueryData` que vio el contenido montado dentro del shell.
/// Lo usa el caso que documenta POR QUÉ el `SafeArea` lleva `bottom: false`.
MediaQueryData? _mqDelContenido;

Widget _sonda([Key key = _kSonda]) => Builder(builder: (ctx) {
      _mqDelContenido = MediaQuery.of(ctx);
      return SizedBox.expand(
          child: ColoredBox(key: key, color: const Color(0xFF000000)));
    });

/// Rama que trae su PROPIO `SafeArea`, como hacen hoy `menu_mesa_screen`,
/// `pedido_estado_screen` y `reserva_wizard_screen`.
Widget _sondaConSafeArea() => SafeArea(child: _sonda(_kSondaSafe));

GoRouter _router() => GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/a', builder: (_, _) => _sonda()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/b', builder: (_, _) => _sondaConSafeArea()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/c', builder: (_, _) => const SizedBox()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/d', builder: (_, _) => const SizedBox()),
            ]),
          ],
        ),
      ],
    );

/// Monta el shell a un ancho y con unos insets de sistema CONCRETOS.
///
/// [padTop] simula la barra de estado / notch y [padBottom] la barra de gestos.
Future<void> _pump(
  WidgetTester tester, {
  required double ancho,
  double alto = 800,
  double padTop = 0,
  double padBottom = 0,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = Size(ancho, alto)
    ..padding = FakeViewPadding(top: padTop, bottom: padBottom)
    ..viewPadding = FakeViewPadding(top: padTop, bottom: padBottom);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
  await tester.pumpAndSettle();
}

void main() {
  // ── Ancho adaptativo ──────────────────────────────────────────────────────
  group('AppShell — ancho del contenido según el viewport', () {
    testWidgets('360px (móvil real): el contenido ocupa TODO el ancho',
        (tester) async {
      await _pump(tester, ancho: 360);
      expect(tester.getSize(find.byKey(_kSonda)).width, 360.0,
          reason: 'a 360px no puede haber columna centrada: el móvil real es '
              'más estrecho que contenidoMax y encajarlo dejaría bandas');
    });

    testWidgets(
        '600px: columna centrada de contenidoMax (comportamiento ACTUAL)',
        (tester) async {
      await _pump(tester, ancho: 600);
      final r = tester.getRect(find.byKey(_kSonda));
      expect(r.width, GriBreakpoints.contenidoMax,
          reason: 'de 0 a 840px el comportamiento debe ser IDÉNTICO al de '
              'antes de 11-13 (T-11-13-01)');
      expect(r.left, (600 - GriBreakpoints.contenidoMax) / 2,
          reason: 'y centrado');
    });

    testWidgets('839px (justo por debajo de expanded): sigue en contenidoMax',
        (tester) async {
      await _pump(tester, ancho: 839);
      expect(
          tester.getSize(find.byKey(_kSonda)).width, GriBreakpoints.contenidoMax,
          reason: 'el borde superior del tramo "idéntico a antes" es 840 '
              'EXCLUSIVE; a 839 todavía manda contenidoMax');
    });

    testWidgets('1200px (escritorio): columna más generosa, ya no 480',
        (tester) async {
      await _pump(tester, ancho: 1200);
      final r = tester.getRect(find.byKey(_kSonda));
      expect(r.width, GriBreakpoints.contenidoMaxAmplio);
      expect(r.width, greaterThan(GriBreakpoints.contenidoMax),
          reason: 'si alguien iguala los dos tokens este test seguiría verde '
              'con solo la primera aserción: aquí se exige que sea MÁS ancho');
      expect(r.left, (1200 - GriBreakpoints.contenidoMaxAmplio) / 2);
    });

    testWidgets('el contenido NUNCA se estira a todo el ancho en escritorio',
        (tester) async {
      await _pump(tester, ancho: 1600);
      expect(tester.getSize(find.byKey(_kSonda)).width, lessThan(1600.0),
          reason: 'borrar el ConstrainedBox en vez de convertirlo en techo '
              'adaptativo es el modo de fallo que este caso vigila');
    });
  });

  // ── Zona segura superior (el bug reportado por el usuario) ────────────────
  group('AppShell — zona segura', () {
    testWidgets('con notch de 44px el contenido NO empieza en y=0',
        (tester) async {
      await _pump(tester, ancho: 390, padTop: 44);
      expect(tester.getTopLeft(find.byKey(_kSonda)).dy, greaterThanOrEqualTo(44),
          reason: 'ESTE es el bug que reportó el usuario: "no deja espacio en '
              'la parte superior, se oculta el logo"');
    });

    testWidgets('sin notch (padding.top: 0) NO se inventa ningún hueco',
        (tester) async {
      await _pump(tester, ancho: 390, padTop: 0);
      expect(tester.getTopLeft(find.byKey(_kSonda)).dy, 0.0,
          reason: 'arreglar el notch no puede costar un margen fijo en los '
              'dispositivos que no lo tienen');
    });

    testWidgets('una pantalla que YA trae SafeArea no acumula doble margen',
        (tester) async {
      await _pump(tester, ancho: 390, padTop: 44);
      // La rama /b es la que trae su propio SafeArea (como menu_mesa_screen,
      // pedido_estado_screen y reserva_wizard_screen).
      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byKey(_kSondaSafe)).dy, 44.0,
          reason: 'SafeArea es idempotente por CONSUMO de MediaQuery: la '
              'anidada no debe reaplicar el inset. 44 y no 88');
    });

    testWidgets('no hay banda muerta entre el contenido y la barra inferior',
        (tester) async {
      await _pump(tester, ancho: 390, alto: 800, padTop: 44, padBottom: 34);
      final contenido = tester.getRect(find.byKey(_kSonda));
      final nav = tester.getRect(find.byType(BottomNavigationBar));
      expect(contenido.bottom, nav.top,
          reason: 'cualquier inset inferior aplicado al body ADEMÁS del que ya '
              'gestiona el Scaffold deja una franja de fondo entre el '
              'contenido y la barra');
      expect(nav.bottom, 800.0,
          reason: 'y la barra tiene que llegar al borde físico de la pantalla');
    });

    testWidgets('el inset inferior se lo queda la barra, no el contenido',
        (tester) async {
      await _pump(tester, ancho: 390, alto: 800, padBottom: 0);
      final sinGesto = tester.getRect(find.byType(BottomNavigationBar)).height;

      await _pump(tester, ancho: 390, alto: 800, padBottom: 34);
      final conGesto = tester.getRect(find.byType(BottomNavigationBar)).height;

      expect(conGesto - sinGesto, 34.0,
          reason: 'la BottomNavigationBar del Scaffold CRECE exactamente el '
              'inset de la barra de gestos. Si alguien envuelve el Scaffold '
              'entero en un SafeArea, la barra deja de crecer y el inset pasa '
              'a comerse el contenido');
    });

    testWidgets(
        'MEDIDO: dentro del body el inset inferior YA viene consumido — por eso '
        '`bottom: false` es documentación de intención, no un arreglo',
        (tester) async {
      await _pump(tester, ancho: 390, alto: 800, padTop: 44, padBottom: 34);

      expect(_mqDelContenido!.padding.bottom, 0.0,
          reason: 'HALLAZGO de 11-13: el Scaffold ya pone padding.bottom a 0 '
              'en el MediaQuery del body cuando hay bottomNavigationBar, así '
              'que `SafeArea(bottom: true)` sería un NO-OP y NO añadiría el '
              'hueco que el plan temía (verificado con una rotura deliberada '
              'que dejó la suite entera en verde). Esta aserción sí tiene '
              'dientes: si el shell perdiera la BottomNavigationBar, el inset '
              'volvería a llegar al body y `bottom: false` pasaría a ser un '
              'bug real — el contenido quedaría bajo la barra de gestos');
      expect(_mqDelContenido!.padding.top, 0.0,
          reason: 'y el superior lo consume el SafeArea del propio shell: por '
              'eso las 3 pantallas que ya traen SafeArea propio no duplican');
    });
  });

  // ── Iconografía de la barra inferior (11-13) ──────────────────────────────
  group('AppShell — los 4 tabs son Icon, no emojis', () {
    testWidgets('4 Icon de GriIcons, ninguno pintado como texto',
        (tester) async {
      await _pump(tester, ancho: 390);

      final barra = find.byType(BottomNavigationBar);
      for (final icono in const [
        GriIcons.inicio,
        GriIcons.buscar,
        GriIcons.reservas,
        GriIcons.perfil,
      ]) {
        expect(find.descendant(of: barra, matching: find.byIcon(icono)),
            findsOneWidget,
            reason: 'falta el icono del tab (o hay dos tabs con el mismo)');
      }

      // Los labels siguen siendo Text; el ICONO ya no puede serlo. Si alguien
      // devuelve un emoji al registro `_tabs`, aquí aparecería un 5.º Text.
      expect(find.descendant(of: barra, matching: find.byType(Text)),
          findsNWidgets(4),
          reason: 'en la barra solo deben quedar los 4 Text de las etiquetas');
      for (final label in const [
        'Inicio',
        'Restaurantes',
        'Reservas',
        'Perfil'
      ]) {
        expect(find.descendant(of: barra, matching: find.text(label)),
            findsOneWidget);
      }
    });

    testWidgets('el size del icono es el fontSize que tenía el emoji (20)',
        (tester) async {
      await _pump(tester, ancho: 390);
      final icono =
          tester.widget<Icon>(find.byIcon(GriIcons.inicio));
      expect(icono.size, 20.0,
          reason: 'regla de 11-13 (T-11-13-05): el icono NO puede cambiar de '
              'tamaño respecto al Text del emoji que sustituye');
    });

    testWidgets('el color activo/inactivo lo sigue poniendo la barra',
        (tester) async {
      await _pump(tester, ancho: 390);
      final barra = tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(barra.selectedItemColor, GriColors.primary);
      // 11-14: la etiqueta del tab INACTIVO es texto de 12px sobre blanco.
      // Con #777777 daba 4.478:1, por debajo del 4.5:1 de WCAG AA, así que
      // pasa al token accesible (#6E6E6E, 5.099:1). El hex va literal a
      // propósito: comparar contra el token dejaría el caso verde si alguien
      // cambiase el valor del token.
      expect(barra.unselectedItemColor, const Color(0xFF6E6E6E));
      expect(barra.unselectedItemColor, GriColors.textoSecundarioAccesible);
      // Y el Icon NO fija color propio: si lo fijara, ganaría al de la barra
      // y el tab activo dejaría de pintarse de naranja.
      expect(tester.widget<Icon>(find.byIcon(GriIcons.inicio)).color, isNull);
    });
  });

  // ── Que el shell siga siendo un shell ─────────────────────────────────────
  group('AppShell — navegación intacta en los tres anchos', () {
    for (final ancho in [360.0, 600.0, 1200.0]) {
      testWidgets('a ${ancho.toInt()}px el tap cambia de branch y de índice',
          (tester) async {
        await _pump(tester, ancho: ancho);
        expect(
            tester
                .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
                .currentIndex,
            0);

        await tester.tap(find.text('Reservas'));
        await tester.pumpAndSettle();

        expect(
            tester
                .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
                .currentIndex,
            2,
            reason: 'el goBranch no puede depender del ancho');
      });
    }
  });
}
