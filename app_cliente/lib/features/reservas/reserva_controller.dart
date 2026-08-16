import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../core/tx_mutex.dart';
import '../../models/reserva.dart';
import '../../models/reserva_create.dart';

part 'reserva_controller.g.dart';

/// Error de dominio de reservas con mensaje user-friendly directo
/// (contrato de la UI — mismo rol que el `detail` de la era REST).
class ReservaException implements Exception {
  const ReservaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Doc ID determinista de la reserva: `{mesaId}_{yyyyMMdd}_{HH}` con la
/// fecha del SLOT en TZ local (Pitfall 3: NUNCA serverTimestamp para el
/// id — la unicidad mesa+slot vive en el propio doc ID, paridad del
/// UNIQUE(mesa,fecha,hora_inicio) de MySQL).
String docIdReserva(String mesaId, DateTime slot) =>
    '$mesaId${_fechaCompacta(slot)}_${slot.hour.toString().padLeft(2, '0')}';

String _fechaCompacta(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String _fechaStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── Mutex en-proceso ─────────────────────────────────────────────────────
//
// Las mutaciones de reservas (y desde 10-04 las de sesión/pedidos/
// calificaciones) serializan a través de `seccionCritica` de
// core/tx_mutex.dart — patrón estrenado aquí en 10-03 y promovido a core
// para compartirlo (gotchas de zonas documentados allí).

/// Port de `backend/app/services/reserva_service.py::crear_reserva`
/// (MIGRA-06): asignación automática de mesa, concurrent-safe.
///
/// 1. Candidatas FUERA de la tx (la query no bloquea): mesas del
///    restaurante ordenadas por `numero` (índice compuesto de 10-01);
///    el filtro de capacidad es client-side (evita un 3er campo de
///    índice) — misma primera-que-entra del backend.
/// 2. DENTRO de runTransaction: `tx.get(reservas/{mesaId}_{yyyyMMdd}_{HH})`
///    por candidata — la primera que NO existe es la elegida. Dos
///    contendientes del mismo slot leen el mismo doc → Firestore serializa.
///    PROHIBIDO "query luego create con autoId" (la query no bloquea docs
///    futuros).
/// 3. `validarTransicion('mesa', ...)`: disponible→reservada aplica la
///    máquina; ya-reservada se tolera (idempotente); ocupada/limpieza lanza.
/// 4. `tx.set` reserva confirmada (auto-confirm) + `tx.update` de la mesa
///    SOLO si estaba disponible.
/// 5. Sin candidata libre → [ReservaException] controlado.
Future<Reserva> crearReserva(
  FirebaseFirestore db, {
  required String uid,
  required String restauranteId,
  required DateTime slot,
  required int personas,
}) {
  return seccionCritica(() =>
      _crearReserva(db, uid: uid, restauranteId: restauranteId, slot: slot,
          personas: personas));
}

Future<Reserva> _crearReserva(
  FirebaseFirestore db, {
  required String uid,
  required String restauranteId,
  required DateTime slot,
  required int personas,
}) async {
  // 1. Candidatas (capacidad >= personas) fuera de la tx.
  final mesasSnap = await db
      .collection('mesas')
      .where('restauranteId', isEqualTo: restauranteId)
      .orderBy('numero')
      .get();
  final candidatas = mesasSnap.docs
      .where((m) => (m.data()['capacidad'] as num? ?? 0) >= personas)
      .toList();
  if (candidatas.isEmpty) {
    throw const ReservaException('No hay mesas con capacidad suficiente');
  }

  final fechaStr = _fechaStr(slot);

  // 2-4. Elección determinista DENTRO de la transacción.
  return db.runTransaction<Reserva>((tx) async {
    for (final mesa in candidatas) {
      final docRef = db.doc('reservas/${docIdReserva(mesa.id, slot)}');
      if ((await tx.get(docRef)).exists) continue; // slot tomado

      final data = mesa.data();
      final estadoMesa = data['estado'] as String? ?? 'disponible';
      final mesaNumero = (data['numero'] as num?)?.toInt() ?? 0;

      if (estadoMesa == 'disponible') {
        validarTransicion('mesa', 'disponible', 'reservada');
        tx.update(mesa.reference, {
          'estado': 'reservada',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (estadoMesa != 'reservada') {
        // ocupada/limpieza → no se puede reservar (port paso 5).
        throw ReservaException(
          'La mesa $mesaNumero no está disponible para reserva',
        );
      }

      final id = docIdReserva(mesa.id, slot);
      tx.set(docRef, {
        'restauranteId': restauranteId,
        'mesaId': mesa.id,
        'mesaNumero': mesaNumero,
        'usuarioId': uid,
        'fecha': Timestamp.fromDate(slot),
        'fechaStr': fechaStr,
        'hora': slot.hour,
        'numPersonas': personas,
        'estado': 'confirmada',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Reserva(
        id: id,
        restauranteId: restauranteId,
        mesaId: mesa.id,
        mesaNumero: mesaNumero,
        usuarioId: uid,
        fecha: slot,
        fechaStr: fechaStr,
        hora: slot.hour,
        numPersonas: personas,
        estado: 'confirmada',
      );
    }
    // 5. Todas las candidatas tienen el slot tomado.
    throw const ReservaException('No hay mesas disponibles en ese horario');
  });
}

/// Port de `cancelar_reserva`: cancela una reserva futura propia.
///
/// Guard UX primero (ownership existence-hiding + fecha futura — las
/// rules re-validan server-side, el cliente nunca es fuente de verdad).
/// Luego en transacción: `validarTransicion('reserva', confirmada →
/// cancelada)` (cancelada es terminal → doble cancelación lanza) y
/// reversión de la mesa SOLO si estaba 'reservada' (si fue promovida a
/// ocupada/limpieza NO se toca — Pitfall 4, paridad Phase 5).
Future<void> cancelarReserva(
  FirebaseFirestore db, {
  required String uid,
  required Reserva reserva,
}) {
  return seccionCritica(() => _cancelarReserva(db, uid: uid, reserva: reserva));
}

Future<void> _cancelarReserva(
  FirebaseFirestore db, {
  required String uid,
  required Reserva reserva,
}) async {
  if (reserva.usuarioId != uid) {
    // Existence hiding: nunca revelar que la reserva existe.
    throw const ReservaException('Reserva no encontrada');
  }
  if (reserva.fechaStr.compareTo(_fechaStr(DateTime.now())) < 0) {
    throw const ReservaException('No se puede cancelar una reserva pasada');
  }

  await db.runTransaction<void>((tx) async {
    final ref = db.doc('reservas/${reserva.id}');
    final snap = await tx.get(ref);
    if (!snap.exists) {
      throw const ReservaException('Reserva no encontrada');
    }
    validarTransicion(
      'reserva',
      snap.data()?['estado'] as String? ?? '',
      'cancelada',
    );

    // Reversión condicional de la mesa (solo si estaba reservada).
    final mesaRef = db.doc('mesas/${reserva.mesaId}');
    final mesaSnap = await tx.get(mesaRef);
    if (mesaSnap.exists && mesaSnap.data()?['estado'] == 'reservada') {
      validarTransicion('mesa', 'reservada', 'disponible');
      tx.update(mesaRef, {
        'estado': 'disponible',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    tx.update(ref, {'estado': 'cancelada'});
  });
}

/// Orquesta las mutaciones de reservas del cliente sobre Firestore.
///
/// `misReservas` es un stream → la lista se refresca sola tras cada
/// mutación (REALTIME): NO hay invalidate (era el refetch de la era REST).
@riverpod
class ReservaController extends _$ReservaController {
  @override
  FutureOr<void> build() {}

  /// Crea la reserva (asignación automática de mesa). Mapea los errores
  /// del dominio a los mismos textos user-friendly de la era dio
  /// (threat 6: jamás un stack trace o detail crudo).
  Future<Reserva> create(ReservaCreate body) async {
    final db = ref.read(firestoreProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      throw const ReservaException('Debes iniciar sesión para reservar');
    }
    final f = DateTime.parse(body.fecha);
    final slot = DateTime(f.year, f.month, f.day, body.hora);

    state = const AsyncLoading<void>();
    try {
      return await crearReserva(db,
          uid: uid,
          restauranteId: body.restauranteId,
          slot: slot,
          personas: body.numPersonas);
    } on ReservaException {
      // 409-equivalentes del port (capacidad/slot tomado/estado mesa).
      throw const ReservaException('Ese horario acaba de ser reservado, '
          'elige otro');
    } on TransicionInvalidaException {
      throw const ReservaException('Ese horario acaba de ser reservado, '
          'elige otro');
    } catch (_) {
      throw const ReservaException('No se pudo crear la reserva. '
          'Intenta de nuevo');
    } finally {
      state = const AsyncData<void>(null);
    }
  }

  /// Cancela una reserva futura propia (con reversión condicional de mesa).
  Future<void> cancel(Reserva reserva) async {
    final db = ref.read(firestoreProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      throw const ReservaException('Debes iniciar sesión');
    }

    state = const AsyncLoading<void>();
    try {
      await cancelarReserva(db, uid: uid, reserva: reserva);
    } on ReservaException {
      rethrow; // ya trae mensaje user-friendly del dominio
    } on TransicionInvalidaException {
      throw const ReservaException('La reserva ya estaba cancelada');
    } catch (_) {
      throw const ReservaException('No se pudo cancelar la reserva');
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
