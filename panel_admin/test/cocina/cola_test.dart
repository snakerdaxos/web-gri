import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/gri_icons.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/format.dart';
import 'package:gri_panel_admin/core/state_machines.dart';
import 'package:gri_panel_admin/features/cocina/cocina_screen.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';

import '../helpers/firebase_fakes.dart';

/// Suite 10-05 Task 3: cola de cocina EN VIVO (onSnapshot — sin WS ni
/// polling), filtro de estados activos ordenados por createdAt ASC, matriz
/// rol×transición en [avanzarPedidoStaff] (las rules re-validan) y el
/// aviso de cuenta en vivo (sesiones activas con cuentaSolicitada).

/// Pedido (doc shape de app_cliente 10-04) — retorna el doc ID creado.
Future<String> _pedido(
  FakeFirebaseFirestore db, {
  required String estado,
  required DateTime createdAt,
  String mesaId = 'GRI-MESA-demo-003',
  int total = 63000,
}) {
  return db.collection('pedidos').add({
    'restauranteId': 'demo',
    'mesaId': mesaId,
    'sesionId': mesaId,
    'usuarioId': 'uid-cli',
    'clienteNombre': 'Carlos Pérez',
    'estado': estado,
    'items': [
      {'productoId': 'p1', 'nombre': 'Pizza Hawaiana', 'precio': 25000, 'cantidad': 2},
      {'productoId': 'p2', 'nombre': 'Limonada', 'precio': 6500, 'cantidad': 2},
    ],
    'total': total,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  }).then((r) => r.id);
}

/// Sesión de mesa (doc shape 10-04: sesiones/{mesaId}).
Future<void> _sesion(
  FakeFirebaseFirestore db, {
  required String mesaId,
  required String estado,
  bool cuentaSolicitada = false,
}) {
  return db.doc('sesiones/$mesaId').set({
    'restauranteId': 'demo',
    'mesaId': mesaId,
    'usuarioId': 'uid-cli',
    'estado': estado,
    'cuentaSolicitada': cuentaSolicitada,
    if (cuentaSolicitada) 'cuentaPedidaAt': FieldValue.serverTimestamp(),
    'inicioAt': FieldValue.serverTimestamp(),
  });
}

/// Container de unidad con fakes + claims (retiene los autoDispose).
ProviderContainer _container(
  FakeFirebaseFirestore db, {
  String role = 'cocina',
}) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    claimsProvider.overrideWith((ref) async => (role: role, rid: 'demo')),
  ]);
  addTearDown(container.dispose);
  return container;
}

Widget _cocina(FakeFirebaseFirestore db, {String role = 'cocina'}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith((ref) async => (role: role, rid: 'demo')),
    ],
    child: const MaterialApp(home: CocinaScreen()),
  );
}

void main() {
  testWidgets('(a) renderiza cards con mesa, items ×cantidad y total COP',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final t = DateTime(2026, 8, 14, 13, 5);
    await _pedido(db, estado: 'enviado', createdAt: t, total: 63000);
    await _pedido(
      db,
      estado: 'en_preparacion',
      createdAt: t.add(const Duration(minutes: 2)),
      mesaId: 'GRI-MESA-demo-005',
      total: 76000,
    );

    // Viewport alto: el ListView es lazy y la 2ª card queda fuera del
    // viewport default (800x600) sin esto.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_cocina(db));
    await tester.pumpAndSettle();

    // MesaNumero derivado del QR del doc (003 → 3).
    expect(find.text('Mesa 3'), findsOneWidget);
    expect(find.text('Mesa 5'), findsOneWidget);
    // Items "nombre ×cantidad" en ambos cards + subtotales int COP.
    expect(find.textContaining('Pizza Hawaiana ×2'), findsNWidgets(2));
    expect(find.textContaining('Limonada ×2'), findsNWidgets(2));
    expect(find.text(formatCOP(50000)), findsNWidgets(2));
    expect(find.text(formatCOP(63000)), findsOneWidget);
    expect(find.text(formatCOP(76000)), findsOneWidget);
    // Chips de estado + usuario + hora.
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('En preparación'), findsOneWidget);
    expect(find.textContaining('Carlos Pérez'), findsNWidgets(2));
    expect(find.text('13:05'), findsOneWidget);
  });

  test(
      '(b) la cola SOLO incluye [enviado, aceptado, en_preparacion] ordenados por createdAt ASC',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final t = DateTime(2026, 8, 14, 13, 5);
    // Se crean DESORDENADOS: el en_preparacion es el más viejo.
    final idPrep =
        await _pedido(db, estado: 'en_preparacion', createdAt: t, total: 1000);
    final idServido = await _pedido(
        db, estado: 'servido', createdAt: t.add(const Duration(minutes: 1)));
    final idAceptado = await _pedido(
        db,
        estado: 'aceptado',
        createdAt: t.add(const Duration(minutes: 2)),
        total: 2000);
    final idRechazado = await _pedido(
        db,
        estado: 'rechazado',
        createdAt: t.add(const Duration(minutes: 3)));
    final idEnviado = await _pedido(
        db,
        estado: 'enviado',
        createdAt: t.add(const Duration(minutes: 4)),
        total: 3000);
    // Otro tenant: invisible.
    await db.collection('pedidos').add({
      'restauranteId': 'norte',
      'mesaId': 'GRI-MESA-norte-001',
      'sesionId': 'GRI-MESA-norte-001',
      'usuarioId': 'uid-x',
      'clienteNombre': 'Ajeno',
      'estado': 'enviado',
      'items': const [],
      'total': 1,
      'createdAt': Timestamp.fromDate(t),
      'updatedAt': Timestamp.fromDate(t),
    });

    final container = _container(db);
    container.listen(pedidosStaffProvider, (_, _) {});
    final cola = await container.read(pedidosStaffProvider.future);

    // FIFO por createdAt ASC — servido/rechazado/ajeno excluidos.
    expect(cola.map((p) => p.id), [idPrep, idAceptado, idEnviado],
        reason: 'en_preparacion(13:05) → aceptado(+2) → enviado(+4)');
    expect(cola.any((p) => p.id == idServido || p.id == idRechazado), isFalse);
  });

  test('(c) un servido desaparece del stream EN VIVO (sin rebuild manual)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final t = DateTime(2026, 8, 14, 13, 5);
    final id = await _pedido(db, estado: 'en_preparacion', createdAt: t);

    final container = _container(db);
    container.listen(pedidosStaffProvider, (_, _) {});
    final antes = await container.read(pedidosStaffProvider.future);
    expect(antes.map((p) => p.id), [id]);

    // La mutación llega por Firestore — nadie invalida el provider.
    await db.doc('pedidos/$id').update({'estado': 'servido'});

    final despues = await container.read(pedidosStaffProvider.future);
    expect(despues, isEmpty, reason: 'servido no es parte de la cola activa');
  });

  testWidgets('(d) matriz de botones: cocina ve Aceptar/Rechazar; mesero no',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final t = DateTime(2026, 8, 14, 13, 5);
    await _pedido(db, estado: 'enviado', createdAt: t);
    await _pedido(
      db,
      estado: 'en_preparacion',
      createdAt: t.add(const Duration(minutes: 1)),
      mesaId: 'GRI-MESA-demo-005',
    );

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_cocina(db, role: 'cocina'));
    await tester.pumpAndSettle();

    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Servido'), findsOneWidget); // label cocina
  });

  testWidgets('(d2) mesero: sin Aceptar/Rechazar; solo Marcar servido',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final t = DateTime(2026, 8, 14, 13, 5);
    await _pedido(db, estado: 'enviado', createdAt: t);
    await _pedido(
      db,
      estado: 'en_preparacion',
      createdAt: t.add(const Duration(minutes: 1)),
      mesaId: 'GRI-MESA-demo-005',
    );

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_cocina(db, role: 'mesero'));
    await tester.pumpAndSettle();

    // Matriz lado mesero: no acepta ni rechaza.
    expect(find.text('Aceptar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
    // Y sobre en_preparación SOLO ve "Marcar servido" (label mesero).
    expect(find.text('Marcar servido'), findsOneWidget);
    expect(find.text('Servido'), findsNothing);
  });

  test('(e1) avanzar enviado→aceptado con rol cocina: OK y update exacto',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id =
        await _pedido(db, estado: 'enviado', createdAt: DateTime(2026, 8, 14));
    final pedido =
        PedidoStaff.fromDoc(await db.doc('pedidos/$id').get());

    await avanzarPedidoStaff(
      db,
      rol: 'cocina',
      pedido: pedido,
      destino: EstadoPedido.aceptado,
    );

    final data = (await db.doc('pedidos/$id').get()).data()!;
    expect(data['estado'], 'aceptado');
    expect(data['updatedAt'], isNotNull, reason: 'el update estampa updatedAt');
    expect(data['mesaId'], 'GRI-MESA-demo-003', reason: 'el update no toca el resto');
  });

  test('(e2) salto enviado→servido lanza TransicionInvalidaException y NO escribe',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id =
        await _pedido(db, estado: 'enviado', createdAt: DateTime(2026, 8, 14));
    final pedido =
        PedidoStaff.fromDoc(await db.doc('pedidos/$id').get());

    await expectLater(
      avanzarPedidoStaff(
        db,
        rol: 'cocina',
        pedido: pedido,
        destino: EstadoPedido.servido,
      ),
      throwsA(isA<TransicionInvalidaException>()
          .having((e) => e.maquina, 'maquina', 'pedido')
          .having((e) => e.actual, 'actual', 'enviado')
          .having((e) => e.nueva, 'nueva', 'servido')),
    );

    expect((await db.doc('pedidos/$id').get()).data()!['estado'], 'enviado');
  });

  test('(e3) mesero NO puede aceptar (enviado→aceptado) — matriz rol',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id =
        await _pedido(db, estado: 'enviado', createdAt: DateTime(2026, 8, 14));
    final pedido =
        PedidoStaff.fromDoc(await db.doc('pedidos/$id').get());

    await expectLater(
      avanzarPedidoStaff(
        db,
        rol: 'mesero',
        pedido: pedido,
        destino: EstadoPedido.aceptado,
      ),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', 'Tu rol no puede hacer esta acción')),
    );

    // El doc quedó intacto.
    expect((await db.doc('pedidos/$id').get()).data()!['estado'], 'enviado');
  });

  test('(e4) mesero SÍ puede servir (en_preparacion→servido) — matriz rol',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _pedido(
        db, estado: 'en_preparacion', createdAt: DateTime(2026, 8, 14));
    final pedido =
        PedidoStaff.fromDoc(await db.doc('pedidos/$id').get());

    await avanzarPedidoStaff(
      db,
      rol: 'mesero',
      pedido: pedido,
      destino: EstadoPedido.servido,
    );

    expect((await db.doc('pedidos/$id').get()).data()!['estado'], 'servido');
  });

  testWidgets('(f) aviso de cuenta en vivo: activa+solicitada aparece; cerrada desaparece',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-001', estado: 'activa', cuentaSolicitada: true);
    // Cerrada con flag: NO avisa.
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-002',
        estado: 'cerrada',
        cuentaSolicitada: true);
    // Activa sin flag: NO avisa.
    await _sesion(db, mesaId: 'GRI-MESA-demo-003', estado: 'activa');

    await tester.pumpWidget(_cocina(db));
    await tester.pumpAndSettle();

    // Solo la sesión activa con cuentaSolicitada.
    expect(find.text('1 mesa pidió la cuenta'), findsOneWidget);

    // El mesero entrega la cuenta → la sesión se cierra → el aviso
    // desaparece EN VIVO (nadie refresca nada).
    await db.doc('sesiones/GRI-MESA-demo-001').update({
      'estado': 'cerrada',
      'cerradaAt': FieldValue.serverTimestamp(),
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('pidió la cuenta'), findsNothing);
  });

  testWidgets('(g) cola vacía → estado vacío', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_cocina(db));
    await tester.pumpAndSettle();

    // 11-21: el emoji de fiesta salió del literal y es ahora un Icon; el
    // finder cambia, la aserción NO (sigue afirmando el estado vacío).
    expect(find.text('No hay pedidos activos'), findsOneWidget);
    expect(find.byIcon(GriIcons.todoAlDia), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });
}
