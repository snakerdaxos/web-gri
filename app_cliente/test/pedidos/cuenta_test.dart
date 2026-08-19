import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/gri_icons.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';

/// Bombea PedidoEstadoScreen con db+auth fakes y sesión REAL abierta —
/// retorna el db para inspeccionar docs tras los taps.
Future<dynamic> _pump(WidgetTester tester) async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
    ],
    child: const MaterialApp(home: PedidoEstadoScreen()),
  ));
  await tester.pumpAndSettle();
  return db;
}

void main() {
  // ── Unidad: solicitarCuenta ─────────────────────────────────────────────

  test('solicitarCuenta → sesion.cuentaSolicitada true + cuentaPedidaAt',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    await solicitarCuenta(db, uid: 'uid-a', mesaId: _mesa);

    final sesion = await db.doc('sesiones/$_mesa').get();
    expect(sesion.data()!['cuentaSolicitada'], true);
    expect(sesion.data()!['cuentaPedidaAt'], isNotNull);
  });

  test('solicitarCuenta de otro usuario → error controlado (dueño only)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    await expectLater(
      solicitarCuenta(db, uid: 'intruso', mesaId: _mesa),
      throwsA(isA<PedidoException>()),
    );
    final sesion = await db.doc('sesiones/$_mesa').get();
    expect(sesion.data()!['cuentaSolicitada'], false,
        reason: 'el flag no se prendió');
  });

  // ── Widgets: la sección de cuenta de PedidoEstadoScreen ────────────────

  testWidgets('sesión sin cuenta → botón "Pedir la cuenta" visible; sin pago',
      (tester) async {
    await _pump(tester);

    expect(find.text('Pedir la cuenta'), findsOneWidget);
    // 11-13: el ✓ dejó de ser un glifo dentro de la cadena y es un Icon.
    // Cambia el FINDER, no lo que se afirma.
    expect(find.text('Cuenta solicitada'), findsNothing);
    expect(find.byIcon(GriIcons.confirmado), findsNothing);
    // Pagos DIFERIDOS (locked 10-04): no existe UI de pago en la app.
    expect(find.textContaining('Pagar'), findsNothing);
  });

  testWidgets('tap → doc con cuentaSolicitada + confirmación (stream vivo)',
      (tester) async {
    final db = await _pump(tester);

    await tester.tap(find.text('Pedir la cuenta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final sesion = await db.doc('sesiones/$_mesa').get();
    expect(sesion.data()!['cuentaSolicitada'], true);
    expect(sesion.data()!['cuentaPedidaAt'], isNotNull);

    expect(find.textContaining('el mesero viene en camino'), findsOneWidget);
    // El botón desaparece y queda la confirmación visible (idempotente UX).
    expect(find.text('Cuenta solicitada'), findsOneWidget);
    expect(find.byIcon(GriIcons.confirmado), findsOneWidget);
    expect(find.text('Pedir la cuenta'), findsNothing);
    expect(find.textContaining('Pagar'), findsNothing);
  });

  testWidgets('cuenta ya pedida (staff flip) → solo ✓, sin botón ni pago',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    await db.doc('sesiones/$_mesa')
        .update({'cuentaSolicitada': true});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta solicitada'), findsOneWidget);
    expect(find.byIcon(GriIcons.confirmado), findsOneWidget);
    expect(find.text('Pedir la cuenta'), findsNothing);
    expect(find.textContaining('Pagar'), findsNothing);
  });
}
