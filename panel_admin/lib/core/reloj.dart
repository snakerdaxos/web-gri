import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reloj.g.dart';

/// Cada cuánto se vuelve a mirar la hora.
///
/// 30 s, no 1 min: la ventana de bloqueo de una reserva se abre y se cierra en
/// un instante concreto, y con un tick de un minuto la mesa podría quedar
/// amarilla hasta 59 s de más. Con 30 s el desfase máximo es medio minuto,
/// que en la sala de un restaurante no significa nada, y son 120 reconstrucciones
/// por hora de un `Column` — nada comparado con el coste de un solo snapshot
/// de Firestore.
const Duration cadenciaDelReloj = Duration(seconds: 30);

/// Fábrica del reloj. Devuelve un stream NUEVO en cada llamada.
///
/// Es una FÁBRICA y no un stream porque hay dos consumidores independientes
/// —el mapa de mesas y los contadores del dashboard— y un stream de
/// suscripción única reventaría con «Stream has already been listened to» en
/// cuanto el segundo escuchara.
typedef FabricaDeReloj = Stream<DateTime> Function();

/// El reloj QUIETO: la hora de ahora, una sola vez, sin temporizador.
///
/// Es el DEFECTO de [fabricaDeRelojProvider]. La hora que da es correcta; lo
/// que no hace es volver a mirarla. Con él, el mapa de mesas se colorea bien
/// y no se refresca solo.
Stream<DateTime> relojQuieto() => Stream<DateTime>.value(DateTime.now());

/// El reloj que LATE: la hora ahora y otra vez cada [cadenciaDelReloj].
///
/// [registrarLimpieza] recibe el cierre que apaga el temporizador. Se pasa
/// `ref.onDispose` — ver abajo por qué la limpieza tiene que ser síncrona.
Stream<DateTime> relojQueLate(void Function(void Function()) registrarLimpieza) {
  final control = StreamController<DateTime>();
  // El primero SIN esperar: si no, la primera pintada no tendría hora y el
  // mapa arrancaría sin colorear medio minuto. Un `add` previo al `listen` se
  // guarda en el búfer del controlador y se entrega al suscribirse.
  control.add(DateTime.now());
  final temporizador = Timer.periodic(
    cadenciaDelReloj,
    (_) => control.add(DateTime.now()),
  );
  registrarLimpieza(() {
    temporizador.cancel();
    control.close();
  });
  return control.stream;
}

/// EL ÚNICO PUNTO POR DONDE ENTRA LA HORA A LA APLICACIÓN.
///
/// ── POR QUÉ HACE FALTA UN PROVIDER PARA `DateTime.now()` ─────────────────
/// Desde 11-34 el color de una mesa NO sale solo de sus documentos: sale de
/// comparar las reservas del día con la hora actual. Eso significa que la
/// pantalla puede quedarse obsoleta SIN QUE CAMBIE NINGÚN DOCUMENTO — pasan
/// los 30 minutos de cortesía, la mesa debería liberarse sola, y ningún
/// `onSnapshot` va a emitir nada porque en Firestore no se ha movido nada.
/// Un `DateTime.now()` leído dentro de `build()` se congela en el primer
/// render.
///
/// ── POR QUÉ EL DEFECTO ES EL RELOJ QUIETO ────────────────────────────────
/// MEDIDO, no teórico: con el reloj latiendo por defecto, la primera pasada
/// completa de la suite del panel dio **80 casos rojos** con
///
///     A Timer is still pending even after the widget tree was disposed.
///
/// La causa es de fontanería y merece quedar escrita. Los tests que montan la
/// app entera usan `UncontrolledProviderScope` con
/// `addTearDown(container.dispose)`, y el harness comprueba `!timersPending`
/// ANTES de ejecutar los tearDown. Cualquier temporizador vivo durante el
/// cuerpo del caso lo enrojece — da igual lo pulcra que sea su cancelación.
///
/// Las dos salidas eran: añadir el override a los catorce archivos que montan
/// la app, o que el defecto no tenga temporizador. La segunda es mejor porque
/// además es la verdad: **un test no tiene por qué saber que el reloj
/// existe**, y un temporizador latiendo dentro de una prueba es una fuente de
/// intermitencia que no aporta nada.
///
/// LO QUE ESTO CUESTA, dicho sin adornos: el LATIDO no está cubierto por
/// ninguna prueba de widget. Se cubre por dos vías distintas:
///   · `test/core/reloj_test.dart` prueba [relojQueLate] directamente con
///     `fakeAsync` — que emite, que sigue emitiendo y que la limpieza apaga
///     el temporizador.
///   · `test/core/reloj_cableado_test.dart` afirma que `main.dart` instala
///     [relojQueLate] en el `ProviderScope` raíz. Sin ese caso, olvidar el
///     override dejaría el mapa sin refrescarse en producción y ninguna
///     prueba lo notaría.
///
/// ── PARA LOS TESTS QUE SÍ MIRAN LA HORA ──────────────────────────────────
/// Se sobreescribe con
/// `fabricaDeRelojProvider.overrideWithValue(() => Stream.value(instante))`
/// y con eso quedan fijados A LA VEZ el mapa y los contadores, que es lo que
/// impide que un test afirme sobre una hora y otro sobre otra. Ninguna prueba
/// de la ventana debe depender del reloj de la máquina: 11-31 encontró cinco
/// archivos que sí dependían y que se habrían puesto rojos a partir de las
/// 19:01.
final fabricaDeRelojProvider = Provider<FabricaDeReloj>((ref) => relojQuieto);

/// La hora actual como `AsyncValue`, para los widgets.
@riverpod
Stream<DateTime> relojDeSala(Ref ref) => ref.watch(fabricaDeRelojProvider)();
