// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PedidoItem _$PedidoItemFromJson(Map<String, dynamic> json) => _PedidoItem(
  productoId: (json['producto_id'] as num).toInt(),
  nombre: json['nombre'] as String,
  cantidad: (json['cantidad'] as num).toInt(),
  precioUnitario: (json['precio_unitario'] as num).toDouble(),
  subtotal: (json['subtotal'] as num).toDouble(),
);

Map<String, dynamic> _$PedidoItemToJson(_PedidoItem instance) =>
    <String, dynamic>{
      'producto_id': instance.productoId,
      'nombre': instance.nombre,
      'cantidad': instance.cantidad,
      'precio_unitario': instance.precioUnitario,
      'subtotal': instance.subtotal,
    };
