// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesion_mesa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SesionMesa _$SesionMesaFromJson(Map<String, dynamic> json) => _SesionMesa(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String,
  mesaId: json['mesaId'] as String,
  usuarioId: json['usuarioId'] as String,
  estado: json['estado'] as String? ?? 'activa',
  cuentaSolicitada: json['cuentaSolicitada'] as bool? ?? false,
  cuentaPedidaAt: json['cuentaPedidaAt'] == null
      ? null
      : DateTime.parse(json['cuentaPedidaAt'] as String),
  inicioAt: json['inicioAt'] == null
      ? null
      : DateTime.parse(json['inicioAt'] as String),
  cerradaAt: json['cerradaAt'] == null
      ? null
      : DateTime.parse(json['cerradaAt'] as String),
  restauranteNombre: json['restauranteNombre'] as String? ?? '',
  mesaNumero: (json['mesaNumero'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SesionMesaToJson(_SesionMesa instance) =>
    <String, dynamic>{
      'id': instance.id,
      'restauranteId': instance.restauranteId,
      'mesaId': instance.mesaId,
      'usuarioId': instance.usuarioId,
      'estado': instance.estado,
      'cuentaSolicitada': instance.cuentaSolicitada,
      'cuentaPedidaAt': instance.cuentaPedidaAt?.toIso8601String(),
      'inicioAt': instance.inicioAt?.toIso8601String(),
      'cerradaAt': instance.cerradaAt?.toIso8601String(),
      'restauranteNombre': instance.restauranteNombre,
      'mesaNumero': instance.mesaNumero,
    };
