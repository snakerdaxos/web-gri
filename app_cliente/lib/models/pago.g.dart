// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pago.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PagoIntencion _$PagoIntencionFromJson(Map<String, dynamic> json) =>
    _PagoIntencion(
      pagoId: (json['pago_id'] as num).toInt(),
      referencia: json['referencia'] as String,
      monto: (json['monto'] as num).toDouble(),
      estado: json['estado'] as String,
      checkoutUrl: json['checkout_url'] as String,
    );

Map<String, dynamic> _$PagoIntencionToJson(_PagoIntencion instance) =>
    <String, dynamic>{
      'pago_id': instance.pagoId,
      'referencia': instance.referencia,
      'monto': instance.monto,
      'estado': instance.estado,
      'checkout_url': instance.checkoutUrl,
    };

_PagoEstado _$PagoEstadoFromJson(Map<String, dynamic> json) => _PagoEstado(
  pagoId: (json['pago_id'] as num).toInt(),
  estado: json['estado'] as String,
  referencia: json['referencia'] as String,
  monto: (json['monto'] as num).toDouble(),
  pedidoIds: (json['pedido_ids'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$PagoEstadoToJson(_PagoEstado instance) =>
    <String, dynamic>{
      'pago_id': instance.pagoId,
      'estado': instance.estado,
      'referencia': instance.referencia,
      'monto': instance.monto,
      'pedido_ids': instance.pedidoIds,
    };
