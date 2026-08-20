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
// El `estado` de la mesa solo intervenía cuando el slot era de HOY, porque
// solo entonces había algo que escribir. Para un slot futuro no se consultaba
// ni se escribía: que la mesa esté ocupada ahora no dice nada de cómo estará
// mañana.
//
// ── 11-34: LA REGLA SE EXTIENDE A HOY, Y EL ARCHIVO CAMBIA DE VEREDICTO ────
// 11-29 hizo el cambio MÍNIMO y dejó escrito que el modelo correcto era otro:
// que el panel derivara el color del mapa de las reservas del día en vez de
// depender de un campo `estado` en vivo. 11-34 lo hace, y con eso el
// argumento de 11-29 se aplica igual a las reservas de HOY:
//
//   · Con el margen mínimo de 4 h (11-31) una reserva de hoy nace SIEMPRE a
//     cuatro horas vista. Marcar la mesa al crearla la retiraba de
//     circulación media tarde por un cliente que quizá no venga.
//   · Que una mesa esté ocupada AHORA tampoco dice nada de cómo estará dentro
//     de cuatro horas, así que descartarla como candidata rechazaba reservas
//     perfectamente válidas.
//
// Desde 11-34, RESERVAR NO TOCA LA MESA, ni hoy ni mañana, y NINGUNA
// candidata se descarta por su estado actual. Varios casos de este archivo
// afirmaban lo contrario y se han INVERTIDO a conciencia: llevan la marca
// (11-34) y dicen qué afirmaban antes.
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
    test(
        'slot de HOY: la mesa ocupada AHORA ya NI SIQUIERA se descarta (11-34)',
        () async {
      // VEREDICTO INVERTIDO. Este caso afirmaba que la mesa ocupada «se salta
      // y gana la siguiente candidata». Saltarla era la mitad buena del
      // arreglo de 11-29 (antes LANZABA), pero seguía siendo un descarte
      // injustificado: el slot está a cuatro horas como mínimo y para
      // entonces la mesa habrá terminado su servicio. Ahora gana la primera
      // candidata por capacidad, como debe ser.
      final db = await buildFakeFirestoreConSeed();
      await db.doc(_mesa1).update({'estado': 'ocupada'});
      final slot = _slotDeHoy();

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: slot,
          ahora: _hoyALas(12),
          personas: 2);

      expect(reserva.mesaId, 'GRI-MESA-demo-001');
      expect(reserva.mesaNumero, 1);
      // Y su estado NO se toca: la sesión que la ocupa ahora es real.
      expect(await _estado(db, _mesa1), 'ocupada');
      // La segunda tampoco: reservar ya no escribe en ninguna mesa.
      expect(await _estado(db, _mesa2), 'disponible');
    });

    test('slot de HOY: una mesa en LIMPIEZA tampoco se descarta (11-34)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc(_mesa1).update({'estado': 'limpieza'});

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);

      expect(reserva.mesaId, 'GRI-MESA-demo-001');
      expect(await _estado(db, _mesa1), 'limpieza');
    });

    test(
        'slot de HOY con TODAS las mesas ocupadas AHORA: la reserva se acepta '
        'igual (11-34)',
        () async {
      // VEREDICTO INVERTIDO. Antes esto era un error con un mensaje sobre la
      // ocupación. Pero el restaurante está lleno AHORA y la reserva es para
      // dentro de cuatro horas por lo menos: rechazarla era negarle una mesa
      // a alguien por el estado de un momento que no tiene nada que ver.
      final db = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }

      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);

      expect(reserva.mesaId, 'GRI-MESA-demo-001');
      expect((await db.collection('reservas').get()).docs, hasLength(1));
      // Y las tres mesas siguen exactamente como estaban.
      expect(await _estado(db, _mesa1), 'ocupada');
    });

    test(
        'slot de HOY: lo que SÍ agota las candidatas siguen siendo las franjas '
        'tomadas',
        () async {
      // El descarte por ocupación desapareció; el de franja tomada NO, porque
      // ese sí es una colisión real: dos reservas no caben en el mismo slot de
      // la misma mesa (lo garantiza el doc ID).
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeHoy();
      await db.doc(_mesa1).update({'estado': 'ocupada'});
      for (final m in ['001', '002', '003']) {
        await _tomarSlot(db, 'GRI-MESA-demo-$m', slot);
      }

      final e = await _capturarError(() => crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: slot,
          ahora: _hoyALas(12),
          personas: 2));

      expect(e.message, 'No hay mesas disponibles en ese horario');
    });

    test('las causas que QUEDAN producen mensajes DISTINTOS (11-34)',
        () async {
      // Eran tres. Desde 11-34 son dos —la ocupación dejó de ser un motivo de
      // rechazo— y el caso (2) comprueba justamente eso: que ya no falla.
      // Sin esta comparación, «cada causa su mensaje» podría cumplirse con el
      // mismo texto repetido, que es el bug original.
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

      // (2) todas las mesas ocupadas AHORA: YA NO ES UN ERROR (11-34).
      final db2 = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db2.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }
      await crearReserva(db2,
          uid: 'u',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);

      // (3) capacidad insuficiente
      final db3 = await buildFakeFirestoreConSeed();
      mensajes.add((await _capturarError(() => crearReserva(db3,
              uid: 'u',
              restauranteId: 'demo',
              slot: _slotDeHoy(),
              ahora: _hoyALas(12),
              personas: 10)))
          .message);

      expect(mensajes, hasLength(2),
          reason: 'dos causas distintas exigen dos textos distintos');
    });
  });

  // ══ BUG B ════════════════════════════════════════════════════════════════
  group('BUG B — reservar no toca el estado de la mesa (ninguna, 11-34)',
      () {
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

    test('reservar para HOY TAMPOCO toca la mesa (11-34)', () async {
      // VEREDICTO INVERTIDO. Este caso custodiaba «el cambio mínimo no puede
      // dejar de marcar las reservas del día, que es lo que el panel pinta en
      // el mapa». Desde 11-34 el panel ya NO pinta ese campo: deriva el color
      // de las reservas del día cruzadas con la hora
      // (panel_admin/lib/features/dashboard/bloqueo_reserva.dart), así que no
      // hay nada que marcar y marcarlo era bloquear la mesa cuatro horas
      // antes de tiempo.
      final db = await buildFakeFirestoreConSeed();

      await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);

      expect(await _estado(db, _mesa1), 'disponible');
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

    test('cancelar una reserva de HOY tampoco toca la mesa (11-34)',
        () async {
      // VEREDICTO INVERTIDO, y por simetría con el create: si crear no la
      // marcó, cancelar no tiene qué desmarcar. La mesa se libera IGUAL —
      // mejor, incluso: el mapa deriva su color de las reservas VIVAS, así
      // que en cuanto esta pasa a `cancelada` deja de teñirla, sin una
      // segunda escritura que pudiera fallar por separado.
      final db = await buildFakeFirestoreConSeed();
      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeHoy(),
          ahora: _hoyALas(12),
          personas: 2);
      // Alguien la ocupa mientras tanto: es el caso que hacía peligrosa la
      // reversión automática.
      await db.doc(_mesa1).update({'estado': 'ocupada'});

      await cancelarReserva(db, uid: 'test-uid', reserva: reserva);

      expect(
        (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
        'cancelada',
      );
      expect(await _estado(db, _mesa1), 'ocupada',
          reason: 'cancelar una reserva no puede echar a quien está comiendo');
    });
  });
}
