import 'package:freezed_annotation/freezed_annotation.dart';

part 'pedido_item.freezed.dart';
part 'pedido_item.g.dart';

/// Ítem de un pedido — SNAPSHOT de `{productoId, nombre, precio, cantidad}`
/// congelado al armar el carrito (gap estructural v1: el nombre/precio se
/// copian del doc de producto; el doc de pedido queda inmutable).
///
/// [precio] es `int` COP — Firestore guarda enteros (research 10).
@freezed
abstract class PedidoItem with _$PedidoItem {
  const factory PedidoItem({
    required String productoId,
    required String nombre,
    required int precio,
    required int cantidad,
  }) = _PedidoItem;

  /// Mapea un elemento del array `items` del doc `pedidos/{id}`.
  factory PedidoItem.fromMap(Map<String, dynamic> map) => PedidoItem(
        productoId: map['productoId'] as String? ?? '',
        nombre: map['nombre'] as String? ?? '',
        precio: (map['precio'] as num?)?.toInt() ?? 0,
        cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      );

  /// `fromJson` SOLO sobrevive para que `api_client` (legacy REST) compile
  /// hasta su purga en 10-04.
  factory PedidoItem.fromJson(Map<String, dynamic> json) =>
      _$PedidoItemFromJson(json);
}
