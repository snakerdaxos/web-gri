import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'producto.dart';

part 'categoria.freezed.dart';
part 'categoria.g.dart';

/// Categoría del menú — doc `categorias/{autoId}` con `restauranteId`
/// ( colección plana, research 10). Los productos se agrupan por
/// `categoriaId` en el provider que arma el detalle.
@freezed
abstract class Categoria with _$Categoria {
  const factory Categoria({
    required String id,
    required String restauranteId,
    required String nombre,
    @Default(1) int orden,
    @Default(true) bool activo,
    @Default(<Producto>[]) List<Producto> productos,
  }) = _Categoria;

  /// Mapea el doc `categorias/{autoId}`; [productos] llega agrupado por
  /// el provider (el doc NO los anida).
  factory Categoria.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<Producto> productos = const <Producto>[],
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Categoria(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      orden: (data['orden'] as num?)?.toInt() ?? 1,
      activo: data['activo'] as bool? ?? true,
      productos: productos,
    );
  }

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      _$CategoriaFromJson(json);
}
