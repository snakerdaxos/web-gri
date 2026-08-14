import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurante.freezed.dart';
part 'restaurante.g.dart';

/// Restaurante (`RestauranteRead` del backend).
///
/// Lo consume el topbar del panel vía `GET /admin/restaurantes/{id}`
/// (staff lee su propio tenant) y el selector de super_admin vía
/// `GET /admin/restaurantes`.
@freezed
abstract class Restaurante with _$Restaurante {
  const factory Restaurante({
    required int id,
    required String nombre,
    String? descripcion,
    @JsonKey(name: 'tipo_cocina') String? tipoCocina,
    String? direccion,
    required bool activo,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Restaurante;

  factory Restaurante.fromJson(Map<String, dynamic> json) =>
      _$RestauranteFromJson(json);
}
