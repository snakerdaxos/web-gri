import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/reservas/reservas_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Tests de /reservas sobre Firestore (RESV-05, 10-06): stream EN VIVO de
/// las reservas de HOY (ventana TZ local — horas fijas 12:00/14:00 para no
/// cruzar medianoche, lección 10-05), 'Marcar ocupada' = transición de la
/// MESA reservada→ocupada, 'No-show' = reserva cancelada, y aislamiento
/// tenant (otro restaurante y ayer NO aparecen).

Future<void> _reserva(
  FakeFirebaseFirestore db, {
  required String rid,
  required String mesaId,
  required DateTime fecha,
  required int numPersonas,
  required String estado,
}) {
  final dia =
      '${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';
  return db
      .doc('reservas/${mesaId}_${dia}_${fecha.hour.toString().padLeft(2, '0')}')
      .set({
    'restauranteId': rid,
    'mesaId': mesaId,
    'fecha': Timestamp.fromDate(fecha),
    'numPersonas': numPersonas,
    'estado': estado,
    'usuarioId': 'uid-ana',
  });
}

/// Reservas de HOY (12:00 confirmada mesa 2, 14:00 pendiente mesa 3) +
/// ruido que NO debe aparecer (ayer + otro tenant).
Future<void> _seedHoy(FakeFirebaseFirestore db) async {
  final hoy = DateTime.now();
  final mediodia = DateTime(hoy.year, hoy.month, hoy.day, 12, 0);
  final tarde = DateTime(hoy.year, hoy.month, hoy.day, 14, 0);
  final ayer = DateTime(hoy.year, hoy.month, hoy.day, 12, 0)
      .subtract(const Duration(days: 1));

  // Mesa 2 reservada (la transición reservada→ocupada es válida).
  await db.doc('mesas/GRI-MESA-demo-002').update({'estado': 'reservada'});

  await _reserva(db,
      rid: 'demo',
      mesaId: 'GRI-MESA-demo-002',
      fecha: mediodia,
      numPersonas: 4,
      estado: 'confirmada');
  await _reserva(db,
      rid: 'demo',
      mesaId: 'GRI-MESA-demo-003',
      fecha: tarde,
      numPersonas: 2,
      estado: 'pendiente');
  await _reserva(db,
      rid: 'demo',
      mesaId: 'GRI-MESA-demo-001',
      fecha: ayer,
      numPersonas: 2,
      estado: 'confirmada');
  await _reserva(db,
      rid: 'norte',
      mesaId: 'GRI-MESA-norte-001',
      fecha: mediodia,
      numPersonas: 6,
      estado: 'confirmada');
}

Widget _screen(FakeFirebaseFirestore db) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: ReservasScreen())),
  );
}

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_screen(db));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '(a) stream de HOY: 2 reservas (confirmada+pendiente), sin ayer ni otro tenant',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      await _pump(tester, db);

      // Cards del día (horas fijas HH:mm del Timestamp).
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('Mesa 2'), findsOneWidget);
      expect(find.text('Mesa 3'), findsOneWidget);
      expect(find.text('4 personas'), findsOneWidget);
      expect(find.text('2 personas'), findsOneWidget);

      // La de ayer (Mesa 1) y la del norte NO aparecen.
      expect(find.text('Mesa 1'), findsNothing);

      // Chips de estado.
      expect(find.text('confirmada'), findsOneWidget);
      expect(find.text('pendiente'), findsOneWidget);

      // 'Marcar ocupada' SOLO en la confirmada; 'No-show' en ambas vivas.
      expect(find.text('Marcar ocupada'), findsOneWidget);
      expect(find.text('No-show'), findsNWidgets(2));
    },
  );

  testWidgets(
    '(b) Marcar ocupada → mesa 2 pasa a ocupada en Firestore + SnackBar',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      await _pump(tester, db);

      await tester.tap(find.text('Marcar ocupada'));
      await tester.pumpAndSettle();

      final mesa = await db.doc('mesas/GRI-MESA-demo-002').get();
      expect(mesa.data()!['estado'], 'ocupada');
      expect(find.text('Mesa 2 marcada ocupada'), findsOneWidget);
    },
  );

  testWidgets(
    '(c) No-show → reserva cancelada (doc + chip tachado en vivo)',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      await _pump(tester, db);

      // El No-show de la pendiente (14:00, mesa 3).
      await tester.tap(find.text('No-show').last);
      await tester.pumpAndSettle();

      // Doc con estado cancelada.
      final snap = await db
          .collection('reservas')
          .where('mesaId', isEqualTo: 'GRI-MESA-demo-003')
          .get();
      expect(snap.size, 1);
      expect(snap.docs.first.data()['estado'], 'cancelada');

      // El stream re-emite: chip cancelada TACHADO y sin acciones vivas
      // en ESA card (la confirmada conserva sus 2 acciones).
      expect(find.text('Reserva cancelada'), findsOneWidget);
      final chip = tester.widget<Text>(find.text('cancelada'));
      expect(chip.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('No-show'), findsOneWidget);
      expect(find.text('Marcar ocupada'), findsOneWidget);
    },
  );

  testWidgets(
    '(d) mesa ya ocupada (carrera) → "La mesa ya cambió de estado"',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      // Otro staff movió la mesa 2 primero.
      await db.doc('mesas/GRI-MESA-demo-002').update({'estado': 'ocupada'});
      await _pump(tester, db);

      await tester.tap(find.text('Marcar ocupada'));
      await tester.pumpAndSettle();

      expect(find.text('La mesa ya cambió de estado'), findsOneWidget);
    },
  );

  testWidgets('(e) día sin reservas → estado vacío', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _pump(tester, db);

    expect(find.text('Sin reservas para hoy'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });
}
