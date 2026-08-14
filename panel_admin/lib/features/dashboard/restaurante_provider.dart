import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/restaurante.dart';

part 'restaurante_provider.g.dart';

/// Restaurante activo en el panel: staff siempre su tenant; super_admin el
/// que elija en el dropdown del AppShell (default al primero activo).
///
/// Notifier custom (Riverpod 3.x: StateProvider se deprecó en favor de
/// NotifierProvider). El estado se setea vía [set] desde el AppShell.
class CurrentRestauranteId extends Notifier<int?> {
  @override
  int? build() {
    final user = ref.read(authStateProvider).value;
    return user?.restaurantId;
  }

  void set(int? id) {
    state = id;
  }
}

final currentRestauranteIdProvider =
    NotifierProvider<CurrentRestauranteId, int?>(
  CurrentRestauranteId.new,
);

/// FutureProvider que resuelve el [Restaurante] a mostrar en el topbar (nombre).
///
/// Staff: siempre su propio tenant. Super_admin: el seleccionado en el
/// dropdown (o el default). Si super_admin sin selección → lanza StateError
/// (no debería ocurrir porque AppShell setea el default apenas carga la lista).
@riverpod
Future<Restaurante> restaurante(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;
  if (rid == null) {
    throw StateError('No hay restaurante seleccionado');
  }
  return ref.read(apiClientProvider).getRestaurante(rid);
}
