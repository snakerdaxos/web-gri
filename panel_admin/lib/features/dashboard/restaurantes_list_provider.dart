import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import 'restaurante_provider.dart';

part 'restaurantes_list_provider.g.dart';

/// Lista de restaurantes ACTIVOS para el selector del `super_admin`
/// (Phase 10 — Firestore realtime): `restaurantes where activo == true`
/// vía snapshots — crear/activar un restaurante lo muestra en vivo.
///
/// Solo lo watch-ea el AppShell cuando los claims dicen super_admin.
/// Defense in depth (patrón del provider legacy): si un staff lo llega a
/// leer, lanza claro — las rules igualmente le denegarían la query.
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await.
@riverpod
Stream<List<RestauranteResumen>> restaurantesList(Ref ref) async* {
  // Watches ANTES del primer await (lección 07-03).
  final db = ref.watch(firestoreProvider);
  final claims = await ref.watch(claimsProvider.future);

  if (claims.role != 'super_admin') {
    throw StateError('restaurantesList es solo para super_admin');
  }

  yield* db
      .collection('restaurantes')
      .where('activo', isEqualTo: true)
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              (
                id: doc.id,
                nombre: doc.data()['nombre'] as String? ?? '',
                activo: true,
              ),
          ]);
}
