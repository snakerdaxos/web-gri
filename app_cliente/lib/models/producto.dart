import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'producto.freezed.dart';
part 'producto.g.dart';

/// Plato/bebida del menú — doc `productos/{autoId}` con colección plana
/// (`restauranteId` + `categoriaId` String).
///
/// ⚠️ [precio] es `int` COP — Firestore guarda enteros, sin floats
/// (anti-pattern del research 10). Formatear SIEMPRE con `formatCOP`
/// (core/format.dart), nunca concatenar strings.
@freezed
abstract class Producto with _$Producto {
  const factory Producto({
    required String id,
    required String restauranteId,
    required String categoriaId,
    required String nombre,
    String? descripcion,
    required int precio,
    String? imagenUrl,
    @Default(true) bool disponible,
    @Default(true) bool activo,
  }) = _Producto;

  factory Producto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Producto(
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

  factory Producto.fromJson(Map<String, dynamic> json) =>
      _$ProductoFromJson(json);
}
