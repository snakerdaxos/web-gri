// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_auth.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Costura inyectable de la acción de ingreso (mismo patrón que 11-07/11-10).

@ProviderFor(googleAuthAccion)
final googleAuthAccionProvider = GoogleAuthAccionProvider._();

/// Costura inyectable de la acción de ingreso (mismo patrón que 11-07/11-10).

final class GoogleAuthAccionProvider
    extends
        $FunctionalProvider<
          GoogleAuthAccion,
          GoogleAuthAccion,
          GoogleAuthAccion
        >
    with $Provider<GoogleAuthAccion> {
  /// Costura inyectable de la acción de ingreso (mismo patrón que 11-07/11-10).
  GoogleAuthAccionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleAuthAccionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleAuthAccionHash();

  @$internal
  @override
  $ProviderElement<GoogleAuthAccion> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoogleAuthAccion create(Ref ref) {
    return googleAuthAccion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleAuthAccion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoogleAuthAccion>(value),
    );
  }
}

String _$googleAuthAccionHash() => r'febadd1e52b2ac91c3319bf0f0f66515a46b8926';
