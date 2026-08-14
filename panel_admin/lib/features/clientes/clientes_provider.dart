import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/cliente_resumen.dart';
import '../dashboard/restaurante_provider.dart';

part 'clientes_provider.g.dart';

/// Clientes del restaurante (usuarios con pedidos en el tenant, ADMN-03).
///
/// Sin WS (decisión research 08): la tabla vive de este FutureProvider y la
/// UI lo invalida cuando corresponde. rid null (super_admin sin selección)
/// → `[]` (patrón mesasProvider).
@riverpod
Future<List<ClienteResumen>> clientes(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) return [];

  final queryRid = user?.isSuperAdmin == true ? rid : null;
  return ref.read(apiClientProvider).getClientes(restauranteId: queryRid);
}
