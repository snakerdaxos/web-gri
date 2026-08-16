import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/state_machines.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/mesas/mesa_actions_sheet.dart';
import 'package:gri_panel_admin/models/mesa.dart';

import '../helpers/firebase_fakes.dart';

/// Suite 10-05 Task 3 (ADMN-04 sobre Firestore): el actions sheet del mapa
/// ofrece SOLO las transiciones válidas de la máquina `mesa` (port 1:1 de
/// state_machines — las rules re-validan), y la mutación
/// [cambiarEstadoMesa] escribe SOLO `{estado, updatedAt}` tras
/// [validarTransicion] — una transición inválida lanza
/// [TransicionInvalidaException] SIN tocar el doc.

Mesa _m(EstadoMesa e) => Mesa(
      id: 'GRI-MESA-demo-002',
      restauranteId: 'demo',
      numero: 2,
      capacidad: 4,
      estado: e,
    );

/// Bombea un host mínimo (botón) que abre el sheet standalone con el fake
/// Firestore cableado. showEdit false = vista mapa del dashboard.
Future<void> _pumpSheetHost(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  Mesa mesa, {
  bool showEdit = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith(
          (ref) async => (role: 'mesero', rid: 'demo'),
        ),
      ],
      child: Consumer(
        builder: (consumerContext, ref, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              // Builder DENTRO del MaterialApp: el context del botón tiene
              // Localizations + Navigator + ScaffoldMessenger (el context
              // del Consumer queda POR ENCIMA del MaterialApp).
              child: Builder(
                builder: (buttonContext) => TextButton(
                  onPressed: () => showMesaActionsSheet(
                    buttonContext,
                    ref,
                    mesa,
                    showEdit: showEdit,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) disponible: exactamente reservada+ocupada; sin Editar',
      (tester) async {
    await _pumpSheetHost(
      tester,
      await buildFakeFirestoreConSeed(),
      _m(EstadoMesa.disponible),
    );

    // Exactamente las 2 transiciones válidas desde disponible.
    expect(find.text('Marcar reservada'), findsOneWidget);
    expect(find.text('Marcar ocupada'), findsOneWidget);
    expect(find.text('Ver código QR'), findsOneWidget);
    // NINGUNA otra acción de estado.
    expect(find.text('Marcar en limpieza'), findsNothing);
    expect(find.text('Liberar reserva'), findsNothing);
    expect(find.text('Liberar'), findsNothing);
    // Mapa operacional: sin edición (vive en /mesas).
    expect(find.text('Editar mesa'), findsNothing);
  });

  testWidgets('(b) limpieza: solo Liberar', (tester) async {
    await _pumpSheetHost(
      tester,
      await buildFakeFirestoreConSeed(),
      _m(EstadoMesa.limpieza),
    );

    expect(find.text('Liberar'), findsOneWidget);
    expect(find.text('Marcar reservada'), findsNothing);
    expect(find.text('Marcar ocupada'), findsNothing);
    expect(find.text('Marcar en limpieza'), findsNothing);
    expect(find.text('Liberar reserva'), findsNothing);
    expect(find.text('Ver código QR'), findsOneWidget);
  });

  testWidgets('(c) ocupada: solo Marcar en limpieza (NO ofrece disponible)',
      (tester) async {
    await _pumpSheetHost(
      tester,
      await buildFakeFirestoreConSeed(),
      _m(EstadoMesa.ocupada),
    );

    expect(find.text('Marcar en limpieza'), findsOneWidget);
    expect(find.text('Marcar reservada'), findsNothing);
    expect(find.text('Marcar ocupada'), findsNothing);
    expect(find.text('Liberar'), findsNothing);
    expect(find.text('Liberar reserva'), findsNothing);
  });

  testWidgets(
      '(d) tap Marcar en limpieza → update de mesas/{qr} SOLO {estado, updatedAt} + SnackBar',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _pumpSheetHost(tester, db, _m(EstadoMesa.ocupada));

    await tester.tap(find.text('Marcar en limpieza'));
    await tester.pumpAndSettle();

    // El doc de la mesa quedó en limpieza…
    final doc = await db.doc('mesas/GRI-MESA-demo-002').get();
    final data = doc.data()!;
    expect(data['estado'], 'limpieza');
    // …y el update tocó SOLO estado/updatedAt: las demás keys del doc
    // quedan intactas (restauranteId/numero/capacidad).
    expect(data['restauranteId'], 'demo');
    expect(data['numero'], 2);
    expect(data['capacidad'], 4);
    expect(data['updatedAt'], isNotNull,
        reason: 'el update debe estampar updatedAt');
    expect(
      data.keys,
      unorderedEquals(
        ['restauranteId', 'numero', 'capacidad', 'estado', 'updatedAt'],
      ),
      reason: 'el update no debe crear/eliminar campos',
    );

    // El sheet se cerró y el feedback quedó en la pantalla.
    expect(find.text('Marcar en limpieza'), findsNothing);
    expect(find.text('Mesa 2 → limpieza'), findsOneWidget);
  });

  testWidgets(
      '(e) transición inválida (ocupada→disponible) lanza y NO toca el doc',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    // La mesa 002 del seed está 'disponible' — se lleva a 'ocupada' por la
    // vía válida para dejarla en el estado del caso.
    await db.doc('mesas/GRI-MESA-demo-002').update({'estado': 'ocupada'});

    final mesa = Mesa.fromDoc(await db.doc('mesas/GRI-MESA-demo-002').get());

    // Salto inválido directo a la función de mutación (lo que el server
    // haría llegar como 409 — aquí la barrera client-side).
    await expectLater(
      cambiarEstadoMesa(db, mesa: mesa, destino: 'disponible'),
      throwsA(isA<TransicionInvalidaException>()),
    );

    // El doc quedó intacto.
    final data = (await db.doc('mesas/GRI-MESA-demo-002').get()).data()!;
    expect(data['estado'], 'ocupada');
  });

  testWidgets('(f) limpieza→disponible SÍ es válida (ciclo del staff)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-002').update({'estado': 'limpieza'});
    final mesa = Mesa.fromDoc(await db.doc('mesas/GRI-MESA-demo-002').get());

    await cambiarEstadoMesa(db, mesa: mesa, destino: 'disponible');

    final data = (await db.doc('mesas/GRI-MESA-demo-002').get()).data()!;
    expect(data['estado'], 'disponible');
  });
}
