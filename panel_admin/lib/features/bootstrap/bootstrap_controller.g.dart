// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Invocación real de `bootstrapPlataforma`.
///
/// El payload lleva SOLO `nombre` y `secreto`: la función promueve al llamador
/// autenticado y no acepta uid ni correo de destino (T-11-07-03). La región la
/// fija `firebaseFunctionsProvider`.

@ProviderFor(bootstrapCallable)
final bootstrapCallableProvider = BootstrapCallableProvider._();

/// Invocación real de `bootstrapPlataforma`.
///
/// El payload lleva SOLO `nombre` y `secreto`: la función promueve al llamador
/// autenticado y no acepta uid ni correo de destino (T-11-07-03). La región la
/// fija `firebaseFunctionsProvider`.

final class BootstrapCallableProvider
    extends
        $FunctionalProvider<
          BootstrapCallable,
          BootstrapCallable,
          BootstrapCallable
        >
    with $Provider<BootstrapCallable> {
  /// Invocación real de `bootstrapPlataforma`.
  ///
  /// El payload lleva SOLO `nombre` y `secreto`: la función promueve al llamador
  /// autenticado y no acepta uid ni correo de destino (T-11-07-03). La región la
  /// fija `firebaseFunctionsProvider`.
  BootstrapCallableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootstrapCallableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootstrapCallableHash();

  @$internal
  @override
  $ProviderElement<BootstrapCallable> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BootstrapCallable create(Ref ref) {
    return bootstrapCallable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BootstrapCallable value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BootstrapCallable>(value),
    );
  }
}

String _$bootstrapCallableHash() => r'8daec603d1976914920976bffcbc9532512e21c6';

/// Implementación real de [BootstrapAccion].
///
/// `keepAlive` a propósito: la pantalla la obtiene con `ref.read` en el
/// submit, sin observarla. Con autoDispose el provider podría descartarse
/// mientras el cierre sigue en vuelo y el `ref.read` de dentro reventaría.

@ProviderFor(bootstrapAccion)
final bootstrapAccionProvider = BootstrapAccionProvider._();

/// Implementación real de [BootstrapAccion].
///
/// `keepAlive` a propósito: la pantalla la obtiene con `ref.read` en el
/// submit, sin observarla. Con autoDispose el provider podría descartarse
/// mientras el cierre sigue en vuelo y el `ref.read` de dentro reventaría.

final class BootstrapAccionProvider
    extends
        $FunctionalProvider<BootstrapAccion, BootstrapAccion, BootstrapAccion>
    with $Provider<BootstrapAccion> {
  /// Implementación real de [BootstrapAccion].
  ///
  /// `keepAlive` a propósito: la pantalla la obtiene con `ref.read` en el
  /// submit, sin observarla. Con autoDispose el provider podría descartarse
  /// mientras el cierre sigue en vuelo y el `ref.read` de dentro reventaría.
  BootstrapAccionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootstrapAccionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootstrapAccionHash();

  @$internal
  @override
  $ProviderElement<BootstrapAccion> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BootstrapAccion create(Ref ref) {
    return bootstrapAccion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BootstrapAccion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BootstrapAccion>(value),
    );
  }
}

String _$bootstrapAccionHash() => r'2dd343b9cfc1428e33626d1456e3b223dce8dd7b';
