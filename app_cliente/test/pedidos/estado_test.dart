import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

import '../helpers/firebase_fakes.dart';

SesionMesa _sesion() => SesionMesa(
      id: 'GRI-MESA-demo-003',
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-003',
      usuarioId: 'test-uid',
      estado: 'activa',
      cuentaSolicitada: false,
      inicioAt: DateTime(2026, 8, 14, 12, 30),
      restauranteNombre: 'Restaurante Demo GRI',
      mesaNumero: 3,
    );

Pedido _p(int n, String estado) => Pedido(
      id: 'pedido$n',
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-003',
      sesionId: 'GRI-MESA-demo-003',
      usuarioId: 'test-uid',
      estado: estado,
      total: 57000,
      createdAt: DateTime(2026, 8, 14, 13, n),
      items: const [
        PedidoItem(
            productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 2),
        PedidoItem(
            productoId: 'p4', nombre: 'Jugo', precio: 7000, cantidad: 1),
      ],
    );

Widget _wrap({required List<Pedido> pedidos}) {
  return ProviderScope(
    overrides: [
      sesionActualProvider.overrideWith((ref) => Stream.value(_sesion())),
      pedidosSessionProvider.overrideWith((ref) => Stream.value(pedidos)),
    ],
    child: const MaterialApp(home: PedidoEstadoScreen()),
  );
}

/// Espera activa hasta que [cond] sea true (los snapshots de los fakes
/// emiten en microtareas — polling breve en vez de tiempos fijos).
Future<void> _hasta(bool Function() cond) async {
  final fin = DateTime.now().add(const Duration(seconds: 5));
  while (!cond()) {
    if (DateTime.now().isAfter(fin)) {
      fail('timeout esperando condición del stream');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  // ── Unidad: realtime MIGRA-05 (snapshots, sin polling ni WS) ───────────

  test(
      'REALTIME: pedidosSessionProvider emite nuevo pedido y cambio a servido sin refetch',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: 'GRI-MESA-demo-001');

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
    ]);
    addTearDown(container.dispose);

    final emisiones = <List<Pedido>>[];
    container.listen(
      pedidosSessionProvider,
      (_, next) => next.whenData((pedidos) => emisiones.add(pedidos)),
    );

    await _hasta(() => emisiones.isNotEmpty);
    expect(emisiones.last, isEmpty, reason: 'sin pedidos aún');

    // Otro "writer" (el cliente) crea el pedido...
    final id = await crearPedido(db,
        uid: 'test-uid',
        mesaCodigo: 'GRI-MESA-demo-001',
        items: const [
          PedidoItem(
              productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 1),
        ]);
    await _hasta(() => emisiones.last.isNotEmpty);
    expect(emisiones.last.first.estado, 'enviado');
    expect(emisiones.last.first.sesionId, 'GRI-MESA-demo-001');

    // ...y cocina lo avanza a servido — el stream lo refleja SOLO.
    await db.doc('pedidos/$id').update({
      'estado': 'servido',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _hasta(() => emisiones.last.first.estado == 'servido');
    expect(emisiones.last.first.estadoLabel, 'Servido');
  });

  // ── Widgets: cards de estado ────────────────────────────────────────────

  testWidgets('cards con chips de estado, items y total COP', (tester) async {
    await tester.pumpWidget(_wrap(pedidos: [_p(1, 'enviado'), _p(2, 'servido')]));
    await tester.pumpAndSettle();

    expect(find.text('Mis pedidos · Mesa 3'), findsOneWidget);
    expect(find.text('Se actualiza automáticamente'), findsOneWidget);

    // Chips de estado por pedido.
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('Servido'), findsOneWidget);
    // Items y total en cada card.
    expect(find.text('Pasta ×2'), findsNWidgets(2));
    // 11-32: 57.000 aparece CUATRO veces y cada una dice algo distinto.
    // Antes de este plan eran dos (los importes de las dos tarjetas) y el
    // comensal no tenia ninguna suma en pantalla. Ahora se suman el "Total a
    // pagar" (solo el pedido SERVIDO) y la linea de lo que sigue en cocina
    // (solo el pedido ENVIADO). Que los cuatro numeros coincidan es una
    // casualidad de este fixture: los dos pedidos valen lo mismo.
    expect(find.textContaining('57.000'), findsNWidgets(4));
    // Lo que de verdad importa: el total NO son los dos pedidos sumados.
    expect(find.textContaining('114.000'), findsNothing,
        reason: 'el pedido enviado no se cobra hasta que se sirva');
  });

  testWidgets('los 5 estados renderizan chips con labels y colores distintos',
      (tester) async {
    await tester.pumpWidget(_wrap(pedidos: [
      _p(1, 'enviado'),
      _p(2, 'aceptado'),
      _p(3, 'en_preparacion'),
      _p(4, 'servido'),
      _p(5, 'rechazado'),
    ]));
    await tester.pumpAndSettle();

    const esperados = {
      'Enviado': Color(0xFF2563EB),
      'Aceptado': Color(0xFFD97706),
      'En preparación': Color(0xFF7C3AED),
      'Servido': Color(0xFF168A52),
      'Rechazado': Color(0xFFC83C2E),
    };
    for (final entry in esperados.entries) {
      // ListView lazy: los cards fuera del viewport no se construyen.
      await tester.scrollUntilVisible(
        find.text(entry.key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      final chip = tester.widget<Text>(find.text(entry.key));
      expect(chip.style?.color, entry.value, reason: entry.key);
    }
  });

  testWidgets('lista vacía → mensaje + CTA al menú', (tester) async {
    await tester.pumpWidget(_wrap(pedidos: const []));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay pedidos en esta sesión'), findsOneWidget);
    expect(find.text('Ver el menú'), findsOneWidget);
    // Con sesión activa y sin cuenta pedida, el botón sigue visible.
    expect(find.text('Pedir la cuenta'), findsOneWidget);
  });
}
