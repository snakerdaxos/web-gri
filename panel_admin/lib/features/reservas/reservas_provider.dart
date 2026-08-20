import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../models/mesa.dart';
import '../../models/reserva.dart';
import '../dashboard/mesas_provider.dart' show cambiarEstadoMesa;
import '../dashboard/restaurante_provider.dart' show ridActivoProvider;

part 'reservas_provider.g.dart';

/// Reservas de HOY del restaurante EN VIVO (RESV-05): la MISMA query del
/// dashboard 10-05 — `reservas where restauranteId == rid where fecha >=
/// inicioHoy && fecha < inicioMañana → snapshots()` (índice
/// restauranteId+fecha de 10-01) con la ventana computada en la TZ local
/// del operador.
///
/// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).
@riverpod
Stream<List<Reserva>> reservasHoy(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield const <Reserva>[];
    return;
  }

  final ahora = DateTime.now();
  final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
  final inicioManana = inicioHoy.add(const Duration(days: 1));

  yield* db
      .collection('reservas')
      .where('restauranteId', isEqualTo: rid)
      .where(
        'fecha',
        isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy),
      )
      .where('fecha', isLessThan: Timestamp.fromDate(inicioManana))
      .snapshots()
      .map((snap) => [for (final doc in snap.docs) Reserva.fromDoc(doc)]);
}

/// 'Marcar ocupada' al llegar el cliente de una reserva: la MESA pasa a
/// `ocupada` DESDE EL ESTADO QUE TENGA, vía [cambiarEstadoMesa] (10-05 —
/// valida la transición ANTES del update y toca SOLO {estado, updatedAt}; las
/// rules re-fuerzan `transMesa`).
///
/// ⚠️ EL ORIGEN YA NO ES SIEMPRE `reservada` (11-29). Antes, crear una reserva
/// marcaba la mesa en el acto fuera cual fuera la fecha, así que al llegar el
/// cliente la mesa estaba siempre `reservada`. Desde 11-29 el `estado` solo lo
/// toca una reserva de HOY: una reserva de hoy creada AYER deja la mesa
/// `disponible`, y `disponible → ocupada` es igual de válida en la máquina y
/// en `transMesa`. NO reintroducir un guard que exija `reservada`: rompería
/// justo ese caso (lo custodia el caso (b2) de reservas_screen_test.dart).
///
/// La reserva en sí NO cambia de estado (ocurrió); lo que se mueve es la
/// mesa. Si otro staff la movió primero (a `ocupada` o `limpieza`) →
/// [TransicionInvalidaException] (la UI la traduce a 'La mesa ya cambió de
/// estado').
Future<void> marcarMesaOcupada(
  FirebaseFirestore db, {
  required Reserva reserva,
}) async {
  final mesaSnap = await db.doc('mesas/${reserva.mesaId}').get();
  if (!mesaSnap.exists) {
    throw StateError('La mesa de la reserva ya no existe');
  }
  await cambiarEstadoMesa(db, mesa: Mesa.fromDoc(mesaSnap), destino: 'ocupada');
}

/// Cancelar por no-show: la reserva pasa a `cancelada` (staff lo permite
/// rules — `soloEstado` con estado final `cancelada`). Transición
/// validada client-side ANTES del update (pendiente|confirmada →
/// cancelada; cancelada es terminal).
Future<void> cancelarReservaNoShow(
  FirebaseFirestore db, {
  required Reserva reserva,
}) {
  validarTransicion('reserva', reserva.estado, 'cancelada');
  return db.doc('reservas/${reserva.id}').update(<String, dynamic>{
    'estado': 'cancelada',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
