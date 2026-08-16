import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'producto_staff.dart';

part 'categoria_staff.freezed.dart';

/// Categoría del menú con sus productos anidados (doc `categorias/{autoId}`,
/// Phase 10). El stream de staff incluye categorías/productos inactivos y
/// agotados con sus flags (el staff ve TODO para gestionar; la query
/// pública del cliente filtra `activo == true` por rules) — NUNCA filtrar
/// client-side en el panel.
@freezed
abstract class CategoriaStaff with _$CategoriaStaff {
  const factory CategoriaStaff({
    /// AutoId de Firestore (el menú no requiere determinismo).
    required String id,

    /// Tenant de la categoría — TODA query filtra por el rid activo.
    @Default('') String restauranteId,
    required String nombre,
    required int orden,
    required bool activo,
    @Default(<ProductoStaff>[]) List<ProductoStaff> productos,
  }) = _CategoriaStaff;

  /// Mapea el doc `categorias/{autoId}` (los productos se anidan
  /// client-side desde el stream de `productos`).
  factory CategoriaStaff.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CategoriaStaff(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      activo: data['activo'] as bool? ?? true,
    );
  }
}
