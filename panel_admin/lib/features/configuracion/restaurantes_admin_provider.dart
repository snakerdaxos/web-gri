import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/restaurante.dart';

part 'restaurantes_admin_provider.g.dart';

/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05): `get()` de TODOS los docs de
/// `restaurantes` (super lee todo por rules — un `where activo == true`
/// escondería los inactivos y no se podrían re-activar).
///
/// Defense in depth (patrón restaurantesListProvider): si un staff lo
/// llega a leer, lanza claro — las rules igualmente le denegarían.
/// El toggle de la UI refresca invalidando aquí.
@riverpod
Future<List<Restaurante>> restaurantesAdmin(Ref ref) async {
  // Watches ANTES del primer await (lección 07-03).
  final db = ref.watch(firestoreProvider);
  final claims = await ref.watch(claimsProvider.future);

  if (claims.role != 'super_admin') {
    throw StateError('restaurantesAdmin es solo para super_admin');
  }

  final snap = await db.collection('restaurantes').get();
  final lista = [for (final doc in snap.docs) Restaurante.fromDoc(doc)]
    ..sort((a, b) => a.nombre.compareTo(b.nombre));
  return lista;
}

/// Toggle de `activo` — update que toca SOLO esa key (rules del super:
/// `diff hasOnly(['activo'])` — ni nombre ni calificaciones tocables
/// desde el panel; threat model 10-06).
Future<void> toggleRestauranteActivo(
  FirebaseFirestore db, {
  required String slug,
  required bool valor,
}) {
  return db.doc('restaurantes/$slug').update(<String, dynamic>{
    'activo': valor,
  });
}
