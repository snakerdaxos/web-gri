import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/reservas/mis_reservas_screen.dart';
import 'package:gri_cliente/features/reservas/reserva_controller.dart';
import 'package:gri_cliente/features/reservas/reservas_provider.dart';
import 'package:gri_cliente/models/reserva.dart';

import '../helpers/firebase_fakes.dart';

/// Cancelación (state machine + reversión condicional de mesa, paridad
/// Phase 5) y misReservasProvider (stream REALTIME) sobre fakes.

DateTime _slotDeManana([int hora = 19]) {
  final t = DateTime.now().add(const Duration(days: 1));
  return DateTime(t.year, t.month, t.day, hora);
}

Widget _wrap(FakeFirebaseFirestore db) => ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        firestoreProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(home: Scaffold(body: MisReservasScreen())),
    );

/// Doc directo (sin pasar por crearReserva) para casos específicos.
Future<void> _sembrarReserva(
  FakeFirebaseFirestore db, {
  required String id,
  required String fechaStr,
  required String estado,
  String usuarioId = 'test-uid',
  String mesaId = 'GRI-MESA-demo-001',
  int mesaNumero = 1,
  int hora = 19,
}) =>
    db.doc('reservas/$id').set({
      'restauranteId': 'demo',
      'mesaId': mesaId,
      'mesaNumero': mesaNumero,
      'usuarioId': usuarioId,
      'fecha': Timestamp.fromDate(DateTime.parse('$fechaStr 19:00:00')),
      'fechaStr': fechaStr,
      'hora': hora,
      'numPersonas': 4,
      'estado': estado,
    });

void main() {
  // ── Servicio: cancelación con reversión condicional ───────────────────
  group('cancelarReserva', () {
    test('cancela futura propia y revierte la mesa (estaba reservada)',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();
      final reserva = await crearReserva(db,
          uid: 'test-uid', restauranteId: 'demo', slot: slot, personas: 2);
      expect(
        (await db.doc('mesas/GRI-MESA-demo-001').get()).data()!['estado'],
        'reservada', // precondición: la tx de create la reservó
      );

      await cancelarReserva(db, uid: 'test-uid', reserva: reserva);

      expect(
        (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
        'cancelada',
      );
      // Reversión: reservada → disponible.
      expect(
        (await db.doc('mesas/GRI-MESA-demo-001').get()).data()!['estado'],
        'disponible',
      );
    });

    test('mesa OCUPADA no se revierte (queda ocupada)', () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();
      final reserva = await crearReserva(db,
          uid: 'test-uid', restauranteId: 'demo', slot: slot, personas: 2);

      // El cliente llegó y la mesa fue promovida a ocupada (RESV-05).
      await db.doc('mesas/GRI-MESA-demo-001').update({'estado': 'ocupada'});

      await cancelarReserva(db, uid: 'test-uid', reserva: reserva);

      expect(
        (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
        'cancelada',
      );
      expect(
        (await db.doc('mesas/GRI-MESA-demo-001').get()).data()!['estado'],
        'ocupada', // NO se toca (Pitfall 4 / paridad Phase 5)
      );
    });

    test('de otro usuario → existence hiding ("Reserva no encontrada")',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();
      final reserva = await crearReserva(db,
          uid: 'dueno', restauranteId: 'demo', slot: slot, personas: 2);

      await expectLater(
        cancelarReserva(db, uid: 'intruso', reserva: reserva),
        throwsA(isA<ReservaException>()
            .having((e) => e.message, 'message', 'Reserva no encontrada')),
      );
      // La reserva queda intacta.
      expect(
        (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
        'confirmada',
      );
    });

    test('reserva pasada → error controlado', () async {
      final db = await buildFakeFirestoreConSeed();
      await _sembrarReserva(db, id: 'r-pasada', fechaStr: '2020-01-01',
          estado: 'confirmada');
      final reserva = (await db.doc('reservas/r-pasada').get()).data()!;

      await expectLater(
        cancelarReserva(
          db,
          uid: 'test-uid',
          reserva: Reserva.fromDoc(await db.doc('reservas/r-pasada').get()),
        ),
        throwsA(isA<ReservaException>().having((e) => e.message, 'message',
            'No se puede cancelar una reserva pasada')),
      );
      expect(reserva['estado'], 'confirmada');
    });
  });

  // ── misReservasProvider: stream REALTIME ──────────────────────────────
  group('misReservasProvider (stream)', () {
    test('orden fecha DESC + join de restauranteNombre + refleja cancel',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Dos reservas propias en slots distintos (misma mesa: slots ≠).
      final temprana = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(18),
          personas: 2);
      final tardia = await crearReserva(db,
          uid: 'test-uid',
          restauranteId: 'demo',
          slot: _slotDeManana(20),
          personas: 4);

      final primeras =
          await container.read(misReservasProvider('test-uid').future);
      expect(primeras.map((r) => r.id).toList(),
          [tardia.id, temprana.id], reason: 'orderBy fecha DESC');
      // Join client-side del nombre (el doc no lo guarda).
      expect(primeras.first.restauranteNombre, 'Restaurante Demo GRI');
      // No filtra ajenas… pero solo pidió las suyas:
      final ajena = await crearReserva(db,
          uid: 'otro-uid', restauranteId: 'demo', slot: _slotDeManana(21),
          personas: 2);
      final trasAjena =
          await container.read(misReservasProvider('test-uid').future);
      expect(
          trasAjena.map((r) => r.id), isNot(contains(ajena.id)));

      // El stream refleja la cancelación SIN refetch (REALTIME).
      await cancelarReserva(db, uid: 'test-uid', reserva: tardia);
      final trasCancel =
          await container.read(misReservasProvider('test-uid').future);
      final cancelada =
          trasCancel.firstWhere((r) => r.id == tardia.id);
      expect(cancelada.estado, 'cancelada');
      expect(cancelada.mesaNumero, 1);
    });
  });

  // ── UI: MisReservasScreen sobre el stream ─────────────────────────────
  testWidgets('divide próximas (fecha >= hoy) y pasadas (fecha < hoy)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final ahora = DateTime.now();
    final hoy =
        '${ahora.year.toString().padLeft(4, '0')}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';
    await _sembrarReserva(db, id: 'r-futura', fechaStr: '2099-01-01', estado: 'confirmada');
    await _sembrarReserva(db, id: 'r-hoy', fechaStr: hoy, estado: 'confirmada', mesaNumero: 2);
    await _sembrarReserva(db, id: 'r-pasada', fechaStr: '2020-01-01', estado: 'cancelada', mesaNumero: 3);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Próximas'), findsOneWidget);
    expect(find.text('Pasadas'), findsOneWidget);
    expect(find.textContaining('2099-01-01'), findsOneWidget);
    expect(find.textContaining(hoy), findsOneWidget);
    expect(find.textContaining('2020-01-01'), findsOneWidget);
  });

  testWidgets(
      'cada reserva muestra restaurante (join), mesa, fecha, hora, personas y estado',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sembrarReserva(db, id: 'r1', fechaStr: '2099-01-01', estado: 'confirmada');
    await _sembrarReserva(db, id: 'r2', fechaStr: '2020-01-01', estado: 'cancelada', mesaNumero: 2);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Join del nombre desde restaurantes/demo.
    expect(find.text('Restaurante Demo GRI'), findsNWidgets(2));
    expect(find.textContaining('Mesa 1'), findsOneWidget);
    expect(find.textContaining('Mesa 2'), findsOneWidget);
    expect(find.textContaining('2099-01-01'), findsOneWidget);
    expect(find.textContaining('19:00'), findsNWidgets(2));
    expect(find.textContaining('4 personas'), findsNWidgets(2));

    // Chips de estado: confirmada verde / cancelada roja.
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);

    final confirmadaChip = tester.widget<Container>(
      find.ancestor(
        of: find.text('Confirmada'),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      (confirmadaChip.decoration as BoxDecoration).color,
      const Color(0xFFDFF7EB),
    );
  });

  testWidgets('Cancelar en futura confirmada: doc cancelada + mesa liberada',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final slot = _slotDeManana();
    final reserva = await crearReserva(db,
        uid: 'test-uid', restauranteId: 'demo', slot: slot, personas: 2);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Solo la futura confirmada tiene botón Cancelar.
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('¿Cancelar'), findsOneWidget);
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Persistió en Firestore: reserva cancelada y mesa revertida.
    expect(
      (await db.doc('reservas/${reserva.id}').get()).data()!['estado'],
      'cancelada',
    );
    expect(
      (await db.doc('mesas/GRI-MESA-demo-001').get()).data()!['estado'],
      'disponible',
    );
    expect(find.text('Reserva cancelada'), findsOneWidget);
  });
}
