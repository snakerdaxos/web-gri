// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Mapa de mesas del restaurante activo EN VIVO (MIGRA-05):
/// `mesas where restauranteId == rid orderBy numero ASC → snapshots()` —
/// sustituye el WS + polling de la era REST (Phase 7).
///
/// * El rid viene de [ridActivoProvider] (claims del staff / selección del
///   super) — NUNCA de un input libre del usuario (Pitfall 4: TODA query
///   lleva `where restauranteId == rid`; las rules re-evalúan por-doc).
/// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).

@ProviderFor(mesas)
final mesasProvider = MesasProvider._();

/// Mapa de mesas del restaurante activo EN VIVO (MIGRA-05):
/// `mesas where restauranteId == rid orderBy numero ASC → snapshots()` —
/// sustituye el WS + polling de la era REST (Phase 7).
///
/// * El rid viene de [ridActivoProvider] (claims del staff / selección del
///   super) — NUNCA de un input libre del usuario (Pitfall 4: TODA query
///   lleva `where restauranteId == rid`; las rules re-evalúan por-doc).
/// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).

final class MesasProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Mesa>>,
          List<Mesa>,
          Stream<List<Mesa>>
        >
    with $FutureModifier<List<Mesa>>, $StreamProvider<List<Mesa>> {
  /// Mapa de mesas del restaurante activo EN VIVO (MIGRA-05):
  /// `mesas where restauranteId == rid orderBy numero ASC → snapshots()` —
  /// sustituye el WS + polling de la era REST (Phase 7).
  ///
  /// * El rid viene de [ridActivoProvider] (claims del staff / selección del
  ///   super) — NUNCA de un input libre del usuario (Pitfall 4: TODA query
  ///   lleva `where restauranteId == rid`; las rules re-evalúan por-doc).
  /// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).
  MesasProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mesasProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mesasHash();

  @$internal
  @override
  $StreamProviderElement<List<Mesa>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Mesa>> create(Ref ref) {
    return mesas(ref);
  }
}

String _$mesasHash() => r'7d68f6ef207c88ced00a4365e576f59c20df8184';
