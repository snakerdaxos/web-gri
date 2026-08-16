// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Pedido _$PedidoFromJson(Map<String, dynamic> json) => _Pedido(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String,
  mesaId: json['mesaId'] as String,
  sesionId: json['sesionId'] as String,
  usuarioId: json['usuarioId'] as String,
  clienteNombre: json['clienteNombre'] as String? ?? '',
  estado: json['estado'] as String,
  total: (json['total'] as num).toInt(),
  items: (json['items'] as List<dynamic>)
      .map((e) => PedidoItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PedidoToJson(_Pedido instance) => <String, dynamic>{
  'id': instance.id,
  'restauranteId': instance.restauranteId,
  'mesaId': instance.mesaId,
  'sesionId': instance.sesionId,
  'usuarioId': instance.usuarioId,
  'clienteNombre': instance.clienteNombre,
  'estado': instance.estado,
  'total': instance.total,
  'items': instance.items,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
