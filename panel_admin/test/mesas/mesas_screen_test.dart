import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/mesas/mesas_crud.dart';
import 'package:gri_panel_admin/features/mesas/mesas_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Tests del CRUD de mesas sobre Firestore (MESA-01, 10-06 Task 1): doc ID
/// determinista = código QR `GRI-MESA-{rid}-{numero:03d}` (colisión = mesa
/// duplicada), update quirúrgico de ficha, move-de-doc al cambiar número
/// (el QR deriva del número — el invariant doc ID == QR se preserva) y el
/// flujo completo del form (crear/duplicado) contra la pantalla viva.

ProviderContainer _container(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    claimsProvider.overrideWith(
      (ref) async => (role: 'admin_restaurante', rid: 'demo'),
    ),
  ]);
  // Mantener el stream escuchando (autoDispose): los read(.future)
  // posteriores a cada write ven el valor NUEVO (patrón stats_render_test).
  container.listen(mesasProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

Widget _screen(FakeFirebaseFirestore db) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: MesasScreen())),
  );
}

void main() {
  // ── Bloque 1: doc ID determinista + stream del mapa ──────────────────────
  test(
    'crearMesa → doc mesas/GRI-MESA-demo-009 con estado disponible + aparece en el stream',
    () async {
      final db = await buildFakeFirestoreConSeed();
      final container = _container(db);

      await crearMesa(db, rid: 'demo', numero: 9, capacidad: 4);

      final doc = await db.doc('mesas/GRI-MESA-demo-009').get();
      expect(doc.exists, isTrue, reason: 'doc ID determinista = código QR');
      final data = doc.data()!;
      expect(data['restauranteId'], 'demo');
      expect(data['numero'], 9);
      expect(data['capacidad'], 4);
      expect(data['estado'], 'disponible');
      expect(data['updatedAt'], isA<Timestamp>());

      // El mapa vivo (mesasProvider 10-05) ya refleja el alta.
      final mesas = await container.read(mesasProvider.future);
      final nueva = mesas.firstWhere((m) => m.id == 'GRI-MESA-demo-009');
      expect(nueva.numero, 9);
      expect(nueva.capacidad, 4);
    },
  );

  // ── Bloque 2: colisión = número duplicado ────────────────────────────────
  test(
    'crearMesa con número existente → error controlado "Ya existe una mesa con ese número"',
    () async {
      final db = await buildFakeFirestoreConSeed();

      await crearMesa(db, rid: 'demo', numero: 9, capacidad: 4);
      // El seed ya trae 001..003: el 1 también colisiona sin crear antes.
      expect(
        () => crearMesa(db, rid: 'demo', numero: 9, capacidad: 2),
        throwsA(
          isA<MesaDuplicadaException>().having(
            (e) => e.toString(),
            'mensaje controlado',
            contains('Ya existe una mesa con ese número'),
          ),
        ),
      );
      expect(
        () => crearMesa(db, rid: 'demo', numero: 1, capacidad: 2),
        throwsA(isA<MesaDuplicadaException>()),
      );
      // El doc original quedó INTACTO (la colisión no sobreescribe).
      final doc = await db.doc('mesas/GRI-MESA-demo-009').get();
      expect(doc.data()!['capacidad'], 4);
    },
  );

  // ── Bloque 3: update quirúrgico + delete ─────────────────────────────────
  test(
    'actualizarMesa(capacidad) persiste SOLO capacidad (+updatedAt); el resto intacto',
    () async {
      final db = await buildFakeFirestoreConSeed();
      final container = _container(db);

      final mesa1 =
          (await container.read(mesasProvider.future)).firstWhere((m) => m.numero == 1);
      await actualizarMesa(db, mesa: mesa1, rid: 'demo', capacidad: 6);

      final doc = await db.doc('mesas/GRI-MESA-demo-001').get();
      final data = doc.data()!;
      expect(data['capacidad'], 6, reason: 'capacidad actualizada');
      expect(data['numero'], 1, reason: 'numero intacto');
      expect(data['estado'], 'disponible', reason: 'estado intacto');
      expect(data['restauranteId'], 'demo');
      expect(doc.id, 'GRI-MESA-demo-001', reason: 'mismo doc (sin cambio de numero)');
    },
  );

  test(
    'actualizarMesa(numero) MUEVE el doc (doc ID = QR deriva del número)',
    () async {
      final db = await buildFakeFirestoreConSeed();
      final container = _container(db);

      final mesa3 =
          (await container.read(mesasProvider.future)).firstWhere((m) => m.numero == 3);
      await actualizarMesa(db, mesa: mesa3, rid: 'demo', numero: 7, capacidad: 8);

      // Nuevo doc con el nuevo ID determinista; el viejo desaparece.
      final nuevo = await db.doc('mesas/GRI-MESA-demo-007').get();
      expect(nuevo.exists, isTrue);
      expect(nuevo.data()!['numero'], 7);
      expect(nuevo.data()!['capacidad'], 8);
      expect(nuevo.data()!['estado'], 'disponible', reason: 'estado viaja al move');
      expect(
        (await db.doc('mesas/GRI-MESA-demo-003').get()).exists,
        isFalse,
        reason: 'el doc viejo (QR obsoleto) se elimina',
      );
    },
  );

  test('eliminarMesa quita el doc y desaparece del stream', () async {
    final db = await buildFakeFirestoreConSeed();
    final container = _container(db);

    await crearMesa(db, rid: 'demo', numero: 9, capacidad: 4);
    expect(
      (await container.read(mesasProvider.future))
          .any((m) => m.id == 'GRI-MESA-demo-009'),
      isTrue,
    );

    await eliminarMesa(db, mesaId: 'GRI-MESA-demo-009');

    expect(
      (await db.doc('mesas/GRI-MESA-demo-009').get()).exists,
      isFalse,
    );
    expect(
      (await container.read(mesasProvider.future))
          .any((m) => m.id == 'GRI-MESA-demo-009'),
      isFalse,
      reason: 'el onSnapshot del mapa refleja la baja',
    );
  });

  // ── Bloque 4: pantalla + form (wire completo contra Firestore) ───────────
  testWidgets('(a) grid vivo renderiza las mesas del seed + FAB', (tester) async {
    final db = await buildFakeFirestoreConSeed();

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
    expect(find.text('Nueva mesa'), findsOneWidget);
  });

  testWidgets(
    '(b) FAB → form → numero 9 + capacidad 4 → doc GRI-MESA-demo-009 + tile en vivo',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nueva mesa'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '9');
      await tester.enterText(fields.at(1), '4');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Write a Firestore con doc ID determinista.
      final doc = await db.doc('mesas/GRI-MESA-demo-009').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['estado'], 'disponible');
      // Confirmación + tile nuevo en el grid (stream, sin invalidate manual).
      expect(find.text('Mesa 9 creada'), findsOneWidget);
      expect(find.text('Mesa 9'), findsOneWidget);
    },
  );

  testWidgets(
    '(c) crear con número duplicado → SnackBar controlado y doc intacto',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nueva mesa'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '2'); // ya existe (seed)
      await tester.enterText(fields.at(1), '4');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe una mesa con ese número'), findsOneWidget);
      // El dialog permanece abierto para corregir; el doc no cambió.
      expect(find.text('Guardar'), findsOneWidget);
      expect((await db.doc('mesas/GRI-MESA-demo-002').get()).data()!['capacidad'], 4);
    },
  );
}
