// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Restaurante _$RestauranteFromJson(Map<String, dynamic> json) => _Restaurante(
  id: (json['id'] as num).toInt(),
  nombre: json['nombre'] as String,
  descripcion: json['descripcion'] as String?,
  tipoCocina: json['tipo_cocina'] as String?,
  direccion: json['direccion'] as String?,
  activo: json['activo'] as bool,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$RestauranteToJson(_Restaurante instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'descripcion': instance.descripcion,
      'tipo_cocina': instance.tipoCocina,
      'direccion': instance.direccion,
      'activo': instance.activo,
      'created_at': instance.createdAt?.toIso8601String(),
    };
