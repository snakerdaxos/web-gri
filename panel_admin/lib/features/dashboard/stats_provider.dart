import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/reloj.dart';
import '../../models/dashboard_stats.dart';
import '../../models/mesa.dart';
import '../../models/reserva.dart';
import 'bloqueo_reserva.dart';
import 'restaurante_provider.dart';

part 'stats_provider.g.dart';

/// Stats del dashboard DERIVADAS de los 3 streams realtime (10-05 Task 3 —
/// sin endpoint): mesas por estado + reservas de hoy + pedidos activos,
/// combinadas con combineLatest para re-emitir ante CUALQUIER cambio.
///
/// * Queries del bloque interfaces del plan:
///   * mesas `where restauranteId == rid` (sin orderBy: solo se cuentan).
///   * reservas `where restauranteId == rid where fecha >= inicioHoy &&
///     fecha < inicioMañana` — ventana computada en la TZ local del
///     operador.
///   * pedidos `where restauranteId == rid where estado in
///     [enviado, aceptado, en_preparacion]` (misma definición de "activo"
///     que la cola de cocina).
/// * Watches ANTES del primer await (lección 07-03, riverpod-3-safe).
@riverpod
Stream<DashboardStats> stats(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    // super_admin sin restaurante elegido: cards en cero hasta la selección.
    yield const DashboardStats(
      mesasDisponibles: 0,
      mesasOcupadas: 0,
      mesasReservadas: 0,
      mesasLimpieza: 0,
      totalMesas: 0,
      reservasHoy: 0,
      pedidosActivos: 0,
    );
    return;
  }

  // Ventana "hoy" en TZ local truncada a día; mañana = +1 día.
  final ahora = DateTime.now();
  final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
  final inicioManana = inicioHoy.add(const Duration(days: 1));

  final mesas$ = db
      .collection('mesas')
      .where('restauranteId', isEqualTo: rid)
      .snapshots();
  final reservasHoy$ = db
      .collection('reservas')
      .where('restauranteId', isEqualTo: rid)
      .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
      .where('fecha', isLessThan: Timestamp.fromDate(inicioManana))
      .snapshots();
  final pedidosActivos$ = db
      .collection('pedidos')
      .where('restauranteId', isEqualTo: rid)
      .where(
        'estado',
        whereIn: const ['enviado', 'aceptado', 'en_preparacion'],
      )
      .snapshots();

  // ── EL RELOJ COMO CUARTO STREAM (11-34) ─────────────────────────────────
  //
  // Los contadores de mesas ya no salen del campo `estado`: salen de cruzar
  // las reservas del día con la hora (ver `bloqueo_reserva.dart`). Eso hace
  // que el recuento correcto CAMBIE sin que cambie ningún documento — a los
  // +30 min de cortesía una mesa deja de estar bloqueada y ningún onSnapshot
  // va a emitir nada, porque en Firestore no se ha movido nada.
  //
  // El reloj entra como un stream MÁS del combineLatest y no como un
  // `ref.watch`: un watch reconstruiría el provider entero cada 30 s y con él
  // volvería a suscribir las TRES consultas de Firestore. Así solo se
  // re-emite el cálculo, con los últimos snapshots ya en memoria: cero
  // lecturas de pago por tick.
  final reloj$ = ref.watch(fabricaDeRelojProvider)();

  yield* _combineLatest4(mesas$, reservasHoy$, pedidosActivos$, reloj$)
      .map((v) {
    final mesas = [for (final doc in v.$1.docs) Mesa.fromDoc(doc)];
    final reservas = [for (final doc in v.$2.docs) Reserva.fromDoc(doc)];
    // MISMA función que pinta el mapa. Si el contador y el mapa se
    // calcularan por separado podrían discrepar, y un tablero que se
    // contradice a sí mismo es peor que uno que no está.
    final conteo = contarPorEstadoVisual(componerMapaDeMesas(
      mesas: mesas,
      reservasDelDia: reservas,
      ahora: v.$4,
    ));
    return DashboardStats(
      mesasDisponibles: conteo.disponibles,
      mesasOcupadas: conteo.ocupadas,
      mesasReservadas: conteo.reservadas,
      mesasLimpieza: conteo.limpieza,
      totalMesas: mesas.length,
      reservasHoy: v.$2.size,
      pedidosActivos: v.$3.size,
    );
  });
}

/// combineLatest de 4 streams sin rxdart: emite apenas TODOS tienen su
/// primer valor y re-emite con los ÚLTIMOS valores de cada stream ante
/// cualquier cambio posterior (derivación de stats — Firestore emite el
/// snapshot inicial inmediato al escuchar, así que la primera emisión llega
/// con los tres de datos; el cuarto es el reloj, que emite su primer valor
/// sin esperar). Los errores se reenvían al stream resultado.
///
/// Pasó de 3 a 4 en 11-34 al entrar el reloj de sala. Se generalizó a mano y
/// no con rxdart por la misma razón de siempre en este repo: una dependencia
/// menos que auditar para 40 líneas que se leen enteras.
Stream<(A, B, C, D)> _combineLatest4<A, B, C, D>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  Stream<D> d,
) {
  late StreamController<(A, B, C, D)> controller;
  A? ultimoA;
  B? ultimoB;
  C? ultimoC;
  D? ultimoD;
  var cancelado = false;
  final subs = <StreamSubscription<dynamic>>[];

  void emitir() {
    if (cancelado) return;
    if (ultimoA != null && ultimoB != null && ultimoC != null &&
        ultimoD != null) {
      controller.add((ultimoA as A, ultimoB as B, ultimoC as C, ultimoD as D));
    }
  }

  controller = StreamController<(A, B, C, D)>(
    // sync: la re-emisión entrega EN el evento del snapshot (no en una
    // microtask posterior) — paridad con `yield*` directo sobre
    // snapshots(): un read posterior a la escritura ya ve el valor nuevo.
    sync: true,
    onListen: () {
      void enchufar<T>(Stream<T> s, void Function(T) set) {
        subs.add(s.listen((v) {
          set(v);
          emitir();
        }, onError: controller.addError));
      }

      enchufar<A>(a, (v) => ultimoA = v);
      enchufar<B>(b, (v) => ultimoB = v);
      enchufar<C>(c, (v) => ultimoC = v);
      enchufar<D>(d, (v) => ultimoD = v);
    },
    onCancel: () async {
      cancelado = true;
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );
  return controller.stream;
}
