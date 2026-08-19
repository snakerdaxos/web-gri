import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/google_auth.dart';

part 'auth_controller.g.dart';

/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del
/// GoRouter (sustituyó al AuthState de la era REST). Stream nativo del SDK:
/// persistencia + refresh de token gratis.
///
/// Solo `AsyncData` con User no-null cuenta como "logueado" (isLoading y
/// AsyncError se tratan como no logueado — misma defensa que el panel).
@Riverpod(keepAlive: true)
Stream<User?> authState(Ref ref) =>
    ref.watch(firebaseAuthProvider).authStateChanges();

/// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
/// autorización real vive en las Security Rules (threat model del plan).
///
/// `forceRefresh: true` al leer: tras un login los claims frescos (seed)
/// deben estar ya en el token; con mock el rebuild lo dispara el
/// invalidate() de login/registro/logout.
@riverpod
Future<({String role, String? rid})> claims(Ref ref) async {
  // Rebuild en cada cambio de sesión (login/logout).
  ref.watch(authStateProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return (role: 'invitado', rid: null);

  final token = await user.getIdTokenResult(true);
  final c = token.claims ?? const <String, dynamic>{};
  // Ausencia de role == cliente (regla `isCliente()` de firestore.rules).
  return (
    role: c['role'] as String? ?? 'cliente',
    rid: c['rid'] as String?,
  );
}

/// Mapea FirebaseAuthException → mensaje humano (la UI muestra
/// StateError.message tal cual; contrato igual que la era dio).
String authErrorMessage(FirebaseAuthException e, {required String fallback}) {
  switch (e.code) {
    case 'invalid-credential': // firebase_auth 6.x unifica user/pass malos
    case 'invalid-login-credentials':
    case 'wrong-password':
    case 'user-not-found':
    case 'user-disabled':
      return 'Credenciales inválidas';
    case 'network-request-failed':
      return 'Sin conexión — verificá tu internet e intentá de nuevo';
    case 'too-many-requests':
      return 'Demasiados intentos — esperá un momento';
    case 'invalid-email':
      return 'Email inválido';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con este email';
    case 'weak-password':
      return 'La contraseña es muy débil';
    default:
      return fallback;
  }
}

/// Orquesta el login del cliente: valida ANTES de tocar red, firma con
/// FirebaseAuth y refresca claims. authStateChanges emite → el redirect
/// del goRouter manda a /inicio (sin navegación manual).
@riverpod
class LoginController extends _$LoginController {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  FutureOr<void> build() {}

  /// Retorna true si el login fue exitoso. Lanza:
  ///  * [ArgumentError] — validación local (sin red).
  ///  * [StateError] — mensaje de usuario (credenciales, red, ...).
  Future<bool> submit(String email, String password) async {
    final trimmed = email.trim();
    if (!_emailRe.hasMatch(trimmed)) {
      throw ArgumentError.value(email, 'email', 'Email inválido');
    }
    if (password.length < 8) {
      throw ArgumentError.value(
        password,
        'password',
        'La contraseña debe tener al menos 8 caracteres',
      );
    }

    state = const AsyncLoading<void>();
    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: trimmed,
            password: password,
          );
      ref.invalidate(claimsProvider);
      return true;
    } on FirebaseAuthException catch (e) {
      throw StateError(
        authErrorMessage(e, fallback: 'Error al iniciar sesión'),
      );
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}

/// Orquesta el registro: crea la cuenta (auto-login nativo del SDK),
/// setea el displayName y escribe el ESPEJO `usuarios/{uid}` con role
/// 'cliente' y restauranteId null — NUNCA otro role (las rules lo
/// fuerzan; el doc espejo jamás autoriza, la authz vive en claims).
@riverpod
class RegisterController extends _$RegisterController {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  FutureOr<void> build() {}

  Future<bool> submit(String nombre, String email, String password) async {
    final trimmedNombre = nombre.trim();
    final trimmedEmail = email.trim();
    if (trimmedNombre.isEmpty) {
      throw ArgumentError.value(nombre, 'nombre', 'El nombre es obligatorio');
    }
    if (!_emailRe.hasMatch(trimmedEmail)) {
      throw ArgumentError.value(email, 'email', 'Email inválido');
    }
    if (password.length < 8) {
      throw ArgumentError.value(
        password,
        'password',
        'La contraseña debe tener al menos 8 caracteres',
      );
    }

    state = const AsyncLoading<void>();
    try {
      final auth = ref.read(firebaseAuthProvider);
      final cred = await auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw StateError('No se pudo crear la cuenta');
      }
      await user.updateDisplayName(trimmedNombre);

      // Espejo de perfil — mismo shape que scripts/seed_firebase.mjs.
      await ref
          .read(firestoreProvider)
          .collection('usuarios')
          .doc(user.uid)
          .set({
        'nombre': trimmedNombre,
        'email': trimmedEmail,
        'role': 'cliente',
        'restauranteId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ref.invalidate(claimsProvider);
      return true;
    } on FirebaseAuthException catch (e) {
      throw StateError(
        authErrorMessage(e, fallback: 'No se pudo crear la cuenta'),
      );
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}

/// Mensaje de usuario para un fallo del ingreso con Google. Delega en
/// [authErrorMessage] salvo la colisión de cuentas, que es específica de un
/// proveedor federado y necesita decirle al usuario QUÉ hacer.
String googleAuthErrorMessage(FirebaseAuthException e) {
  if (e.code == 'account-exists-with-different-credential') {
    return 'Ya tienes una cuenta con ese correo y contraseña. '
        'Inicia sesión con tu contraseña.';
  }
  return authErrorMessage(e, fallback: 'No se pudo iniciar sesión con Google');
}

/// Nombre del perfil a partir de la cuenta de Google. NUNCA vacío ni nulo:
/// displayName → parte local del correo → 'Cliente'.
String nombreDesdeCuentaGoogle(User user) {
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  final local = (user.email ?? '').trim().split('@').first.trim();
  if (local.isNotEmpty) return local;
  return 'Cliente';
}

/// Orquesta el ingreso/registro con Google del CLIENTE (11-17).
///
/// Tras el handshake crea el ESPEJO `usuarios/{uid}` **solo si no existe**,
/// con la MISMA forma que [RegisterController.submit] — `role: 'cliente'` y
/// `restauranteId: null`, que es justo lo que exige el create de
/// `firestore.rules`. Un usuario de Google NO obtiene claims: es cliente por
/// ausencia de claim, igual que un auto-registro.
///
/// El handshake en sí vive detrás de `googleAuthAccionProvider` para poder
/// inyectarlo en tests (ver la cabecera de test/auth/google_signin_test.dart).
@riverpod
class GoogleSignInController extends _$GoogleSignInController {
  @override
  FutureOr<void> build() {}

  /// `true` si se ingresó, `false` si el usuario canceló (que NO es un error).
  /// Lanza [StateError] con un mensaje ya traducido para todo lo demás.
  Future<bool> ingresar() async {
    state = const AsyncLoading<void>();
    try {
      final auth = ref.read(firebaseAuthProvider);
      final cred = await ref.read(googleAuthAccionProvider)(auth);
      final user = cred.user;
      if (user == null) {
        throw StateError('No se pudo iniciar sesión con Google');
      }
      await _crearEspejoSiNoExiste(user);
      ref.invalidate(claimsProvider);
      return true;
    } on GoogleIngresoCancelado {
      return false;
    } on FirebaseAuthException catch (e) {
      // Defensa en profundidad: si la cancelación llega como código crudo
      // (no traducida por el adaptador) tampoco debe verse como un error.
      if (googleCodigosDeCancelacion.contains(e.code)) return false;
      throw StateError(googleAuthErrorMessage(e));
    } finally {
      state = const AsyncData<void>(null);
    }
  }

  /// Espejo de perfil — mismo shape que [RegisterController.submit] y que
  /// scripts/seed_firebase.mjs. Si el doc YA existe no se toca: el usuario
  /// pudo editar su nombre y un segundo ingreso no debe pisarlo.
  Future<void> _crearEspejoSiNoExiste(User user) async {
    final doc =
        ref.read(firestoreProvider).collection('usuarios').doc(user.uid);
    final snap = await doc.get();
    if (snap.exists) return;
    await doc.set({
      'nombre': nombreDesdeCuentaGoogle(user),
      'email': user.email ?? '',
      'role': 'cliente',
      'restauranteId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Cierra la sesión (perfil). authStateChanges emite null → el
/// refreshListenable del GoRouter redirige a /login.
@riverpod
class LogoutController extends _$LogoutController {
  @override
  FutureOr<void> build() {}

  Future<void> logout() async {
    await ref.read(firebaseAuthProvider).signOut();
    ref.invalidate(claimsProvider);
  }
}
