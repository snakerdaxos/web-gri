import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/auth_controller.dart';
import '../../core/firebase_providers.dart';

part 'perfil_controller.g.dart';

/// Perfil visible del cliente: `usuarios/{uid}` (fuente del nombre) con
/// fallback al Auth user. Se rebuild al cambiar la sesión y tras guardar
/// (invalidate desde el controller).
@riverpod
Future<({String nombre, String email})> perfil(Ref ref) async {
  ref.watch(authStateProvider); // rebuild en login/logout
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    throw StateError('Sesión no iniciada');
  }

  final doc = await ref
      .read(firestoreProvider)
      .collection('usuarios')
      .doc(user.uid)
      .get();
  final data = doc.data();
  return (
    nombre: (data?['nombre'] as String?) ?? user.displayName ?? '',
    email: (data?['email'] as String?) ?? user.email ?? '',
  );
}

/// Edición del perfil del cliente (AUTH-05 sobre Firebase):
/// * [actualizarNombre] — update `usuarios/{uid}` TOCANDO SOLO 'nombre'
///   (las rules congelan role/restauranteId/email);
/// * [cambiarPassword] — re-autenticación con la password actual y luego
///   updatePassword (requiere login reciente: el re-auth va primero).
@riverpod
class PerfilController extends _$PerfilController {
  @override
  FutureOr<void> build() {}

  /// Retorna true si el update fue exitoso. Lanza [ArgumentError] si el
  /// nombre está vacío; [StateError] con mensaje de usuario ante errores.
  Future<bool> actualizarNombre(String nombre) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(nombre, 'nombre', 'El nombre es obligatorio');
    }

    state = const AsyncLoading<void>();
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        throw StateError('Sesión no iniciada');
      }
      // SOLO el campo nombre — el diff de rules (`hasOnly(['nombre'])`)
      // rechazaría cualquier otra key.
      await ref
          .read(firestoreProvider)
          .collection('usuarios')
          .doc(user.uid)
          .update({'nombre': trimmed});
      ref.invalidate(perfilProvider);
      return true;
    } on FirebaseException catch (e) {
      // Firestore errors (update del doc espejo).
      throw StateError(
        switch (e.code) {
          'permission-denied' => 'No tenés permisos para guardar el perfil',
          'unavailable' => 'Sin conexión — verificá tu internet',
          _ => 'No se pudo guardar el perfil',
        },
      );
    } finally {
      state = const AsyncData<void>(null);
    }
  }

  /// Cambia la contraseña: re-autentica con email+actual y recién ahí
  /// updatePassword. 'wrong-password' → 'Contraseña actual incorrecta';
  /// 'requires-recent-login' no debería llegar (el re-auth ya se hizo).
  Future<bool> cambiarPassword(String actual, String nueva) async {
    if (nueva.length < 8) {
      throw ArgumentError.value(
        nueva,
        'password',
        'La contraseña debe tener al menos 8 caracteres',
      );
    }

    state = const AsyncLoading<void>();
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        throw StateError('Sesión no iniciada');
      }
      final email = user.email;
      if (email == null) {
        throw StateError('No se pudo verificar tu identidad');
      }

      // Re-auth primero (updatePassword exige login reciente).
      final cred = EmailAuthProvider.credential(email: email, password: actual);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(nueva);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw StateError('Contraseña actual incorrecta');
      }
      if (e.code == 'requires-recent-login') {
        // No debería ocurrir: el re-auth va primero. Mensaje defensivo.
        throw StateError('Iniciá sesión de nuevo y probá otra vez');
      }
      throw StateError(
        authErrorMessage(e, fallback: 'No se pudo cambiar la contraseña'),
      );
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
