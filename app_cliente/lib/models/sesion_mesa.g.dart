// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesion_mesa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SesionMesa _$SesionMesaFromJson(Map<String, dynamic> json) => _SesionMesa(
  id: (json['id'] as num).toInt(),
  restauranteId: (json['restaurante_id'] as num).toInt(),
  restauranteNombre: json['restaurante_nombre'] as String,
  mesaId: (json['mesa_id'] as num).toInt(),
  mesaNumero: (json['mesa_numero'] as num).toInt(),
  abiertaEn: DateTime.parse(json['abierta_en'] as String),
  solicitaCuenta: json['solicita_cuenta'] as bool,
  solicitadaEn: json['solicitada_en'] == null
      ? null
      : DateTime.parse(json['solicitada_en'] as String),
);

Map<String, dynamic> _$SesionMesaToJson(_SesionMesa instance) =>
    <String, dynamic>{
      'id': instance.id,
      'restaurante_id': instance.restauranteId,
      'restaurante_nombre': instance.restauranteNombre,
      'mesa_id': instance.mesaId,
      'mesa_numero': instance.mesaNumero,
      'abierta_en': instance.abiertaEn.toIso8601String(),
      'solicita_cuenta': instance.solicitaCuenta,
      'solicitada_en': instance.solicitadaEn?.toIso8601String(),
    };
