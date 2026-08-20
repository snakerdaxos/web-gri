// test/reservas/errores_honestos_reserva_test.dart — el flujo de reservas deja
// de aplastar todas sus causas en una sola frase, y encima falsa (11-29,
// BUG C).
//
// ── EL BUG ─────────────────────────────────────────────────────────────────
// `ReservaController.create` tenía esto:
//
//     } on ReservaException {
//       // 409-equivalentes del port (capacidad/slot tomado/estado mesa).
//       throw const ReservaException('Ese horario acaba de ser reservado, '
//           'elige otro');
//
// El propio comentario enumera TRES causas distintas —capacidad insuficiente,
// slot tomado, estado de la mesa— y elige para las tres el texto de UNA. Para
// dos de ellas es directamente falso. Y lo peor: `crearReserva` ya lanzaba el
// mensaje correcto; el `catch` lo TIRABA.
//
// El usuario lo sufrió reservando para una fecha futura en una base con CERO
// reservas: la app le dijo que su horario acababa de ser reservado.
//
// Es la tercera vez que este patrón cuesta tiempo real en este proyecto (el
// escáner en 11-23, el panel en 11-26). El criterio es el de 11-23: se
// clasifica la causa en `core/firebase_error_mapper.dart` y se redacta por
// (causa, contexto). Aquí se estrenan los contextos `crearReserva` y
// `cancelarReserva`.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_error_mapper.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/reloj.dart';
import 'package:gri_cliente/features/reservas/reserva_controller.dart';
import 'package:gri_cliente/models/reserva_create.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';

/// El texto que este plan retira: afirmaba una causa para CUALQUIER fallo.
const _mensajeCiego = 'Ese horario acaba de ser reservado, elige otro';

FirebaseException _fb(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

/// Instante FIJO del día de hoy. Desde 11-31 hay un margen mínimo de 4 h
/// para reservar, así que un caso con el slot de HOY a las 23:00 dejaría de
/// pasar a partir de las 19:01 si el «ahora» lo pusiera el reloj de la
/// máquina. La FECHA sigue siendo la real; lo que se fija es la HORA.
DateTime _hoyALas(int h) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, h);
}

DateTime _slotDeManana([int hora = 19]) {
  final t = DateTime.now().add(const Duration(days: 1));
  return DateTime(t.year, t.month, t.day, hora);
}

DateTime _slotDeHoy([int hora = 23]) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, hora);
}

String _fechaStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

ReservaCreate _cuerpo(DateTime slot, {int personas = 2}) => ReservaCreate(
      restauranteId: 'demo',
      fecha: _fechaStr(slot),
      hora: slot.hour,
      numPersonas: personas,
    );

/// Intercepta `debugPrint` para afirmar que los `catch` dejan traza.
///
/// Los dos `catch (_)` de este archivo eran MUDOS: 11-23 lo dejó anotado como
/// deuda («se tragan la excepción sin dejar traza»). Se cierra aquí.
class _Trazas {
  _Trazas() : _original = debugPrint {
    debugPrint =
        (String? mensaje, {int? wrapWidth}) => _lineas.add(mensaje ?? '');
  }

  final DebugPrintCallback _original;
  final List<String> _lineas = [];

  void esperar(String code, CausaFallo causa) {
    debugPrint = _original;
    final todo = _lineas.join('\n');
    expect(todo, contains(code),
        reason: 'el catch tiene que dejar la causa real en el log');
    expect(todo, contains(causa.toString()),
        reason: 'y CÓMO la clasificó, para poder depurar la clasificación');
  }

  void restaurar() => debugPrint = _original;
}

/// Ejecuta `ReservaController.create` de verdad (el `catch` bajo prueba vive
/// en el controller, no en el servicio) y devuelve el mensaje que sale.
Future<String> _mensajeDeCreate(dynamic db, ReservaCreate cuerpo) async {
  final container = ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(mockAuth()),
    firestoreProvider.overrideWithValue(db),
    // 11-31: reloj fijo. El controller pasa este instante a `crearReserva`,
    // y sin fijarlo los casos con slot de HOY dependerían de la hora a la
    // que se corriera la suite.
    relojProvider.overrideWithValue(() => _hoyALas(12)),
  ]);
  addTearDown(container.dispose);
  try {
    await container.read(reservaControllerProvider.notifier).create(cuerpo);
  } on ReservaException catch (e) {
    return e.message;
  }
  fail('se esperaba que create() fallara');
}

void main() {
  // ══ 1. El mapeador conoce los dos contextos nuevos ═══════════════════════
  group('mapeador — contextos crearReserva / cancelarReserva', () {
    test('las seis causas dan seis textos DISTINTOS en cada contexto', () {
      for (final contexto in [Contexto.crearReserva, Contexto.cancelarReserva]) {
        final textos = {
          for (final causa in CausaFallo.values)
            mensajeDe(causa, contexto: contexto),
        };
        expect(textos, hasLength(CausaFallo.values.length),
            reason: 'en $contexto hay causas compartiendo texto: '
                'es exactamente el bug que se está cerrando');
      }
    });

    test('permisoDenegado habla de la CUENTA, jamás del horario', () {
      for (final contexto in [Contexto.crearReserva, Contexto.cancelarReserva]) {
        final texto =
            mensajeDe(CausaFallo.permisoDenegado, contexto: contexto);
        expect(texto.toLowerCase(), contains('cuenta'));
        expect(texto.toLowerCase(), isNot(contains('horario')));
        expect(texto.toLowerCase(), isNot(contains('conexión')));
      }
    });

    test('desconocido no inventa causa (ni el horario, ni la red)', () {
      for (final contexto in [Contexto.crearReserva, Contexto.cancelarReserva]) {
        final texto = mensajeDe(CausaFallo.desconocido, contexto: contexto);
        expect(texto.toLowerCase(), isNot(contains('horario')));
        expect(texto.toLowerCase(), isNot(contains('conexión')));
        expect(texto.toLowerCase(), isNot(contains('cuenta')));
      }
    });

    test('sinConexion sí habla de la conexión, y solo esa causa', () {
      final texto =
          mensajeDe(CausaFallo.sinConexion, contexto: Contexto.crearReserva);
      expect(texto.toLowerCase(), contains('conexión'));
    });
  });

  // ══ 2. create() propaga la causa REAL ════════════════════════════════════
  group('create() — cada causa sale con su propio mensaje', () {
    test('capacidad insuficiente → lo dice, no culpa al horario', () async {
      final db = await buildFakeFirestoreConSeed();

      final msg = await _mensajeDeCreate(
          db, _cuerpo(_slotDeManana(), personas: 10));

      expect(msg, 'No hay mesas con capacidad suficiente');
      expect(msg, isNot(_mensajeCiego));
    });

    test('slot tomado en todas las candidatas → habla del horario (aquí sí)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();
      for (final m in ['001', '002', '003']) {
        await db
            .doc('reservas/${docIdReserva('GRI-MESA-demo-$m', slot)}')
            .set({'mesaId': 'GRI-MESA-demo-$m', 'estado': 'confirmada'});
      }

      final msg = await _mensajeDeCreate(db, _cuerpo(slot));

      expect(msg, 'No hay mesas disponibles en ese horario');
    });

    test('todas las mesas ocupadas HOY → habla de la ocupación', () async {
      final db = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }

      final msg = await _mensajeDeCreate(db, _cuerpo(_slotDeHoy()));

      expect(msg, contains('ocupadas en este momento'));
      expect(msg.toLowerCase(), isNot(contains('horario')));
    });

    test('permission-denied → habla de la CUENTA, y deja traza', () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();
      final trazas = _Trazas();
      // Primer `tx.get` del bucle de asignación: el slot de la candidata 001.
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('reservas/${docIdReserva('GRI-MESA-demo-001', slot)}'))
          .thenThrow(_fb('permission-denied'));

      final msg = await _mensajeDeCreate(db, _cuerpo(slot));

      trazas.esperar('permission-denied', CausaFallo.permisoDenegado);
      expect(
        msg,
        mensajeDe(CausaFallo.permisoDenegado, contexto: Contexto.crearReserva),
      );
      expect(msg.toLowerCase(), isNot(contains('horario')));
    });

    test('unavailable → habla de la CONEXIÓN', () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();
      final trazas = _Trazas();
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('reservas/${docIdReserva('GRI-MESA-demo-001', slot)}'))
          .thenThrow(_fb('unavailable'));

      final msg = await _mensajeDeCreate(db, _cuerpo(slot));

      trazas.restaurar();
      expect(
        msg,
        mensajeDe(CausaFallo.sinConexion, contexto: Contexto.crearReserva),
      );
      expect(msg.toLowerCase(), isNot(contains('horario')));
    });

    test('las cinco situaciones producen cinco mensajes DISTINTOS', () async {
      // La comparación que el bug no hacía: cinco causas, cinco textos.
      final mensajes = <String>{};

      final db1 = await buildFakeFirestoreConSeed();
      mensajes.add(await _mensajeDeCreate(
          db1, _cuerpo(_slotDeManana(), personas: 10)));

      final db2 = await buildFakeFirestoreConSeed();
      final slot2 = _slotDeManana();
      for (final m in ['001', '002', '003']) {
        await db2
            .doc('reservas/${docIdReserva('GRI-MESA-demo-$m', slot2)}')
            .set({'mesaId': 'GRI-MESA-demo-$m', 'estado': 'confirmada'});
      }
      mensajes.add(await _mensajeDeCreate(db2, _cuerpo(slot2)));

      final db3 = await buildFakeFirestoreConSeed();
      for (final m in ['001', '002', '003']) {
        await db3.doc('mesas/GRI-MESA-demo-$m').update({'estado': 'ocupada'});
      }
      mensajes.add(await _mensajeDeCreate(db3, _cuerpo(_slotDeHoy())));

      final db4 = await buildFakeFirestoreConSeed();
      final slot4 = _slotDeManana();
      final t4 = _Trazas();
      whenCalling(Invocation.method(#get, null))
          .on(db4.doc('reservas/${docIdReserva('GRI-MESA-demo-001', slot4)}'))
          .thenThrow(_fb('permission-denied'));
      mensajes.add(await _mensajeDeCreate(db4, _cuerpo(slot4)));
      t4.restaurar();

      final db5 = await buildFakeFirestoreConSeed();
      final slot5 = _slotDeManana();
      final t5 = _Trazas();
      whenCalling(Invocation.method(#get, null))
          .on(db5.doc('reservas/${docIdReserva('GRI-MESA-demo-001', slot5)}'))
          .thenThrow(_fb('unavailable'));
      mensajes.add(await _mensajeDeCreate(db5, _cuerpo(slot5)));
      t5.restaurar();

      expect(mensajes, hasLength(5));
      expect(mensajes, isNot(contains(_mensajeCiego)));
    });
  });

  // ══ 3. cancel() ══════════════════════════════════════════════════════════
  group('cancel() — el catch mudo deja de serlo', () {
    test('permission-denied → habla de la CUENTA, y deja traza', () async {
      final db = await buildFakeFirestoreConSeed();
      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(),
          personas: 2);
      final container = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        firestoreProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      final trazas = _Trazas();
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('reservas/${reserva.id}'))
          .thenThrow(_fb('permission-denied'));

      String? msg;
      try {
        await container
            .read(reservaControllerProvider.notifier)
            .cancel(reserva);
      } on ReservaException catch (e) {
        msg = e.message;
      }

      trazas.esperar('permission-denied', CausaFallo.permisoDenegado);
      expect(
        msg,
        mensajeDe(CausaFallo.permisoDenegado,
            contexto: Contexto.cancelarReserva),
      );
    });

    test('los mensajes de dominio ya correctos NO cambian', () async {
      final db = await buildFakeFirestoreConSeed();
      final reserva = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(),
          personas: 2);
      final container = ProviderContainer(overrides: [
        // Otro uid: existence hiding del dominio.
        firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'intruso')),
        firestoreProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      String? msg;
      try {
        await container
            .read(reservaControllerProvider.notifier)
            .cancel(reserva);
      } on ReservaException catch (e) {
        msg = e.message;
      }

      expect(msg, 'Reserva no encontrada');
    });
  });

  // ══ 4. GATE estático ═════════════════════════════════════════════════════
  test('GATE: el mensaje ciego no vuelve al código de ninguna de las dos apps',
      () async {
    // El barrido de pantallas solo ve lo que monta (lección de 11-14): esto
    // lee las FUENTES. Los comentarios documentan el bug a propósito y se
    // saltan (falso positivo que 11-23 midió en su gate de grep).
    const fuentes = <String>[
      'lib/features/reservas/reserva_controller.dart',
      'lib/features/reservas/reserva_wizard_screen.dart',
      'lib/features/reservas/mis_reservas_screen.dart',
      '../panel_admin/lib/features/reservas/reservas_screen.dart',
      '../panel_admin/lib/features/reservas/reservas_provider.dart',
    ];
    final infracciones = <String>[];
    for (final ruta in fuentes) {
      final archivo = File(ruta);
      expect(await archivo.exists(), isTrue, reason: 'no existe $ruta');
      final lineas = await archivo.readAsLines();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (linea.trimLeft().startsWith('//')) continue;
        if (linea.contains('Ese horario acaba de ser reservado')) {
          infracciones.add('$ruta:${i + 1}: ${linea.trim()}');
        }
      }
    }
    expect(infracciones, isEmpty,
        reason: 'ese texto afirma UNA causa para varias; el mensaje tiene que '
            'venir del dominio o de mensajeDe/mensajeDeFallo');
  });
}
