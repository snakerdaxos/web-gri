import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurante.freezed.dart';
part 'restaurante.g.dart';

/// Restaurante público (`RestaurantePublico` del backend) — item de la lista
/// `GET /public/restaurantes`.
///
/// [calificacion] es el promedio (1 decimal) calculado server-side y
/// [totalCalificaciones] el count de reseñas (CALI-02, 09-02). "—" cuando
/// no hay reseñas.
@freezed
abstract class Restaurante with _$Restaurante {
  const factory Restaurante({
    required int id,
    required String nombre,
    @JsonKey(name: 'tipo_cocina') String? tipoCocina,
    String? descripcion,
    String? direccion,
    double? calificacion,
    @JsonKey(name: 'total_calificaciones') @Default(0) int totalCalificaciones,
  }) = _Restaurante;

  factory Restaurante.fromJson(Map<String, dynamic> json) =>
      _$RestauranteFromJson(json);

  const Restaurante._();

  /// "4.8" o "—" (sin datos hasta Phase 9).
  String get calificacionLabel =>
      calificacion == null ? '—' : calificacion!.toStringAsFixed(1);

  /// "4.8 (245)" o "—" — promedio + count reales (CALI-02). El número que
  /// llega del backend YA es el promedio: sin lógica local.
  String get ratingLabel {
    if (calificacion == null || totalCalificaciones <= 0) return '—';
    return '${calificacion!.toStringAsFixed(1)} ($totalCalificaciones)';
  }
}
