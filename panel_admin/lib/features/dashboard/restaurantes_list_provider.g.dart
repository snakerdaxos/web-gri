// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurantes_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lista de restaurantes ACTIVOS para el selector del `super_admin`
/// (Phase 10 — Firestore realtime): `restaurantes where activo == true`
/// vía snapshots — crear/activar un restaurante lo muestra en vivo.
///
/// Solo lo watch-ea el AppShell cuando los claims dicen super_admin.
/// Defense in depth (patrón del provider legacy): si un staff lo llega a
/// leer, lanza claro — las rules igualmente le denegarían la query.
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await.

@ProviderFor(restaurantesList)
final restaurantesListProvider = RestaurantesListProvider._();

/// Lista de restaurantes ACTIVOS para el selector del `super_admin`
/// (Phase 10 — Firestore realtime): `restaurantes where activo == true`
/// vía snapshots — crear/activar un restaurante lo muestra en vivo.
///
/// Solo lo watch-ea el AppShell cuando los claims dicen super_admin.
/// Defense in depth (patrón del provider legacy): si un staff lo llega a
/// leer, lanza claro — las rules igualmente le denegarían la query.
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await.

final class RestaurantesListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RestauranteResumen>>,
          List<RestauranteResumen>,
          Stream<List<RestauranteResumen>>
        >
    with
        $FutureModifier<List<RestauranteResumen>>,
        $StreamProvider<List<RestauranteResumen>> {
  /// Lista de restaurantes ACTIVOS para el selector del `super_admin`
  /// (Phase 10 — Firestore realtime): `restaurantes where activo == true`
  /// vía snapshots — crear/activar un restaurante lo muestra en vivo.
  ///
  /// Solo lo watch-ea el AppShell cuando los claims dicen super_admin.
  /// Defense in depth (patrón del provider legacy): si un staff lo llega a
  /// leer, lanza claro — las rules igualmente le denegarían la query.
  ///
  /// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
  /// ANTES del primer await.
  RestaurantesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restaurantesListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restaurantesListHash();

  @$internal
  @override
  $StreamProviderElement<List<RestauranteResumen>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RestauranteResumen>> create(Ref ref) {
    return restaurantesList(ref);
  }
}

String _$restaurantesListHash() => r'b1a9b05f6ed954d1200724dd1ef513f21f24ff47';
