import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../models/restaurante.dart';
import '../../models/restaurante_detalle.dart';

part 'restaurantes_provider.g.dart';

/// Lista de restaurantes activos — `GET /public/restaurantes` (sin auth).
/// `calificacion` siempre null en Phase 5 (UI muestra "—").
@riverpod
Future<List<Restaurante>> restaurantesList(Ref ref) async {
  return ref.read(apiClientProvider).getPublicRestaurantes();
}

/// Detalle con menú anidado — `GET /public/restaurantes/{id}` (sin auth).
@riverpod
Future<RestauranteDetalle> restauranteDetalle(Ref ref, int id) async {
  return ref.read(apiClientProvider).getPublicRestaurante(id);
}
