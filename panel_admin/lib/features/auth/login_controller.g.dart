// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(LoginController)
final loginControllerProvider = LoginControllerProvider._();

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
final class LoginControllerProvider
    extends $AsyncNotifierProvider<LoginController, void> {
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

String _$loginControllerHash() => r'06d871d292f391c9560ce675de1af56b431d0ce0';

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
