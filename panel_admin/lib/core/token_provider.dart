import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'auth_storage.dart';

part 'token_provider.g.dart';

/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del GoRouter.
///
/// build(): storage sin tokens → null (no autenticado). Con tokens → valida
/// contra `GET /auth/me`; cualquier error (incluye 401 con refresh fallido
/// vía interceptor) → clear storage + null (T-04-08: solo AsyncData con User
/// no-null cuenta como "logueado").
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    final storage = ref.read(authStorageProvider);
    final client = ref.read(apiClientProvider);

    // Cablea el logout upstream: refresh fallido en el interceptor → sesión
    // muerta → state null → redirect a /login (T-04-06).
    client.onSessionExpired = _handleSessionExpired;

    final access = await storage.readAccess();
    final refresh = await storage.readRefresh();
    if (access == null || refresh == null) return null;

    try {
      return await client.me();
    } catch (_) {
      await storage.clear();
      return null;
    }
  }

  Future<void> _handleSessionExpired() async {
    await ref.read(authStorageProvider).clear();
    state = const AsyncData(null);
  }

  Future<void> logout() => _handleSessionExpired();
}
