// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'producto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Producto _$ProductoFromJson(Map<String, dynamic> json) => _Producto(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String,
  categoriaId: json['categoriaId'] as String,
  nombre: json['nombre'] as String,
  descripcion: json['descripcion'] as String?,
  precio: (json['precio'] as num).toInt(),
  imagenUrl: json['imagenUrl'] as String?,
  disponible: json['disponible'] as bool? ?? true,
  activo: json['activo'] as bool? ?? true,
);

Map<String, dynamic> _$ProductoToJson(_Producto instance) => <String, dynamic>{
  'id': instance.id,
  'restauranteId': instance.restauranteId,
  'categoriaId': instance.categoriaId,
  'nombre': instance.nombre,
  'descripcion': instance.descripcion,
  'precio': instance.precio,
  'imagenUrl': instance.imagenUrl,
  'disponible': instance.disponible,
  'activo': instance.activo,
};
