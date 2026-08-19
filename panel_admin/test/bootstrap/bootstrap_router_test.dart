import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/auth/login_screen.dart';
import 'package:gri_panel_admin/features/bootstrap/bootstrap_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Guard del GoRouter REAL frente a `/bootstrap` (11-07, Tarea 3).
///
/// ── POR QUÉ ESTE ARCHIVO EXISTE ───────────────────────────────────────────
/// El guard vigente redirige en CADA evento de `authStateChanges`
/// (`refreshListenable`). `createUserWithEmailAndPassword` produce uno de esos
/// eventos en mitad del bootstrap: en cuanto la cuenta se crea hay sesión, el
/// router se re-evalúa y —sin la exención— expulsa al usuario de `/bootstrap`
/// hacia `/` **con la callable todavía en vuelo**. La reversión de la cuenta se
/// quedaría sin pantalla donde ejecutarse.
///
/// Un test que pumpee `BootstrapScreen` suelta NO ejercita el router: pasaría
/// en verde con el flujo roto. Por eso estos casos montan `GriApp`, que resuelve
/// `goRouterProvider` de verdad, y mueven el stream de sesión a mano.
void main() {
  /// Sesión controlable a mano: el override de `authStateChangesProvider`
  /// devuelve este stream, así que `ctrl.add(user)` es exactamente el evento
  /// que dispara el alta de cuenta.
  late StreamController<User?> ctrl;
  late ProviderContainer container;

  Future<void> montar(WidgetTester tester) async {
    // El panel es una app de ESCRITORIO. 1000x900 es un ancho de ventana
    // representativo.
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ── FILTRO DE OVERFLOW RETIRADO EN 11-21 ──────────────────────────────
    // Aquí vivía un `FlutterError.onError` que se tragaba las excepciones de
    // desborde de RenderFlex para que estos casos pudieran quedarse en verde
    // con el sidebar roto. Los cuatro desbordes que lo motivaban están
    // cerrados (sidebar 85px + ítem de menú 33px + topbar 77px + cabecera del
    // mapa de mesas 148px) y su regresión la vigila
    // `test/shared/app_shell_layout_test.dart`. NO VOLVER A PONERLO: un filtro
    // así deja de ocultar un defecto conocido y pasa a ocultar los que vengan.

    ctrl = StreamController<User?>.broadcast();
    final db = await buildFakeFirestoreVacio();
    container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => ctrl.stream),
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      claimsProvider.overrideWith(
        (ref) async => (role: 'super_admin', rid: null),
      ),
    ]);
    addTearDown(() {
      container.dispose();
      ctrl.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GriApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SIN sesión, /bootstrap se renderiza y NO redirige a /login',
      (tester) async {
    await montar(tester);
    // Punto de partida: sin sesión el guard manda a /login.
    expect(find.byType(LoginScreen), findsOneWidget);

    container.read(goRouterProvider).go('/bootstrap');
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('CON sesión, /bootstrap se renderiza y NO redirige a /',
      (tester) async {
    await montar(tester);

    ctrl.add(MockUser(uid: 'u-super', email: 'fundador@demo.gri.dev'));
    await tester.pumpAndSettle();
    // Con sesión el guard saca de /login hacia el dashboard.
    expect(find.byType(LoginScreen), findsNothing);

    container.read(goRouterProvider).go('/bootstrap');
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapScreen), findsOneWidget);
  });

  testWidgets(
      'EL CASO QUE ROMPE EL FLUJO: el evento de sesión del alta de cuenta NO '
      'expulsa de /bootstrap', (tester) async {
    await montar(tester);
    container.read(goRouterProvider).go('/bootstrap');
    await tester.pumpAndSettle();
    expect(find.byType(BootstrapScreen), findsOneWidget);

    // Esto es literalmente lo que emite `createUserWithEmailAndPassword`
    // cuando la cuenta se crea, con la callable aún en vuelo.
    ctrl.add(MockUser(uid: 'u-nuevo', email: 'fundador@demo.gri.dev'));
    await tester.pumpAndSettle();

    expect(
      find.byType(BootstrapScreen),
      findsOneWidget,
      reason: 'si el guard expulsa aquí, la reversión de la cuenta se queda '
          'sin pantalla donde ejecutarse',
    );
  });

  testWidgets('el guard NO se aflojó de más: /mesas sin sesión sigue yendo a '
      '/login', (tester) async {
    await montar(tester);

    container.read(goRouterProvider).go('/mesas');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(BootstrapScreen), findsNothing);
  });

  testWidgets('desde el login hay camino a /bootstrap (enlace de primera vez)',
      (tester) async {
    await montar(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    final enlace = find.text('¿Primera vez? Inicializar plataforma');
    expect(enlace, findsOneWidget);

    await tester.tap(enlace);
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapScreen), findsOneWidget);
  });
}
