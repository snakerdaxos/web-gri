import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/token_provider.dart';
import '../../core/ws_client.dart';
import '../../models/pedido_staff.dart';
import '../dashboard/restaurante_provider.dart';

part 'pedidos_staff_provider.g.dart';

/// Stream de la cola de pedidos activos EN VIVO (RT-01, 07-02): WS push con
/// kick-to-refetch — antes polling 10s.
///
/// Cada evento WS relevante (`pedido.creado`, `pedido.estado`,
/// `sesion.cuenta` y `mesa.estado` — la cola re-ordena si la mesa cambia)
/// dispara un GET refresh: el evento SOLO es señal, JAMÁS muta la cola
/// local (cero drift — el server ya construye la cola con joins display y
/// orden FIFO FIELD()). `wsResyncProvider` (reconexión restablecida) →
/// re-sync total; Timer de 60s como safety net.
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
/// staff jamás filtra client-side. El contrato `Stream<List<PedidoStaff>>`
/// no cambia — los consumers quedan intactos.
@riverpod
Stream<List<PedidoStaff>> pedidosStaff(Ref ref) async* {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) {
    yield* const Stream<List<PedidoStaff>>.empty();
    return;
  }

  final queryRid = user?.isSuperAdmin == true ? rid : null;
  final client = ref.read(apiClientProvider);

  // Snapshot inicial (re-sync de RT-03: estado autoritativo al montar).
  yield await client.getPedidosActivos(restauranteId: queryRid);

  final controller = StreamController<List<PedidoStaff>>();
  Future<void> refresh() async {
    try {
      controller.add(await client.getPedidosActivos(restauranteId: queryRid));
    } catch (e) {
      // No romper el stream: el error va al AsyncValue y el próximo
      // evento/tick puede recuperar.
      controller.addError(e);
    }
  }

  // 1) Eventos WS relevantes → kick-to-refetch (NO mutar estado local).
  const relevantes = {
    'pedido.creado',
    'pedido.estado',
    'sesion.cuenta',
    'mesa.estado',
  };
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
