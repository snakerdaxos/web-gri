import 'package:freezed_annotation/freezed_annotation.dart';

part 'cliente_resumen.freezed.dart';

/// Resumen de un cliente del restaurante (ADMN-03, Phase 10).
///
/// Cliente = usuario CON pedidos en el tenant, DERIVADO de pedidos
/// (fold client-side): las rules no permiten al staff leer `usuarios/`
/// ajenos, así que el nombre llega denormalizado en cada pedido
/// (`clienteNombre`). Quien solo reservó NO aparece (sin pedidos).
///
/// NOTA de coste (documentada en el plan): v1 demo hace get + fold en
/// cliente; las agregaciones formales viven en una fase futura.
@freezed
abstract class ClienteResumen with _$ClienteResumen {
  const factory ClienteResumen({
    /// UID de Firebase del cliente.
    required String usuarioId,

    /// Nombre denormalizado del ÚLTIMO pedido (snapshot).
    required String clienteNombre,
    required int nPedidos,

    /// Σ totals int COP.
    required int totalConsumo,

    /// createdAt del pedido más reciente.
    DateTime? ultimoPedido,
  }) = _ClienteResumen;
}
