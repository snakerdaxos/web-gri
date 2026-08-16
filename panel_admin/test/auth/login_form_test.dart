// Tests del login del panel (Phase 10 — 10-05 Task 2): la suite cubre los
// 4 casos del plan — staff entra con su rid, super va al selector (sin
// rid hasta elegir), cliente RECHAZADO con sesión cerrada, y credenciales
// inválidas mapeadas — más la parity de validación pre-red (screen
// intacta). Claims se proveen con override directo del provider (patrón
// 10-02 — NO se mockea el token).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/auth/login_controller.dart';
import 'package:gri_panel_admin/features/auth/login_screen.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/features/dashboard/restaurantes_list_provider.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';
/// Container con fakes + claims cableados (patrón firebase_fakes.dart).
ProviderContainer _container(
  MockFirebaseAuth auth,
  FakeFirebaseFirestore db, {
  ({String role, String? rid})? claims,
}) {
  final container = ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
    if (claims != null) claimsProvider.overrideWith((ref) async => claims),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Riverpod 3: los providers reactivos son autoDispose — un `read`
/// sin listener deja que el scheduler los dispose a mitad del await.
/// Estos listen pasivos los retienen durante el test.
void _retenerStaff(ProviderContainer c) {
  c.listen(ridActivoProvider, (_, _) {});
  c.listen(restauranteActivoProvider, (_, _) {});
}

void _retenerSuper(ProviderContainer c) {
  c.listen(ridActivoProvider, (_, _) {});
  c.listen(restaurantesListProvider, (_, _) {});
}

Future<void> _fillForm(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.pump();
}

void main() {
  // ── UI parity: validación pre-red (screen intacta) ─────────────────────

  testWidgets('form invalid email disables submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await _fillForm(tester, 'not-an-email', 'Demo!1234');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'email inválido debe deshabilitar el botón');
  });

  testWidgets('form short password disables submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'abc');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'password < 8 chars debe deshabilitar el botón');
  });

  testWidgets('form valid enables submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'Demo!1234');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull, reason: 'email válido + password 8+ chars habilita el botón');
  });

  // ── Caso 4: credenciales inválidas → mensaje mapeado ──────────────────

  testWidgets(
      'submit con credenciales inválidas → SnackBar "Credenciales inválidas"',
      (tester) async {
    final auth = mockAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'Demo!1234');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    // Avanza la animación de entrada del SnackBar SIN pumpAndSettle para no
    // disparar el auto-dismiss (4s).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Credenciales inválidas'), findsOneWidget);
    expect(auth.currentUser, isNull, reason: 'el login fallido no abre sesión');
  });

  // ── Caso 1: staff entra directo al dashboard de SU restaurante ────────

  test('login staff (mesero) → true y ridActivo == claims.rid (dashboard de su restaurante)',
      () async {
    final auth = mockAuth(email: 'mesero@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'mesero', rid: 'demo'),
    );

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit('mesero@demo.gri.dev', 'Demo!1234');

    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull, reason: 'sesión iniciada');

    // El rid SIEMPRE viene de claims (nunca de un input libre).
    _retenerStaff(container);
    final rid = await container.read(ridActivoProvider.future);
    expect(rid, 'demo');

    // El topbar resuelve el nombre del doc restaurantes/{rid}.
    final activo = await container.read(restauranteActivoProvider.future);
    expect(activo?.nombre, 'Restaurante Demo GRI');
  });

  // ── Caso 2: super_admin va al selector (sin rid hasta elegir) ─────────

  test('login super_admin → true, sin rid hasta elegir (selector de restaurantes)',
      () async {
    final auth = mockAuth(email: 'super@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'super_admin', rid: null),
    );

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit('super@demo.gri.dev', 'Demo!1234');

    expect(ok, isTrue);

    // Sin elección → sin rid: las vistas de datos quedan vacías hasta que
    // el super elija (selector del topbar).
    _retenerSuper(container);
    final sinEleccion = await container.read(ridActivoProvider.future);
    expect(sinEleccion, isNull);

    // El selector solo ve restaurantes ACTIVOS (sur inactivo excluido).
    final lista = await container.read(restaurantesListProvider.future);
    expect(lista.map((r) => r.id), ['demo', 'norte']);

    // Al elegir, el rid activo sigue la selección.
    container.read(seleccionRestauranteProvider.notifier).set('norte');
    final conEleccion = await container.read(ridActivoProvider.future);
    expect(conEleccion, 'norte');
  });

  // ── Caso 3: cliente NO entra (defense UX del threat model) ────────────

  test('login cliente → rechazado con mensaje y sesión CERRADA', () async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev');
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'cliente', rid: null),
    );

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('carlos@demo.gri.dev', 'Demo!1234'),
      throwsA(isA<StateError>().having((e) => e.message, 'message',
          'Esta aplicación es solo para personal del restaurante')),
    );

    // La sesión NO queda abierta para un usuario sin rol staff/super.
    expect(auth.currentUser, isNull, reason: 'el rechazo hace signOut');
  });

  test('login staff sin rid en claims → rechazado (cuenta mal sembrada)',
      () async {
    final auth = mockAuth(email: 'cocina@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'cocina', rid: null),
    );

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('cocina@demo.gri.dev', 'Demo!1234'),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', contains('restaurante asignado'))),
    );
    expect(auth.currentUser, isNull);
  });
}
