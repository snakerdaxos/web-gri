import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';

part 'login_controller.g.dart';

/// Roles con los que se entra al panel (must_have 10-05): staff entra
/// directo al dashboard de SU restaurante (claims rid); `super_admin`
/// elige restaurante; `cliente` (y cualquier otro) NO entra.
const _rolesStaff = {'admin_restaurante', 'mesero', 'cocina'};

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
    default:
      return fallback;
  }
}

/// Orquesta el login del PANEL: firma con FirebaseAuth y enruta por claims
/// `{role, rid}` (threat model: el cliente NO entra — defense UX; las
/// rules igualmente denegarían toda query staff).
///
/// Enrutado por claims (leídos con `idTokenResult` forceRefresh — evita la
/// carrera del token cacheado):
///  * `super_admin` → OK (el shell muestra el selector de restaurantes).
///  * `admin_restaurante` | `mesero` | `cocina` → OK con rid de claims.
///  * cualquier otro (`cliente`, sin role) → `signOut` + StateError — la
///    sesión NO queda abierta para un usuario que no puede usar el panel.
@riverpod
class LoginController extends _$LoginController {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  FutureOr<void> build() {}

  /// Retorna true si el login fue exitoso. Lanza:
  ///  * [ArgumentError] — validación local (sin red).
  ///  * [StateError] — mensaje de usuario (credenciales, rol, ...).
  Future<bool> submit(String email, String password) async {
    final trimmed = email.trim();
    if (!_emailRe.hasMatch(trimmed)) {
      throw ArgumentError.value(email, 'email', 'Email inválido');
    }
    // POLICY-LOGIN-OK: esto es INICIAR SESIÓN, no fijar una contraseña. La
    // política de 11-22 NO se aplica aquí a propósito — una cuenta creada
    // antes de la política tiene que poder seguir entrando (T-11-22-04).
    if (password.length < 8) {
      throw ArgumentError.value(
        password,
        'password',
        'La contraseña debe tener al menos 8 caracteres',
      );
    }

    state = const AsyncLoading<void>();
    final auth = ref.read(firebaseAuthProvider);
    try {
      await auth.signInWithEmailAndPassword(email: trimmed, password: password);

      // Claims frescos AL INSTANTE (forceRefresh dentro de claimsProvider):
      // el rid de staff decide el dashboard; el super va al selector.
      ref.invalidate(claimsProvider);
      final claims = await ref.read(claimsProvider.future);

      if (claims.role == 'super_admin') {
        return true; // → shell + selector de restaurantes
      }
      if (_rolesStaff.contains(claims.role)) {
        if (claims.rid == null || claims.rid!.isEmpty) {
          await auth.signOut();
          throw StateError(
            'Tu cuenta no tiene restaurante asignado — contacta al '
            'administrador',
          );
        }
        return true; // → dashboard de SU restaurante
      }

      // cliente / sin role: la sesión no se abre en el panel.
      await auth.signOut();
      throw StateError(
        'Esta aplicación es solo para personal del restaurante',
      );
    } on FirebaseAuthException catch (e) {
      throw StateError(
        authErrorMessage(e, fallback: 'Error al iniciar sesión'),
      );
    } finally {
      state = const AsyncData<void>(null);
    }
  }

  /// Cierra la sesión. authStateChanges emite null → el refreshListenable
  /// del GoRouter redirige a /login.
  ///
  /// ── EL `keepAlive` NO ES DEFENSIVO: SIN ÉL ESTO REVIENTA (11-34) ────────
  ///
  /// Este método existía desde 10-05 y nadie lo llamaba (11-34 le puso por
  /// fin un botón, en el topbar del AppShell). Al llamarlo por primera vez
  /// salió su defecto: en Riverpod 3 los providers son autoDispose, y quien
  /// pulsa el botón hace `ref.read(...notifier).logout()` — un `read` NO crea
  /// listener, así que el controlador se crea y queda planificado para
  /// disposición inmediata. Cuando el `await signOut()` vuelve, el notifier
  /// YA está dispuesto y `ref.invalidate(claimsProvider)` lanza:
  ///
  ///   «Cannot use "ref" after the provider was disposed»
  ///
  /// Además del error, el efecto es peor que ruidoso: `claimsProvider` NO se
  /// invalida, así que los claims del usuario que acaba de salir siguen
  /// cacheados. Y en el panel esto pasa SIEMPRE, no de vez en cuando: la
  /// redirección a `/login` desmonta el shell entero mientras el `signOut`
  /// está en vuelo.
  ///
  /// `keepAlive()` retiene el provider durante la operación y `link.close()`
  /// lo devuelve a su comportamiento normal. Lo cubre el caso «RECORRIDO
  /// COMPLETO» de `test/shared/cerrar_sesion_test.dart`, que se pone rojo si
  /// se quita esta línea.
  Future<void> logout() async {
    final link = ref.keepAlive();
    try {
      await ref.read(firebaseAuthProvider).signOut();
      ref.invalidate(claimsProvider);
    } finally {
      link.close();
    }
  }
}
