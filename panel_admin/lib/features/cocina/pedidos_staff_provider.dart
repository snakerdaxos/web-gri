import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/token_provider.dart';
import '../../models/pedido_staff.dart';
import '../dashboard/restaurante_provider.dart';

part 'pedidos_staff_provider.g.dart';

/// Stream de la cola de pedidos activos con polling 10s — espejo de
/// [mesasProvider] sobre `GET /staff/pedidos?activos=true` (ADMN-05).
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
/// staff jamás filtra client-side. Phase 7 (WS) retira el Timer sin
/// tocar los consumers.
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

  yield await client.getPedidosActivos(restauranteId: queryRid);

  final controller = StreamController<List<PedidoStaff>>();
  Timer? timer;
  timer = Timer.periodic(Duration(seconds: Env.pollSeconds), (_) async {
    try {
      controller.add(await client.getPedidosActivos(restauranteId: queryRid));
    } catch (e) {
      controller.addError(e);
    }
  });
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  yield* controller.stream;
}
