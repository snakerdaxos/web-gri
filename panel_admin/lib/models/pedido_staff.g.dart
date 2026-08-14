// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido_staff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PedidoStaffItem _$PedidoStaffItemFromJson(Map<String, dynamic> json) =>
    _PedidoStaffItem(
      productoId: (json['producto_id'] as num).toInt(),
      nombre: json['nombre'] as String,
      cantidad: (json['cantidad'] as num).toInt(),
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );

Map<String, dynamic> _$PedidoStaffItemToJson(_PedidoStaffItem instance) =>
    <String, dynamic>{
      'producto_id': instance.productoId,
      'nombre': instance.nombre,
      'cantidad': instance.cantidad,
      'precio_unitario': instance.precioUnitario,
      'subtotal': instance.subtotal,
    };

_PedidoStaff _$PedidoStaffFromJson(Map<String, dynamic> json) => _PedidoStaff(
  id: (json['id'] as num).toInt(),
  sesionId: (json['sesion_id'] as num?)?.toInt(),
  mesaNumero: (json['mesa_numero'] as num).toInt(),
  estado: estadoPedidoFromJson(json['estado'] as String),
  total: (json['total'] as num).toDouble(),
  notas: json['notas'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => PedidoStaffItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  usuarioNombre: json['usuario_nombre'] as String,
  solicitaCuenta: json['solicita_cuenta'] as bool? ?? false,
  solicitadaEn: json['solicitada_en'] == null
      ? null
      : DateTime.parse(json['solicitada_en'] as String),
);

Map<String, dynamic> _$PedidoStaffToJson(_PedidoStaff instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sesion_id': instance.sesionId,
      'mesa_numero': instance.mesaNumero,
      'estado': estadoPedidoToJson(instance.estado),
      'total': instance.total,
      'notas': instance.notas,
      'created_at': instance.createdAt.toIso8601String(),
      'items': instance.items,
      'usuario_nombre': instance.usuarioNombre,
      'solicita_cuenta': instance.solicitaCuenta,
      'solicitada_en': instance.solicitadaEn?.toIso8601String(),
    };
