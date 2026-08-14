// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Pedido _$PedidoFromJson(Map<String, dynamic> json) => _Pedido(
  id: (json['id'] as num).toInt(),
  sesionId: (json['sesion_id'] as num).toInt(),
  mesaNumero: (json['mesa_numero'] as num).toInt(),
  estado: json['estado'] as String,
  total: (json['total'] as num).toDouble(),
  notas: json['notas'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => PedidoItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PedidoToJson(_Pedido instance) => <String, dynamic>{
  'id': instance.id,
  'sesion_id': instance.sesionId,
  'mesa_numero': instance.mesaNumero,
  'estado': instance.estado,
  'total': instance.total,
  'notas': instance.notas,
  'created_at': instance.createdAt.toIso8601String(),
  'items': instance.items,
};
