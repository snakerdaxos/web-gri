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

String _$crearStaffAccionHash() => r'd27b1b556fc6597fe9a49f6e5e20151dce022a73';
