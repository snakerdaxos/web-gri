// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipo_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Invocación real de `crearUsuarioStaff`. La región la fija
/// `firebaseFunctionsProvider` (`us-central1`, declarada en los dos lados).

@ProviderFor(crearStaffCallable)
final crearStaffCallableProvider = CrearStaffCallableProvider._();

/// Invocación real de `crearUsuarioStaff`. La región la fija
/// `firebaseFunctionsProvider` (`us-central1`, declarada en los dos lados).

final class CrearStaffCallableProvider
    extends
        $FunctionalProvider<
          CrearStaffCallable,
          CrearStaffCallable,
          CrearStaffCallable
        >
    with $Provider<CrearStaffCallable> {
  /// Invocación real de `crearUsuarioStaff`. La región la fija
  /// `firebaseFunctionsProvider` (`us-central1`, declarada en los dos lados).
  CrearStaffCallableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crearStaffCallableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crearStaffCallableHash();

  @$internal
  @override
  $ProviderElement<CrearStaffCallable> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CrearStaffCallable create(Ref ref) {
    return crearStaffCallable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrearStaffCallable value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrearStaffCallable>(value),
    );
  }
}

String _$crearStaffCallableHash() =>
    r'c0d744943bc03c58306d73dcf1e276c4e6ba9b49';

/// Implementación real de [CrearStaffAccion].
///
/// `keepAlive` a propósito: el diálogo la obtiene con `ref.read` en el submit,
/// sin observarla; con autoDispose podría descartarse con la llamada en vuelo.

@ProviderFor(crearStaffAccion)
final crearStaffAccionProvider = CrearStaffAccionProvider._();

/// Implementación real de [CrearStaffAccion].
///
/// `keepAlive` a propósito: el diálogo la obtiene con `ref.read` en el submit,
/// sin observarla; con autoDispose podría descartarse con la llamada en vuelo.

final class CrearStaffAccionProvider
    extends
        $FunctionalProvider<
          CrearStaffAccion,
          CrearStaffAccion,
          CrearStaffAccion
        >
    with $Provider<CrearStaffAccion> {
  /// Implementación real de [CrearStaffAccion].
  ///
  /// `keepAlive` a propósito: el diálogo la obtiene con `ref.read` en el submit,
  /// sin observarla; con autoDispose podría descartarse con la llamada en vuelo.
  CrearStaffAccionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crearStaffAccionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crearStaffAccionHash();

  @$internal
  @override
  $ProviderElement<CrearStaffAccion> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CrearStaffAccion create(Ref ref) {
    return crearStaffAccion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrearStaffAccion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrearStaffAccion>(value),
    );
  }
}

String _$crearStaffAccionHash() => r'7a90a39ce5d9b6975dd9a80c9cbe822d70f71fa2';

/// Invocación real de `cambiarEstadoStaff`.

@ProviderFor(cambiarEstadoCallable)
final cambiarEstadoCallableProvider = CambiarEstadoCallableProvider._();

/// Invocación real de `cambiarEstadoStaff`.

final class CambiarEstadoCallableProvider
    extends
        $FunctionalProvider<
          CambiarEstadoCallable,
          CambiarEstadoCallable,
          CambiarEstadoCallable
        >
    with $Provider<CambiarEstadoCallable> {
  /// Invocación real de `cambiarEstadoStaff`.
  CambiarEstadoCallableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cambiarEstadoCallableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cambiarEstadoCallableHash();

  @$internal
  @override
  $ProviderElement<CambiarEstadoCallable> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CambiarEstadoCallable create(Ref ref) {
    return cambiarEstadoCallable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CambiarEstadoCallable value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CambiarEstadoCallable>(value),
    );
  }
}

String _$cambiarEstadoCallableHash() =>
    r'2a4c27b36cd94295dadf852d830dcaebcc189b9c';

/// Implementación real de [CambiarEstadoAccion].
///
/// El payload lleva SOLO `uid` y `activo`: ni rol ni restaurante. Los dos los
/// DERIVA el servidor del objetivo (de sus claims o, si ya está de baja, de su
/// doc espejo). Mandarlos desde aquí sería darle al cliente una palanca sobre
/// una decisión que no le corresponde, exactamente como el `restauranteId` del
/// alta.

@ProviderFor(cambiarEstadoAccion)
final cambiarEstadoAccionProvider = CambiarEstadoAccionProvider._();

/// Implementación real de [CambiarEstadoAccion].
///
/// El payload lleva SOLO `uid` y `activo`: ni rol ni restaurante. Los dos los
/// DERIVA el servidor del objetivo (de sus claims o, si ya está de baja, de su
/// doc espejo). Mandarlos desde aquí sería darle al cliente una palanca sobre
/// una decisión que no le corresponde, exactamente como el `restauranteId` del
/// alta.

final class CambiarEstadoAccionProvider
    extends
        $FunctionalProvider<
          CambiarEstadoAccion,
          CambiarEstadoAccion,
          CambiarEstadoAccion
        >
    with $Provider<CambiarEstadoAccion> {
  /// Implementación real de [CambiarEstadoAccion].
  ///
  /// El payload lleva SOLO `uid` y `activo`: ni rol ni restaurante. Los dos los
  /// DERIVA el servidor del objetivo (de sus claims o, si ya está de baja, de su
  /// doc espejo). Mandarlos desde aquí sería darle al cliente una palanca sobre
  /// una decisión que no le corresponde, exactamente como el `restauranteId` del
  /// alta.
  CambiarEstadoAccionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cambiarEstadoAccionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cambiarEstadoAccionHash();

  @$internal
  @override
  $ProviderElement<CambiarEstadoAccion> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CambiarEstadoAccion create(Ref ref) {
    return cambiarEstadoAccion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CambiarEstadoAccion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CambiarEstadoAccion>(value),
    );
  }
}

String _$cambiarEstadoAccionHash() =>
    r'f92bcf2f13b6edced12755ae205ebb6fa9f3b94e';
