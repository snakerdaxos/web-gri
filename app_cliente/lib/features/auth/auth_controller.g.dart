// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orquesta el login del cliente: valida ANTES de tocar red, escribe tokens
/// en storage, invalida authState (dispara el redirect del goRouter).

@ProviderFor(LoginController)
final loginControllerProvider = LoginControllerProvider._();

/// Orquesta el login del cliente: valida ANTES de tocar red, escribe tokens
/// en storage, invalida authState (dispara el redirect del goRouter).
final class LoginControllerProvider
    extends $AsyncNotifierProvider<LoginController, void> {
  /// Orquesta el login del cliente: valida ANTES de tocar red, escribe tokens
  /// en storage, invalida authState (dispara el redirect del goRouter).
  LoginControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginControllerHash();

  @$internal
  @override
  LoginController create() => LoginController();
}

String _$loginControllerHash() => r'463450fbc33ab6c79b52d47ddf0b5cb8c831c534';

/// Orquesta el login del cliente: valida ANTES de tocar red, escribe tokens
/// en storage, invalida authState (dispara el redirect del goRouter).

abstract class _$LoginController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Orquesta el registro del cliente: valida local, crea la cuenta
/// (`POST /auth/register`) y hace AUTO-LOGIN (login inmediato para obtener
/// los JWTs) — el usuario aterriza logueado en /inicio.

@ProviderFor(RegisterController)
final registerControllerProvider = RegisterControllerProvider._();

/// Orquesta el registro del cliente: valida local, crea la cuenta
/// (`POST /auth/register`) y hace AUTO-LOGIN (login inmediato para obtener
/// los JWTs) — el usuario aterriza logueado en /inicio.
final class RegisterControllerProvider
    extends $AsyncNotifierProvider<RegisterController, void> {
  /// Orquesta el registro del cliente: valida local, crea la cuenta
  /// (`POST /auth/register`) y hace AUTO-LOGIN (login inmediato para obtener
  /// los JWTs) — el usuario aterriza logueado en /inicio.
  RegisterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'registerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$registerControllerHash();

  @$internal
  @override
  RegisterController create() => RegisterController();
}

String _$registerControllerHash() =>
    r'a90b5c7e842b0ad6bfd6b6209b9718d9274c2062';

/// Orquesta el registro del cliente: valida local, crea la cuenta
/// (`POST /auth/register`) y hace AUTO-LOGIN (login inmediato para obtener
/// los JWTs) — el usuario aterriza logueado en /inicio.

abstract class _$RegisterController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
