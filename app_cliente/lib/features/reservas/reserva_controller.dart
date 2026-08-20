import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_error_mapper.dart';
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
/// 3. El `estado` de la mesa SOLO interviene si el slot es de HOY (bug B,
///    ver abajo): disponible→reservada aplica la máquina; ya-reservada se
///    tolera (idempotente); ocupada/limpieza SALTA a la siguiente candidata.
/// 4. `tx.set` reserva confirmada (auto-confirm) + `tx.update` de la mesa
///    SOLO si el slot es de hoy y la mesa estaba disponible.
/// 5. Sin candidata libre → [ReservaException] controlado, con el motivo
///    REAL por el que se agotaron las candidatas.
///
/// ── LOS DOS BUGS QUE ESTA FUNCIÓN TENÍA (11-29) ─────────────────────────
///
/// **BUG A — una mesa ocupada abortaba la búsqueda entera.** El bucle era
/// incoherente: un SLOT tomado hacía `continue`, pero una MESA ocupada
/// LANZABA. Con `GRI-MESA-demo-001` ocupada (primera candidata para 2
/// personas) no se podía reservar aunque hubiera ocho mesas libres detrás.
/// Ahora se salta y solo se falla cuando se han examinado TODAS.
///
/// **BUG B — reservar para el futuro bloqueaba la mesa hoy.** El
/// `tx.update(mesa, {'estado': 'reservada'})` corría fuera cual fuera la
/// fecha del slot, así que una reserva para el martes que viene marcaba la
/// mesa reservada AHORA y la quitaba de la circulación. El `estado` de la
/// mesa describe ESTE momento: solo lo toca una reserva de HOY.
///
/// De ahí se sigue lo demás: si para un slot futuro no se escribe el
/// estado, tampoco hay que consultarlo — el guard existía solo para
/// proteger esa escritura. Que la mesa esté ocupada ahora no dice nada de
/// cómo estará mañana, y la unicidad mesa+slot ya la garantiza el doc ID.
///
/// DEUDA DECLARADA (decisión del usuario, 2026-08-20): el modelo correcto es
/// que el mapa de mesas del panel lea las reservas del día en vez de depender
/// de un campo `estado` en vivo. Aquí se hace el cambio MÍNIMO.
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
  final esHoy = fechaStr == _fechaStr(DateTime.now());

  // Motivos por los que se descartó cada candidata. Se cuentan para poder
  // decir la VERDAD si no queda ninguna: el bug original aplastaba tres
  // causas distintas en «ese horario acaba de ser reservado».
  var slotsTomados = 0;
  var mesasOcupadas = 0;

  // 2-4. Elección determinista DENTRO de la transacción.
  return db.runTransaction<Reserva>((tx) async {
    for (final mesa in candidatas) {
      final docRef = db.doc('reservas/${docIdReserva(mesa.id, slot)}');
      if ((await tx.get(docRef)).exists) {
        slotsTomados++;
        continue; // slot tomado
      }

      final data = mesa.data();
      final estadoMesa = data['estado'] as String? ?? 'disponible';
      final mesaNumero = (data['numero'] as num?)?.toInt() ?? 0;

      if (esHoy) {
        if (estadoMesa == 'disponible') {
          validarTransicion('mesa', 'disponible', 'reservada');
          tx.update(mesa.reference, {
            'estado': 'reservada',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (estadoMesa != 'reservada') {
          // ocupada/limpieza → hoy no sirve. SE SALTA (bug A: antes lanzaba
          // aquí y mataba la búsqueda con el resto de mesas sin mirar).
          mesasOcupadas++;
          continue;
        }
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
    // 5. Se examinaron TODAS las candidatas y ninguna sirve. El mensaje dice
    //    por qué de verdad (bug C: antes se descartaba aquí la causa).
    throw ReservaException(_sinCandidata(
      slotsTomados: slotsTomados,
      mesasOcupadas: mesasOcupadas,
      personas: personas,
    ));
  });
}

/// Redacta el fallo de la asignación automática CON su causa.
///
/// Tres situaciones distintas que el bug original resumía en una sola frase
/// —y la que elegía era falsa en dos de los tres casos:
///
/// * solo slots tomados  → es un problema de HORARIO (elige otra hora);
/// * solo mesas ocupadas → es un problema de AHORA MISMO (espera o cambia de
///   día); solo puede pasar reservando para hoy;
/// * las dos            → se dicen las dos, con sus cifras.
String _sinCandidata({
  required int slotsTomados,
  required int mesasOcupadas,
  required int personas,
}) {
  final comensales = personas == 1 ? '1 persona' : '$personas personas';
  if (mesasOcupadas == 0) {
    // Texto histórico, correcto para esta causa: no se toca.
    return 'No hay mesas disponibles en ese horario';
  }
  if (slotsTomados == 0) {
    return 'Todas las mesas para $comensales están ocupadas en este momento. '
        'Prueba más tarde o reserva para otro día.';
  }
  final ocupadas =
      mesasOcupadas == 1 ? '1 ocupada' : '$mesasOcupadas ocupadas';
  return 'No queda ninguna mesa para ese horario: $slotsTomados con la franja '
      'ya reservada y $ocupadas en este momento.';
}

/// Port de `cancelar_reserva`: cancela una reserva futura propia.
///
/// Guard UX primero (ownership existence-hiding + fecha futura — las
/// rules re-validan server-side, el cliente nunca es fuente de verdad).
/// Luego en transacción: `validarTransicion('reserva', confirmada →
/// cancelada)` (cancelada es terminal → doble cancelación lanza) y
/// reversión de la mesa SOLO si la reserva era de HOY y la mesa estaba
/// 'reservada' (si fue promovida a ocupada/limpieza NO se toca — Pitfall 4,
/// paridad Phase 5).
///
/// **La condición «de hoy» es la simétrica del bug B (11-29).** Si crear una
/// reserva futura no marca la mesa, cancelarla no puede desmarcarla: la mesa
/// puede estar 'reservada' por OTRA reserva, la de esta tarde, y liberarla
/// aquí la borraría del mapa del panel.
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

    // Reversión condicional de la mesa: solo si la reserva era de HOY (la
    // única que llegó a marcarla) y la mesa sigue 'reservada'.
    if (reserva.fechaStr == _fechaStr(DateTime.now())) {
      final mesaRef = db.doc('mesas/${reserva.mesaId}');
      final mesaSnap = await tx.get(mesaRef);
      if (mesaSnap.exists && mesaSnap.data()?['estado'] == 'reservada') {
        validarTransicion('mesa', 'reservada', 'disponible');
        tx.update(mesaRef, {
          'estado': 'disponible',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
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

  /// Crea la reserva (asignación automática de mesa).
  ///
  /// ── BUG C, ARREGLADO EN 11-29 ─────────────────────────────────────────
  /// Aquí había esto:
  ///
  ///     } on ReservaException {
  ///       // 409-equivalentes del port (capacidad/slot tomado/estado mesa).
  ///       throw const ReservaException('Ese horario acaba de ser reservado,
  ///           elige otro');
  ///
  /// El comentario enumera TRES causas y elige el texto de UNA — falso para
  /// las otras dos. Y `crearReserva` YA lanzaba el mensaje correcto: este
  /// `catch` lo tiraba. El usuario lo sufrió reservando para una fecha futura
  /// en una base con cero reservas.
  ///
  /// Ahora: el error de DOMINIO sube tal cual (ya trae la causa), y lo que no
  /// es de dominio se clasifica con el mapeador único de 11-23. Sigue sin
  /// salir jamás un stack trace ni un `detail` crudo (threat 6).
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
      rethrow; // ya trae la causa REAL redactada por el dominio
    } on TransicionInvalidaException {
      // La mesa se movió entre la lectura y la escritura de la tx: no es que
      // el horario esté tomado.
      throw ReservaException(mensajeDe(CausaFallo.noDisponible,
          contexto: Contexto.crearReserva));
    } catch (e) {
      // Antes: `catch (_)` MUDO (deuda que 11-23 dejó anotada). Un
      // permission-denied o un backend caído salían por el mismo texto y sin
      // dejar rastro para depurar.
      debugPrint('crearReserva falló [${clasificarFallo(e)}]: $e');
      throw ReservaException(
          mensajeDeFallo(e, contexto: Contexto.crearReserva));
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
      // 'cancelada' es terminal: la única transición que falla aquí es la
      // doble cancelación.
      throw ReservaException(mensajeDe(CausaFallo.noDisponible,
          contexto: Contexto.cancelarReserva));
    } catch (e) {
      debugPrint('cancelarReserva falló [${clasificarFallo(e)}]: $e');
      throw ReservaException(
          mensajeDeFallo(e, contexto: Contexto.cancelarReserva));
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
