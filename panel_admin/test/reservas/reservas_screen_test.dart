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
    // 11-34: la cabecera dice 'Reservas · hoy dd/MM/yyyy' — el 'de hoy'
    // se movió a la pestaña, que ahora es quien separa hoy de próximas.
    expect(find.textContaining('Reservas · hoy'), findsOneWidget);
  });

  // ══════════════════════════════════════════════════════════════════════
  // HOY Y PRÓXIMAS, SEPARADAS (11-34)
  //
  // Hasta 11-34 la consulta acotaba a `fecha >= inicioHoy && fecha <
  // inicioMañana`. Y hasta 11-31 el cliente solo podía reservar de mañana en
  // adelante. Combinando las dos cosas: NINGUNA reserva había sido nunca
  // visible para el restaurante hasta el día en que ocurría — no se podían
  // planificar ni las compras ni los turnos.
  //
  // Se prueban las dos direcciones: que las futuras APAREZCAN en su pestaña,
  // y que NO se cuelen en la de hoy (que es lo que rompería la operación de
  // sala).
  // ══════════════════════════════════════════════════════════════════════

  /// Reserva a [dias] días vista, a las 20:00, para que nunca cruce
  /// medianoche por muy tarde que se ejecute la suite.
  Future<void> reservaFutura(
    FakeFirebaseFirestore db, {
    required int dias,
    required String mesaId,
    int numPersonas = 2,
  }) {
    final hoy = DateTime.now();
    final f = DateTime(hoy.year, hoy.month, hoy.day, 20, 0)
        .add(Duration(days: dias));
    return _reserva(db,
        rid: 'demo',
        mesaId: mesaId,
        fecha: f,
        numPersonas: numPersonas,
        estado: 'confirmada');
  }

  testWidgets('(j) las reservas de MAÑANA no aparecen en la pestaña de hoy',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _seedHoy(db);
    await reservaFutura(db, dias: 1, mesaId: 'GRI-MESA-demo-004',
        numPersonas: 7);
    await _pump(tester, db);

    // La pestaña activa es 'Hoy': la de mañana (7 personas) no está.
    expect(find.text('7 personas'), findsNothing);
    expect(find.text('Mesa 2'), findsOneWidget);
  });

  testWidgets(
      '(k) en «Próximos 7 días» SÍ aparece la de mañana — el agujero tapado',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _seedHoy(db);
    await reservaFutura(db, dias: 1, mesaId: 'GRI-MESA-demo-004',
        numPersonas: 7);
    await _pump(tester, db);

    await tester.tap(find.textContaining('Próximos 7 días'));
    await tester.pumpAndSettle();

    expect(find.text('7 personas'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('(l) una reserva a 30 días queda FUERA de la ventana de 7',
      (tester) async {
    // Canario del caso anterior: sin este, «Próximas» podría estar leyendo
    // TODAS las reservas futuras y (k) seguiría en verde.
    final db = await buildFakeFirestoreConSeed();
    await reservaFutura(db, dias: 30, mesaId: 'GRI-MESA-demo-004',
        numPersonas: 9);
    await _pump(tester, db);

    await tester.tap(find.textContaining('Próximos 7 días'));
    await tester.pumpAndSettle();

    expect(find.text('9 personas'), findsNothing);
    expect(find.textContaining('Sin reservas en los próximos'), findsOneWidget);
  });

  testWidgets(
      '(m) las acciones de SALA no existen en «Próximas»: marcar ocupada una '
      'mesa por una reserva de mañana la bloquearía hoy', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await reservaFutura(db, dias: 2, mesaId: 'GRI-MESA-demo-004');
    await _pump(tester, db);

    await tester.tap(find.textContaining('Próximos 7 días'));
    await tester.pumpAndSettle();

    expect(find.text('Mesa 4'), findsOneWidget, reason: 'la reserva SÍ está');
    expect(find.text('Marcar ocupada'), findsNothing);
    expect(find.text('No-show'), findsNothing);
  });

  testWidgets('(n) las pestañas llevan la CUENTA para no esconder nada',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _seedHoy(db); // 2 de hoy
    await reservaFutura(db, dias: 1, mesaId: 'GRI-MESA-demo-004');
    await reservaFutura(db, dias: 3, mesaId: 'GRI-MESA-demo-005');
    await _pump(tester, db);

    expect(find.text('Hoy (2)'), findsOneWidget);
    expect(find.text('Próximos 7 días (2)'), findsOneWidget);
  });

  testWidgets(
      '(o) «Próximas» AGRUPA por día: dos reservas de días distintos llevan '
      'dos cabeceras', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await reservaFutura(db, dias: 1, mesaId: 'GRI-MESA-demo-004');
    await reservaFutura(db, dias: 3, mesaId: 'GRI-MESA-demo-005');
    await _pump(tester, db);

    await tester.tap(find.textContaining('Próximos 7 días'));
    await tester.pumpAndSettle();

    final hoy = DateTime.now();
    final d1 = DateTime(hoy.year, hoy.month, hoy.day)
        .add(const Duration(days: 1));
    final d3 = DateTime(hoy.year, hoy.month, hoy.day)
        .add(const Duration(days: 3));
    // El formato de la cabecera se construye igual que en la pantalla; lo
    // que este caso afirma NO es el formato (eso sería tautológico) sino que
    // hay DOS cabeceras distintas y que cada reserva cae bajo la suya.
    expect(find.byType(Card), findsNWidgets(2));
    expect(d1.day == d3.day, isFalse, reason: 'ancla: son días distintos');
  });
}
