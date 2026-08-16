import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/clientes/clientes_provider.dart';
import 'package:gri_panel_admin/features/clientes/clientes_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Tests de clientes DERIVADOS de pedidos (ADMN-03, 10-06): fold distinct
/// por usuarioId (con conteos/totales/último), aislamiento tenant (pedidos
/// de otro restaurante NO cuentan — sin leer usuarios/), tabla con
/// formatCOP e historial por family.

Future<void> _pedido(
  FakeFirebaseFirestore db, {
  required String rid,
  required String uid,
  required String nombre,
  required int total,
  required DateTime createdAt,
  String estado = 'pagado',
  List<Map<String, Object>> items = const [],
}) {
  return db.collection('pedidos').add({
    'restauranteId': rid,
    'mesaId': 'GRI-MESA-$rid-002',
    'sesionId': 'GRI-MESA-$rid-002',
    'usuarioId': uid,
    'clienteNombre': nombre,
    'estado': estado,
    'items': items,
    'total': total,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  });
}

/// 3 pedidos de 2 usuarios en demo (Ana×2 + Luis×1) + 1 de Ana en norte
/// (NO cuenta) + 1 sin usuarioId (ignorado).
Future<void> _seedPedidos(FakeFirebaseFirestore db) async {
  await _pedido(db,
      rid: 'demo',
      uid: 'uid-ana',
      nombre: 'Ana Torres',
      total: 32000,
      createdAt: DateTime(2026, 8, 14, 20, 15),
      items: [
        {'productoId': 'p1', 'nombre': 'Pizza Hawaiana', 'precio': 16000, 'cantidad': 2},
      ]);
  await _pedido(db,
      rid: 'demo',
      uid: 'uid-ana',
      nombre: 'Ana Torres',
      total: 27500,
      createdAt: DateTime(2026, 8, 12, 13, 0));
  await _pedido(db,
      rid: 'demo',
      uid: 'uid-luis',
      nombre: 'Luis Gómez',
      total: 12000,
      createdAt: DateTime(2026, 8, 13, 19, 30));
  await _pedido(db,
      rid: 'norte',
      uid: 'uid-ana',
      nombre: 'Ana Torres',
      total: 99000,
      createdAt: DateTime(2026, 8, 15, 21, 0));
  await _pedido(db,
      rid: 'demo',
      uid: '',
      nombre: 'Sin usuario',
      total: 5000,
      createdAt: DateTime(2026, 8, 15, 22, 0));
}

Widget _screen(FakeFirebaseFirestore db) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: ClientesScreen())),
  );
}

void main() {
  test(
    'fold: 2 resúmenes desde 3 pedidos de demo — conteos/totales/últimos correctos',
    () async {
      final db = await buildFakeFirestoreConSeed();
      await _seedPedidos(db);

      final container = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith(
          (ref) async => (role: 'admin_restaurante', rid: 'demo'),
        ),
      ]);
      addTearDown(container.dispose);

      final clientes = await container.read(clientesProvider.future);
      expect(clientes, hasLength(2), reason: '2 usuarios con pedidos en demo');

      // Orden DESC por último pedido: Ana (14/08) antes que Luis (13/08).
      final ana = clientes[0];
      expect(ana.usuarioId, 'uid-ana');
      expect(ana.clienteNombre, 'Ana Torres');
      expect(ana.nPedidos, 2);
      expect(ana.totalConsumo, 59500); // 32000 + 27500 (norte NO cuenta)
      expect(ana.ultimoPedido, DateTime(2026, 8, 14, 20, 15));

      final luis = clientes[1];
      expect(luis.usuarioId, 'uid-luis');
      expect(luis.nPedidos, 1);
      expect(luis.totalConsumo, 12000);
    },
  );

  testWidgets('(a) tabla renderiza nombres, total COP y conteos', (
    tester,
  ) async {
    final db = await buildFakeFirestoreConSeed();
    await _seedPedidos(db);

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Luis Gómez'), findsOneWidget);

    // formatCOP: 59500 → "$ 59.500" (grouping es_CO).
    expect(find.textContaining('59.500'), findsOneWidget);
    expect(find.textContaining('12.000'), findsOneWidget);

    // Conteos de pedidos por cliente.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Fecha del último pedido (dd/MM/yyyy).
    expect(find.text('14/08/2026'), findsOneWidget);
  });

  testWidgets('(b) tap en fila → historial con sus pedidos DESC', (
    tester,
  ) async {
    final db = await buildFakeFirestoreConSeed();
    await _seedPedidos(db);

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ana Torres'));
    await tester.pumpAndSettle();

    // Historial = SOLO los 2 pedidos de Ana en demo (el del norte no).
    expect(find.text('Historial de Ana Torres'), findsOneWidget);
    expect(find.text('Mesa 2'), findsNWidgets(2));
    expect(find.textContaining('32.000'), findsOneWidget);
    expect(find.textContaining('27.500'), findsOneWidget);
    expect(find.text('2× Pizza Hawaiana'), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Historial de Ana Torres'), findsNothing);
  });

  testWidgets('(c) sin pedidos → empty state', (tester) async {
    final db = await buildFakeFirestoreConSeed();

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay clientes con pedidos'), findsOneWidget);
    expect(find.text('Ana Torres'), findsNothing);
  });
}
