// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categoria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Categoria _$CategoriaFromJson(Map<String, dynamic> json) => _Categoria(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String,
  nombre: json['nombre'] as String,
  orden: (json['orden'] as num?)?.toInt() ?? 1,
  activo: json['activo'] as bool? ?? true,
  productos:
      (json['productos'] as List<dynamic>?)
          ?.map((e) => Producto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Producto>[],
);

Map<String, dynamic> _$CategoriaToJson(_Categoria instance) =>
    <String, dynamic>{
      'id': instance.id,
      'restauranteId': instance.restauranteId,
      'nombre': instance.nombre,
      'orden': instance.orden,
      'activo': instance.activo,
      'productos': instance.productos,
    };
