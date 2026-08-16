import 'package:freezed_annotation/freezed_annotation.dart';

part 'reporte.freezed.dart';

/// Reporte de ventas por rango (REPO-01/02, Phase 10) — computado EN EL
/// CLIENTE (fold de pedidos `servido` en el rango; decisión planner:
/// agregaciones formales = fase futura).
///
/// * [totalVentas] — Σ `total` (int COP) de los pedidos servidos en rango.
/// * [numeroPedidos] — count de esos pedidos.
/// * [topPlatos] — por nombre de item (snapshot): Σ cantidad y Σ venta
///   (precio×cantidad del snapshot), ordenado por cantidad DESC.
///
/// NOTA documentada (threat model 10-06): venta = estado `servido`
/// (`pagado` inalcanzable en v1); los montos son display client-side
/// hasta que la validación fuerte llegue con Functions (fase pagos).
@freezed
abstract class Reporte with _$Reporte {
  const factory Reporte({
    required int totalVentas,
    required int numeroPedidos,
    @Default(<TopPlato>[]) List<TopPlato> topPlatos,
  }) = _Reporte;
}

/// Un plato del top (desde el snapshot de items de los pedidos servidos).
@freezed
abstract class TopPlato with _$TopPlato {
  const factory TopPlato({
    required String nombre,
    required int cantidad,

    /// Σ precio×cantidad del snapshot (int COP).
    required int venta,
  }) = _TopPlato;
}
