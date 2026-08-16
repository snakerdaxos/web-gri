import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/dashboard_stats.dart';
import '../../models/mesa.dart';
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

  yield* _combineLatest3(mesas$, reservasHoy$, pedidosActivos$).map((v) {
    final mesas = [for (final doc in v.$1.docs) Mesa.fromDoc(doc)];
    return DashboardStats(
      mesasDisponibles: mesas
          .where((m) => m.estado == EstadoMesa.disponible)
          .length,
      mesasOcupadas: mesas.where((m) => m.estado == EstadoMesa.ocupada).length,
      mesasReservadas:
          mesas.where((m) => m.estado == EstadoMesa.reservada).length,
      mesasLimpieza:
          mesas.where((m) => m.estado == EstadoMesa.limpieza).length,
      totalMesas: mesas.length,
      reservasHoy: v.$2.size,
      pedidosActivos: v.$3.size,
    );
  });
}

/// combineLatest de 3 streams sin rxdart: emite apenas TODOS tienen su
/// primer valor y re-emite con los ÚLTIMOS valores de cada stream ante
/// cualquier cambio posterior (derivación de stats — Firestore emite el
/// snapshot inicial inmediato al escuchar, así que la primera emisión
/// llega con los 3). Los errores se reenvían al stream resultado.
Stream<(A, B, C)> _combineLatest3<A, B, C>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
) {
  late StreamController<(A, B, C)> controller;
  A? ultimoA;
  B? ultimoB;
  C? ultimoC;
  var cancelado = false;
  final subs = <StreamSubscription<dynamic>>[];

  void emitir() {
    if (cancelado) return;
    if (ultimoA != null && ultimoB != null && ultimoC != null) {
      controller.add((ultimoA as A, ultimoB as B, ultimoC as C));
    }
  }

  controller = StreamController<(A, B, C)>(
    // sync: la re-emisión entrega EN el evento del snapshot (no en una
    // microtask posterior) — paridad con `yield*` directo sobre
    // snapshots(): un read posterior a la escritura ya ve el valor nuevo.
    sync: true,
    onListen: () {
      subs.add(
        a.listen(
          (v) {
            ultimoA = v;
            emitir();
          },
          onError: controller.addError,
        ),
      );
      subs.add(
        b.listen(
          (v) {
            ultimoB = v;
            emitir();
          },
          onError: controller.addError,
        ),
      );
      subs.add(
        c.listen(
          (v) {
            ultimoC = v;
            emitir();
          },
          onError: controller.addError,
        ),
      );
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
