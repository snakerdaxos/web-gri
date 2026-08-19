// core/google_auth.dart — adaptador de Google Sign-In para la app cliente (11-17).
//
// Dos ramas de plataforma DELIBERADAS:
//
//   * Web     → `FirebaseAuth.signInWithPopup(GoogleAuthProvider())`. Firebase
//               resuelve el client ID desde la configuración de la app Web del
//               propio proyecto: no necesita ni la huella SHA-1 ni el client ID
//               en código. Evita además el botón renderizado por
//               `google_sign_in_web`, que obligaría a rediseñar la pantalla
//               (prohibido por la decisión de identidad visual).
//   * Android → plugin `google_sign_in` 7.x con `serverClientId`, para obtener
//               el idToken y canjearlo con `signInWithCredential`.
//
// El panel admin NO usa este archivo: el staff se crea por la callable y sigue
// con email/contraseña.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'google_auth.g.dart';

/// Web client ID de OAuth del proyecto p-gri-b5b40 (número 703827387403).
/// Es una credencial PÚBLICA: viaja en el cliente por diseño y no es un secreto
/// (el client *secret* no se usa en este flujo). Por eso va versionada y NO por
/// --dart-define: un valor por entorno complicaría el arranque sin aportar nada.
/// Se usa como `serverClientId` en Android; en Web no hace falta (ver abajo).
const String googleWebClientId =
    '703827387403-o05u1u7gffibbfqo4419ds3pjcul12g2.apps.googleusercontent.com';

/// El usuario abandonó el flujo (cerró el popup, pulsó atrás en el selector de
/// cuentas). NO es un error: la UI vuelve a la pantalla en silencio.
class GoogleIngresoCancelado implements Exception {
  const GoogleIngresoCancelado();

  @override
  String toString() => 'GoogleIngresoCancelado';
}

/// Códigos con los que Firebase Auth reporta que el usuario cerró el popup.
/// Se tratan como cancelación, no como fallo.
const Set<String> googleCodigosDeCancelacion = {
  'popup-closed-by-user',
  'cancelled-popup-request',
  'web-context-canceled',
  'user-cancelled',
};

/// Firma de la acción de ingreso. Es la COSTURA que los tests inyectan:
/// el handshake real necesita canales de plataforma que no existen en
/// `flutter test`, así que se sustituye por un doble.
typedef GoogleAuthAccion = Future<UserCredential> Function(FirebaseAuth auth);

/// Ejecuta el ingreso con Google en la plataforma actual.
Future<UserCredential> ingresarConGoogle(FirebaseAuth auth) async {
  if (kIsWeb) return _ingresarConGoogleWeb(auth);
  return _ingresarConGoogleNativo(auth);
}

/// Rama WEB — operativa sin ningún trámite pendiente en la consola.
Future<UserCredential> _ingresarConGoogleWeb(FirebaseAuth auth) async {
  try {
    return await auth.signInWithPopup(GoogleAuthProvider());
  } on FirebaseAuthException catch (e) {
    if (googleCodigosDeCancelacion.contains(e.code)) {
      throw const GoogleIngresoCancelado();
    }
    rethrow;
  }
}

/// Rama ANDROID/iOS — plugin `google_sign_in` 7.x.
///
/// Requiere la huella SHA-1 registrada en la app Android `com.gri.gri_cliente`
/// (ver Tarea 4 del plan 11-17); sin ella: DEVELOPER_ERROR / código 10.
Future<UserCredential> _ingresarConGoogleNativo(FirebaseAuth auth) async {
  final signIn = GoogleSignIn.instance;
  // `initialize` es idempotente: puede llamarse en cada ingreso.
  await signIn.initialize(serverClientId: googleWebClientId);

  if (!signIn.supportsAuthenticate()) {
    throw StateError(
      'Esta plataforma no soporta el ingreso interactivo con Google.',
    );
  }

  final GoogleSignInAccount cuenta;
  try {
    // En 7.x `authenticate()` LANZA si el usuario cancela; no devuelve null.
    cuenta = await signIn.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw const GoogleIngresoCancelado();
    }
    rethrow;
  }

  final idToken = cuenta.authentication.idToken;
  if (idToken == null) {
    // Síntoma exacto de un serverClientId mal configurado. Decirlo aquí
    // ahorra horas frente a fallar más adelante con un null opaco.
    throw StateError(
      'Google no devolvió idToken. Revisá que el serverClientId '
      '($googleWebClientId) sea el Web client ID del proyecto y que la huella '
      'SHA-1 esté registrada en la app Android com.gri.gri_cliente.',
    );
  }

  return auth.signInWithCredential(
    GoogleAuthProvider.credential(idToken: idToken),
  );
}

/// Costura inyectable de la acción de ingreso (mismo patrón que 11-07/11-10).
@Riverpod(keepAlive: true)
GoogleAuthAccion googleAuthAccion(Ref ref) => ingresarConGoogle;
