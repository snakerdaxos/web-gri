// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserva_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReservaCreate _$ReservaCreateFromJson(Map<String, dynamic> json) =>
    _ReservaCreate(
      restauranteId: (json['restaurante_id'] as num).toInt(),
      fecha: json['fecha'] as String,
      horaInicio: json['hora_inicio'] as String,
      numPersonas: (json['num_personas'] as num).toInt(),
    );

Map<String, dynamic> _$ReservaCreateToJson(_ReservaCreate instance) =>
    <String, dynamic>{
      'restaurante_id': instance.restauranteId,
      'fecha': instance.fecha,
      'hora_inicio': instance.horaInicio,
      'num_personas': instance.numPersonas,
    };
