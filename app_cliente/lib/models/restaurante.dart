import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurante.freezed.dart';
part 'restaurante.g.dart';

/// Restaurante público (`RestaurantePublico` del backend) — item de la lista
/// `GET /public/restaurantes`.
///
/// [calificacion] es SIEMPRE null en Phase 5 (la UI muestra "—"); Phase 9
/// la llena con el agregado de CALI-02.
@freezed
abstract class Restaurante with _$Restaurante {
  const factory Restaurante({
    required int id,
    required String nombre,
    @JsonKey(name: 'tipo_cocina') String? tipoCocina,
    String? descripcion,
    String? direccion,
    double? calificacion,
  }) = _Restaurante;

  factory Restaurante.fromJson(Map<String, dynamic> json) =>
      _$RestauranteFromJson(json);

  const Restaurante._();

  /// "4.8" o "—" (sin datos hasta Phase 9).
  String get calificacionLabel =>
      calificacion == null ? '—' : calificacion!.toStringAsFixed(1);
}
