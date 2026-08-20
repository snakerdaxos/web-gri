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
import 'package:gri_cliente/core/password_policy.dart';
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


/// El `TextField` interno del campo con esa key.
Finder _campo(Key k) =>
    find.descendant(of: find.byKey(k), matching: find.byType(TextField));

Finder _ojo(Key k) =>
    find.descendant(of: find.byKey(k), matching: find.byType(IconButton));

bool _obscuro(WidgetTester tester, Key k) =>
    tester.widget<TextField>(_campo(k)).obscureText;

IconData _iconoDe(WidgetTester tester, Key k) =>
    (tester.widget<IconButton>(_ojo(k)).icon as Icon).icon!;

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

  // -- 11-06: los DOS campos de contraseña del perfil, independientes -----

  testWidgets('perfil: ambas contraseñas arrancan ocultas y con ojo',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    expect(_obscuro(tester, const ValueKey('perfil-pass-actual')), isTrue);
    expect(_obscuro(tester, const ValueKey('perfil-password')), isTrue);
    expect(_iconoDe(tester, const ValueKey('perfil-pass-actual')),
        Icons.visibility);
    expect(
        _iconoDe(tester, const ValueKey('perfil-password')), Icons.visibility);
  });

  testWidgets(
      'perfil: mostrar "Contraseña actual" NO revela "Nueva contraseña"',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    const actual = ValueKey('perfil-pass-actual');
    const nueva = ValueKey('perfil-password');

    await tester.tap(_ojo(actual));
    await tester.pump();

    expect(_obscuro(tester, actual), isFalse);
    expect(_obscuro(tester, nueva), isTrue,
        reason: 'cada PasswordField tiene su propio estado');
    expect(_iconoDe(tester, actual), Icons.visibility_off);
    expect(_iconoDe(tester, nueva), Icons.visibility);

    // Y al revés: revelar la nueva no vuelve a ocultar la actual.
    await tester.tap(_ojo(nueva));
    await tester.pump();
    expect(_obscuro(tester, actual), isFalse);
    expect(_obscuro(tester, nueva), isFalse);
  });

  testWidgets('perfil: el ojo conserva el helperText y el prefijo del campo',
      (tester) async {
    // La extracción del widget NO puede perder la decoración existente
    // (el plan lo exige: extraer, no rediseñar).
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    expect(find.text('Solo si vas a cambiar la contraseña'), findsOneWidget);
    expect(find.text('Déjala vacía para no cambiarla'), findsOneWidget);
    expect(find.text('Contraseña actual'), findsOneWidget);
    expect(find.text('Nueva contraseña (opcional)'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('perfil-pass-actual')),
            matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget);
  });

  testWidgets('perfil: revelar la contraseña no altera lo que se guarda',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('perfil-pass-actual')), 'Demo!1234');
    await tester.tap(_ojo(const ValueKey('perfil-pass-actual')));
    await tester.pump();

    expect(
        tester
            .widget<TextField>(_campo(const ValueKey('perfil-pass-actual')))
            .controller!
            .text,
        'Demo!1234');
  });

  // ── 11-22: la política de contraseñas en el perfil ──────────────────────
  //
  // ESTE ERA EL HUECO MÁS GRANDE de los cuatro: hasta este plan los dos campos
  // del perfil NO llevaban `validator` ninguno, así que la pantalla no
  // comprobaba absolutamente nada y la única defensa era el `length < 8` del
  // controlador. `12345678` se guardaba.
  //
  // Lo delicado aquí no es aplicar la regla, es NO romper la semántica del
  // campo: la contraseña nueva es OPCIONAL y vacía significa "no la cambio".

  testWidgets('perfil: una contraseña nueva que incumple NO guarda NADA',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    // Se cambia TAMBIÉN el nombre: si el guardado no se cortara, el nombre se
    // habría escrito antes de llegar a la contraseña (el orden del código es
    // nombre → password) y el perfil quedaría a medias.
    await tester.enterText(
        find.byKey(const ValueKey('perfil-nombre')), 'Carlitos Rey');
    await tester.enterText(
        find.byKey(const ValueKey('perfil-pass-actual')), 'Demo!1234');
    await tester.enterText(
        find.byKey(const ValueKey('perfil-password')), '12345678');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Te faltan una mayúscula y una minúscula.'), findsOneWidget);
    expect(find.text('Perfil actualizado ✅'), findsNothing);

    final doc = await db.collection('usuarios').doc(_uid).get();
    expect(
      doc.data()!['nombre'],
      'Carlos Pérez',
      reason: 'no se puede guardar media edición cuando la contraseña no vale',
    );
  });

  testWidgets('perfil: la contraseña VACÍA sigue significando "no la cambio"',
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

    // Ni un aviso de política sobre un campo que el usuario dejó en blanco.
    expect(find.textContaining('Te falta'), findsNothing);
    expect(find.textContaining('al menos 8 caracteres'), findsNothing);
    expect(find.text('Perfil actualizado ✅'), findsOneWidget);

    final doc = await db.collection('usuarios').doc(_uid).get();
    expect(doc.data()!['nombre'], 'Carlitos Rey');
  });

  testWidgets('perfil: contraseña nueva SIN la actual avisa y no guarda',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('perfil-password')), 'NuevaPass1');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Escribe tu contraseña actual para poder cambiarla'),
      findsOneWidget,
    );
    expect(find.text('Perfil actualizado ✅'), findsNothing);
  });

  testWidgets('perfil: la política se anuncia ANTES de fallar', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    await tester.pumpWidget(_wrap(auth: auth, db: db));
    await tester.pumpAndSettle();

    expect(find.text(ayudaPolitica), findsOneWidget);
    // Y el aviso de opcionalidad, que es la otra mitad de la información, NO se
    // pierde por el camino.
    expect(find.text('Déjala vacía para no cambiarla'), findsOneWidget);
  });

  test('cambiarPassword aplica la POLÍTICA, no solo la longitud', () async {
    // La última línea de defensa del cliente. Sin esto, una pantalla futura que
    // olvidara el validador volvería a dejar pasar `12345678`.
    final db = await buildFakeFirestoreConSeed();
    await _sembrarUsuario(db);
    final auth = mockAuth(email: 'carlos@demo.gri.dev', uid: _uid);

    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(perfilControllerProvider.notifier)
          .cambiarPassword('Demo!1234', '12345678'),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        'Te faltan una mayúscula y una minúscula.',
      )),
    );

    // Y la que SÍ cumple pasa (el control no es un "rechaza siempre").
    expect(
      await container
          .read(perfilControllerProvider.notifier)
          .cambiarPassword('Demo!1234', 'Abcdefg1'),
      isTrue,
    );
  });
}

