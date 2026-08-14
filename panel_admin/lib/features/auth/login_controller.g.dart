// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orquesta el login: valida ANTES de tocar red, escribe tokens en storage,
/// invalida authState (dispara el redirect del goRouter al dashboard).
///
/// Es la ÚNICA puerta de escritura de tokens desde UI (T-04-07).

@ProviderFor(LoginController)
final loginControllerProvider = LoginControllerProvider._();

/// Orquesta el login: valida ANTES de tocar red, escribe tokens en storage,
/// invalida authState (dispara el redirect del goRouter al dashboard).
///
/// Es la ÚNICA puerta de escritura de tokens desde UI (T-04-07).
final class LoginControllerProvider
    extends $AsyncNotifierProvider<LoginController, void> {
  /// Orquesta el login: valida ANTES de tocar red, escribe tokens en storage,
  /// invalida authState (dispara el redirect del goRouter al dashboard).
  ///
  /// Es la ÚNICA puerta de escritura de tokens desde UI (T-04-07).
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

/// Orquesta el login: valida ANTES de tocar red, escribe tokens en storage,
/// invalida authState (dispara el redirect del goRouter al dashboard).
///
/// Es la ÚNICA puerta de escritura de tokens desde UI (T-04-07).

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
