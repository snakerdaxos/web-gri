import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'producto_staff.freezed.dart';

/// Producto del menú visto por staff (doc `productos/{autoId}`, Phase 10).
///
/// Dos flags con semánticas DISTINTAS (threat model 08-04):
///  * [disponible] — agotado transitorio: SIGUE visible en la app del
///    cliente con flag (rules exigen `activo && disponible` para el read
///    público, así que el agotado desaparece de la QUERY pública pero la
///    ficha vive para re-activarlo).
///  * [activo] — soft-delete: desaparece del menú del cliente (el staff
///    lo sigue viendo).
///
/// `precio` es int COP (research 10: sin floats).
@freezed
abstract class ProductoStaff with _$ProductoStaff {
  const factory ProductoStaff({
    /// AutoId de Firestore.
    required String id,

    /// Tenant del producto — TODA query filtra por el rid activo.
    @Default('') String restauranteId,
    required String categoriaId,
    required String nombre,
    @Default('') String? descripcion,
    required int precio,
    @Default('') String? imagenUrl,
    required bool disponible,
    required bool activo,
  }) = _ProductoStaff;

  /// Mapea el doc `productos/{autoId}`.
  factory ProductoStaff.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProductoStaff(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      categoriaId: data['categoriaId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      precio: (data['precio'] as num?)?.toInt() ?? 0,
      imagenUrl: data['imagenUrl'] as String?,
      disponible: data['disponible'] as bool? ?? true,
      activo: data['activo'] as bool? ?? true,
    );
  }
}
