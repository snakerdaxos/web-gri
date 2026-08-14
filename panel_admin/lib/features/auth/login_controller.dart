import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/token_provider.dart';

part 'login_controller.g.dart';

/// Orquesta el login: valida ANTES de tocar red, escribe tokens en storage,
/// invalida authState (dispara el redirect del goRouter al dashboard).
///
/// Es la ÚNICA puerta de escritura de tokens desde UI (T-04-07).
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
      // Rebuild del authState → refreshListenable → redirect a '/'.
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
