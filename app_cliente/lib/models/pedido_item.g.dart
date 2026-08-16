// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PedidoItem _$PedidoItemFromJson(Map<String, dynamic> json) => _PedidoItem(
  productoId: json['productoId'] as String,
  nombre: json['nombre'] as String,
  precio: (json['precio'] as num).toInt(),
  cantidad: (json['cantidad'] as num).toInt(),
);

Map<String, dynamic> _$PedidoItemToJson(_PedidoItem instance) =>
    <String, dynamic>{
      'productoId': instance.productoId,
      'nombre': instance.nombre,
      'precio': instance.precio,
      'cantidad': instance.cantidad,
    };
