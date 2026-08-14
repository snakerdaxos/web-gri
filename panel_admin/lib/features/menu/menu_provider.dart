import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/categoria_staff.dart';
import '../dashboard/restaurante_provider.dart';

part 'menu_provider.g.dart';

/// Menú completo del tenant (categorías con productos anidados, MENU-01).
///
/// El menú NO tiene eventos WS (decisión research 08: refresh on-demand,
/// Pattern 3 vía 2) — tras cada mutación exitosa la UI llama
/// `ref.invalidate(staffMenuProvider)`.
///
/// rid null (super_admin sin restaurante seleccionado) → `[]` en vez de
/// explotar (patrón mesasProvider, misma resolución de tenant).
@riverpod
Future<List<CategoriaStaff>> staffMenu(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;

  if (rid == null) return [];

  final queryRid = user?.isSuperAdmin == true ? rid : null;
  return ref.read(apiClientProvider).getStaffMenu(restauranteId: queryRid);
}
