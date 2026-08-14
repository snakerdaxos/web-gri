import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/cliente_resumen.dart';
import '../../models/pedido_staff.dart';
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

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03) —
/// misma shape que la cola de pedidos (`PedidoStaffRead` reusado, 08-01).
///
/// 404 existence hiding relacional cuando el usuario no tiene pedidos aquí:
/// el dialog lo traduce a 'Sin pedidos en este restaurante' (el error y el
/// vacío son indistinguibles por diseño).
@riverpod
Future<List<PedidoStaff>> clienteHistorial(Ref ref, int usuarioId) async {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) return [];

  final queryRid = user?.isSuperAdmin == true ? rid : null;
  return ref
      .read(apiClientProvider)
      .getClienteHistorial(usuarioId, restauranteId: queryRid);
}
