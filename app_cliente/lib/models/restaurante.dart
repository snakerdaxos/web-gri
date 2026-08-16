import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurante.freezed.dart';
part 'restaurante.g.dart';

/// Restaurante público — doc `restaurantes/{slug}` (Firestore, Phase 10).
///
/// [id] es el slug (doc ID) — String end-to-end. [califProm]/[califCount]
/// son el rating desnormalizado (CALI-02, actualizado por el panel):
/// "—" cuando [califCount] == 0.
///
/// `fromJson` heredado de la era REST — sin uso tras la migración; la
/// vía canónica es [fromDoc].
@freezed
abstract class Restaurante with _$Restaurante {
  const factory Restaurante({
    required String id,
    required String nombre,
    String? tipoCocina,
    String? descripcion,
    String? direccion,
    @Default(0.0) double califProm,
    @Default(0) int califCount,
  }) = _Restaurante;

  /// Mapea el `DocumentSnapshot` de `restaurantes/{slug}` (doc shapes del
  /// research 10: ids String, califProm double, califCount int).
  factory Restaurante.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Restaurante(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      tipoCocina: data['tipoCocina'] as String?,
      descripcion: data['descripcion'] as String?,
      direccion: data['direccion'] as String?,
      califProm: (data['califProm'] as num?)?.toDouble() ?? 0.0,
      califCount: (data['califCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory Restaurante.fromJson(Map<String, dynamic> json) =>
      _$RestauranteFromJson(json);

  const Restaurante._();

  /// "4.8" o "—" (sin reseñas).
  String get calificacionLabel =>
      califCount <= 0 ? '—' : califProm.toStringAsFixed(1);

  /// "4.8 (245)" o "—" — promedio + count reales (CALI-02).
  String get ratingLabel {
    if (califCount <= 0) return '—';
    return '${califProm.toStringAsFixed(1)} ($califCount)';
  }
}
