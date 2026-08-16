// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Restaurante _$RestauranteFromJson(Map<String, dynamic> json) => _Restaurante(
  id: json['id'] as String,
  nombre: json['nombre'] as String,
  tipoCocina: json['tipoCocina'] as String?,
  descripcion: json['descripcion'] as String?,
  direccion: json['direccion'] as String?,
  califProm: (json['califProm'] as num?)?.toDouble() ?? 0.0,
  califCount: (json['califCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RestauranteToJson(_Restaurante instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'tipoCocina': instance.tipoCocina,
      'descripcion': instance.descripcion,
      'direccion': instance.direccion,
      'califProm': instance.califProm,
      'califCount': instance.califCount,
    };
