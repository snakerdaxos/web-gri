// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// El restaurante activo del operador actual:
///  * staff → `claims.rid` (SU tenant — inamovible desde la UI).
///  * super_admin → [seleccionRestauranteProvider].
///
/// TODAS las queries staff del panel derivan su `where restauranteId`
/// de aquí (aislamiento tenant, Pitfall 4 del research).
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await.

@ProviderFor(ridActivo)
final ridActivoProvider = RidActivoProvider._();

/// El restaurante activo del operador actual:
///  * staff → `claims.rid` (SU tenant — inamovible desde la UI).
///  * super_admin → [seleccionRestauranteProvider].
///
/// TODAS las queries staff del panel derivan su `where restauranteId`
/// de aquí (aislamiento tenant, Pitfall 4 del research).
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await.

final class RidActivoProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// El restaurante activo del operador actual:
  ///  * staff → `claims.rid` (SU tenant — inamovible desde la UI).
  ///  * super_admin → [seleccionRestauranteProvider].
  ///
  /// TODAS las queries staff del panel derivan su `where restauranteId`
  /// de aquí (aislamiento tenant, Pitfall 4 del research).
  ///
  /// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
  /// ANTES del primer await.
  RidActivoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ridActivoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ridActivoHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return ridActivo(ref);
  }
}

String _$ridActivoHash() => r'04124c38036db179a2cedde46387eb6d3e31dea9';

/// Restaurante activo EN VIVO para el TopBar — stream del doc
/// `restaurantes/{rid}` (nombre/activo). Sin rid (super sin selección)
/// emite `null` → el topbar muestra el selector en su lugar.

@ProviderFor(restauranteActivo)
final restauranteActivoProvider = RestauranteActivoProvider._();

/// Restaurante activo EN VIVO para el TopBar — stream del doc
/// `restaurantes/{rid}` (nombre/activo). Sin rid (super sin selección)
/// emite `null` → el topbar muestra el selector en su lugar.

final class RestauranteActivoProvider
    extends
        $FunctionalProvider<
          AsyncValue<RestauranteResumen?>,
          RestauranteResumen?,
          Stream<RestauranteResumen?>
        >
    with
        $FutureModifier<RestauranteResumen?>,
        $StreamProvider<RestauranteResumen?> {
  /// Restaurante activo EN VIVO para el TopBar — stream del doc
  /// `restaurantes/{rid}` (nombre/activo). Sin rid (super sin selección)
  /// emite `null` → el topbar muestra el selector en su lugar.
  RestauranteActivoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restauranteActivoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restauranteActivoHash();

  @$internal
  @override
  $StreamProviderElement<RestauranteResumen?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RestauranteResumen?> create(Ref ref) {
    return restauranteActivo(ref);
  }
}

String _$restauranteActivoHash() => r'746bf3b7121a8de72fc562f494bc6c9ca7aa9cbb';

/// FutureProvider que resuelve el [Restaurante] a mostrar (REST legacy).

@ProviderFor(restaurante)
final restauranteProvider = RestauranteProvider._();

/// FutureProvider que resuelve el [Restaurante] a mostrar (REST legacy).

final class RestauranteProvider
    extends
        $FunctionalProvider<
          AsyncValue<Restaurante>,
          Restaurante,
          FutureOr<Restaurante>
        >
    with $FutureModifier<Restaurante>, $FutureProvider<Restaurante> {
  /// FutureProvider que resuelve el [Restaurante] a mostrar (REST legacy).
  RestauranteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restauranteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restauranteHash();

  @$internal
  @override
  $FutureProviderElement<Restaurante> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Restaurante> create(Ref ref) {
    return restaurante(ref);
  }
}

String _$restauranteHash() => r'c69884d90a2827b4db4f9247df4d4b245ed16d90';
