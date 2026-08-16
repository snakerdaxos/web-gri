import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/state_machines.dart';
import 'package:gri_cliente/features/sesion_qr/scan_screen.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../helpers/firebase_fakes.dart';

/// Sesión QR sobre Firestore (Task 1 de 10-04): abrirSesion tx determinista
/// sobre sesiones/{mesaId}, concurrencia doble-apertura (MIGRA-06), y el
/// stream del doc como banner vivo. Todo contra fakes in-memory.

const _mesa = 'GRI-MESA-demo-001';

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
  // ── Unidad: la tx de abrirSesion ─────────────────────────────────────────

  test('mesa disponible → sesión activa con dueño y mesa pasa a ocupada',
      () async {
    final db = await buildFakeFirestoreConSeed();

    final sesion = await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    expect(sesion.estado, 'activa');
    expect(sesion.usuarioId, 'uid-a');
    expect(sesion.mesaId, _mesa);
    expect(sesion.mesaNumero, 1, reason: 'numero leído de la mesa en la tx');

    final doc = await db.doc('sesiones/$_mesa').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['estado'], 'activa');
    expect(doc.data()!['usuarioId'], 'uid-a');
    expect(doc.data()!['mesaId'], _mesa, reason: 'mesaId == docId (rules)');
    expect(doc.data()!['cuentaSolicitada'], false);

    final mesa = await db.doc('mesas/$_mesa').get();
    expect(mesa.data()!['estado'], 'ocupada');
  });

  test('CONCURRENCIA (MIGRA-06): dos abrirSesion simultáneos → 1 gana, 1 "Mesa ocupada"',
      () async {
    final db = await buildFakeFirestoreConSeed();

    final resultados = await Future.wait<String>([
      abrirSesion(db, uid: 'uid-a', codigoQR: _mesa)
          .then((_) => 'ok')
          .catchError((_) => 'error'),
      abrirSesion(db, uid: 'uid-b', codigoQR: _mesa)
          .then((_) => 'ok')
          .catchError((_) => 'error'),
    ]);
    // .catchError tapa el mensaje — repetimos por separado para assertearlo.
    final perdedor = abrirSesion(db, uid: 'uid-c', codigoQR: _mesa);

    expect(resultados.where((r) => r == 'ok').length, 1,
        reason: 'exactamente UNA sesión se crea');
    await expectLater(perdedor,
        throwsA(isA<SesionException>().having((e) => e.message, 'message', 'Mesa ocupada')));

    final doc = await db.doc('sesiones/$_mesa').get();
    expect(doc.data()!['estado'], 'activa');
    expect(doc.data()!['usuarioId'], anyOf('uid-a', 'uid-b'));
    final mesa = await db.doc('mesas/$_mesa').get();
    expect(mesa.data()!['estado'], 'ocupada');
  });

  test('mesa en limpieza → TransicionInvalidaException (mensaje controlado en el controller)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/$_mesa').update({'estado': 'limpieza'});

    await expectLater(
      abrirSesion(db, uid: 'uid-a', codigoQR: _mesa),
      throwsA(isA<TransicionInvalidaException>()),
    );

    // El controller lo traduce a mensaje user-friendly (contrato de la UI).
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'uid-a')),
    ]);
    addTearDown(container.dispose);

    final error = await container
        .read(sesionControllerProvider.notifier)
        .abrir(_mesa)
        .then<Object?>((s) => s, onError: (Object e) => e);
    expect(error, isA<SesionException>());
    expect((error as SesionException).message,
        'La mesa no está disponible en este momento');
  });

  test('código inexistente (GRI-MESA-demo-999) → "Código de mesa inválido"',
      () async {
    final db = await buildFakeFirestoreConSeed();

    await expectLater(
      abrirSesion(db, uid: 'uid-a', codigoQR: 'GRI-MESA-demo-999'),
      throwsA(isA<SesionException>()
          .having((e) => e.message, 'message', 'Código de mesa inválido')),
    );

    final sesiones = await db.collection('sesiones').get();
    expect(sesiones.docs, isEmpty, reason: 'sin doc creado');
  });

  test('sesión cerrada previa en esa mesa → se permite re-abrir', () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('sesiones/GRI-MESA-demo-002').set({
      'restauranteId': 'demo',
      'mesaId': 'GRI-MESA-demo-002',
      'usuarioId': 'otro-uid',
      'estado': 'cerrada',
      'cuentaSolicitada': true,
      'inicioAt': DateTime(2026, 8, 1, 12),
    });

    final sesion =
        await abrirSesion(db, uid: 'uid-a', codigoQR: 'GRI-MESA-demo-002');

    expect(sesion.estado, 'activa');
    final doc = await db.doc('sesiones/GRI-MESA-demo-002').get();
    expect(doc.data()!['estado'], 'activa');
    expect(doc.data()!['usuarioId'], 'uid-a');
    expect(doc.data()!['cuentaSolicitada'], false,
        reason: 'el set reemplaza el doc (nueva sesión limpia)');
    final mesa = await db.doc('mesas/GRI-MESA-demo-002').get();
    expect(mesa.data()!['estado'], 'ocupada');
  });

  test('stream sesionProvider refleja cuentaSolicitada=true de otro writer',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final emisiones = <SesionMesa>[];
    container.listen(
      sesionProvider(_mesa),
      (_, next) => next.whenData((s) => emisiones.add(s)),
    );

    await _hasta(() => emisiones.isNotEmpty);
    expect(emisiones.last.cuentaSolicitada, false);
    expect(emisiones.last.estado, 'activa');
    expect(emisiones.last.restauranteNombre, 'Restaurante Demo GRI',
        reason: 'enriquecido client-side (join)');
    expect(emisiones.last.mesaNumero, 1);

    // Otro writer (staff/mesero flip) — el stream lo refleja solo.
    await db.doc('sesiones/$_mesa').update({'cuentaSolicitada': true});

    await _hasta(() => emisiones.last.cuentaSolicitada);
    expect(emisiones.last.cuentaSolicitada, true);
  });

  // ── Widgets: ScanScreen (input manual de primera clase) ─────────────────

  Widget wrapFake(FakeTestFirestoreBuilder builder) {
    final router = GoRouter(
      initialLocation: '/sesion/scan',
      routes: [
        GoRoute(path: '/sesion/scan', builder: (_, _) => const ScanScreen()),
        GoRoute(
          path: '/mesa',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('MESA_PAGE'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(builder.db),
        firebaseAuthProvider.overrideWithValue(builder.auth ?? mockAuth()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('render inicial: sin cámara, input manual y hint del nuevo formato',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('Escanear con cámara'), findsOneWidget);
    expect(find.text('O escribe el código de la mesa'), findsOneWidget);
    expect(find.text('GRI-MESA-demo-001'), findsOneWidget,
        reason: 'hint con slug de restaurante');
  });

  testWidgets('GRI-MESA-001 (sin slug) queda bloqueado por el validator',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'GRI-MESA-001');
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();

    expect(find.textContaining('formato GRI-MESA-demo-001'), findsOneWidget);
    // Sin navegación.
    expect(find.text('MESA_PAGE'), findsNothing);
  });

  testWidgets('GRI-MESA-demo-001 válido → sesión abierta (Mesa 1) + navegación',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), _mesa);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mesa 1'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsOneWidget);

    final doc = await db.doc('sesiones/$_mesa').get();
    expect(doc.data()!['usuarioId'], 'test-uid');
  });

  testWidgets('mesa ocupada por sesión ajena → SnackBar "Mesa ocupada", sin navegar',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('sesiones/$_mesa').set({
      'restauranteId': 'demo',
      'mesaId': _mesa,
      'usuarioId': 'otro-uid',
      'estado': 'activa',
      'cuentaSolicitada': false,
    });

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), _mesa);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mesa ocupada'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);
    expect(find.text('Abrir mesa'), findsOneWidget, reason: 'permite reintentar');
  });

  testWidgets('mesa en limpieza → mensaje controlado (sin crash ni navegación)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/$_mesa').update({'estado': 'limpieza'});

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), _mesa);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.text('La mesa no está disponible en este momento'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);
  });
}

/// Envoltorio mínimo para inyectar db+auth al _wrap de los widget tests.
class FakeTestFirestoreBuilder {
  FakeTestFirestoreBuilder({required this.db, this.auth});

  final dynamic db;
  final dynamic auth;
}
