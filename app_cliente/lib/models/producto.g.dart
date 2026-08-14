// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'producto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Producto _$ProductoFromJson(Map<String, dynamic> json) => _Producto(
  id: (json['id'] as num).toInt(),
  nombre: json['nombre'] as String,
  descripcion: json['descripcion'] as String?,
  precio: (json['precio'] as num).toDouble(),
  imagenUrl: json['imagen_url'] as String?,
  disponible: json['disponible'] as bool,
);

Map<String, dynamic> _$ProductoToJson(_Producto instance) => <String, dynamic>{
  'id': instance.id,
  'nombre': instance.nombre,
  'descripcion': instance.descripcion,
  'precio': instance.precio,
  'imagen_url': instance.imagenUrl,
  'disponible': instance.disponible,
};
