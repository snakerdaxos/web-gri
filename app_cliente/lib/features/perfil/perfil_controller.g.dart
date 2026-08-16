// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'perfil_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Perfil visible del cliente: `usuarios/{uid}` (fuente del nombre) con
/// fallback al Auth user. Se rebuild al cambiar la sesión y tras guardar
/// (invalidate desde el controller).

@ProviderFor(perfil)
final perfilProvider = PerfilProvider._();

/// Perfil visible del cliente: `usuarios/{uid}` (fuente del nombre) con
/// fallback al Auth user. Se rebuild al cambiar la sesión y tras guardar
/// (invalidate desde el controller).

final class PerfilProvider
    extends
        $FunctionalProvider<
          AsyncValue<({String email, String nombre})>,
          ({String email, String nombre}),
          FutureOr<({String email, String nombre})>
        >
    with
        $FutureModifier<({String email, String nombre})>,
        $FutureProvider<({String email, String nombre})> {
  /// Perfil visible del cliente: `usuarios/{uid}` (fuente del nombre) con
  /// fallback al Auth user. Se rebuild al cambiar la sesión y tras guardar
  /// (invalidate desde el controller).
  PerfilProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'perfilProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$perfilHash();

  @$internal
  @override
  $FutureProviderElement<({String email, String nombre})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({String email, String nombre})> create(Ref ref) {
    return perfil(ref);
  }
}

String _$perfilHash() => r'9e3a5d42ec45f928e96b4402387ab53757a336ee';

/// Edición del perfil del cliente (AUTH-05 sobre Firebase):
/// * [actualizarNombre] — update `usuarios/{uid}` TOCANDO SOLO 'nombre'
///   (las rules congelan role/restauranteId/email);
/// * [cambiarPassword] — re-autenticación con la password actual y luego
///   updatePassword (requiere login reciente: el re-auth va primero).

@ProviderFor(PerfilController)
final perfilControllerProvider = PerfilControllerProvider._();

/// Edición del perfil del cliente (AUTH-05 sobre Firebase):
/// * [actualizarNombre] — update `usuarios/{uid}` TOCANDO SOLO 'nombre'
///   (las rules congelan role/restauranteId/email);
/// * [cambiarPassword] — re-autenticación con la password actual y luego
///   updatePassword (requiere login reciente: el re-auth va primero).
final class PerfilControllerProvider
    extends $AsyncNotifierProvider<PerfilController, void> {
  /// Edición del perfil del cliente (AUTH-05 sobre Firebase):
  /// * [actualizarNombre] — update `usuarios/{uid}` TOCANDO SOLO 'nombre'
  ///   (las rules congelan role/restauranteId/email);
  /// * [cambiarPassword] — re-autenticación con la password actual y luego
  ///   updatePassword (requiere login reciente: el re-auth va primero).
  PerfilControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'perfilControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$perfilControllerHash();

  @$internal
  @override
  PerfilController create() => PerfilController();
}

String _$perfilControllerHash() => r'2ccf73accf21b9e25d6df549e0d273853bff0250';

/// Edición del perfil del cliente (AUTH-05 sobre Firebase):
/// * [actualizarNombre] — update `usuarios/{uid}` TOCANDO SOLO 'nombre'
///   (las rules congelan role/restauranteId/email);
/// * [cambiarPassword] — re-autenticación con la password actual y luego
///   updatePassword (requiere login reciente: el re-auth va primero).

abstract class _$PerfilController extends $AsyncNotifier<void> {
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
