import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/reserva.dart';
import '../dashboard/restaurante_provider.dart';

part 'reservas_provider.g.dart';

/// Reservas del día (`GET /staff/reservas?fecha=`, RESV-05) — family por
/// fecha `YYYY-MM-DD`. La UI invalida con la fecha-key al cambiar el picker
/// o tras marcar una mesa ocupada (refresh on-demand, sin WS — decisión
/// research 08).
///
/// Patrón rid/queryRid (mesasProvider): staff manda su tenant implícito
/// (token); super_admin manda el del dropdown. rid null (super_admin sin
/// selección) → `[]` (patrón clientesProvider).
@riverpod
Future<List<Reserva>> reservasDelDia(Ref ref, String fechaYYYYMMDD) async {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) return [];

  final queryRid = user?.isSuperAdmin == true ? rid : null;
  return ref
      .read(apiClientProvider)
      .getReservas(fecha: fechaYYYYMMDD, restauranteId: queryRid);
}
