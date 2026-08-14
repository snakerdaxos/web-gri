// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de mesas con polling 10s — espejo de [statsProvider] pero sobre
/// `GET /staff/mesas` (mapa de mesas, ADMN-02).

@ProviderFor(mesas)
final mesasProvider = MesasProvider._();

/// Stream de mesas con polling 10s — espejo de [statsProvider] pero sobre
/// `GET /staff/mesas` (mapa de mesas, ADMN-02).

final class MesasProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Mesa>>,
          List<Mesa>,
          Stream<List<Mesa>>
        >
    with $FutureModifier<List<Mesa>>, $StreamProvider<List<Mesa>> {
  /// Stream de mesas con polling 10s — espejo de [statsProvider] pero sobre
  /// `GET /staff/mesas` (mapa de mesas, ADMN-02).
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

String _$mesasHash() => r'ab3b93ecee697a0bb6d1c9f501113d1f64483899';
