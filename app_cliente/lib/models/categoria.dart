import 'package:freezed_annotation/freezed_annotation.dart';

import 'producto.dart';

part 'categoria.freezed.dart';
part 'categoria.g.dart';

/// Categoría del menú con sus productos (`CategoriaConProductos`) — el
/// backend ya los agrupa; el cliente solo renderiza.
@freezed
abstract class Categoria with _$Categoria {
  const factory Categoria({
    required int id,
    required String nombre,
    required int orden,
    required List<Producto> productos,
  }) = _Categoria;

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      _$CategoriaFromJson(json);
}
