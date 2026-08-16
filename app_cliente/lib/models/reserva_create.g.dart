// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserva_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReservaCreate _$ReservaCreateFromJson(Map<String, dynamic> json) =>
    _ReservaCreate(
      restauranteId: json['restauranteId'] as String,
      fecha: json['fecha'] as String,
      hora: (json['hora'] as num).toInt(),
      numPersonas: (json['numPersonas'] as num).toInt(),
    );

Map<String, dynamic> _$ReservaCreateToJson(_ReservaCreate instance) =>
    <String, dynamic>{
      'restauranteId': instance.restauranteId,
      'fecha': instance.fecha,
      'hora': instance.hora,
      'numPersonas': instance.numPersonas,
    };
