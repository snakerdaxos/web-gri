// Tests del perfil sobre Firebase (10-02 Task 3): perfilProvider lee
// usuarios/{uid}; actualizarNombre toca SOLO 'nombre' (assert de keys —
// rules congelan el resto); cambiarPassword mapea wrong-password.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/perfil/perfil_controller.dart';
import 'package:gri_cliente/features/perfil/perfil_screen.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';

const _uid = 'test-uid';

/// Doc espejo igual al que escribe el registro/seed.
///
/// [uid] parametrizable: mock_exceptions registra los throws en un mapa
/// GLOBAL claveado por == y MockUser usa EquatableMixin (== por VALOR) —
/// los tests que registran un throw usan un uid DISTINTO para no
/// contaminar a los users "value-igual" de los demás tests.
Future<void> _sembrarUsuario(FakeFirebaseFirestore db, [String uid = _uid]) =>
    db.collection('usuarios').doc(uid).set({
      'nombre': 'Carlos Pérez',
      'email': 'carlos@demo.gri.dev',
      'role': 'cliente',
      'restauranteId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

Widget _wrap({required FirebaseAuth auth, required FirebaseFirestore db}) {
  return ProviderScope(
    overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(db),
    ],
    // Scaffold: en producción lo provee el AppShell; el SnackBar del
    // guardado necesita uno en el árbol del test.
    child: const MaterialApp(home: Scaffold(body: PerfilScreen())),
  );
}

void main() {
  // ── UI: render + edición ──────────────────────────────────────────────

  testWidgets('muestra nombre y email del perfil (usuarios/{uid})',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('carlos@demo.gri.dev'), findsOneWidget);
  });

  testWidgets('Guardar actualiza el nombre tocando SOLO ese campo',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('perfil-nombre')), 'Carlitos Rey');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // El doc quedó con el nombre nuevo y las demás keys INTACTAS
    // (rules: update solo puede tocar 'nombre').
    final doc = await db.collection('usuarios').doc(_uid).get();
    final data = doc.data()!;
    expect(data['nombre'], 'Carlitos Rey');
    expect(data['email'], 'carlos@demo.gri.dev');
    expect(data['role'], 'cliente');
    expect(data['restauranteId'], isNull);
    expect(data.keys,
        unorderedEquals(['nombre', 'email', 'role', 'restauranteId', 'createdAt']));

    expect(find.text('Perfil actualizado ✅'), findsOneWidget);
  });

  testWidgets('password actual incorrecta → mensaje mapeado en snackbar',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db, 'uid-wrong-pass');
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: 'uid-wrong-pass');
    // El re-auth del mock rechaza la credencial con wrong-password.
    whenCalling(Invocation.method(#reauthenticateWithCredential, null))
        .on(auth.currentUser!)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('perfil-pass-actual')), 'Incorrecta!9');
    await tester.enterText(
        find.byKey(const ValueKey('perfil-password')), 'NuevaPass!23');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Contraseña actual incorrecta'), findsOneWidget);
  });

  // ── Controller: unidad ────────────────────────────────────────────────

  test('cambiarPassword con actual incorrecta → Contraseña actual incorrecta',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db, 'uid-wrong-pass');
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: 'uid-wrong-pass');
    whenCalling(Invocation.method(#reauthenticateWithCredential, null))
        .on(auth.currentUser!)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(perfilControllerProvider.notifier).cambiarPassword(
            'Incorrecta!9',
            'NuevaPass!23',
          ),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', 'Contraseña actual incorrecta')),
    );
  });

  test('cambiarPassword re-autentica y actualiza (happy path)', () async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final ok = await container
        .read(perfilControllerProvider.notifier)
        .cambiarPassword('Demo!1234', 'NuevaPass!23');
    expect(ok, isTrue);
  });

  test('nueva password < 8 → validación local ArgumentError', () async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    // La validación local corre ANTES de tocar el SDK (orden del código):
    // corta con ArgumentError sin re-auth.
    await expectLater(
      container
          .read(perfilControllerProvider.notifier)
          .cambiarPassword('Demo!1234', 'corta'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
