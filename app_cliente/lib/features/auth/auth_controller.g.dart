// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del
/// GoRouter (reemplaza a token_provider.AuthState). Stream nativo del SDK:
/// persistencia + refresh de token gratis.
///
/// Solo `AsyncData` con User no-null cuenta como "logueado" (isLoading y
/// AsyncError se tratan como no logueado — misma defensa que el panel).

@ProviderFor(authState)
final authStateProvider = AuthStateProvider._();

/// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del
/// GoRouter (reemplaza a token_provider.AuthState). Stream nativo del SDK:
/// persistencia + refresh de token gratis.
///
/// Solo `AsyncData` con User no-null cuenta como "logueado" (isLoading y
/// AsyncError se tratan como no logueado — misma defensa que el panel).

final class AuthStateProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  /// Fuente única de verdad de "¿hay sesión?" — la lee el redirect del
  /// GoRouter (reemplaza a token_provider.AuthState). Stream nativo del SDK:
  /// persistencia + refresh de token gratis.
  ///
  /// Solo `AsyncData` con User no-null cuenta como "logueado" (isLoading y
  /// AsyncError se tratan como no logueado — misma defensa que el panel).
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
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return authState(ref);
  }
}

String _$authStateHash() => r'4f403845df0a7b94f769c9a7d5f9b2e890f4960f';

/// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
/// autorización real vive en las Security Rules (threat model del plan).
///
/// `forceRefresh: true` al leer: tras un login los claims frescos (seed)
/// deben estar ya en el token; con mock el rebuild lo dispara el
/// invalidate() de login/registro/logout.

@ProviderFor(claims)
final claimsProvider = ClaimsProvider._();

/// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
/// autorización real vive en las Security Rules (threat model del plan).
///
/// `forceRefresh: true` al leer: tras un login los claims frescos (seed)
/// deben estar ya en el token; con mock el rebuild lo dispara el
/// invalidate() de login/registro/logout.

final class ClaimsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({String? rid, String role})>,
          ({String? rid, String role}),
          FutureOr<({String? rid, String role})>
        >
    with
        $FutureModifier<({String? rid, String role})>,
        $FutureProvider<({String? rid, String role})> {
  /// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
  /// autorización real vive en las Security Rules (threat model del plan).
  ///
  /// `forceRefresh: true` al leer: tras un login los claims frescos (seed)
  /// deben estar ya en el token; con mock el rebuild lo dispara el
  /// invalidate() de login/registro/logout.
  ClaimsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claimsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claimsHash();

  @$internal
  @override
  $FutureProviderElement<({String? rid, String role})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({String? rid, String role})> create(Ref ref) {
    return claims(ref);
  }
}

String _$claimsHash() => r'3920bda560bd9a583f47ad8d8ec1e55e023d63f8';

/// Orquesta el login del cliente: valida ANTES de tocar red, firma con
/// FirebaseAuth y refresca claims. authStateChanges emite → el redirect
/// del goRouter manda a /inicio (sin navegación manual).

@ProviderFor(LoginController)
final loginControllerProvider = LoginControllerProvider._();

/// Orquesta el login del cliente: valida ANTES de tocar red, firma con
/// FirebaseAuth y refresca claims. authStateChanges emite → el redirect
/// del goRouter manda a /inicio (sin navegación manual).
final class LoginControllerProvider
    extends $AsyncNotifierProvider<LoginController, void> {
  /// Orquesta el login del cliente: valida ANTES de tocar red, firma con
  /// FirebaseAuth y refresca claims. authStateChanges emite → el redirect
  /// del goRouter manda a /inicio (sin navegación manual).
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

String _$loginControllerHash() => r'0ee18dd7d6128f420bc7816b6c8c7ec72d4e5020';

/// Orquesta el login del cliente: valida ANTES de tocar red, firma con
/// FirebaseAuth y refresca claims. authStateChanges emite → el redirect
/// del goRouter manda a /inicio (sin navegación manual).

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

/// Orquesta el registro: crea la cuenta (auto-login nativo del SDK),
/// setea el displayName y escribe el ESPEJO `usuarios/{uid}` con role
/// 'cliente' y restauranteId null — NUNCA otro role (las rules lo
/// fuerzan; el doc espejo jamás autoriza, la authz vive en claims).

@ProviderFor(RegisterController)
final registerControllerProvider = RegisterControllerProvider._();

/// Orquesta el registro: crea la cuenta (auto-login nativo del SDK),
/// setea el displayName y escribe el ESPEJO `usuarios/{uid}` con role
/// 'cliente' y restauranteId null — NUNCA otro role (las rules lo
/// fuerzan; el doc espejo jamás autoriza, la authz vive en claims).
final class RegisterControllerProvider
    extends $AsyncNotifierProvider<RegisterController, void> {
  /// Orquesta el registro: crea la cuenta (auto-login nativo del SDK),
  /// setea el displayName y escribe el ESPEJO `usuarios/{uid}` con role
  /// 'cliente' y restauranteId null — NUNCA otro role (las rules lo
  /// fuerzan; el doc espejo jamás autoriza, la authz vive en claims).
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
    r'6b96aedab4cf9b35ed86a35e5a5b5fad7398d421';

/// Orquesta el registro: crea la cuenta (auto-login nativo del SDK),
/// setea el displayName y escribe el ESPEJO `usuarios/{uid}` con role
/// 'cliente' y restauranteId null — NUNCA otro role (las rules lo
/// fuerzan; el doc espejo jamás autoriza, la authz vive en claims).

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

/// Cierra la sesión (perfil). authStateChanges emite null → el
/// refreshListenable del GoRouter redirige a /login.

@ProviderFor(LogoutController)
final logoutControllerProvider = LogoutControllerProvider._();

/// Cierra la sesión (perfil). authStateChanges emite null → el
/// refreshListenable del GoRouter redirige a /login.
final class LogoutControllerProvider
    extends $AsyncNotifierProvider<LogoutController, void> {
  /// Cierra la sesión (perfil). authStateChanges emite null → el
  /// refreshListenable del GoRouter redirige a /login.
  LogoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logoutControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logoutControllerHash();

  @$internal
  @override
  LogoutController create() => LogoutController();
}

String _$logoutControllerHash() => r'bdbcbaee26b2466e56a4a272f09f1cc9e2b36f9e';

/// Cierra la sesión (perfil). authStateChanges emite null → el
/// refreshListenable del GoRouter redirige a /login.

abstract class _$LogoutController extends $AsyncNotifier<void> {
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
