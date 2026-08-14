import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../models/pedido.dart';
import '../sesion_qr/sesion_provider.dart';

part 'pedidos_provider.g.dart';

/// Stream de pedidos de la sesión activa con polling 10s (PEDI-04) —
/// clon EXACTO del patrón mesas_provider del panel (Pitfall 8: el timer
/// se cancela en `ref.onDispose`; Phase 7 lo reemplaza por WebSocket).
///
/// Sin sesión activa → stream vacío (la screen muestra el estado vacío).
/// autoDispose: al dejar de observarse (salir de la pantalla) el timer
/// muere — sin timers zombis entre navegación.
@riverpod
Stream<List<Pedido>> pedidosSession(Ref ref) async* {
  final sesion = ref.watch(sesionProvider).value;
  if (sesion == null) {
    yield* const Stream<List<Pedido>>.empty();
    return;
  }

  final client = ref.read(apiClientProvider);

  yield await client.getPedidosActuales();

  final controller = StreamController<List<Pedido>>();
  Timer? timer;
  timer = Timer.periodic(Duration(seconds: Env.pollSeconds), (_) async {
    try {
      controller.add(await client.getPedidosActuales());
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
