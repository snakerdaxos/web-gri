import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/token_provider.dart';
import '../../models/dashboard_stats.dart';
import 'restaurante_provider.dart';

part 'stats_provider.g.dart';

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
@riverpod
Stream<DashboardStats> stats(Ref ref) async* {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) {
    // super_admin pre-selección: no hay datos que mostrar todavía.
    yield* const Stream<DashboardStats>.empty();
    return;
  }

  // Para super_admin mandamos el rid; para staff lo dejamos en null (backend
  // resuelve el suyo, defensa T-04-02).
  final queryRid = user?.isSuperAdmin == true ? rid : null;
  final client = ref.read(apiClientProvider);

  // Emite el primer valor de inmediato (UX: spinner solo durante el 1er fetch).
  yield await client.getStats(restauranteId: queryRid);

  final controller = StreamController<DashboardStats>();
  Timer? timer;
  timer = Timer.periodic(Duration(seconds: Env.pollSeconds), (_) async {
    try {
      controller.add(await client.getStats(restauranteId: queryRid));
    } catch (e) {
      // No rompemos el stream: el error va al AsyncValue pero el siguiente
      // tick puede recuperar. El dashboard lo renderiza con retry.
      controller.addError(e);
    }
  });
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  yield* controller.stream;
}
