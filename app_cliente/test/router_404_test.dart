import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/app.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/auth/auth_controller.dart';
import 'package:gri_cliente/features/auth/login_screen.dart';
import 'package:gri_cliente/features/restaurantes/home_screen.dart';
import 'package:gri_cliente/features/shared/not_found_screen.dart';

import 'helpers/firebase_fakes.dart';

/// 404 propio de la app cliente sobre el GoRouter REAL (11-09).
///
/// Se monta `GriClienteApp`, que resuelve `goRouterProvider` de verdad. Un test
/// que pumpee `NotFoundScreen` suelta NO probaría nada de lo que importa aquí:
/// que el `errorBuilder` esté cableado, y sobre todo que el `redirect` del
/// guard siga mandando SOBRE él.
void main() {
  late StreamController<User?> ctrl;
  late ProviderContainer container;

  Future<void> montar(WidgetTester tester) async {
    ctrl = StreamController<User?>.broadcast();
    final db = await buildFakeFirestoreVacio();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => ctrl.stream),
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
    ]);
    addTearDown(() {
      container.dispose();
      ctrl.close();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const GriClienteApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> conSesion(WidgetTester tester) async {
    ctrl.add(MockUser(uid: 'u1', email: 'cliente@demo.gri.dev'));
    await tester.pumpAndSettle();
  }

  /// Todo el texto pintado en pantalla, para poder afirmar que algo NO aparece
  /// en ningún sitio (y no solo que no aparece donde yo miré).
  String textoDeLaPantalla(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');

  testWidgets('una URL inexistente muestra la pantalla 404 propia',
      (tester) async {
    await montar(tester);
    await conSesion(tester);

    container.read(goRouterProvider).go('/ruta-que-no-existe');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.text('Página no encontrada'), findsOneWidget);
    // La ruta pedida se muestra para que el usuario sepa qué enlace falló.
    expect(find.text('/ruta-que-no-existe'), findsOneWidget);
  });

  testWidgets(
      'el botón de salida devuelve a una ruta REAL, no a otro 404',
      (tester) async {
    await montar(tester);
    await conSesion(tester);
    container.read(goRouterProvider).go('/ruta-que-no-existe');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al inicio'));
    await tester.pumpAndSettle();

    // Esta app NO tiene ruta '/': su initialLocation es '/inicio'. Con
    // `context.go('/')` —lo que decía el plan— este tap caería en OTRO 404 y
    // el usuario quedaría atrapado.
    expect(find.byType(NotFoundScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
      'T-11-09-02: se muestra el path pero NUNCA los query params ni el '
      'fragmento', (tester) async {
    await montar(tester);
    await conSesion(tester);

    container
        .read(goRouterProvider)
        .go('/no-existe?token=SECRETO-DE-SESION&uid=u1#frag-SECRETO');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    final texto = textoDeLaPantalla(tester);
    expect(texto, contains('/no-existe'));
    expect(
      texto,
      isNot(contains('SECRETO')),
      reason: 'un enlace mal formado puede llevar un token; pintarlo lo expone '
          'a quien mire la pantalla y a cualquier captura',
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

    // Si el errorBuilder se evaluara antes que el redirect, un anónimo podría
    // sondear qué rutas existen comparando 404 contra login.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });

  testWidgets('no se aflojó de más: una ruta REAL sigue funcionando',
      (tester) async {
    await montar(tester);
    await conSesion(tester);

    container.read(goRouterProvider).go('/inicio');
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotFoundScreen), findsNothing);
  });
}
