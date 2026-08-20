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

Future<void> _pump(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  Size tamano = const Size(1200, 1800),
}) async {
  tester.view.physicalSize = tamano;
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
    '(b2) Marcar ocupada con la mesa DISPONIBLE: la reserva de hoy creada AYER '
    'no la pre-marcaba (11-29)',
    (tester) async {
      // CONSECUENCIA DIRECTA DEL BUG B. Antes de 11-29, crear una reserva
      // marcaba la mesa 'reservada' en el acto, fuera cual fuera la fecha, así
      // que al llegar el cliente la mesa SIEMPRE estaba 'reservada' y la
      // transición era reservada→ocupada. Desde 11-29 el estado solo se toca
      // si el slot es de HOY: una reserva para hoy creada AYER deja la mesa
      // 'disponible' y el botón tiene que seguir funcionando
      // (disponible→ocupada está en la máquina y en `transMesa` de las rules).
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      // El seed marca la mesa 2 'reservada'. Se deshace: este es el escenario
      // nuevo, la mesa libre hasta que el cliente aparece.
      await db.doc('mesas/GRI-MESA-demo-002').update({'estado': 'disponible'});
      await _pump(tester, db);

      await tester.tap(find.text('Marcar ocupada'));
      await tester.pumpAndSettle();

      final mesa = await db.doc('mesas/GRI-MESA-demo-002').get();
      expect(mesa.data()!['estado'], 'ocupada');
      expect(find.text('Mesa 2 marcada ocupada'), findsOneWidget);
      // Y NO el mensaje de carrera, que sería falso aquí.
      expect(find.text('La mesa ya cambió de estado'), findsNothing);
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

  // ── Geometría de la tarjeta (11-21) ──────────────────────────────────────
  //
  // El `_ReservaCard` era un Row único con hora (20 bold) + Expanded + chip +
  // DOS botones sin acotar. Con la tarjeta estrecha, el chip y los botones se
  // salían de la tarjeta.

  testWidgets(
      '(g) a 650px de contenido la tarjeta NO desborda: los botones bajan a '
      'una segunda fila', (tester) async {
    final desbordes = <String>[];
    final onErrorPrevio = FlutterError.onError;
    // OVERFLOW-DETECTOR: se recogen para AFIRMAR que la lista queda vacía.
    // Ver test/shared/sin_filtros_overflow_test.dart.
    FlutterError.onError = (details) {
      final txt = details.exceptionAsString();
      if (txt.contains('A RenderFlex overflowed')) {
        desbordes.add(txt.split('\n').first);
        return;
      }
      onErrorPrevio?.call(details);
    };
    try {
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      await _pump(tester, db, tamano: const Size(650, 1200));
    } finally {
      FlutterError.onError = onErrorPrevio;
    }

    expect(desbordes, isEmpty,
        reason: 'la tarjeta de reserva desborda a 650px: '
            '${desbordes.join(" | ")}');

    // Y sigue siendo usable: el chip y los dos botones están todos.
    expect(find.text('confirmada'), findsOneWidget);
    expect(find.text('No-show'), findsNWidgets(2));
    expect(find.text('Marcar ocupada'), findsOneWidget);

    // Segunda fila REAL: el botón queda por DEBAJO del chip, no a su lado.
    final chip = tester.getRect(find.text('confirmada').first);
    final boton = tester.getRect(find.text('Marcar ocupada').first);
    expect(boton.top, greaterThan(chip.bottom),
        reason: 'a 650px las acciones deben ir en una segunda fila');
  });

  testWidgets(
      '(h) a 1200px la tarjeta conserva EXACTAMENTE la fila única de siempre',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _seedHoy(db);
    await _pump(tester, db, tamano: const Size(1200, 1800));

    final hora = tester.getRect(find.text('12:00'));
    final chip = tester.getRect(find.text('confirmada'));
    final boton = tester.getRect(find.text('Marcar ocupada'));

    // Todo en la misma banda vertical (una sola fila) y en el orden de
    // siempre: hora → … → chip → botones.
    expect(chip.center.dy, closeTo(hora.center.dy, 2));
    expect(boton.center.dy, closeTo(hora.center.dy, 2));
    expect(chip.left, greaterThan(hora.right));
    expect(boton.left, greaterThan(chip.right));
  });

  testWidgets(
      '(i) la cabecera con la fecha tampoco desborda en una columna estrecha',
      (tester) async {
    // La pantalla suelta a 420px: es el ancho al que la cabecera
    // «📅 Reservas de hoy (dd/MM/yyyy)» dejaba de caber. Se pumpea SIN el
    // shell a propósito — dentro del shell este ancho ya no se alcanza sin
    // arrastrar también los tiles del dashboard, y lo que se quiere aislar
    // aquí es la cabecera.
    final desbordes = <String>[];
    final onErrorPrevio = FlutterError.onError;
    // OVERFLOW-DETECTOR: se recogen para AFIRMAR que la lista queda vacía.
    FlutterError.onError = (details) {
      final txt = details.exceptionAsString();
      if (txt.contains('A RenderFlex overflowed')) {
        desbordes.add(txt.split('\n').first);
        return;
      }
      onErrorPrevio?.call(details);
    };
    try {
      final db = await buildFakeFirestoreConSeed();
      await _seedHoy(db);
      await _pump(tester, db, tamano: const Size(420, 1200));
    } finally {
      FlutterError.onError = onErrorPrevio;
    }

    expect(desbordes, isEmpty,
        reason: 'la cabecera de /reservas desborda a 420px: '
            '${desbordes.join(" | ")}');
    expect(find.textContaining('Reservas de hoy'), findsOneWidget);
  });
}
