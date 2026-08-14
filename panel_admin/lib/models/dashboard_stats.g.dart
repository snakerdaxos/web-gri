// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DashboardStats _$DashboardStatsFromJson(Map<String, dynamic> json) =>
    _DashboardStats(
      mesasDisponibles: (json['mesas_disponibles'] as num).toInt(),
      mesasOcupadas: (json['mesas_ocupadas'] as num).toInt(),
      mesasReservadas: (json['mesas_reservadas'] as num).toInt(),
      mesasLimpieza: (json['mesas_limpieza'] as num).toInt(),
      totalMesas: (json['total_mesas'] as num).toInt(),
      reservasHoy: (json['reservas_hoy'] as num).toInt(),
      pedidosActivos: (json['pedidos_activos'] as num).toInt(),
    );

Map<String, dynamic> _$DashboardStatsToJson(_DashboardStats instance) =>
    <String, dynamic>{
      'mesas_disponibles': instance.mesasDisponibles,
      'mesas_ocupadas': instance.mesasOcupadas,
      'mesas_reservadas': instance.mesasReservadas,
      'mesas_limpieza': instance.mesasLimpieza,
      'total_mesas': instance.totalMesas,
      'reservas_hoy': instance.reservasHoy,
      'pedidos_activos': instance.pedidosActivos,
    };
