import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/restaurante.dart';

part 'restaurantes_list_provider.g.dart';

/// Lista de restaurantes para el dropdown del super_admin (`GET /admin/restaurantes`).
///
/// Solo lo watch el AppShell cuando `authState.isSuperAdmin` es true. Para
/// staff este provider nunca se construye (no se necesita).
@riverpod
Future<List<Restaurante>> restaurantesList(Ref ref) async {
  // Defense in depth: si un staff lo llega a leer, lanza claro.
  final user = ref.read(authStateProvider).value;
  if (user == null || !user.isSuperAdmin) {
    throw StateError('restaurantesList es solo para super_admin');
  }
  return ref.read(apiClientProvider).listRestaurantes();
}
