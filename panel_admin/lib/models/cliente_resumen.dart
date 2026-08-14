import 'package:freezed_annotation/freezed_annotation.dart';

part 'cliente_resumen.freezed.dart';
part 'cliente_resumen.g.dart';

/// Resumen de un cliente del restaurante (`GET /staff/clientes`, ADMN-03).
///
/// Cliente = usuario CON pedidos en el tenant (JOIN pedido→usuario en el
/// backend, 08-01): quien solo reservó NO aparece. `totalGastado` llega
/// como JSON number (float serializado server-side).
@freezed
abstract class ClienteResumen with _$ClienteResumen {
  const factory ClienteResumen({
    @JsonKey(name: 'usuario_id') required int usuarioId,
    required String nombre,
    required String email,
    @JsonKey(name: 'num_pedidos') required int numPedidos,
    @JsonKey(name: 'total_gastado') required double totalGastado,
    @JsonKey(name: 'ultimo_pedido_at') required DateTime? ultimoPedidoAt,
  }) = _ClienteResumen;

  factory ClienteResumen.fromJson(Map<String, dynamic> json) =>
      _$ClienteResumenFromJson(json);
}
