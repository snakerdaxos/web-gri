// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido_staff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PedidoStaffItem _$PedidoStaffItemFromJson(Map<String, dynamic> json) =>
    _PedidoStaffItem(
      productoId: json['productoId'] as String,
      nombre: json['nombre'] as String,
      cantidad: (json['cantidad'] as num).toInt(),
      precio: (json['precio'] as num).toInt(),
      subtotal: (json['subtotal'] as num).toInt(),
    );

Map<String, dynamic> _$PedidoStaffItemToJson(_PedidoStaffItem instance) =>
    <String, dynamic>{
      'productoId': instance.productoId,
      'nombre': instance.nombre,
      'cantidad': instance.cantidad,
      'precio': instance.precio,
      'subtotal': instance.subtotal,
    };

_PedidoStaff _$PedidoStaffFromJson(Map<String, dynamic> json) => _PedidoStaff(
  id: json['id'] as String,
  restauranteId: json['restauranteId'] as String? ?? '',
  mesaId: json['mesaId'] as String? ?? '',
  sesionId: json['sesionId'] as String?,
  mesaNumero: (json['mesaNumero'] as num).toInt(),
  estado: estadoPedidoFromJson(json['estado'] as String),
  total: (json['total'] as num).toInt(),
  notas: json['notas'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => PedidoStaffItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  usuarioNombre: json['usuarioNombre'] as String,
  solicitaCuenta: json['solicitaCuenta'] as bool? ?? false,
  solicitadaEn: json['solicitadaEn'] == null
      ? null
      : DateTime.parse(json['solicitadaEn'] as String),
);

Map<String, dynamic> _$PedidoStaffToJson(_PedidoStaff instance) =>
    <String, dynamic>{
      'id': instance.id,
      'restauranteId': instance.restauranteId,
      'mesaId': instance.mesaId,
      'sesionId': instance.sesionId,
      'mesaNumero': instance.mesaNumero,
      'estado': estadoPedidoToJson(instance.estado),
      'total': instance.total,
      'notas': instance.notas,
      'createdAt': instance.createdAt.toIso8601String(),
      'items': instance.items,
      'usuarioNombre': instance.usuarioNombre,
      'solicitaCuenta': instance.solicitaCuenta,
      'solicitadaEn': instance.solicitadaEn?.toIso8601String(),
    };
