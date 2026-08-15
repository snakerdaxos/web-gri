// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Restaurante _$RestauranteFromJson(Map<String, dynamic> json) => _Restaurante(
  id: (json['id'] as num).toInt(),
  nombre: json['nombre'] as String,
  tipoCocina: json['tipo_cocina'] as String?,
  descripcion: json['descripcion'] as String?,
  direccion: json['direccion'] as String?,
  calificacion: (json['calificacion'] as num?)?.toDouble(),
  totalCalificaciones: (json['total_calificaciones'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RestauranteToJson(_Restaurante instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'tipo_cocina': instance.tipoCocina,
      'descripcion': instance.descripcion,
      'direccion': instance.direccion,
      'calificacion': instance.calificacion,
      'total_calificaciones': instance.totalCalificaciones,
    };
