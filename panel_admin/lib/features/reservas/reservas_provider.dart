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

/// Cuántos días hacia adelante se muestran en «Próximas».
///
/// SIETE. La pregunta que el restaurante le hace a esta pantalla es «¿qué
/// tengo esta semana?», que es lo que decide las compras y los turnos.
/// Ampliarlo a «todas las futuras» exigiría paginación para un dato que casi
/// nadie mira, y acortarlo a 2-3 días deja fuera justo el fin de semana.
const int diasDeReservasProximas = 7;

/// Reservas FUTURAS del restaurante EN VIVO (11-34): desde el inicio de MAÑANA
/// hasta [diasDeReservasProximas] días después.
///
/// ── EL AGUJERO QUE ESTO TAPA ──────────────────────────────────────────────
/// `reservasHoy` acota a `fecha >= inicioHoy && fecha < inicioMañana`: hoy y
/// solo hoy. Y hasta 11-31 el cliente únicamente podía reservar de mañana en
/// adelante (`firstDate: mañana`). Combinando las dos cosas: **ninguna reserva
/// había sido nunca visible para el restaurante hasta el día en que ocurría.**
/// Un restaurante que no ve las reservas de mañana no puede planificar ni las
/// compras ni los turnos — y la pantalla no daba ninguna pista de que hubiera
/// algo que no estaba viendo.
///
/// ── SEPARADA DE `reservasHoy` A PROPÓSITO ─────────────────────────────────
/// Podría ser una sola consulta con una ventana más ancha, pero el uso es
/// distinto y por eso la interfaz las separa (decisión del usuario): hoy se
/// OPERA —marcar ocupada, no-show— y mañana se PLANIFICA. Además `reservasHoy`
/// alimenta el color del mapa de mesas, que solo puede mirar hoy; mezclarlas
/// obligaría a re-filtrar en cada consumidor.
///
/// ── ÍNDICE ────────────────────────────────────────────────────────────────
/// Ninguno nuevo. `reservas(restauranteId ASC, fecha ASC)` ya existe en
/// `firestore.indexes.json` desde 10-01 y sirve igual a una ventana más ancha:
/// igualdad en `restauranteId` + rango y orden en `fecha`. El `orderBy('fecha')`
/// es explícito porque aquí el ORDEN es parte del producto (una agenda
/// desordenada no es una agenda) y no una casualidad del rango.
@riverpod
Stream<List<Reserva>> reservasProximas(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield const <Reserva>[];
    return;
  }

  final ahora = DateTime.now();
  final inicioManana = DateTime(ahora.year, ahora.month, ahora.day)
      .add(const Duration(days: 1));
  final fin = inicioManana.add(const Duration(days: diasDeReservasProximas));

  yield* db
      .collection('reservas')
      .where('restauranteId', isEqualTo: rid)
      .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioManana))
      .where('fecha', isLessThan: Timestamp.fromDate(fin))
      .orderBy('fecha')
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
