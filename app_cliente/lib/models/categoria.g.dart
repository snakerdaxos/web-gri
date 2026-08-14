// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categoria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Categoria _$CategoriaFromJson(Map<String, dynamic> json) => _Categoria(
  id: (json['id'] as num).toInt(),
  nombre: json['nombre'] as String,
  orden: (json['orden'] as num).toInt(),
  productos: (json['productos'] as List<dynamic>)
      .map((e) => Producto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CategoriaToJson(_Categoria instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'orden': instance.orden,
      'productos': instance.productos,
    };
