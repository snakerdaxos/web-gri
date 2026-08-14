import 'package:freezed_annotation/freezed_annotation.dart';

part 'pedido_item.freezed.dart';
part 'pedido_item.g.dart';

/// Ítem de un pedido (`PedidoItemRead` del backend) — snapshot del precio
/// al momento del envío (server-side, jamás precios del cliente).
@freezed
abstract class PedidoItem with _$PedidoItem {
  const factory PedidoItem({
    @JsonKey(name: 'producto_id') required int productoId,
    required String nombre,
    required int cantidad,
    @JsonKey(name: 'precio_unitario') required double precioUnitario,
    required double subtotal,
  }) = _PedidoItem;

  factory PedidoItem.fromJson(Map<String, dynamic> json) =>
      _$PedidoItemFromJson(json);
}
