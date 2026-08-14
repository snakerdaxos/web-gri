// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Mesa _$MesaFromJson(Map<String, dynamic> json) => _Mesa(
  id: (json['id'] as num).toInt(),
  numero: (json['numero'] as num).toInt(),
  capacidad: (json['capacidad'] as num).toInt(),
  codigoQr: json['codigo_qr'] as String,
  estado: estadoMesaFromJson(json['estado'] as String),
);

Map<String, dynamic> _$MesaToJson(_Mesa instance) => <String, dynamic>{
  'id': instance.id,
  'numero': instance.numero,
  'capacidad': instance.capacidad,
  'codigo_qr': instance.codigoQr,
  'estado': _$EstadoMesaEnumMap[instance.estado]!,
};

const _$EstadoMesaEnumMap = {
  EstadoMesa.disponible: 'disponible',
  EstadoMesa.ocupada: 'ocupada',
  EstadoMesa.reservada: 'reservada',
  EstadoMesa.limpieza: 'limpieza',
};
