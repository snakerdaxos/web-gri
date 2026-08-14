import 'package:freezed_annotation/freezed_annotation.dart';

import 'categoria.dart';

part 'restaurante_detalle.freezed.dart';
part 'restaurante_detalle.g.dart';

/// Detalle público con menú anidado (`RestauranteDetalle` del backend) —
/// `GET /public/restaurantes/{id}`.
@freezed
abstract class RestauranteDetalle with _$RestauranteDetalle {
  const factory RestauranteDetalle({
    required int id,
    required String nombre,
    @JsonKey(name: 'tipo_cocina') String? tipoCocina,
    String? descripcion,
    String? direccion,
    double? calificacion,
    required List<Categoria> categorias,
  }) = _RestauranteDetalle;

  factory RestauranteDetalle.fromJson(Map<String, dynamic> json) =>
      _$RestauranteDetalleFromJson(json);

  const RestauranteDetalle._();

  String get calificacionLabel =>
      calificacion == null ? '—' : calificacion!.toStringAsFixed(1);
}
