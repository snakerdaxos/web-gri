// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de DashboardStats con polling 10s (deuda Phase 7: WS).
///
/// Emite el fetch inicial inmediatamente, luego Timer.periodic cada
/// Env.pollSeconds (default 10). El timer se cancela en ref.onDispose.
///
/// Filtra por restaurante:
///  * staff → restaurante_id=null (backend usa el tenant del token; Plan 04-01
///    ignora el param para staff).
///  * super_admin → restaurante_id=currentRestauranteIdProvider.
///
/// Si super_admin sin selección (rid null) → emite Stream vacío hasta que se
/// setee el default (dashboard_screen muestra estado "Selecciona restaurante").

@ProviderFor(stats)
final statsProvider = StatsProvider._();

/// Stream de DashboardStats con polling 10s (deuda Phase 7: WS).
///
/// Emite el fetch inicial inmediatamente, luego Timer.periodic cada
/// Env.pollSeconds (default 10). El timer se cancela en ref.onDispose.
///
/// Filtra por restaurante:
///  * staff → restaurante_id=null (backend usa el tenant del token; Plan 04-01
///    ignora el param para staff).
///  * super_admin → restaurante_id=currentRestauranteIdProvider.
///
/// Si super_admin sin selección (rid null) → emite Stream vacío hasta que se
/// setee el default (dashboard_screen muestra estado "Selecciona restaurante").

final class StatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardStats>,
          DashboardStats,
          Stream<DashboardStats>
        >
    with $FutureModifier<DashboardStats>, $StreamProvider<DashboardStats> {
  /// Stream de DashboardStats con polling 10s (deuda Phase 7: WS).
  ///
  /// Emite el fetch inicial inmediatamente, luego Timer.periodic cada
  /// Env.pollSeconds (default 10). El timer se cancela en ref.onDispose.
  ///
  /// Filtra por restaurante:
  ///  * staff → restaurante_id=null (backend usa el tenant del token; Plan 04-01
  ///    ignora el param para staff).
  ///  * super_admin → restaurante_id=currentRestauranteIdProvider.
  ///
  /// Si super_admin sin selección (rid null) → emite Stream vacío hasta que se
  /// setee el default (dashboard_screen muestra estado "Selecciona restaurante").
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

String _$statsHash() => r'48c7590ccb5acc252f8fc5ae5518edaf99d58f11';
