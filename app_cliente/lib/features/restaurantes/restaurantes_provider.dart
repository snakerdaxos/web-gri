import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../models/restaurante.dart';
import '../../models/restaurante_detalle.dart';

part 'restaurantes_provider.g.dart';

/// Lista de restaurantes activos — INTERINO Task 1: sigue legacy REST
/// (api_client) con ids String; Task 2 lo reescribe sobre Firestore
/// (`collection('restaurantes').where('activo')` + fromDoc).
@riverpod
Future<List<Restaurante>> restaurantesList(Ref ref) async {
  return ref.read(apiClientProvider).getPublicRestaurantes();
}

/// Detalle con menú anidado — INTERINO Task 1 (legacy REST, id String).
@riverpod
Future<RestauranteDetalle> restauranteDetalle(Ref ref, String id) async {
  return ref.read(apiClientProvider).getPublicRestaurante(id);
}
