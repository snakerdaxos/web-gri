import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../models/mesa.dart';
import 'restaurante_provider.dart';

part 'mesas_provider.g.dart';

/// Mapa de mesas del restaurante activo EN VIVO (MIGRA-05):
/// `mesas where restauranteId == rid orderBy numero ASC → snapshots()` —
/// sustituye el WS + polling de la era REST (Phase 7).
///
/// * El rid viene de [ridActivoProvider] (claims del staff / selección del
///   super) — NUNCA de un input libre del usuario (Pitfall 4: TODA query
///   lleva `where restauranteId == rid`; las rules re-evalúan por-doc).
/// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).
@riverpod
Stream<List<Mesa>> mesas(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    // super_admin sin restaurante elegido: mapa vacío hasta la selección.
    yield const <Mesa>[];
    return;
  }

  yield* db
      .collection('mesas')
      .where('restauranteId', isEqualTo: rid)
      .orderBy('numero')
      .snapshots()
      .map((snap) => [for (final doc in snap.docs) Mesa.fromDoc(doc)]);
}

/// Cambio de estado de una mesa desde el mapa operacional (ADMN-04).
///
/// 1. [validarTransicion] de la máquina `mesa` ANTES de escribir — un
///    salto inválido (p.ej. ocupada→disponible) lanza
///    [TransicionInvalidaException] SIN tocar el doc (barrera
///    client-side de lo que las rules re-fuerzan con `transMesa`).
/// 2. Update de SOLO `{estado, updatedAt}` — jamás toca el resto del doc.
Future<void> cambiarEstadoMesa(
  FirebaseFirestore db, {
  required Mesa mesa,
  required String destino,
}) async {
  validarTransicion('mesa', mesa.estado.name, destino);

  await db.doc('mesas/${mesa.id}').update(<String, dynamic>{
    'estado': destino,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
