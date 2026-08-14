// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del GoRouter.
///
/// build(): storage sin tokens → null (no autenticado). Con tokens → valida
/// contra `GET /auth/me`; cualquier error (incluye 401 con refresh fallido
/// vía interceptor) → clear storage + null (T-04-08: solo AsyncData con User
/// no-null cuenta como "logueado").

@ProviderFor(AuthState)
final authStateProvider = AuthStateProvider._();

/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del GoRouter.
///
/// build(): storage sin tokens → null (no autenticado). Con tokens → valida
/// contra `GET /auth/me`; cualquier error (incluye 401 con refresh fallido
/// vía interceptor) → clear storage + null (T-04-08: solo AsyncData con User
/// no-null cuenta como "logueado").
final class AuthStateProvider extends $AsyncNotifierProvider<AuthState, User?> {
  /// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del GoRouter.
  ///
  /// build(): storage sin tokens → null (no autenticado). Con tokens → valida
  /// contra `GET /auth/me`; cualquier error (incluye 401 con refresh fallido
  /// vía interceptor) → clear storage + null (T-04-08: solo AsyncData con User
  /// no-null cuenta como "logueado").
  AuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  AuthState create() => AuthState();
}

String _$authStateHash() => r'9102916493c66e8e331f7abb5cdf9a5b09ef8a69';

/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del GoRouter.
///
/// build(): storage sin tokens → null (no autenticado). Con tokens → valida
/// contra `GET /auth/me`; cualquier error (incluye 401 con refresh fallido
/// vía interceptor) → clear storage + null (T-04-08: solo AsyncData con User
/// no-null cuenta como "logueado").

abstract class _$AuthState extends $AsyncNotifier<User?> {
  FutureOr<User?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<User?>, User?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<User?>, User?>,
              AsyncValue<User?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
