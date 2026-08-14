import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/token_provider.dart';

part 'auth_controller.g.dart';

/// Orquesta el login del cliente: valida ANTES de tocar red, escribe tokens
/// en storage, invalida authState (dispara el redirect del goRouter).
@riverpod
class LoginController extends _$LoginController {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  FutureOr<void> build() {}

  /// Retorna true si el login fue exitoso. Lanza:
  ///  * [ArgumentError] — validación local (sin red).
  ///  * [StateError] 'Credenciales inválidas' — 401 del API.
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
      final pair = await ref.read(apiClientProvider).login(trimmed, password);
      await ref.read(authStorageProvider).write(pair.access, pair.refresh);
      // Rebuild del authState → refreshListenable → redirect a /inicio.
      ref.invalidate(authStateProvider);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw StateError('Credenciales inválidas');
      }
      rethrow;
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}

/// Orquesta el registro del cliente: valida local, crea la cuenta
/// (`POST /auth/register`) y hace AUTO-LOGIN (login inmediato para obtener
/// los JWTs) — el usuario aterriza logueado en /inicio.
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
      final client = ref.read(apiClientProvider);
      await client.register(trimmedNombre, trimmedEmail, password);
      // Auto-login: la cuenta ya existe → JWTs → sesión iniciada.
      final pair = await client.login(trimmedEmail, password);
      await ref.read(authStorageProvider).write(pair.access, pair.refresh);
      ref.invalidate(authStateProvider);
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 409) {
        final data = e.response?.data;
        final detail = data is Map ? data['detail'] : null;
        throw StateError(detail?.toString() ?? 'No se pudo crear la cuenta');
      }
      rethrow;
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
