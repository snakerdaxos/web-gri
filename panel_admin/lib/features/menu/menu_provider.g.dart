// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Menú completo del tenant EN VIVO (MENU-01/02): categorías con productos
/// anidados — `categorias where restauranteId == rid orderBy orden` +
/// `productos where restauranteId == rid`, combinados con combineLatest
/// (cada alta/edición/toggle re-emite: los cambios se reflejan en vivo en
/// el panel Y en el discover del cliente, que escucha la misma colección
/// con los filtros públicos de rules).
///
/// El staff ve TODO (inactivos y agotados con sus flags — NUNCA filtrar
/// client-side; la query pública del cliente es otra, con `activo`).
///
/// rid null (super_admin sin restaurante seleccionado) → `[]` (patrón
/// mesasProvider). Watches ANTES del primer await (lección 07-03).

@ProviderFor(staffMenu)
final staffMenuProvider = StaffMenuProvider._();

/// Menú completo del tenant EN VIVO (MENU-01/02): categorías con productos
/// anidados — `categorias where restauranteId == rid orderBy orden` +
/// `productos where restauranteId == rid`, combinados con combineLatest
/// (cada alta/edición/toggle re-emite: los cambios se reflejan en vivo en
/// el panel Y en el discover del cliente, que escucha la misma colección
/// con los filtros públicos de rules).
///
/// El staff ve TODO (inactivos y agotados con sus flags — NUNCA filtrar
/// client-side; la query pública del cliente es otra, con `activo`).
///
/// rid null (super_admin sin restaurante seleccionado) → `[]` (patrón
/// mesasProvider). Watches ANTES del primer await (lección 07-03).

final class StaffMenuProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoriaStaff>>,
          List<CategoriaStaff>,
          Stream<List<CategoriaStaff>>
        >
    with
        $FutureModifier<List<CategoriaStaff>>,
        $StreamProvider<List<CategoriaStaff>> {
  /// Menú completo del tenant EN VIVO (MENU-01/02): categorías con productos
  /// anidados — `categorias where restauranteId == rid orderBy orden` +
  /// `productos where restauranteId == rid`, combinados con combineLatest
  /// (cada alta/edición/toggle re-emite: los cambios se reflejan en vivo en
  /// el panel Y en el discover del cliente, que escucha la misma colección
  /// con los filtros públicos de rules).
  ///
  /// El staff ve TODO (inactivos y agotados con sus flags — NUNCA filtrar
  /// client-side; la query pública del cliente es otra, con `activo`).
  ///
  /// rid null (super_admin sin restaurante seleccionado) → `[]` (patrón
  /// mesasProvider). Watches ANTES del primer await (lección 07-03).
  StaffMenuProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'staffMenuProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$staffMenuHash();

  @$internal
  @override
  $StreamProviderElement<List<CategoriaStaff>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CategoriaStaff>> create(Ref ref) {
    return staffMenu(ref);
  }
}

String _$staffMenuHash() => r'e0dca2d9134ca2c80691f1003a82a83f830f93f3';
