// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurantes_admin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05, 08-05): `GET /admin/restaurantes
/// ?incluir_inactivos=true` (única vista que expone inactivos).
///
/// El toggle de activo de la UI refresca invalidando aquí. Watch de
/// authState para reactividad al login/logout (el tab solo lo watch-ea
/// super_admin, pero el watch hace al provider re-construirse con la sesión).

@ProviderFor(restaurantesAdmin)
final restaurantesAdminProvider = RestaurantesAdminProvider._();

/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05, 08-05): `GET /admin/restaurantes
/// ?incluir_inactivos=true` (única vista que expone inactivos).
///
/// El toggle de activo de la UI refresca invalidando aquí. Watch de
/// authState para reactividad al login/logout (el tab solo lo watch-ea
/// super_admin, pero el watch hace al provider re-construirse con la sesión).

final class RestaurantesAdminProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Restaurante>>,
          List<Restaurante>,
          FutureOr<List<Restaurante>>
        >
    with
        $FutureModifier<List<Restaurante>>,
        $FutureProvider<List<Restaurante>> {
  /// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
  /// 'Restaurantes' del super_admin (PLAT-05, 08-05): `GET /admin/restaurantes
  /// ?incluir_inactivos=true` (única vista que expone inactivos).
  ///
  /// El toggle de activo de la UI refresca invalidando aquí. Watch de
  /// authState para reactividad al login/logout (el tab solo lo watch-ea
  /// super_admin, pero el watch hace al provider re-construirse con la sesión).
  RestaurantesAdminProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restaurantesAdminProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restaurantesAdminHash();

  @$internal
  @override
  $FutureProviderElement<List<Restaurante>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Restaurante>> create(Ref ref) {
    return restaurantesAdmin(ref);
  }
}

String _$restaurantesAdminHash() => r'719cdd6a0b7e19d3dfb0d15d1884171a1ced9d27';
