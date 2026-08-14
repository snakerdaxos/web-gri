import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/token_provider.dart';
import '../../core/ws_client.dart';
import '../../models/mesa.dart';
import 'restaurante_provider.dart';

part 'mesas_provider.g.dart';

/// Stream de mesas EN VIVO (RT-02, 07-02): WS push con kick-to-refetch —
/// antes polling 10s.
///
/// El evento WS (`mesa.estado`) SOLO dispara el GET refresh: JAMÁS muta la
/// lista local (cero drift — el server es la única fuente de verdad y el
/// snapshot re-GETeado siempre gana). `wsResyncProvider` (reconexión
/// restablecida) → re-sync total; el Timer de 60s es el safety net que
/// acota la ventana de un WS muerto silencioso (half-open).
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). El contrato `Stream<List<Mesa>>` no cambia — los
/// consumers quedan intactos.
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await/yield — un rebuild con el generator suspendido
/// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
/// eventos que llegan durante el GET inicial quedan bufferizados en el
/// controller single-subscription.
@riverpod
Stream<List<Mesa>> mesas(Ref ref) async* {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) {
    yield* const Stream<List<Mesa>>.empty();
    return;
  }

  final queryRid = user?.isSuperAdmin == true ? rid : null;
  final client = ref.read(apiClientProvider);

  // Suscripciones y teardown REGISTRADAS ANTES del primer await (gotcha
  // riverpod 3.4 post-await). El controller single-subscription bufferiza
  // los refresh que lleguen mientras se entrega el snapshot inicial.
  final controller = StreamController<List<Mesa>>();
  Future<void> refresh() async {
    try {
      final mesas = await client.getMesas(restauranteId: queryRid);
      if (!controller.isClosed) controller.add(mesas);
    } catch (e) {
      // No romper el stream: el error va al AsyncValue y el próximo
      // evento/tick puede recuperar.
      if (!controller.isClosed) controller.addError(e);
    }
  }

  // 1) Evento WS relevante → kick-to-refetch (NO mutar estado local).
  final sub1 = ref
      .watch(wsEventsProvider)
      .where((e) => e.type == 'mesa.estado')
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

  // Snapshot inicial (re-sync de RT-03: estado autoritativo al montar).
  yield await client.getMesas(restauranteId: queryRid);
  yield* controller.stream;
}
