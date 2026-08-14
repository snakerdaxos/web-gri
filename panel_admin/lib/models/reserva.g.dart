// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserva.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Reserva _$ReservaFromJson(Map<String, dynamic> json) => _Reserva(
  id: (json['id'] as num).toInt(),
  restauranteNombre: json['restaurante_nombre'] as String,
  mesaId: (json['mesa_id'] as num).toInt(),
  mesaNumero: (json['mesa_numero'] as num).toInt(),
  fecha: json['fecha'] as String,
  horaInicio: json['hora_inicio'] as String,
  numPersonas: (json['num_personas'] as num).toInt(),
  estado: json['estado'] as String,
);

Map<String, dynamic> _$ReservaToJson(_Reserva instance) => <String, dynamic>{
  'id': instance.id,
  'restaurante_nombre': instance.restauranteNombre,
  'mesa_id': instance.mesaId,
  'mesa_numero': instance.mesaNumero,
  'fecha': instance.fecha,
  'hora_inicio': instance.horaInicio,
  'num_personas': instance.numPersonas,
  'estado': instance.estado,
};
