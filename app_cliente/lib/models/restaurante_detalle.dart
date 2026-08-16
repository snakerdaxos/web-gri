import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'categoria.dart';

part 'restaurante_detalle.freezed.dart';
part 'restaurante_detalle.g.dart';

/// Detalle público con menú anidado — ensamblado con 3 lecturas de
/// Firestore (doc del restaurante + categorías + productos, research 10).
///
/// `fromJson` heredado de la era REST — sin uso tras la migración; la
/// vía canónica es [fromDoc] con las categorías ya agrupadas.
@freezed
abstract class RestauranteDetalle with _$RestauranteDetalle {
  const factory RestauranteDetalle({
    required String id,
    required String nombre,
    String? tipoCocina,
    String? descripcion,
    String? direccion,
    @Default(0.0) double califProm,
    @Default(0) int califCount,
    required List<Categoria> categorias,
  }) = _RestauranteDetalle;

  /// Mapea el doc `restaurantes/{id}`; las categorías (con sus productos
  /// ya agrupados por `categoriaId`) las arma el provider.
  factory RestauranteDetalle.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required List<Categoria> categorias,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RestauranteDetalle(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      tipoCocina: data['tipoCocina'] as String?,
      descripcion: data['descripcion'] as String?,
      direccion: data['direccion'] as String?,
      califProm: (data['califProm'] as num?)?.toDouble() ?? 0.0,
      califCount: (data['califCount'] as num?)?.toInt() ?? 0,
      categorias: categorias,
    );
  }

  factory RestauranteDetalle.fromJson(Map<String, dynamic> json) =>
      _$RestauranteDetalleFromJson(json);

  const RestauranteDetalle._();

  String get calificacionLabel =>
      califCount <= 0 ? '—' : califProm.toStringAsFixed(1);

  /// "4.8 (245)" o "—" — mismo formato que la lista (CALI-02).
  String get ratingLabel {
    if (califCount <= 0) return '—';
    return '${califProm.toStringAsFixed(1)} ($califCount)';
  }
}
