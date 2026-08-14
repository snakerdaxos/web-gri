import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/restaurante.dart';

part 'restaurantes_admin_provider.g.dart';

/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05, 08-05): `GET /admin/restaurantes
/// ?incluir_inactivos=true` (única vista que expone inactivos).
///
/// El toggle de activo de la UI refresca invalidando aquí. Watch de
/// authState para reactividad al login/logout (el tab solo lo watch-ea
/// super_admin, pero el watch hace al provider re-construirse con la sesión).
@riverpod
Future<List<Restaurante>> restaurantesAdmin(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  // Defense in depth (patrón restaurantesListProvider): si un staff lo
  // llega a leer, lanza claro — /admin/restaurantes le daría 403 igual.
  if (user == null || !user.isSuperAdmin) {
    throw StateError('restaurantesAdmin es solo para super_admin');
  }
  return ref
      .read(apiClientProvider)
      .listRestaurantes(incluirInactivos: true);
}
