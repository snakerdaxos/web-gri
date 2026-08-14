import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/ws_client.dart';
import '../../models/pedido.dart';
import '../sesion_qr/sesion_provider.dart';

part 'pedidos_provider.g.dart';

/// Stream de pedidos de la sesión activa EN VIVO (PEDI-04, Phase 7).
///
/// GET inicial (snapshot autoritativo) + kick-to-refetch: los eventos WS
/// (`pedido.creado` / `pedido.estado` / `sesion.cuenta` / `sesion.abierta` /
/// `sesion.cerrada`) NUNCA mutan la lista local — disparan un
/// `GET /cliente/pedidos/actual` (única fuente de verdad de orden/estado).
/// El polling de 10s quedó en safety net de [Env.pollSafetyNetSeconds]
/// (acota half-open tras background, Pitfall 6 del research 07).
///
/// `sesion.cerrada` (anti-zombi del staff o pago) → invalidate de
/// [sesionProvider]: el banner "Estás en la Mesa X" desaparece y este
/// provider colapsa a Stream.empty al reconstruirse con sesión null
/// (el 404 del GET ya se traduce a null). Se refetchea igualmente por si
/// llega una `cerrada` de una sesión vieja.
///
/// Sin sesión activa → stream vacío. autoDispose: al dejar de observarse
/// mueren las suscripciones al broadcast del WsClient y el timer.
@riverpod
Stream<List<Pedido>> pedidosSession(Ref ref) async* {
  final sesion = ref.watch(sesionProvider).value;
  if (sesion == null) {
    yield* const Stream<List<Pedido>>.empty();
    return;
  }

  final client = ref.read(apiClientProvider);

  // Snapshot inicial — también el re-sync de RT-03 (tras reconexión WS).
  yield await client.getPedidosActuales();

  final controller = StreamController<List<Pedido>>();
  Future<void> refresh() async {
    try {
      controller.add(await client.getPedidosActuales());
    } catch (e) {
      controller.addError(e);
    }
  }

  // 1) Eventos WS relevantes → kick-to-refetch (idempotente por diseño).
  const kickTypes = {
    'pedido.creado',
    'pedido.estado',
    'sesion.cuenta',
    'sesion.abierta',
    'sesion.cerrada',
  };
  final sub1 = ref
      .watch(wsEventsProvider)
      .where((e) => kickTypes.contains(e.type))
      .listen((e) {
    if (e.type == 'sesion.cerrada') {
      ref.invalidate(sesionProvider); // la sesión murió → banner fuera
    }
    refresh();
  });

  // 2) Reconexión WS restablecida → re-sync total.
  final sub2 = ref.watch(wsResyncProvider).listen((_) => refresh());

  // 3) Safety net: polling lento 60s.
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
