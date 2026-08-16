// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante_detalle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RestauranteDetalle _$RestauranteDetalleFromJson(Map<String, dynamic> json) =>
    _RestauranteDetalle(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      tipoCocina: json['tipoCocina'] as String?,
      descripcion: json['descripcion'] as String?,
      direccion: json['direccion'] as String?,
      califProm: (json['califProm'] as num?)?.toDouble() ?? 0.0,
      califCount: (json['califCount'] as num?)?.toInt() ?? 0,
      categorias: (json['categorias'] as List<dynamic>)
          .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RestauranteDetalleToJson(_RestauranteDetalle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'tipoCocina': instance.tipoCocina,
      'descripcion': instance.descripcion,
      'direccion': instance.direccion,
      'califProm': instance.califProm,
      'califCount': instance.califCount,
      'categorias': instance.categorias,
    };
