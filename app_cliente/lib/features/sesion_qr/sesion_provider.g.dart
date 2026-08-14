// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Sesión de mesa activa del usuario (o null) — `GET /cliente/sesiones/actual`.
///
/// keepAlive como [AuthState]: la sesión debe sobrevivir la navegación entre
/// tabs y pantallas (home banner / menú / pedidos la observan). Un 404 del
/// backend se traduce a null (sin sesión), cualquier otro error queda como
/// AsyncError — los watchers leen `.value` y lo tratan como "sin sesión".

@ProviderFor(sesion)
final sesionProvider = SesionProvider._();

/// Sesión de mesa activa del usuario (o null) — `GET /cliente/sesiones/actual`.
///
/// keepAlive como [AuthState]: la sesión debe sobrevivir la navegación entre
/// tabs y pantallas (home banner / menú / pedidos la observan). Un 404 del
/// backend se traduce a null (sin sesión), cualquier otro error queda como
/// AsyncError — los watchers leen `.value` y lo tratan como "sin sesión".

final class SesionProvider
    extends
        $FunctionalProvider<
          AsyncValue<SesionMesa?>,
          SesionMesa?,
          FutureOr<SesionMesa?>
        >
    with $FutureModifier<SesionMesa?>, $FutureProvider<SesionMesa?> {
  /// Sesión de mesa activa del usuario (o null) — `GET /cliente/sesiones/actual`.
  ///
  /// keepAlive como [AuthState]: la sesión debe sobrevivir la navegación entre
  /// tabs y pantallas (home banner / menú / pedidos la observan). Un 404 del
  /// backend se traduce a null (sin sesión), cualquier otro error queda como
  /// AsyncError — los watchers leen `.value` y lo tratan como "sin sesión".
  SesionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sesionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sesionHash();

  @$internal
  @override
  $FutureProviderElement<SesionMesa?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SesionMesa?> create(Ref ref) {
    return sesion(ref);
  }
}

String _$sesionHash() => r'e7ac9ae7b5424947e64de93cb95fb7b1e5f45b98';

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// Los errores (404 código inexistente / 409 mesa ocupada / limpieza /
/// sesión en otra mesa) se propagan a la screen, que muestra el `detail`
/// del server en un SnackBar rojo — nunca crash.

@ProviderFor(SesionController)
final sesionControllerProvider = SesionControllerProvider._();

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// Los errores (404 código inexistente / 409 mesa ocupada / limpieza /
/// sesión en otra mesa) se propagan a la screen, que muestra el `detail`
/// del server en un SnackBar rojo — nunca crash.
final class SesionControllerProvider
    extends $AsyncNotifierProvider<SesionController, void> {
  /// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
  ///
  /// Los errores (404 código inexistente / 409 mesa ocupada / limpieza /
  /// sesión en otra mesa) se propagan a la screen, que muestra el `detail`
  /// del server en un SnackBar rojo — nunca crash.
  SesionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sesionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sesionControllerHash();

  @$internal
  @override
  SesionController create() => SesionController();
}

String _$sesionControllerHash() => r'7f55957481fcd6922d636647115030c8a96f8a47';

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// Los errores (404 código inexistente / 409 mesa ocupada / limpieza /
/// sesión en otra mesa) se propagan a la screen, que muestra el `detail`
/// del server en un SnackBar rojo — nunca crash.

abstract class _$SesionController extends $AsyncNotifier<void> {
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
