// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stats del dashboard DERIVADAS de los 3 streams realtime (10-05 Task 3 —
/// sin endpoint): mesas por estado + reservas de hoy + pedidos activos,
/// combinadas con combineLatest para re-emitir ante CUALQUIER cambio.
///
/// * Queries del bloque interfaces del plan:
///   * mesas `where restauranteId == rid` (sin orderBy: solo se cuentan).
///   * reservas `where restauranteId == rid where fecha >= inicioHoy &&
///     fecha < inicioMañana` — ventana computada en la TZ local del
///     operador.
///   * pedidos `where restauranteId == rid where estado in
///     [enviado, aceptado, en_preparacion]` (misma definición de "activo"
///     que la cola de cocina).
/// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).

@ProviderFor(stats)
final statsProvider = StatsProvider._();

/// Stats del dashboard DERIVADAS de los 3 streams realtime (10-05 Task 3 —
/// sin endpoint): mesas por estado + reservas de hoy + pedidos activos,
/// combinadas con combineLatest para re-emitir ante CUALQUIER cambio.
///
/// * Queries del bloque interfaces del plan:
///   * mesas `where restauranteId == rid` (sin orderBy: solo se cuentan).
///   * reservas `where restauranteId == rid where fecha >= inicioHoy &&
///     fecha < inicioMañana` — ventana computada en la TZ local del
///     operador.
///   * pedidos `where restauranteId == rid where estado in
///     [enviado, aceptado, en_preparacion]` (misma definición de "activo"
///     que la cola de cocina).
/// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).

final class StatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardStats>,
          DashboardStats,
          Stream<DashboardStats>
        >
    with $FutureModifier<DashboardStats>, $StreamProvider<DashboardStats> {
  /// Stats del dashboard DERIVADAS de los 3 streams realtime (10-05 Task 3 —
  /// sin endpoint): mesas por estado + reservas de hoy + pedidos activos,
  /// combinadas con combineLatest para re-emitir ante CUALQUIER cambio.
  ///
  /// * Queries del bloque interfaces del plan:
  ///   * mesas `where restauranteId == rid` (sin orderBy: solo se cuentan).
  ///   * reservas `where restauranteId == rid where fecha >= inicioHoy &&
  ///     fecha < inicioMañana` — ventana computada en la TZ local del
  ///     operador.
  ///   * pedidos `where restauranteId == rid where estado in
  ///     [enviado, aceptado, en_preparacion]` (misma definición de "activo"
  ///     que la cola de cocina).
  /// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).
  StatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statsHash();

  @$internal
  @override
  $StreamProviderElement<DashboardStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DashboardStats> create(Ref ref) {
    return stats(ref);
  }
}

String _$statsHash() => r'1ce07e25bdc5b7cd2725e6786f91e9b5b2a04748';
