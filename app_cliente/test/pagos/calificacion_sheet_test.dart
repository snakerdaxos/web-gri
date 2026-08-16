import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pagos/calificacion_sheet.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido_item.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';
const _items = [
  PedidoItem(productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 2),
];

/// Siembra un pedido en [estado] con la sesión en [sesionEstado] y lo
/// retorna su docId.
Future<String> _sembrarPedido(
  dynamic db, {
  String estado = 'servido',
  String sesionEstado = 'cerrada',
  String uid = 'test-uid',
}) async {
  await abrirSesion(db, uid: uid, codigoQR: _mesa);
  final id = await crearPedido(db, uid: uid, mesaCodigo: _mesa, items: _items);
  await db.doc('pedidos/$id').update({'estado': estado});
  if (sesionEstado != 'activa') {
    await db.doc('sesiones/$_mesa').update({
      'estado': sesionEstado,
      'cerradaAt': FieldValue.serverTimestamp(),
    });
  }
  return id;
}

void main() {
  // ── Unidad: la tx de calificar (agregado atómico) ───────────────────────

  test(
      'calificar pedido servido con sesión cerrada → calificaciones 1:1 + recompute atómico',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db);

    // 0,0 × 0 → primera: 5.
    await calificar(db, uid: 'test-uid', pedidoId: id, estrellas: 5);

    final calif = await db.doc('calificaciones/$id').get();
    expect(calif.exists, isTrue, reason: 'doc ID = pedidoId (1:1)');
    expect(calif.data()!['estrellas'], 5);
    expect(calif.data()!['restauranteId'], 'demo');
    expect(calif.data()!['usuarioId'], 'test-uid');
    expect(calif.data()!['comentario'], '');

    final rest = await db.doc('restaurantes/demo').get();
    expect(rest.data()!['califCount'], 1);
    expect((rest.data()!['califProm'] as num), 5.0);
  });

  test('segunda calificación de OTRO pedido → promedio recomputado (5,5 → 4)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id1 = await _sembrarPedido(db);
    // El staff cierra el ciclo de la mesa (limpieza→disponible) antes de
    // que el cliente re-abra para un segundo pedido.
    await db.doc('mesas/$_mesa').update({'estado': 'disponible'});
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    final id2 =
        await crearPedido(db, uid: 'test-uid', mesaCodigo: _mesa, items: _items);
    await db.doc('pedidos/$id2').update({'estado': 'servido'});
    await db.doc('sesiones/$_mesa').update({'estado': 'cerrada'});

    await calificar(db, uid: 'test-uid', pedidoId: id1, estrellas: 5);
    await calificar(db,
        uid: 'test-uid', pedidoId: id2, estrellas: 3, comentario: 'Bien');

    final rest = await db.doc('restaurantes/demo').get();
    expect(rest.data()!['califCount'], 2);
    expect((rest.data()!['califProm'] as num), 4.0,
        reason: '(5×1 + 3)/2 = 4 — leído y escrito en la MISMA tx');
    final calif2 = await db.doc('calificaciones/$id2').get();
    expect(calif2.data()!['comentario'], 'Bien');
  });

  test('calificar el MISMO pedido dos veces → error 1:1 (sin duplicados)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db);
    await calificar(db, uid: 'test-uid', pedidoId: id, estrellas: 5);

    await expectLater(
      calificar(db, uid: 'test-uid', pedidoId: id, estrellas: 3),
      throwsA(isA<CalificacionException>().having(
          (e) => e.message, 'message', 'Este pedido ya fue calificado')),
    );
    final rest = await db.doc('restaurantes/demo').get();
    expect(rest.data()!['califCount'], 1, reason: 'el agregado no avanzó');
  });

  test('calificar con sesión AÚN ACTIVA → error controlado (locked tras cierre)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db, sesionEstado: 'activa');

    await expectLater(
      calificar(db, uid: 'test-uid', pedidoId: id, estrellas: 4),
      throwsA(isA<CalificacionException>().having((e) => e.message,
          'message', 'Podrás calificar cuando el restaurante cierre tu sesión')),
    );
    expect((await db.collection('calificaciones').get()).docs, isEmpty);
  });

  test('calificar pedido de OTRO usuario → error controlado', () async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db, uid: 'dueno');

    await expectLater(
      calificar(db, uid: 'intruso', pedidoId: id, estrellas: 4),
      throwsA(isA<CalificacionException>().having((e) => e.message,
          'message', 'Solo puedes calificar tus propios pedidos')),
    );
    expect((await db.collection('calificaciones').get()).docs, isEmpty);
  });

  test('calificar pedido NO servido (enviado) → error controlado', () async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db, estado: 'enviado');

    await expectLater(
      calificar(db, uid: 'test-uid', pedidoId: id, estrellas: 4),
      throwsA(isA<CalificacionException>()
          .having((e) => e.message, 'message', 'Solo puedes calificar pedidos servidos')),
    );
    expect((await db.collection('calificaciones').get()).docs, isEmpty);
  });

  // ── Widgets: el sheet de estrellas (UI intacta) ─────────────────────────

  /// Host con botón que abre el sheet apuntando a [pedidoId].
  Widget wrapCon(dynamic db, String pedidoId, {String etiqueta = 'abrir'}) {
    return ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CalificacionSheet(pedidoId: pedidoId),
                ),
                child: Text(etiqueta),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('5 estrellas custom: tap en la 4ta → 4 llenas, valor 4',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db);
    await tester.pumpWidget(wrapCon(db, id));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Inicial: 5 vacías.
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.byIcon(Icons.star), findsNothing);

    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.byIcon(Icons.star_border), findsNWidgets(1));
  });

  testWidgets(
      'Enviar deshabilitado sin estrellas; con 4+comentario escribe el doc, cierra y agradece',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db);

    await tester.pumpWidget(wrapCon(db, id));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Deshabilitado con 0 estrellas.
    var btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Enviar calificación'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();

    btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Enviar calificación'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '¡Excelente todo!');
    await tester.pump();

    await tester.tap(find.text('Enviar calificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final calif = await db.doc('calificaciones/$id').get();
    expect(calif.data()!['estrellas'], 4);
    expect(calif.data()!['comentario'], '¡Excelente todo!');

    // Sheet cerrado + SnackBar de gracias.
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(find.text('¡Gracias por calificar! 🙌'), findsOneWidget);
  });

  testWidgets('ya calificado → mensaje específico, sheet NO cierra',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final id = await _sembrarPedido(db);
    await calificar(db, uid: 'test-uid', pedidoId: id, estrellas: 5);

    await tester.pumpWidget(wrapCon(db, id));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border).at(4));
    await tester.pump();
    await tester.tap(find.text('Enviar calificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Este pedido ya fue calificado'), findsOneWidget);
    // El sheet sigue abierto para que el usuario vea el error.
    expect(find.byIcon(Icons.star), findsNWidgets(5));
  });
}
