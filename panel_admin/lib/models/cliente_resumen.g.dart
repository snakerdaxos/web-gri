// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cliente_resumen.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClienteResumen _$ClienteResumenFromJson(Map<String, dynamic> json) =>
    _ClienteResumen(
      usuarioId: (json['usuario_id'] as num).toInt(),
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      numPedidos: (json['num_pedidos'] as num).toInt(),
      totalGastado: (json['total_gastado'] as num).toDouble(),
      ultimoPedidoAt: json['ultimo_pedido_at'] == null
          ? null
          : DateTime.parse(json['ultimo_pedido_at'] as String),
    );

Map<String, dynamic> _$ClienteResumenToJson(_ClienteResumen instance) =>
    <String, dynamic>{
      'usuario_id': instance.usuarioId,
      'nombre': instance.nombre,
      'email': instance.email,
      'num_pedidos': instance.numPedidos,
      'total_gastado': instance.totalGastado,
      'ultimo_pedido_at': instance.ultimoPedidoAt?.toIso8601String(),
    };
