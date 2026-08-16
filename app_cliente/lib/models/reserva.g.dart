// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserva.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Reserva _$ReservaFromJson(Map<String, dynamic> json) => _Reserva(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String,
  restauranteNombre: json['restauranteNombre'] as String? ?? '',
  mesaId: json['mesaId'] as String,
  mesaNumero: (json['mesaNumero'] as num).toInt(),
  usuarioId: json['usuarioId'] as String,
  fecha: DateTime.parse(json['fecha'] as String),
  fechaStr: json['fechaStr'] as String,
  hora: (json['hora'] as num).toInt(),
  numPersonas: (json['numPersonas'] as num).toInt(),
  estado: json['estado'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ReservaToJson(_Reserva instance) => <String, dynamic>{
  'id': instance.id,
  'restauranteId': instance.restauranteId,
  'restauranteNombre': instance.restauranteNombre,
  'mesaId': instance.mesaId,
  'mesaNumero': instance.mesaNumero,
  'usuarioId': instance.usuarioId,
  'fecha': instance.fecha.toIso8601String(),
  'fechaStr': instance.fechaStr,
  'hora': instance.hora,
  'numPersonas': instance.numPersonas,
  'estado': instance.estado,
  'createdAt': instance.createdAt?.toIso8601String(),
};
