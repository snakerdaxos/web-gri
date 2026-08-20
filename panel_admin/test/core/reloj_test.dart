// ============================================================================
// GRI — El RELOJ DE SALA (plan 11-34).
//
// Desde 11-34 el color de una mesa se calcula cruzando las reservas del día
// con la hora, así que la pantalla puede quedarse obsoleta SIN QUE CAMBIE
// NINGÚN DOCUMENTO: pasan los 30 minutos de cortesía y ningún onSnapshot va a
// avisar, porque en Firestore no se ha movido nada. El reloj es lo único que
// hace que la mesa se libere sola en la pantalla.
//
// ── POR QUÉ ESTE ARCHIVO EXISTE ──────────────────────────────────────────
// El DEFECTO de `fabricaDeRelojProvider` es el reloj QUIETO —una sola
// emisión, sin temporizador— porque un `Timer.periodic` vivo dentro de un
// test de widget enrojece el harness («A Timer is still pending even after
// the widget tree was disposed»: 80 casos medidos en la primera pasada). El
// que LATE se instala solo en `main.dart`.
//
// Eso deja el latido fuera de las pruebas de widget, y no se puede dejar sin
// cubrir: es la pieza de la que depende la liberación automática. Aquí se
// prueba directamente, con `fakeAsync`, sin montar nada.
// ============================================================================

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/reloj.dart';

void main() {
  test('el reloj QUIETO emite UNA hora y se acaba', () async {
    final horas = await relojQuieto().toList();

    expect(horas, hasLength(1));
    // No se afirma CUÁL es la hora: sería afirmar que `DateTime.now()` es
    // `DateTime.now()`. Lo que importa es que emite una y no queda colgado.
  });

  test('el reloj que LATE emite al instante, sin esperar el primer tick', () {
    fakeAsync((async) {
      final vistas = <DateTime>[];
      final limpiezas = <void Function()>[];
      final sub = relojQueLate(limpiezas.add).listen(vistas.add);

      // Cero tiempo transcurrido: solo se drenan las microtareas.
      async.flushMicrotasks();
      expect(vistas, hasLength(1),
          reason: 'sin esto el mapa arrancaría sin colorear medio minuto');

      sub.cancel();
      for (final l in limpiezas) {
        l();
      }
    });
  });

  test('sigue latiendo: tres tics son tres horas más', () {
    fakeAsync((async) {
      final vistas = <DateTime>[];
      final limpiezas = <void Function()>[];
      final sub = relojQueLate(limpiezas.add).listen(vistas.add);
      async.flushMicrotasks();

      async.elapse(cadenciaDelReloj * 3);

      expect(vistas, hasLength(4), reason: 'la inicial + tres tics');
      // NO se afirma que las horas avancen. Se intentó y ES FLAKY: `fakeAsync`
      // adelanta los TEMPORIZADORES, no `DateTime.now()`, así que las cuatro
      // horas salen del reloj real y son iguales salvo que la máquina cruce
      // un milisegundo entre medias. La primera pasada de esta suite lo
      // demostró en directo: rojo, y verde al repetir sin tocar nada. Lo que
      // este archivo puede afirmar sin mentir es la CADENCIA (cuántas veces
      // emite) y la LIMPIEZA; de dónde sale la hora lo afirma quien la fija,
      // que son los tests de la ventana.

      sub.cancel();
      for (final l in limpiezas) {
        l();
      }
    });
  });

  test('media hora de latido cubre de sobra la ventana de cortesía', () {
    // La cadencia tiene que ser bastante más fina que los 30 min de
    // cortesía, o la mesa se liberaría con retraso visible. 30 s dan 60
    // muestras dentro de la ventana.
    fakeAsync((async) {
      final vistas = <DateTime>[];
      final limpiezas = <void Function()>[];
      final sub = relojQueLate(limpiezas.add).listen(vistas.add);
      async.flushMicrotasks();

      async.elapse(const Duration(minutes: 30));

      expect(vistas.length, greaterThanOrEqualTo(60));

      sub.cancel();
      for (final l in limpiezas) {
        l();
      }
    });
  });

  test('LA LIMPIEZA APAGA EL TEMPORIZADOR (el fallo de las 80 pruebas)', () {
    fakeAsync((async) {
      final limpiezas = <void Function()>[];
      final sub = relojQueLate(limpiezas.add).listen((_) {});
      async.flushMicrotasks();
      expect(async.periodicTimerCount, 1);

      for (final l in limpiezas) {
        l();
      }

      expect(async.periodicTimerCount, 0,
          reason: 'un temporizador que sobrevive a su dueño es el defecto '
              'que costó 80 casos rojos');
      sub.cancel();
    });
  });

  test('CANARIO: sin llamar a la limpieza, el temporizador SIGUE vivo', () {
    // Sin este caso, el anterior pasaría igual aunque la limpieza no hiciera
    // nada — bastaría con que `fakeAsync` no contara temporizadores.
    fakeAsync((async) {
      final limpiezas = <void Function()>[];
      final sub = relojQueLate(limpiezas.add).listen((_) {});
      async.flushMicrotasks();

      expect(async.periodicTimerCount, 1);

      for (final l in limpiezas) {
        l();
      }
      sub.cancel();
    });
  });
}
