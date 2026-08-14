// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Menú completo del tenant (categorías con productos anidados, MENU-01).
///
/// El menú NO tiene eventos WS (decisión research 08: refresh on-demand,
/// Pattern 3 vía 2) — tras cada mutación exitosa la UI llama
/// `ref.invalidate(staffMenuProvider)`.
///
/// rid null (super_admin sin restaurante seleccionado) → `[]` en vez de
/// explotar (patrón mesasProvider, misma resolución de tenant).

@ProviderFor(staffMenu)
final staffMenuProvider = StaffMenuProvider._();

/// Menú completo del tenant (categorías con productos anidados, MENU-01).
///
/// El menú NO tiene eventos WS (decisión research 08: refresh on-demand,
/// Pattern 3 vía 2) — tras cada mutación exitosa la UI llama
/// `ref.invalidate(staffMenuProvider)`.
///
/// rid null (super_admin sin restaurante seleccionado) → `[]` en vez de
/// explotar (patrón mesasProvider, misma resolución de tenant).

final class StaffMenuProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoriaStaff>>,
          List<CategoriaStaff>,
          FutureOr<List<CategoriaStaff>>
        >
    with
        $FutureModifier<List<CategoriaStaff>>,
        $FutureProvider<List<CategoriaStaff>> {
  /// Menú completo del tenant (categorías con productos anidados, MENU-01).
  ///
  /// El menú NO tiene eventos WS (decisión research 08: refresh on-demand,
  /// Pattern 3 vía 2) — tras cada mutación exitosa la UI llama
  /// `ref.invalidate(staffMenuProvider)`.
  ///
  /// rid null (super_admin sin restaurante seleccionado) → `[]` en vez de
  /// explotar (patrón mesasProvider, misma resolución de tenant).
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
  $FutureProviderElement<List<CategoriaStaff>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CategoriaStaff>> create(Ref ref) {
    return staffMenu(ref);
  }
}

String _$staffMenuHash() => r'cdafe42af9d1fb2cb8428a3481dea28d2f42a92b';
