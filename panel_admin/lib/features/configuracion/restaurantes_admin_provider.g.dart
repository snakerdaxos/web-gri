// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurantes_admin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05): `get()` de TODOS los docs de
/// `restaurantes` (super lee todo por rules — un `where activo == true`
/// escondería los inactivos y no se podrían re-activar).
///
/// Defense in depth (patrón restaurantesListProvider): si un staff lo
/// llega a leer, lanza claro — las rules igualmente le denegarían.
/// El toggle de la UI refresca invalidando aquí.

@ProviderFor(restaurantesAdmin)
final restaurantesAdminProvider = RestaurantesAdminProvider._();

/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05): `get()` de TODOS los docs de
/// `restaurantes` (super lee todo por rules — un `where activo == true`
/// escondería los inactivos y no se podrían re-activar).
///
/// Defense in depth (patrón restaurantesListProvider): si un staff lo
/// llega a leer, lanza claro — las rules igualmente le denegarían.
/// El toggle de la UI refresca invalidando aquí.

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
  /// 'Restaurantes' del super_admin (PLAT-05): `get()` de TODOS los docs de
  /// `restaurantes` (super lee todo por rules — un `where activo == true`
  /// escondería los inactivos y no se podrían re-activar).
  ///
  /// Defense in depth (patrón restaurantesListProvider): si un staff lo
  /// llega a leer, lanza claro — las rules igualmente le denegarían.
  /// El toggle de la UI refresca invalidando aquí.
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

String _$restaurantesAdminHash() => r'cccf15c8c13a6ddc058722d2e927eecf3d698d3d';
