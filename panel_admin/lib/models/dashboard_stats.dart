import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_stats.freezed.dart';
part 'dashboard_stats.g.dart';

/// Los 7 counts del dashboard (`GET /staff/stats`, ADMN-01).
@freezed
abstract class DashboardStats with _$DashboardStats {
  const factory DashboardStats({
    @JsonKey(name: 'mesas_disponibles') required int mesasDisponibles,
    @JsonKey(name: 'mesas_ocupadas') required int mesasOcupadas,
    @JsonKey(name: 'mesas_reservadas') required int mesasReservadas,
    @JsonKey(name: 'mesas_limpieza') required int mesasLimpieza,
    @JsonKey(name: 'total_mesas') required int totalMesas,
    @JsonKey(name: 'reservas_hoy') required int reservasHoy,
    @JsonKey(name: 'pedidos_activos') required int pedidosActivos,
  }) = _DashboardStats;

  factory DashboardStats.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsFromJson(json);
}
