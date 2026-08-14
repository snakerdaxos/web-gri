// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante_detalle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RestauranteDetalle _$RestauranteDetalleFromJson(Map<String, dynamic> json) =>
    _RestauranteDetalle(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      tipoCocina: json['tipo_cocina'] as String?,
      descripcion: json['descripcion'] as String?,
      direccion: json['direccion'] as String?,
      calificacion: (json['calificacion'] as num?)?.toDouble(),
      categorias: (json['categorias'] as List<dynamic>)
          .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RestauranteDetalleToJson(_RestauranteDetalle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'tipo_cocina': instance.tipoCocina,
      'descripcion': instance.descripcion,
      'direccion': instance.direccion,
      'calificacion': instance.calificacion,
      'categorias': instance.categorias,
    };
