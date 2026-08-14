import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/token_provider.dart';
import '../../models/mesa.dart';
import 'restaurante_provider.dart';

part 'mesas_provider.g.dart';

/// Stream de mesas con polling 10s — espejo de [statsProvider] pero sobre
/// `GET /staff/mesas` (mapa de mesas, ADMN-02).
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

  yield await client.getMesas(restauranteId: queryRid);

  final controller = StreamController<List<Mesa>>();
  Timer? timer;
  timer = Timer.periodic(Duration(seconds: Env.pollSeconds), (_) async {
    try {
      controller.add(await client.getMesas(restauranteId: queryRid));
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
