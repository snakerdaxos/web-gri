import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';

part 'bootstrap_controller.g.dart';

/// Acción completa del bootstrap: crear la cuenta, invocar la callable,
/// refrescar los claims y —si algo falla— revertir.
///
/// Es una COSTURA inyectable: la pantalla la lee del provider, así que los
/// tests de formulario la sustituyen por un doble y no necesitan Firebase.
typedef BootstrapAccion = Future<void> Function({
  required String nombre,
  required String email,
  required String password,
  required String secreto,
});

/// Costura de la callable sola. Existe porque `FirebaseFunctions` no se puede
/// instanciar en `flutter test` (exige una app Firebase inicializada): sin
/// ella, la acción REAL sería inejecutable en tests y todo lo que hace —la
/// invalidación de claims y la reversión de la cuenta— quedaría afirmado en
/// vez de verificado.
typedef BootstrapCallable = Future<void> Function(Map<String, dynamic> payload);

/// Error con mensaje ya traducido y listo para pintar.
class BootstrapException implements Exception {
  const BootstrapException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Mensajes de la callable. Los CINCO motivos de denegación del servidor
/// comparten un único `permission-denied` con un texto idéntico a propósito
/// (la función no revela cuál falló), así que aquí solo se puede enumerar lo
/// que el usuario debe revisar.
const _msgPermissionDenied =
    'No se pudo inicializar: revisa el correo, que esté verificado, y el secreto.';
const _msgFailedPrecondition =
    'Falta configurar la inicialización en el despliegue.';
const _msgUnauthenticated = 'Vuelve a intentarlo.';
const _msgGenerico = 'No se pudo inicializar la plataforma. Intenta de nuevo.';

String _mensajeCallable(String code) => switch (code) {
      'permission-denied' => _msgPermissionDenied,
      'failed-precondition' => _msgFailedPrecondition,
      'unauthenticated' => _msgUnauthenticated,
      _ => _msgGenerico,
    };

String _mensajeAuth(FirebaseAuthException e) => switch (e.code) {
      'weak-password' => 'La contraseña es demasiado débil.',
      'invalid-email' => 'Correo inválido.',
      'invalid-credential' ||
      'wrong-password' =>
        'Ese correo ya existe y la contraseña no coincide.',
      'network-request-failed' => 'Sin conexión — revisa tu internet.',
      'too-many-requests' => 'Demasiados intentos — esperá un momento.',
      'operation-not-allowed' =>
        'El registro con correo y contraseña está deshabilitado en el proyecto.',
      _ => 'No se pudo crear la cuenta. Intenta de nuevo.',
    };

/// Invocación real de `bootstrapPlataforma`.
///
/// El payload lleva SOLO `nombre` y `secreto`: la función promueve al llamador
/// autenticado y no acepta uid ni correo de destino (T-11-07-03). La región la
/// fija `firebaseFunctionsProvider`.
@Riverpod(keepAlive: true)
BootstrapCallable bootstrapCallable(Ref ref) {
  return (payload) async {
    await ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('bootstrapPlataforma')
        .call<Object?>(payload);
  };
}

/// Implementación real de [BootstrapAccion].
///
/// `keepAlive` a propósito: la pantalla la obtiene con `ref.read` en el
/// submit, sin observarla. Con autoDispose el provider podría descartarse
/// mientras el cierre sigue en vuelo y el `ref.read` de dentro reventaría.
@Riverpod(keepAlive: true)
BootstrapAccion bootstrapAccion(Ref ref) {
  return ({
    required String nombre,
    required String email,
    required String password,
    required String secreto,
  }) async {
    final auth = ref.read(firebaseAuthProvider);
    final correo = email.trim().toLowerCase();

    // --- 1. Cuenta ----------------------------------------------------------
    // `cuentaCreadaAqui` decide si la reversión puede borrar la cuenta.
    // Borrar una cuenta que ya existía sería destruir datos de otra persona.
    var cuentaCreadaAqui = true;
    try {
      await auth.createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') {
        throw BootstrapException(_mensajeAuth(e));
      }
      cuentaCreadaAqui = false;
      try {
        await auth.signInWithEmailAndPassword(
          email: correo,
          password: password,
        );
      } on FirebaseAuthException catch (e2) {
        throw BootstrapException(_mensajeAuth(e2));
      }
    }

    // OJO: `createUserWithEmailAndPassword` acaba de emitir un evento de
    // `authStateChanges`. El guard del router lo escucha vía `refreshListenable`
    // y, si `/bootstrap` no estuviera exenta, expulsaría al usuario AHORA
    // MISMO — con la callable todavía en vuelo y la reversión de abajo sin
    // pantalla donde ejecutarse. Ver `app.dart`.

    // --- 2. Callable --------------------------------------------------------
    try {
      await ref.read(bootstrapCallableProvider)({
        'nombre': nombre.trim(),
        'secreto': secreto,
      });
    } on FirebaseFunctionsException catch (e) {
      await _revertir(auth, cuentaCreadaAqui);
      throw BootstrapException(_mensajeCallable(e.code));
    } catch (_) {
      await _revertir(auth, cuentaCreadaAqui);
      throw const BootstrapException(_msgGenerico);
    }

    // A partir de aquí la persona YA es super_admin en el servidor: nada de
    // lo que siga puede revertir la cuenta.

    // --- 3. Claims frescos --------------------------------------------------
    // SIN este `invalidate` el nuevo super_admin aterriza en el panel como
    // `cliente`: `claimsProvider` es keepAlive y solo se recomputa cuando emite
    // `authStateChanges`; `getIdToken(true)` refresca el token pero NO genera
    // un evento de auth, así que el provider seguiría devolviendo el valor
    // cacheado. Precedente idéntico en
    // `features/auth/login_controller.dart:76`.
    ref.invalidate(claimsProvider);
    await ref.read(claimsProvider.future);
  };
}

/// Deshace el alta de cuenta cuando el bootstrap no llegó a completarse.
///
/// Sin esto quedaría una cuenta sin claims y —si el centinela llegó a
/// crearse— una plataforma bloqueada. Los errores de la propia reversión se
/// tragan a propósito: el error que debe ver el usuario es el original.
Future<void> _revertir(FirebaseAuth auth, bool cuentaCreadaAqui) async {
  if (!cuentaCreadaAqui) return;
  try {
    await auth.currentUser?.delete();
  } catch (_) {
    // La cuenta puede requerir re-autenticación reciente para borrarse.
  }
  try {
    await auth.signOut();
  } catch (_) {
    // Nada que hacer: el error relevante es el de la callable.
  }
}
