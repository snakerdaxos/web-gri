// test/auth/google_signin_test.dart — Ingreso con Google en la app cliente (11-17).
//
// ── FRONTERA DE ESTA COBERTURA (leer antes de añadir un caso) ──────────────
//
// El handshake REAL con Google NO se prueba aquí, y no es un descuido:
//
//   * `firebase_auth_mocks` no modela `signInWithCredential` con una
//     credencial de Google ni el canje del idToken.
//   * El plugin `google_sign_in` necesita canales de plataforma que no
//     existen en `flutter test` (`GoogleSignIn.instance.authenticate()`
//     lanza MissingPluginException en la VM de test).
//
// Mockear el plugin para "cubrir" el handshake fabricaría confianza falsa:
// probaría el mock, no el flujo. PROHIBIDO hacerlo.
//
// Lo que SÍ se prueba aquí, a través de la costura `googleAuthAccionProvider`:
//   1. el espejo `usuarios/{uid}` (creación, forma exacta del mapa, idempotencia),
//   2. la derivación del nombre,
//   3. la traducción de errores (colisión de cuentas, red) y la cancelación,
//   4. el valor exacto del Web client ID,
//   5. el estado del botón en login y registro (Tarea 2).
//
// El handshake real se verifica A MANO: en Web contra el proyecto real y en
// Android tras registrar la huella SHA-1 (checkpoint del plan). El emulador
// de Auth NO implementa el flujo de Google.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/google_auth.dart';
import 'package:gri_cliente/features/auth/auth_controller.dart';

import '../helpers/firebase_fakes.dart';

/// Costura de ÉXITO: devuelve el `UserCredential` del MockFirebaseAuth.
/// `signInWithPopup` sobre el mock hace el mismo `_fakeSignIn` que cualquier
/// otro método, así que es el equivalente más fiel a la rama Web real.
GoogleAuthAccion _accionOk() =>
    (auth) => auth.signInWithPopup(GoogleAuthProvider());

/// Costura que FALLA — para los casos de error y de cancelación.
GoogleAuthAccion _accionQueLanza(Object error) =>
    (_) => Future<UserCredential>.error(error);

ProviderContainer _container(
  FirebaseAuth auth,
  FirebaseFirestore db,
  GoogleAuthAccion accion,
) {
  final container = ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
    googleAuthAccionProvider.overrideWithValue(accion),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<Map<String, dynamic>?> _espejo(FirebaseFirestore db, String uid) async {
  final snap = await db.collection('usuarios').doc(uid).get();
  return snap.exists ? snap.data() : null;
}

void main() {
  group('Web client ID', () {
    test('es EXACTAMENTE el que entregó el usuario para p-gri-b5b40', () {
      // Un carácter mal copiado no se descubre hasta el runtime, y allí
      // aparece como DEVELOPER_ERROR / idToken nulo — un síntoma opaco.
      expect(
        googleWebClientId,
        '703827387403-o05u1u7gffibbfqo4419ds3pjcul12g2.apps.googleusercontent.com',
      );
    });

    test('pertenece al número de proyecto 703827387403', () {
      expect(googleWebClientId.startsWith('703827387403-'), isTrue);
      expect(googleWebClientId.endsWith('.apps.googleusercontent.com'), isTrue);
    });
  });

  group('espejo usuarios/{uid} tras el primer ingreso con Google', () {
    test('lo crea con role cliente, restauranteId null, nombre y email',
        () async {
      final db = await buildFakeFirestoreVacio();
      final auth = mockAuth(
        uid: 'g-uid-1',
        email: 'ana@gmail.com',
        displayName: 'Ana Gómez',
        signedIn: false,
      );
      final c = _container(auth, db, _accionOk());

      final ok =
          await c.read(googleSignInControllerProvider.notifier).ingresar();

      expect(ok, isTrue);
      final doc = await _espejo(db, 'g-uid-1');
      expect(doc, isNotNull);
      expect(doc!['role'], 'cliente');
      expect(doc['restauranteId'], isNull);
      expect(doc['nombre'], 'Ana Gómez');
      expect(doc['email'], 'ana@gmail.com');
    });

    test('el mapa escrito NO lleva ningún role distinto de cliente ni rid',
        () async {
      // Aserción sobre el mapa COMPLETO: la regla de create de
      // firestore.rules exige `role == 'cliente' && restauranteId == null`.
      // Fijar aquí las claves exactas hace que una divergencia se vea en
      // test y no como un permission-denied opaco en campo.
      final db = await buildFakeFirestoreVacio();
      final auth = mockAuth(
          uid: 'g-uid-2',
          email: 'b@gmail.com',
          displayName: 'B',
          signedIn: false);
      final c = _container(auth, db, _accionOk());

      await c.read(googleSignInControllerProvider.notifier).ingresar();

      final doc = (await _espejo(db, 'g-uid-2'))!;
      expect(doc.keys.toSet(),
          {'nombre', 'email', 'role', 'restauranteId', 'createdAt'});
      expect(doc['role'], 'cliente');
      expect(doc['restauranteId'], isNull);
    });

    test('sin displayName: el nombre cae a la parte local del correo',
        () async {
      final db = await buildFakeFirestoreVacio();
      final auth = mockAuth(
          uid: 'g-uid-3', email: 'pedro.ruiz@gmail.com', signedIn: false);
      final c = _container(auth, db, _accionOk());

      await c.read(googleSignInControllerProvider.notifier).ingresar();

      expect((await _espejo(db, 'g-uid-3'))!['nombre'], 'pedro.ruiz');
    });

    test('con displayName en blanco tampoco queda vacío', () async {
      final db = await buildFakeFirestoreVacio();
      final auth = mockAuth(
          uid: 'g-uid-4',
          email: 'vacio@gmail.com',
          displayName: '   ',
          signedIn: false);
      final c = _container(auth, db, _accionOk());

      await c.read(googleSignInControllerProvider.notifier).ingresar();

      final nombre = (await _espejo(db, 'g-uid-4'))!['nombre'] as String;
      expect(nombre.trim(), isNotEmpty);
      expect(nombre, 'vacio');
    });

    test('el segundo ingreso NO pisa el nombre que el usuario editó', () async {
      final db = await buildFakeFirestoreVacio();
      final auth = mockAuth(
          uid: 'g-uid-5',
          email: 'ana@gmail.com',
          displayName: 'Ana Gómez',
          signedIn: false);
      final c = _container(auth, db, _accionOk());

      await c.read(googleSignInControllerProvider.notifier).ingresar();
      // El usuario edita su perfil desde la app.
      await db.collection('usuarios').doc('g-uid-5').update({'nombre': 'Anita'});

      await c.read(googleSignInControllerProvider.notifier).ingresar();

      expect((await _espejo(db, 'g-uid-5'))!['nombre'], 'Anita');
    });
  });

  group('traducción de errores', () {
    test('account-exists-with-different-credential → mensaje claro, no crudo',
        () async {
      final db = await buildFakeFirestoreVacio();
      final auth =
          mockAuth(uid: 'g-uid-6', email: 'admin@gmail.com', signedIn: false);
      final c = _container(
        auth,
        db,
        _accionQueLanza(FirebaseAuthException(
            code: 'account-exists-with-different-credential')),
      );

      Object? capturado;
      try {
        await c.read(googleSignInControllerProvider.notifier).ingresar();
      } catch (e) {
        capturado = e;
      }

      expect(capturado, isA<StateError>());
      expect(
        (capturado! as StateError).message,
        'Ya tienes una cuenta con ese correo y contraseña. '
        'Inicia sesión con tu contraseña.',
      );
      // El código crudo de Firebase NO escapa al usuario.
      expect(capturado.toString(),
          isNot(contains('account-exists-with-different-credential')));
    });

    test('network-request-failed → mensaje genérico accionable', () async {
      final db = await buildFakeFirestoreVacio();
      final auth =
          mockAuth(uid: 'g-uid-7', email: 'x@gmail.com', signedIn: false);
      final c = _container(auth, db,
          _accionQueLanza(FirebaseAuthException(code: 'network-request-failed')));

      Object? capturado;
      try {
        await c.read(googleSignInControllerProvider.notifier).ingresar();
      } catch (e) {
        capturado = e;
      }

      expect(capturado, isA<StateError>());
      expect((capturado! as StateError).message,
          'Sin conexión — verificá tu internet e intentá de nuevo');
    });

    test('un código desconocido cae en un mensaje de usuario, no en el code',
        () async {
      final db = await buildFakeFirestoreVacio();
      final auth =
          mockAuth(uid: 'g-uid-8', email: 'x@gmail.com', signedIn: false);
      final c = _container(auth, db,
          _accionQueLanza(FirebaseAuthException(code: 'internal-error')));

      Object? capturado;
      try {
        await c.read(googleSignInControllerProvider.notifier).ingresar();
      } catch (e) {
        capturado = e;
      }

      expect(capturado, isA<StateError>());
      expect((capturado! as StateError).message,
          'No se pudo iniciar sesión con Google');
    });
  });

  group('cancelación del usuario', () {
    test('GoogleIngresoCancelado NO es error: devuelve false en silencio',
        () async {
      final db = await buildFakeFirestoreVacio();
      final auth =
          mockAuth(uid: 'g-uid-9', email: 'x@gmail.com', signedIn: false);
      final c =
          _container(auth, db, _accionQueLanza(const GoogleIngresoCancelado()));

      final ok =
          await c.read(googleSignInControllerProvider.notifier).ingresar();

      expect(ok, isFalse);
      // Y no deja rastro: sin sesión no hay espejo.
      expect(await _espejo(db, 'g-uid-9'), isNull);
    });

    test('el cierre del popup de Firebase se trata como cancelación', () async {
      for (final code in const [
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-canceled',
        'user-cancelled',
      ]) {
        final db = await buildFakeFirestoreVacio();
        final auth =
            mockAuth(uid: 'g-uid-c', email: 'x@gmail.com', signedIn: false);
        final c = _container(
            auth, db, _accionQueLanza(FirebaseAuthException(code: code)));

        final ok =
            await c.read(googleSignInControllerProvider.notifier).ingresar();

        expect(ok, isFalse, reason: '$code debe tratarse como cancelación');
      }
    });
  });

  group('estado del controlador', () {
    test('queda en AsyncData tras un error (el botón se vuelve a habilitar)',
        () async {
      final db = await buildFakeFirestoreVacio();
      final auth =
          mockAuth(uid: 'g-uid-10', email: 'x@gmail.com', signedIn: false);
      final c = _container(auth, db,
          _accionQueLanza(FirebaseAuthException(code: 'internal-error')));

      await expectLater(
        c.read(googleSignInControllerProvider.notifier).ingresar(),
        throwsA(isA<StateError>()),
      );

      expect(c.read(googleSignInControllerProvider).isLoading, isFalse);
    });
  });
}
