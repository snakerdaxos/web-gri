import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/auth/login_screen.dart';
import 'package:gri_panel_admin/features/dashboard/dashboard_screen.dart';
import 'package:gri_panel_admin/features/shared/not_found_screen.dart';

import 'helpers/firebase_fakes.dart';

/// 404 propio del panel sobre el GoRouter REAL (11-09).
///
/// El panel es web: escribir una URL a mano es un gesto normal aquí. Se monta
/// `GriApp` (que resuelve `goRouterProvider` de verdad) porque lo que hay que
/// probar no es la pantalla suelta, sino su INTERACCIÓN con el guard de sesión:
/// el `redirect` debe seguir mandando sobre el `errorBuilder`.
void main() {
  late StreamController<User?> ctrl;
  late ProviderContainer container;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ── FILTRO DE OVERFLOW RETIRADO EN 11-21 ──────────────────────────────
    // Aquí vivía el mismo filtro heredado de bootstrap_router_test.dart. El
    // sidebar ya no desborda; su regresión la vigila
    // `test/shared/app_shell_layout_test.dart`. NO VOLVER A PONERLO.

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
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const GriApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> conSesion(WidgetTester tester) async {
    ctrl.add(MockUser(uid: 'u-super', email: 'super@demo.gri.dev'));
    await tester.pumpAndSettle();
  }

  String textoDeLaPantalla(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');

  testWidgets('CON sesión, una URL inexistente muestra la pantalla 404 propia',
      (tester) async {
    await montar(tester);
    await conSesion(tester);

    container.read(goRouterProvider).go('/ruta-que-no-existe');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.text('Página no encontrada'), findsOneWidget);
    expect(find.text('/ruta-que-no-existe'), findsOneWidget);
  });

  testWidgets('el botón devuelve al panel (/), que aquí SÍ existe',
      (tester) async {
    await montar(tester);
    await conSesion(tester);
    container.read(goRouterProvider).go('/ruta-que-no-existe');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al panel'));
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
      'T-11-09-02: se muestra el path pero NUNCA los query params ni el '
      'fragmento', (tester) async {
    await montar(tester);
    await conSesion(tester);

    container
        .read(goRouterProvider)
        .go('/no-existe?token=SECRETO-DE-STAFF&rid=demo#frag-SECRETO');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    final texto = textoDeLaPantalla(tester);
    expect(texto, contains('/no-existe'));
    expect(
      texto,
      isNot(contains('SECRETO')),
      reason: 'en un panel de administración por el query string viajan ids de '
          'restaurante y tokens de invitación',
    );
    expect(texto, isNot(contains('token=')));
    expect(texto, isNot(contains('frag')));
  });

  testWidgets(
      'T-11-09-03: SIN sesión el guard manda sobre el 404 (va a /login)',
      (tester) async {
    await montar(tester);

    container.read(goRouterProvider).go('/ruta-que-no-existe');
    await tester.pumpAndSettle();

    // El 404 no puede servir para sondear qué rutas internas existen: sin
    // sesión, exista o no la ruta, la respuesta es siempre la misma.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });

  testWidgets(
      'SIN sesión, una ruta que SÍ existe da la MISMA respuesta que una que no',
      (tester) async {
    await montar(tester);

    container.read(goRouterProvider).go('/mesas');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    container.read(goRouterProvider).go('/ruta-que-no-existe');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('no se aflojó de más: una ruta REAL con sesión sigue funcionando',
      (tester) async {
    await montar(tester);
    await conSesion(tester);

    container.read(goRouterProvider).go('/mesas');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsNothing);
  });
}
