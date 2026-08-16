// Tests de auth sobre FirebaseAuth (10-02 Task 3): validación de UI parity
// (screens intactas) + flujo login/registro/logout con MockFirebaseAuth y
// FakeFirebaseFirestore (helpers). El registro DEBE crear usuarios/{uid}
// con role 'cliente' y restauranteId null — nunca otro role.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/auth/auth_controller.dart';
import 'package:gri_cliente/features/auth/login_screen.dart';
import 'package:gri_cliente/features/auth/register_screen.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

Future<void> _fill(WidgetTester tester, List<String> values) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
  await tester.pump();
}

/// Container con las instancias fake cableadas (patrón de override de
/// test/helpers/firebase_fakes.dart).
ProviderContainer _container(FirebaseAuth auth, FirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  // ── UI parity: validación pre-red (screens intactas) ──────────────────

  testWidgets('login: email inválido deshabilita el botón', (tester) async {
    await tester.pumpWidget(_wrap());

    await _fill(tester, ['not-an-email', 'Demo!1234']);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'email inválido debe deshabilitar Ingresar (validación pre-red)');
  });

  testWidgets('login: password < 8 deshabilita el botón', (tester) async {
    await tester.pumpWidget(_wrap());

    await _fill(tester, ['carlos@demo.gri.dev', 'abc']);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'password < 8 chars debe deshabilitar Ingresar');
  });

  testWidgets('login: toggle navega a la pantalla de registro', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Ingresar'), findsOneWidget);

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Crear cuenta'), findsWidgets);
  });

  testWidgets(
      'register: requiere nombre + email válido + password ≥ 8 para habilitar',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    // Vacío → disabled.
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'form vacío deshabilita Crear');

    // Solo nombre → disabled.
    await _fill(tester, ['Carlos']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'sin email/password deshabilita Crear');

    // Nombre + email inválido → disabled.
    await _fill(tester, ['Carlos', 'not-an-email', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'email inválido deshabilita Crear');

    // Todo válido → enabled.
    await _fill(tester, ['Carlos Pérez', 'carlos@test.gri.dev', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
        reason: 'nombre + email válido + password 8+ habilita Crear');
  });

  // ── Login/logout con MockFirebaseAuth ─────────────────────────────────

  test('login OK firma la sesión', () async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit('carlos@demo.gri.dev', 'Demo!1234');

    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull,
        reason: 'signInWithEmailAndPassword deja sesión iniciada');
  });

  test('login con credenciales inválidas → Credenciales inválidas',
      () async {
    final auth = mockAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('carlos@demo.gri.dev', 'Mala!2345'),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', 'Credenciales inválidas')),
    );
  });

  test('login sin red → mensaje de conexión', () async {
    final auth = mockAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    final container = _container(auth, await buildFakeFirestoreConSeed());

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('carlos@demo.gri.dev', 'Demo!1234'),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', contains('Sin conexión'))),
    );
  });

  test('logout cierra la sesión', () async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev');
    final container = _container(auth, await buildFakeFirestoreConSeed());

    await container.read(logoutControllerProvider.notifier).logout();

    expect(auth.currentUser, isNull);
  });

  // ── Registro: espejo usuarios/{uid} con role cliente ──────────────────

  test('registro crea usuarios/{uid} con role cliente y restauranteId null',
      () async {
    final auth = MockFirebaseAuth(); // sin sesión → createUser auto-loguea
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    final ok = await container.read(registerControllerProvider.notifier).submit(
          'Carlos Pérez',
          'carlos@nuevo.gri.dev',
          'Demo!1234',
        );

    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull, reason: 'auto-login tras registro');

    final uid = auth.currentUser!.uid;
    final doc = await db.collection('usuarios').doc(uid).get();
    expect(doc.exists, isTrue, reason: 'registro escribe el espejo usuarios/{uid}');

    final data = doc.data()!;
    // LOCKED (must_haves): role SIEMPRE 'cliente', restauranteId null.
    expect(data['role'], 'cliente');
    expect(data['restauranteId'], isNull);
    expect(data['nombre'], 'Carlos Pérez');
    expect(data['email'], 'carlos@nuevo.gri.dev');
    expect(data.keys, unorderedEquals(
        ['nombre', 'email', 'role', 'restauranteId', 'createdAt']));

    // DisplayName queda disponible para la UI.
    expect(auth.currentUser!.displayName, 'Carlos Pérez');
  });

  test('registro con email existente → mensaje mapeado', () async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
    final container = _container(auth, await buildFakeFirestoreConSeed());

    await expectLater(
      container.read(registerControllerProvider.notifier).submit(
            'Carlos',
            'carlos@demo.gri.dev',
            'Demo!1234',
          ),
      throwsA(isA<StateError>().having((e) => e.message, 'message',
          'Ya existe una cuenta con este email')),
    );
  });

  test('login no toca Firestore (solo Auth)', () async {
    // El login NO escribe nada — la sesión es asunto del SDK.
    final auth = mockAuth(email: 'maria@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    await container
        .read(loginControllerProvider.notifier)
        .submit('maria@demo.gri.dev', 'Demo!1234');

    final usuarios = await db.collection('usuarios').get();
    expect(usuarios.docs, isEmpty,
        reason: 'login no crea docs — solo el registro escribe el espejo');
  });
}
