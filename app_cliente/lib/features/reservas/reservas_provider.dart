import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/reserva.dart';

part 'reservas_provider.g.dart';

/// Reservas del cliente autenticado — STREAM Firestore (REALTIME,
/// MIGRA-06: sustituye al refetch de la era REST y al polling):
/// `where('usuarioId') + orderBy('fecha', descending)` + `snapshots()`
/// (índice compuesto reservas/usuarioId+fecha DESC de 10-01).
///
/// El join de `restauranteNombre` es client-side (el doc NO lo guarda):
/// un get por restaurante distinto del snapshot.
@riverpod
Stream<List<Reserva>> misReservas(Ref ref, String uid) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection('reservas')
      .where('usuarioId', isEqualTo: uid)
      .orderBy('fecha', descending: true)
      .snapshots()
      .asyncMap((snap) async {
    final nombres = <String, String>{};
    final ids = <String>{
      for (final d in snap.docs) d.data()['restauranteId'] as String? ?? '',
    }..remove('');
    await Future.wait([
      for (final id in ids)
        db.doc('restaurantes/$id').get().then((doc) {
          nombres[id] = doc.data()?['nombre'] as String? ?? '';
        }),
    ]);
    return [
      for (final d in snap.docs)
        Reserva.fromDoc(d).copyWith(
          restauranteNombre:
              nombres[d.data()['restauranteId'] as String? ?? ''] ?? '',
        ),
    ];
  });
}
