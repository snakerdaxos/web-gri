import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/token_provider.dart';
import '../../core/ws_client.dart';
import '../../models/dashboard_stats.dart';
import 'restaurante_provider.dart';

part 'stats_provider.g.dart';

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

  // Snapshot inicial inmediato (UX: spinner solo durante el 1er fetch).
  yield await client.getStats(restauranteId: queryRid);

  final controller = StreamController<DashboardStats>();
  Future<void> refresh() async {
    try {
      controller.add(await client.getStats(restauranteId: queryRid));
    } catch (e) {
      // No rompemos el stream: el error va al AsyncValue pero el siguiente
      // evento puede recuperar. El dashboard lo renderiza con retry.
      controller.addError(e);
    }
  }

  // 1) Eventos WS relevantes → kick-to-refetch (NO mutar estado local).
  const relevantes = {'mesa.estado', 'pedido.creado', 'pedido.estado'};
  final sub1 = ref
      .watch(wsEventsProvider)
      .where((e) => relevantes.contains(e.type))
      .listen((_) => refresh());
  // 2) Reconexión restablecida → re-sync total (RT-03).
  final sub2 = ref.watch(wsResyncProvider).listen((_) => refresh());
  // 3) Safety net: polling lento 60s (cubre bugs de WS; barato).
  final timer = Timer.periodic(
    Duration(seconds: Env.pollSafetyNetSeconds),
    (_) => refresh(),
  );

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    timer.cancel();
    controller.close();
  });
  yield* controller.stream;
}
