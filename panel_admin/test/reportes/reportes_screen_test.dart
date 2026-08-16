import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/format.dart';
import 'package:gri_panel_admin/features/reportes/reportes_provider.dart';
import 'package:gri_panel_admin/features/reportes/reportes_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Tests de /reportes sobre Firestore (REPO-01/02, 10-06): fold EN CLIENTE
/// de pedidos SERVIDOS en el rango (fuera de rango y no-servidos NO
/// computan), top platos desde el snapshot de items (Σ cantidad, Σ venta)
/// ordenado por cantidad DESC, validación de rango client-side y estado
/// vacío.

Future<void> _pedido(
  FakeFirebaseFirestore db, {
  required String estado,
  required DateTime createdAt,
  required int total,
  List<Map<String, Object>> items = const [],
  String rid = 'demo',
}) {
  return db.collection('pedidos').add({
    'restauranteId': rid,
    'mesaId': 'GRI-MESA-$rid-002',
    'sesionId': 'GRI-MESA-$rid-002',
    'usuarioId': 'uid-ana',
    'clienteNombre': 'Ana Torres',
    'estado': estado,
    'items': items,
    'total': total,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  });
}

/// 2 servidos en rango + 1 servido FUERA + 1 enviado en rango + 1 servido
/// en rango de OTRO tenant (NO computa).
Future<void> _seed(FakeFirebaseFirestore db) async {
  await _pedido(db,
      estado: 'servido',
      createdAt: DateTime(2026, 8, 12, 13, 0),
      total: 57000,
      items: [
        {'productoId': 'p1', 'nombre': 'Pizza Hawaiana', 'precio': 16000, 'cantidad': 2},
        {'productoId': 'p2', 'nombre': 'Limonada', 'precio': 5000, 'cantidad': 5},
      ]);
  await _pedido(db,
      estado: 'servido',
      createdAt: DateTime(2026, 8, 15, 20, 30),
      total: 16000,
      items: [
        {'productoId': 'p1', 'nombre': 'Pizza Hawaiana', 'precio': 16000, 'cantidad': 1},
      ]);
  await _pedido(db,
      estado: 'servido',
      createdAt: DateTime(2026, 8, 1, 13, 0),
      total: 99000,
      items: [
        {'productoId': 'p3', 'nombre': 'Bandeja paisa', 'precio': 33000, 'cantidad': 3},
      ]);
  await _pedido(db,
      estado: 'enviado',
      createdAt: DateTime(2026, 8, 14, 12, 0),
      total: 40000,
      items: [
        {'productoId': 'p1', 'nombre': 'Pizza Hawaiana', 'precio': 20000, 'cantidad': 2},
      ]);
  await _pedido(db,
      estado: 'servido',
      createdAt: DateTime(2026, 8, 13, 19, 0),
      total: 88000,
      rid: 'norte',
      items: [
        {'productoId': 'p4', 'nombre': 'Salmón', 'precio': 44000, 'cantidad': 2},
      ]);
}

Widget _screen(FakeFirebaseFirestore db) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: ReportesScreen())),
  );
}

void main() {
  final desde = DateTime(2026, 8, 10);
  final hasta = DateTime(2026, 8, 20, 23, 59, 59, 999);

  test(
    'fold: solo servidos-en-rango computan; top platos por cantidad DESC',
    () async {
      final db = await buildFakeFirestoreConSeed();
      await _seed(db);

      final container = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith(
          (ref) async => (role: 'admin_restaurante', rid: 'demo'),
        ),
      ]);
      addTearDown(container.dispose);

      final reporte =
          await container.read(reporteProvider(desde, hasta).future);

      // 2 servidos en rango (57k + 16k); fuera-de-rango, enviado y norte
      // quedan afuera.
      expect(reporte.numeroPedidos, 2);
      expect(reporte.totalVentas, 73000);

      // Top platos desde snapshots, orden por cantidad DESC: Limonada
      // 5× (25000) primero; Pizza 3× (2+1 = 48000) después.
      expect(reporte.topPlatos, hasLength(2));
      expect(reporte.topPlatos[0].nombre, 'Limonada');
      expect(reporte.topPlatos[0].cantidad, 5);
      expect(reporte.topPlatos[0].venta, 25000);
      expect(reporte.topPlatos[1].nombre, 'Pizza Hawaiana');
      expect(reporte.topPlatos[1].cantidad, 3);
      expect(reporte.topPlatos[1].venta, 48000);
    },
  );

  test('validarRango: invertido → mensaje; válido/partial → null', () {
    expect(
      ReportesScreenState.validarRango(
          DateTime(2026, 8, 20), DateTime(2026, 8, 10)),
      'La fecha inicial no puede ser mayor que la final',
    );
    expect(
      ReportesScreenState.validarRango(
          DateTime(2026, 8, 10), DateTime(2026, 8, 20)),
      isNull,
    );
    expect(ReportesScreenState.validarRango(DateTime(2026, 8, 20), null), isNull);
    expect(ReportesScreenState.validarRango(null, DateTime(2026, 8, 10)), isNull);
  });

  testWidgets('(a) Consultar con rango → cards total/pedidos + top platos', (
    tester,
  ) async {
    final db = await buildFakeFirestoreConSeed();
    await _seed(db);

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    // Rango fijado vía el setter @visibleForTesting (alternativa al manejo
    // frágil de los pickers en widget tests).
    final state = tester.state<ReportesScreenState>(
      find.byType(ReportesScreen),
    );
    state.debugSetFechas(DateTime(2026, 8, 10), DateTime(2026, 8, 20));
    await tester.pump();

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    // Cards resumen: total (2 servidos en rango) y count — formatCOP.
    expect(find.text('Total vendido'), findsOneWidget);
    expect(find.text(formatCOP(73000)), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    // '2' vive en DOS lugares: el value del card Pedidos y el número del
    // avatar del 2º plato del top.
    final avatars = find.byType(CircleAvatar);
    expect(avatars, findsNWidgets(2));
    expect(find.descendant(of: avatars, matching: find.text('2')), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));

    // Top platos: ×5 Limonada y ×3 Pizza (orden cantidad DESC).
    expect(find.text('Platos más vendidos'), findsOneWidget);
    expect(find.text('Limonada'), findsOneWidget);
    expect(find.text('Pizza Hawaiana'), findsOneWidget);
    expect(find.text('×5'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    // Ventas por plato desde snapshots.
    expect(find.text(formatCOP(25000)), findsOneWidget);
    expect(find.text(formatCOP(48000)), findsOneWidget);

    // Orden por cantidad DESC: Limonada(5) encima de Pizza(3).
    expect(
      tester.getTopLeft(find.text('Limonada')).dy
          < tester.getTopLeft(find.text('Pizza Hawaiana')).dy,
      isTrue,
    );
  });

  testWidgets(
    '(b) desde > hasta → SnackBar visible y sin resultados',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _seed(db);

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(db));
      await tester.pumpAndSettle();

      final state = tester.state<ReportesScreenState>(
        find.byType(ReportesScreen),
      );
      state.debugSetFechas(DateTime(2026, 8, 20), DateTime(2026, 8, 10));
      await tester.pump();

      await tester.tap(find.text('Consultar'));
      await tester.pump();

      expect(
        find.text('La fecha inicial no puede ser mayor que la final'),
        findsOneWidget,
      );
      expect(find.text('Total vendido'), findsNothing,
          reason: 'no debe consultarse nada');
    },
  );

  testWidgets('(c) rango sin servidos → "Sin ventas en el rango"', (
    tester,
  ) async {
    final db = await buildFakeFirestoreConSeed();
    await _seed(db);

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    final state = tester.state<ReportesScreenState>(
      find.byType(ReportesScreen),
    );
    // Rango donde solo hay un servido FUERA (agosto 1) — nada computa.
    state.debugSetFechas(DateTime(2026, 8, 2), DateTime(2026, 8, 8));
    await tester.pump();

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin ventas en el rango'), findsOneWidget);
  });
}
