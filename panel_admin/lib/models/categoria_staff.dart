import 'package:freezed_annotation/freezed_annotation.dart';

import 'producto_staff.dart';

part 'categoria_staff.freezed.dart';
part 'categoria_staff.g.dart';

/// Categoría del menú con sus productos anidados (`GET /staff/menu`,
/// MENU-01). El endpoint de staff incluye categorías/productos inactivos y
/// agotados con sus flags (el staff ve TODO para gestionar; /public filtra
/// solo `activo`) — NUNCA filtrar client-side.
@freezed
abstract class CategoriaStaff with _$CategoriaStaff {
  const factory CategoriaStaff({
    required int id,
    required String nombre,
    required int orden,
    required bool activo,
    required List<ProductoStaff> productos,
  }) = _CategoriaStaff;

  factory CategoriaStaff.fromJson(Map<String, dynamic> json) =>
      _$CategoriaStaffFromJson(json);
}
