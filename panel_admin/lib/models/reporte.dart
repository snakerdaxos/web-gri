import 'package:freezed_annotation/freezed_annotation.dart';

part 'reporte.freezed.dart';
part 'reporte.g.dart';

/// Venta agregada por día (`GET /staff/reportes/ventas` → `por_dia[]`,
/// REPO-01, backend 08-02).
///
/// `fecha` viaja como `YYYY-MM-DD` (string, lista ordenada ASC por fecha);
/// `total` llega como JSON number (Decimal→float serializado server-side).
@freezed
abstract class VentaDia with _$VentaDia {
  const factory VentaDia({
    required String fecha,
    required double total,
    @JsonKey(name: 'num_pedidos') required int numPedidos,
  }) = _VentaDia;

  factory VentaDia.fromJson(Map<String, dynamic> json) =>
      _$VentaDiaFromJson(json);
}

/// Reporte de ventas por rango (`GET /staff/reportes/ventas`, REPO-01).
///
/// Venta = pedido en estado `servido`|`pagado` (decisión locked 08-02).
/// Sin `desde`/`hasta` el server aplica su default DB-side (últimos 7 días
/// — la respuesta SIEMPRE trae el rango efectivo en [desde]/[hasta]).
@freezed
abstract class VentasReporte with _$VentasReporte {
  const factory VentasReporte({
    required String desde,
    required String hasta,
    required double total,
    @JsonKey(name: 'num_pedidos') required int numPedidos,
    @JsonKey(name: 'por_dia') required List<VentaDia> porDia,
  }) = _VentasReporte;

  factory VentasReporte.fromJson(Map<String, dynamic> json) =>
      _$VentasReporteFromJson(json);
}

/// Plato más vendido (`GET /staff/reportes/top-platos`, REPO-02) — SUM(
/// cantidad) DESC sobre pedido_item; `nombre` es el ACTUAL del producto y
/// `total` el monto exacto por snapshot de precio (backend 08-02).
@freezed
abstract class TopPlato with _$TopPlato {
  const factory TopPlato({
    @JsonKey(name: 'producto_id') required int productoId,
    required String nombre,
    required int cantidad,
    required double total,
  }) = _TopPlato;

  factory TopPlato.fromJson(Map<String, dynamic> json) =>
      _$TopPlatoFromJson(json);
}
