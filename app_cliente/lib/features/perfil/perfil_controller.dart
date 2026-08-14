import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';

part 'perfil_controller.g.dart';

/// Edición del perfil del cliente (AUTH-05): PATCH /cliente/perfil con
/// nombre (siempre) y password (solo si el user la escribió — el email es
/// immutable server-side y jamás se envía).
@riverpod
class PerfilController extends _$PerfilController {
  @override
  FutureOr<void> build() {}

  /// Retorna true si el update fue exitoso. Lanza [StateError] con el
  /// detail del backend ante 400/422.
  Future<bool> updatePerfil(String nombre, String? password) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(nombre, 'nombre', 'El nombre es obligatorio');
    }

    state = const AsyncLoading<void>();
    try {
      await ref.read(apiClientProvider).updatePerfil(
            nombre: trimmed,
            password: (password != null && password.isNotEmpty)
                ? password
                : null,
          );
      // Rebuild del authState → la UI (home, shell) ve el nombre nuevo.
      ref.invalidate(authStateProvider);
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 422) {
        final data = e.response?.data;
        final detail = data is Map ? data['detail'] : null;
        throw StateError(detail?.toString() ?? 'No se pudo guardar el perfil');
      }
      rethrow;
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
