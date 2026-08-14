// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurantes_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lista de restaurantes para el dropdown del super_admin (`GET /admin/restaurantes`).
///
/// Solo lo watch el AppShell cuando `authState.isSuperAdmin` es true. Para
/// staff este provider nunca se construye (no se necesita).

@ProviderFor(restaurantesList)
final restaurantesListProvider = RestaurantesListProvider._();

/// Lista de restaurantes para el dropdown del super_admin (`GET /admin/restaurantes`).
///
/// Solo lo watch el AppShell cuando `authState.isSuperAdmin` es true. Para
/// staff este provider nunca se construye (no se necesita).

final class RestaurantesListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Restaurante>>,
          List<Restaurante>,
          FutureOr<List<Restaurante>>
        >
    with
        $FutureModifier<List<Restaurante>>,
        $FutureProvider<List<Restaurante>> {
  /// Lista de restaurantes para el dropdown del super_admin (`GET /admin/restaurantes`).
  ///
  /// Solo lo watch el AppShell cuando `authState.isSuperAdmin` es true. Para
  /// staff este provider nunca se construye (no se necesita).
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
  $FutureProviderElement<List<Restaurante>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Restaurante>> create(Ref ref) {
    return restaurantesList(ref);
  }
}

String _$restaurantesListHash() => r'00d4eebdd91a1ab95dfafa817d03b4008cb0ea79';
