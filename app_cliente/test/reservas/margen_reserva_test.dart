// test/reservas/margen_reserva_test.dart — reservar para HOY con 4 horas de
// margen (decisión del usuario, 2026-08-20: «sí pero con un margen de 4
// horas, ya que no se puede reservar para la misma hora»).
//
// ── LA REGLA, ENUNCIADA ────────────────────────────────────────────────────
//
//   Un slot se puede reservar si EMPIEZA al menos 4 horas después de ahora:
//
//       slot >= ahora + 4 h        (la igualdad SÍ vale)
//
//   Los slots son horas en punto (12:00..21:00), así que en la práctica se
//   toma `ahora + 4 h` y se sube a la hora en punto siguiente, salvo que ya
//   caiga en punto:
//
//       son las 14:30  →  límite 18:30  →  el primer slot de hoy es 19:00
//       son las 14:00  →  límite 18:00  →  el primer slot de hoy es 18:00
//       son las 14:01  →  límite 18:01  →  el primer slot de hoy es 19:00
//       son las 17:00  →  límite 21:00  →  el primer (y único) slot es 21:00
//       son las 17:01  →  límite 21:01  →  HOY YA NO HAY SLOTS
//
// ── POR QUÉ TODOS LOS INSTANTES DE ESTE ARCHIVO SON FIJOS ──────────────────
//
// Un test que calcula lo que espera con la MISMA expresión que el código no
// prueba nada: `ahora.add(Duration(hours: 4))` contra la aritmética del
// código estaría siempre verde, tuviera el código el margen que tuviera.
// Aquí nunca se calcula: se dice «son las 14:30» y se afirma «18:00 NO,
// 19:00 SÍ». Además hace los casos deterministas — con `DateTime.now()`, un
// caso con el slot de las 23:00 de hoy se pondría rojo a partir de las 19:01.
//
// ── HUSO HORARIO ───────────────────────────────────────────────────────────
//
// Todo lo de aquí es hora LOCAL (`DateTime` sin `utc`), que es lo que maneja
// el resto del flujo: el slot que elige el usuario es una hora de pared y el
// doc ID `{mesaId}_{yyyyMMdd}_{HH}` se compone con la fecha local. El margen
// es una DIFERENCIA entre dos instantes, así que no depende del huso: da lo
// mismo en America/Bogota (UTC-5, sin horario de verano) que en el huso de
// la máquina de CI. La comparación server-side de `firestore.rules` es entre
// dos instantes absolutos por la misma razón (ver scripts/test/rules).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/features/reservas/reserva_controller.dart';

import '../helpers/firebase_fakes.dart';

// Instantes FIJOS. 2026-08-20 es un jueves cualquiera; nada depende de eso.
final _hoy = DateTime(2026, 8, 20);
final _manana = DateTime(2026, 8, 21);

DateTime _a(int h, [int m = 0, int s = 0]) => DateTime(2026, 8, 20, h, m, s);
DateTime _slotHoy(int h) => DateTime(2026, 8, 20, h);
DateTime _slotManana(int h) => DateTime(2026, 8, 21, h);

Future<String> _estado(FakeFirebaseFirestore db, String mesa) async =>
    (await db.doc('mesas/$mesa').get()).data()!['estado'] as String;

Future<ReservaException> _error(Future<void> Function() accion) async {
  try {
    await accion();
  } on ReservaException catch (e) {
    return e;
  }
  fail('se esperaba una ReservaException y la llamada tuvo éxito');
}

void main() {
  group('el margen, dicho con instantes fijos', () {
    test('son las 14:30: las 18:00 de hoy NO, las 19:00 SÍ', () {
      expect(slotRespetaMargen(_slotHoy(18), _a(14, 30)), isFalse);
      expect(slotRespetaMargen(_slotHoy(19), _a(14, 30)), isTrue);
    });

    test('son las 14:00 EN PUNTO: las 18:00 de hoy valen (la igualdad cuenta)',
        () {
      expect(slotRespetaMargen(_slotHoy(18), _a(14)), isTrue);
    });

    test('son las 14:00:01: las 18:00 ya no valen (un segundo de más)', () {
      expect(slotRespetaMargen(_slotHoy(18), _a(14, 0, 1)), isFalse);
    });

    test('el margen son 4 horas, no 3 ni 5', () {
      // Contra el slot de las 18:00: a 3 h (15:00) no; a 5 h (13:00) sí.
      expect(slotRespetaMargen(_slotHoy(18), _a(15)), isFalse);
      expect(slotRespetaMargen(_slotHoy(18), _a(13)), isTrue);
      expect(margenMinimoReserva, const Duration(hours: 4));
    });

    test('un slot de MAÑANA siempre respeta el margen, sea la hora que sea',
        () {
      // 23:59 de hoy → mañana a las 12:00 quedan 12 h y pico.
      expect(slotRespetaMargen(_slotManana(12), _a(23, 59)), isTrue);
    });
  });

  group('la rejilla que ve el usuario sale de la MISMA regla', () {
    test('a las 14:30 hoy ofrece 19:00, 20:00 y 21:00 — nada antes', () {
      expect(horasReservablesEn(_hoy, _a(14, 30)), ['19:00', '20:00', '21:00']);
    });

    test('a las 14:00 en punto hoy ofrece también las 18:00', () {
      expect(horasReservablesEn(_hoy, _a(14)),
          ['18:00', '19:00', '20:00', '21:00']);
    });

    test('a las 08:00 en punto hoy ofrece la rejilla ENTERA (12:00 incluida)',
        () {
      expect(horasReservablesEn(_hoy, _a(8)), horasSlotReserva);
      expect(horasSlotReserva.first, '12:00');
      expect(horasSlotReserva.last, '21:00');
    });

    test('a las 08:01 hoy ya perdió las 12:00', () {
      expect(horasReservablesEn(_hoy, _a(8, 1)).first, '13:00');
      expect(horasReservablesEn(_hoy, _a(8, 1)), hasLength(9));
    });

    test('a las 17:00 hoy queda UNA sola hora: las 21:00', () {
      expect(horasReservablesEn(_hoy, _a(17)), ['21:00']);
    });

    test('a las 17:01 hoy ya no queda ninguna', () {
      expect(horasReservablesEn(_hoy, _a(17, 1)), isEmpty);
    });

    test('mañana ofrece la rejilla entera aunque hoy esté cerrado', () {
      expect(horasReservablesEn(_manana, _a(17, 1)), horasSlotReserva);
    });

    test(
        'CONSISTENCIA rejilla↔validador: cada hora ofrecida la acepta el '
        'validador y cada hora omitida la rechaza', () {
      // No es tautológico: recorre la rejilla COMPLETA y contrasta la lista
      // que se PINTA contra el predicado que DECIDE. Si alguien filtrara la
      // lista con otra aritmética (el fallo clásico: picker con `>` y
      // validador con `>=`), aquí saltaría.
      for (final ahora in [
        _a(8),
        _a(8, 1),
        _a(14),
        _a(14, 30),
        _a(17),
        _a(17, 1),
      ]) {
        final ofrecidas = horasReservablesEn(_hoy, ahora);
        for (final h in horasSlotReserva) {
          final slot = _slotHoy(int.parse(h.substring(0, 2)));
          expect(ofrecidas.contains(h), slotRespetaMargen(slot, ahora),
              reason: 'a las $ahora, la hora $h');
        }
      }
    });
  });

  group('qué día se puede elegir en el calendario', () {
    test('a las 14:30 el calendario ya abre en HOY', () {
      expect(primeraFechaReservable(_a(14, 30)), _hoy);
    });

    test('a las 17:00 todavía abre en hoy (queda la de las 21:00)', () {
      expect(primeraFechaReservable(_a(17)), _hoy);
    });

    test('a las 17:01 hoy ya no da de sí: el calendario abre en MAÑANA', () {
      expect(primeraFechaReservable(_a(17, 1)), _manana);
    });

    test('a las 23:30 abre en mañana, no en pasado mañana', () {
      expect(primeraFechaReservable(_a(23, 30)), _manana);
    });
  });

  group('crearReserva aplica el margen ANTES de tocar nada', () {
    test('slot de hoy a 3 h y media: rechazado y con el motivo real', () async {
      final db = await buildFakeFirestoreConSeed();

      final e = await _error(() => crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(18),
          personas: 2,
          ahora: _a(14, 30)));

      expect(e.message, contains('4 horas de antelación'));
      // Dice cuál es el primero que SÍ, y sale de la misma función que pinta
      // la rejilla: no puede contradecirla.
      expect(e.message, contains('19:00'));
      // Y no escribió NADA: ni la reserva ni el estado de la mesa.
      expect((await db.collection('reservas').get()).docs, isEmpty);
      expect(await _estado(db, 'GRI-MESA-demo-001'), 'disponible');
    });

    test('a las 17:01 el mensaje manda a otro día, no a una hora que no hay',
        () async {
      final db = await buildFakeFirestoreConSeed();

      final e = await _error(() => crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(21),
          personas: 2,
          ahora: _a(17, 1)));

      expect(e.message, contains('Elige otro día'));
      expect(e.message, isNot(contains('El primer horario')));
    });

    test('slot de hoy a 4 h y media: se crea', () async {
      final db = await buildFakeFirestoreConSeed();

      final r = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(19),
          personas: 2,
          ahora: _a(14, 30));

      expect(r.fechaStr, '2026-08-20');
      expect(r.hora, 19);
    });

    test('slot de hoy a EXACTAMENTE 4 h: se crea (el borde es inclusivo)',
        () async {
      final db = await buildFakeFirestoreConSeed();

      final r = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(18),
          personas: 2,
          ahora: _a(14));

      expect(r.hora, 18);
    });
  });

  // ══ LA RAMA `esHoy` YA NO ES TEÓRICA ══════════════════════════════════════
  //
  // Hasta este plan el selector empezaba MAÑANA, así que esta rama —la que
  // marca la mesa `reservada` y la que salta las mesas ocupadas— era
  // inalcanzable desde el producto (medido y declarado en el SUMMARY de
  // 11-29). Con el margen de 4 h pasa a ejecutarse de verdad.
  group('esHoy en vivo: la reserva de hoy SÍ mueve el estado de la mesa', () {
    test('reserva de hoy: la mesa asignada queda reservada', () async {
      final db = await buildFakeFirestoreConSeed();

      final r = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(19),
          personas: 2,
          ahora: _a(14, 30));

      expect(r.mesaId, 'GRI-MESA-demo-001');
      expect(await _estado(db, 'GRI-MESA-demo-001'), 'reservada');
    });

    test('la misma reserva pero para MAÑANA no toca ninguna mesa', () async {
      final db = await buildFakeFirestoreConSeed();

      await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotManana(19),
          personas: 2,
          ahora: _a(14, 30));

      expect(await _estado(db, 'GRI-MESA-demo-001'), 'disponible');
    });

    test('mesa OCUPADA ahora: se salta y gana la siguiente (bug A, en vivo)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc('mesas/GRI-MESA-demo-001').update({'estado': 'ocupada'});

      final r = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(19),
          personas: 2,
          ahora: _a(14, 30));

      expect(r.mesaId, 'GRI-MESA-demo-002');
      expect(await _estado(db, 'GRI-MESA-demo-002'), 'reservada');
      // La ocupada no se toca: sigue con su sesión real encima.
      expect(await _estado(db, 'GRI-MESA-demo-001'), 'ocupada');
    });

    test(
        'TODAS ocupadas hoy: el mensaje habla de ocupación, no del margen ni '
        'del horario', () async {
      final db = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }

      final e = await _error(() => crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(19),
          personas: 2,
          ahora: _a(14, 30)));

      expect(e.message, contains('ocupadas en este momento'));
      expect(e.message, isNot(contains('antelación')));
    });

    test('cancelar una reserva de HOY revierte la mesa (simétrico, en vivo)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final r = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotHoy(19),
          personas: 2,
          ahora: _a(14, 30));
      expect(await _estado(db, 'GRI-MESA-demo-001'), 'reservada');

      await cancelarReserva(db, uid: 'test-uid', reserva: r, ahora: _a(14, 35));

      expect(await _estado(db, 'GRI-MESA-demo-001'), 'disponible');
    });
  });
}
