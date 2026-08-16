import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurante.freezed.dart';

/// Restaurante — doc `restaurantes/{slug}` (Phase 10).
///
/// Lo consume la ficha read-only de /configuracion (staff de SU tenant) y
/// el tab de super_admin (lista completa con inactivos).
@freezed
abstract class Restaurante with _$Restaurante {
  const factory Restaurante({
    /// Slug (doc ID) — ej. `demo`.
    required String id,
    required String nombre,
    String? descripcion,
    String? tipoCocina,
    String? direccion,
    required bool activo,

    /// Agregado de calificaciones (lo mantiene la tx de calificar).
    @Default(0.0) double califProm,
    @Default(0) int califCount,
  }) = _Restaurante;

  /// Mapea el doc `restaurantes/{slug}`.
  factory Restaurante.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Restaurante(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      tipoCocina: data['tipoCocina'] as String?,
      direccion: data['direccion'] as String?,
      activo: data['activo'] as bool? ?? false,
      califProm: (data['califProm'] as num?)?.toDouble() ?? 0.0,
      califCount: (data['califCount'] as num?)?.toInt() ?? 0,
    );
  }
}
