// test/reservas/asignacion_mesa_test.dart — la asignación automática de mesa
// deja de fallar por dos motivos que no tenían nada que ver con el horario
// pedido (11-29).
//
// ── LOS DOS BUGS QUE ESTE ARCHIVO FIJA ─────────────────────────────────────
//
// El usuario intentó reservar para una FECHA FUTURA contra el proyecto real y
// la app le dijo «Ese horario acaba de ser reservado, elige otro». En la base
// no había NI UNA reserva. Las causas reales fueron dos, y ninguna era el
// horario:
//
//   BUG A — el bucle sobre las mesas candidatas era incoherente. Un SLOT
//   tomado hacía `continue` (probar la siguiente mesa), pero una MESA ocupada
//   LANZABA, abortando la búsqueda entera. `GRI-MESA-demo-001` (capacidad 2)
//   estaba `ocupada` porque el propio usuario había abierto sesión en ella, y
//   es la primera candidata para 2 personas: las otras ocho mesas libres no se
//   llegaban a mirar.
//
//   BUG B — `tx.update(mesa, {'estado': 'reservada'})` se ejecutaba fuera cual
//   fuera la fecha del slot. Reservar para el martes que viene marcaba la mesa
//   reservada HOY, bloqueándola para quien entrara por la puerta. El `estado`
//   de la mesa describe ESTE MOMENTO.
//
// ── LA REGLA QUE SE DERIVA (y que estos casos custodian) ───────────────────
// El `estado` de la mesa solo interviene cuando el slot es de HOY, porque solo
// entonces hay algo que escribir. Para un slot futuro no se consulta ni se
// escribe: que la mesa esté ocupada ahora no dice nada de cómo estará mañana.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/features/reservas/reserva_controller.dart';

import '../helpers/firebase_fakes.dart';

/// Slot de HOY. La hora tardía es deliberada: lo único que mira el arreglo es
/// la FECHA, así que el caso es determinista se ejecute a la hora que se
/// ejecute.
DateTime _slotDeHoy([int hora = 23]) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, hora);
}

/// Instante FIJO del día de hoy. Se pasa explícitamente a `crearReserva` /
/// `cancelarReserva` para que los casos con slot de HOY no dependan de la
/// hora a la que se corra la suite: desde 11-31 hay un margen mínimo de 4 h,
/// así que con `DateTime.now()` un caso con el slot de las 23:00 se pondría
/// rojo a partir de las 19:01. La FECHA sigue siendo la real (los slots de
/// mañana y la pantalla la comparten); lo que se fija es la HORA.
DateTime _hoyALas(int h) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, h);
}

DateTime _slotDeManana([int hora = 19]) {
  final t = DateTime.now().add(const Duration(days: 1));
  return DateTime(t.year, t.month, t.day, hora);
}

/// El seed trae `GRI-MESA-demo-001..003` con capacidades 2/4/6, todas
/// `disponible` (helpers/firebase_fakes.dart).
const _mesa1 = 'mesas/GRI-MESA-demo-001';
const _mesa2 = 'mesas/GRI-MESA-demo-002';

Future<String> _estado(FakeFirebaseFirestore db, String ruta) async =>
    (await db.doc(ruta).get()).data()!['estado'] as String;

/// Ocupa el SLOT de una mesa (no la mesa): el doc de reserva ya existe.
Future<void> _tomarSlot(
        FakeFirebaseFirestore db, String mesaId, DateTime slot) =>
    db.doc('reservas/${docIdReserva(mesaId, slot)}').set({
      'restauranteId': 'demo',
      'mesaId': mesaId,
      'usuarioId': 'otro',
      'estado': 'confirmada',
    });

Future<ReservaException> _capturarError(Future<void> Function() accion) async {
  try {
    await accion();
  } on ReservaException catch (e) {
    return e;
  }
  fail('se esperaba una ReservaException y la llamada tuvo éxito');
}

void main() {
  // ══ BUG A ════════════════════════════════════════════════════════════════
  group('BUG A — una mesa ocupada NO aborta la búsqueda', () {
    test('slot de HOY: la mesa ocupada se salta y gana la siguiente candidata',
        () async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc(_mesa1).update({'estado': 'ocupada'});
      final slot = _slotDeHoy();

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: slot,
          ahora: _hoyALas(12),
          personas: 2);

      // La 001 (capacidad 2) es la primera candidata y está ocupada; antes del
      // arreglo esto lanzaba y las otras dos no se miraban.
      expect(reserva.mesaId, 'GRI-MESA-demo-002');
      expect(reserva.mesaNumero, 2);
      expect(await _estado(db, _mesa2), 'reservada');
      // La mesa saltada no se toca: sigue ocupada por su sesión real.
      expect(await _estado(db, _mesa1), 'ocupada');
    });

    test('slot de HOY: una mesa en LIMPIEZA también se salta', () async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc(_mesa1).update({'estado': 'limpieza'});

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);

      expect(reserva.mesaId, 'GRI-MESA-demo-002');
      expect(await _estado(db, _mesa1), 'limpieza');
    });

    test(
        'slot de HOY con TODAS las mesas ocupadas: el mensaje habla de ocupación, no del horario',
        () async {
      final db = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }

      final e = await _capturarError(() => crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2));

      expect(
        e.message,
        'Todas las mesas para 2 personas están ocupadas en este momento. '
        'Prueba más tarde o reserva para otro día.',
      );
      // El mensaje del bug original culpaba al horario. Nunca más por esta vía.
      expect(e.message.toLowerCase(), isNot(contains('horario')));
      // Y ninguna mesa se movió.
      expect(await _estado(db, _mesa1), 'ocupada');
      expect((await db.collection('reservas').get()).docs, isEmpty);
    });

    test(
        'slot de HOY con causas MEZCLADAS: el mensaje cuenta las dos, sin inventar una sola',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeHoy();
      await db.doc(_mesa1).update({'estado': 'ocupada'});
      await _tomarSlot(db, 'GRI-MESA-demo-002', slot);
      await _tomarSlot(db, 'GRI-MESA-demo-003', slot);

      final e = await _capturarError(() => crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: slot,
          ahora: _hoyALas(12),
          personas: 2));

      expect(
        e.message,
        'No queda ninguna mesa para ese horario: 2 con la franja ya reservada '
        'y 1 ocupada en este momento.',
      );
    });

    test('las tres causas producen tres mensajes DISTINTOS', () async {
      // Sin esto, «cuenta las dos causas» podría cumplirse con el mismo texto
      // repetido: es la comparación que faltaba en el bug original.
      final mensajes = <String>{};

      // (1) todos los slots tomados
      final db1 = await buildFakeFirestoreConSeed();
      final slot1 = _slotDeHoy();
      for (final m in ['001', '002', '003']) {
        await _tomarSlot(db1, 'GRI-MESA-demo-$m', slot1);
      }
      mensajes.add((await _capturarError(() => crearReserva(db1,
              uid: 'u',
              restauranteId: 'demo',
              slot: slot1,
              ahora: _hoyALas(12),
              personas: 2)))
          .message);

      // (2) todas las mesas ocupadas
      final db2 = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db2.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }
      mensajes.add((await _capturarError(() => crearReserva(db2,
              uid: 'u',
              restauranteId: 'demo',
              slot: _slotDeHoy(),
              ahora: _hoyALas(12),
              personas: 2)))
          .message);

      // (3) capacidad insuficiente
      final db3 = await buildFakeFirestoreConSeed();
      mensajes.add((await _capturarError(() => crearReserva(db3,
              uid: 'u',
              restauranteId: 'demo',
              slot: _slotDeHoy(),
              ahora: _hoyALas(12),
              personas: 10)))
          .message);

      expect(mensajes, hasLength(3),
          reason: 'tres causas distintas exigen tres textos distintos');
    });
  });

  // ══ BUG B ════════════════════════════════════════════════════════════════
  group('BUG B — una reserva FUTURA no toca el estado de la mesa', () {
    test('reservar para MAÑANA deja la mesa como estaba (disponible)',
        () async {
      final db = await buildFakeFirestoreConSeed();

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(),
          personas: 2);

      expect(reserva.mesaId, 'GRI-MESA-demo-001');
      // ESTO es el bug B: la mesa quedaba 'reservada' desde hoy, bloqueada
      // para quien entrara por la puerta.
      expect(await _estado(db, _mesa1), 'disponible');
      // La reserva sí existe, con su fecha.
      expect(
        (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
        'confirmada',
      );
    });

    test('reservar para HOY sí pasa la mesa disponible → reservada', () async {
      // La otra mitad del arreglo: el cambio mínimo NO puede dejar de marcar
      // las reservas del día, que es lo que el panel pinta en el mapa.
      final db = await buildFakeFirestoreConSeed();

      await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);

      expect(await _estado(db, _mesa1), 'reservada');
    });

    test(
        'reservar para MAÑANA en una mesa ocupada AHORA: se asigna igual (el estado de hoy no la descalifica)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc(_mesa1).update({'estado': 'ocupada'});

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(),
          personas: 2);

      expect(reserva.mesaId, 'GRI-MESA-demo-001');
      expect(await _estado(db, _mesa1), 'ocupada'); // intacta
    });

    test(
        'cancelar una reserva FUTURA no revierte el estado de la mesa (que puede venir de otra reserva de hoy)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(),
          personas: 2);
      // Alguien reserva ESA mesa para hoy: la mesa pasa a reservada.
      await db.doc(_mesa1).update({'estado': 'reservada'});

      await cancelarReserva(db, uid: 'test-uid', reserva: reserva);

      expect(
        (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
        'cancelada',
      );
      // Simétrico al create: si la reserva futura no la reservó, cancelarla no
      // la libera. Antes del arreglo esto dejaba la mesa 'disponible' y
      // borraba del mapa la reserva de HOY.
      expect(await _estado(db, _mesa1), 'reservada');
    });

    test('cancelar una reserva de HOY sí revierte reservada → disponible',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);
      expect(await _estado(db, _mesa1), 'reservada');

      await cancelarReserva(db, uid: 'test-uid', reserva: reserva);

      expect(await _estado(db, _mesa1), 'disponible');
    });
  });
}
