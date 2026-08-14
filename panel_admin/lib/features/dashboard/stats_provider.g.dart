// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de DashboardStats EN VIVO (RT-01/02, 07-02): WS push con
/// kick-to-refetch — antes polling 10s.
///
/// Emite el fetch inicial inmediato, luego cada evento WS relevante
/// (`mesa.estado`, `pedido.creado`, `pedido.estado` — dashboard completo en
/// vivo) dispara un GET refresh (el evento SOLO es señal). `wsResyncProvider`
/// (reconexión restablecida) → re-sync total; Timer de 60s como safety net
/// de un WS muerto silencioso.
///
/// Filtra por restaurante:
///  * staff → restaurante_id=null (backend usa el tenant del token; Plan 04-01
///    ignora el param para staff).
///  * super_admin → restaurante_id=currentRestauranteIdProvider.
///
/// Si super_admin sin selección (rid null) → emite Stream vacío hasta que se
/// setee el default (dashboard_screen muestra estado "Selecciona restaurante").
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await/yield — un rebuild con el generator suspendido
/// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
/// eventos que llegan durante el GET inicial quedan bufferizados en el
/// controller single-subscription.

@ProviderFor(stats)
final statsProvider = StatsProvider._();

/// Stream de DashboardStats EN VIVO (RT-01/02, 07-02): WS push con
/// kick-to-refetch — antes polling 10s.
///
/// Emite el fetch inicial inmediato, luego cada evento WS relevante
/// (`mesa.estado`, `pedido.creado`, `pedido.estado` — dashboard completo en
/// vivo) dispara un GET refresh (el evento SOLO es señal). `wsResyncProvider`
/// (reconexión restablecida) → re-sync total; Timer de 60s como safety net
/// de un WS muerto silencioso.
///
/// Filtra por restaurante:
///  * staff → restaurante_id=null (backend usa el tenant del token; Plan 04-01
///    ignora el param para staff).
///  * super_admin → restaurante_id=currentRestauranteIdProvider.
///
/// Si super_admin sin selección (rid null) → emite Stream vacío hasta que se
/// setee el default (dashboard_screen muestra estado "Selecciona restaurante").
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await/yield — un rebuild con el generator suspendido
/// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
/// eventos que llegan durante el GET inicial quedan bufferizados en el
/// controller single-subscription.

final class StatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardStats>,
          DashboardStats,
          Stream<DashboardStats>
        >
    with $FutureModifier<DashboardStats>, $StreamProvider<DashboardStats> {
  /// Stream de DashboardStats EN VIVO (RT-01/02, 07-02): WS push con
  /// kick-to-refetch — antes polling 10s.
  ///
  /// Emite el fetch inicial inmediato, luego cada evento WS relevante
  /// (`mesa.estado`, `pedido.creado`, `pedido.estado` — dashboard completo en
  /// vivo) dispara un GET refresh (el evento SOLO es señal). `wsResyncProvider`
  /// (reconexión restablecida) → re-sync total; Timer de 60s como safety net
  /// de un WS muerto silencioso.
  ///
  /// Filtra por restaurante:
  ///  * staff → restaurante_id=null (backend usa el tenant del token; Plan 04-01
  ///    ignora el param para staff).
  ///  * super_admin → restaurante_id=currentRestauranteIdProvider.
  ///
  /// Si super_admin sin selección (rid null) → emite Stream vacío hasta que se
  /// setee el default (dashboard_screen muestra estado "Selecciona restaurante").
  ///
  /// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
  /// ANTES del primer await/yield — un rebuild con el generator suspendido
  /// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
  /// eventos que llegan durante el GET inicial quedan bufferizados en el
  /// controller single-subscription.
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

String _$statsHash() => r'a7b963ee50c611bd096bfd060f2ef2a5674355b2';
