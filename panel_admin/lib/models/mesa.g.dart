// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Mesa _$MesaFromJson(Map<String, dynamic> json) => _Mesa(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String? ?? '',
  numero: (json['numero'] as num).toInt(),
  capacidad: (json['capacidad'] as num).toInt(),
  estado: estadoMesaFromJson(json['estado'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MesaToJson(_Mesa instance) => <String, dynamic>{
  'id': instance.id,
  'restauranteId': instance.restauranteId,
  'numero': instance.numero,
  'capacidad': instance.capacidad,
  'estado': _$EstadoMesaEnumMap[instance.estado]!,
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$EstadoMesaEnumMap = {
  EstadoMesa.disponible: 'disponible',
  EstadoMesa.ocupada: 'ocupada',
  EstadoMesa.reservada: 'reservada',
  EstadoMesa.limpieza: 'limpieza',
};
