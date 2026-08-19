import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/reservas/reserva_controller.dart';
import 'package:gri_cliente/features/reservas/reserva_wizard_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Wizard + servicio `crearReserva` sobre FakeFirebaseFirestore (MIGRA-06).
///
/// Nota de concurrencia: el fake ejecuta runTransaction SIN control
/// optimista (writes inmediatos) — la serialización entre llamadas del
/// mismo proceso la aporta el mutex `_seccionCritica` del controller
/// (en Firestore real es el OCC de la transacción el que serializa).

DateTime _slotDeManana([int hora = 19]) {
  final t = DateTime.now().add(const Duration(days: 1));
  return DateTime(t.year, t.month, t.day, hora);
}

String _fechaStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _mesasSeed = [
  'GRI-MESA-demo-001',
  'GRI-MESA-demo-002',
  'GRI-MESA-demo-003',
];

Widget _wrap(FakeFirebaseFirestore db,
        {String nombre = 'Restaurante Demo GRI'}) =>
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        firestoreProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: ReservaWizardScreen(
          // La key depende del nombre a propósito: un `pumpWidget` con otro
          // nombre pero sin key REUTILIZA el State (mismo runtimeType) y el
          // wizard se quedaría en el step al que llegó la vez anterior.
          key: ValueKey(nombre),
          restauranteId: 'demo',
          restauranteNombre: nombre,
        ),
      ),
    );

/// Llena el wizard completo (fecha mañana vía dialog OK, hora 19:00,
/// personas por defecto) y avanza hasta Confirmar.
Future<void> _llenarHastaConfirmar(WidgetTester tester) async {
  await tester.tap(find.text('Elegir fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Elige una hora'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('19:00').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  // ── Servicio: transacción determinista (port de reserva_service.py) ──
  group('crearReserva (tx determinista)', () {
    test('crea doc {mesaId}_{yyyyMMdd}_{HH} confirmada y pasa la mesa a reservada',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();

      final reserva = await crearReserva(db,
          uid: 'test-uid', restauranteId: 'demo', slot: slot, personas: 2);

      // Doc determinista de la PRIMERA mesa con capacidad (orden numero).
      expect(reserva.mesaId, 'GRI-MESA-demo-001');
      expect(reserva.id, docIdReserva('GRI-MESA-demo-001', slot));

      final doc = await db
          .doc('reservas/${docIdReserva('GRI-MESA-demo-001', slot)}')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['estado'], 'confirmada');
      expect(doc.data()!['usuarioId'], 'test-uid');
      expect(doc.data()!['restauranteId'], 'demo');
      expect(doc.data()!['fechaStr'], _fechaStr(slot));
      expect(doc.data()!['hora'], 19);
      expect(doc.data()!['numPersonas'], 2);
      expect(doc.data()!['mesaNumero'], 1);

      // La mesa estaba disponible → reservada.
      final mesa = await db.doc('mesas/GRI-MESA-demo-001').get();
      expect(mesa.data()!['estado'], 'reservada');
    });

    test(
        'CONCURRENCIA (MIGRA-06): dos crearReserva simultáneas → mesas distintas, jamás 2 docs para la misma mesa+slot',
        () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();

      final resultados = await Future.wait([
        crearReserva(db,
            uid: 'uid-a', restauranteId: 'demo', slot: slot, personas: 2),
        crearReserva(db,
            uid: 'uid-b', restauranteId: 'demo', slot: slot, personas: 2),
      ]);

      final docs = (await db.collection('reservas').get()).docs;

      // Ambas tienen mesa, pero DISTINTA (exactamente 1 gana cada mesa).
      expect(resultados.map((r) => r.mesaId).toSet(), hasLength(2));
      // Un doc por reserva — ids deterministas únicos por construcción.
      expect(docs, hasLength(2));
      expect(docs.map((d) => d.id).toSet(), hasLength(2));
      for (final r in resultados) {
        expect(r.estado, 'confirmada');
      }
      // La segunda reserva NO pisó el slot de la primera: cada doc lleva
      // el usuario que la ganó.
      expect(docs.map((d) => d.data()['usuarioId']).toSet(),
          {'uid-a', 'uid-b'});
    });

    test('todas las mesas del slot tomadas → error controlado', () async {
      final db = await buildFakeFirestoreConSeed();
      final slot = _slotDeManana();

      // Pre-sembrar el slot de TODAS las candidatas (capacidad >= 2: las 3).
      for (final mesaId in _mesasSeed) {
        await db.doc('reservas/${docIdReserva(mesaId, slot)}').set({
          'restauranteId': 'demo',
          'mesaId': mesaId,
          'usuarioId': 'otro',
          'estado': 'confirmada',
        });
      }

      await expectLater(
        crearReserva(db,
            uid: 'test-uid',
            restauranteId: 'demo',
            slot: slot,
            personas: 2),
        throwsA(isA<ReservaException>().having(
            (e) => e.message, 'message', 'No hay mesas disponibles en ese horario')),
      );
    });

    test('capacidad insuficiente → mismo error controlado, sin writes', () async {
      final db = await buildFakeFirestoreConSeed();

      // 10 personas > capacidad máxima del seed (6) → sin candidatas.
      await expectLater(
        crearReserva(db,
            uid: 'test-uid',
            restauranteId: 'demo',
            slot: _slotDeManana(),
            personas: 10),
        throwsA(isA<ReservaException>().having((e) => e.message, 'message',
            'No hay mesas con capacidad suficiente')),
      );
      expect((await db.collection('reservas').get()).docs, isEmpty);
    });
  });

  // ── UI del wizard ─────────────────────────────────────────────────────
  testWidgets('Stepper de 4 pasos: Fecha / Hora / Personas / Confirmar',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.byType(Stepper), findsOneWidget);
    expect(find.text('Fecha'), findsWidgets);
    expect(find.text('Hora'), findsWidgets);
    expect(find.text('Personas'), findsWidgets);
    expect(find.text('Confirmar'), findsWidgets);
  });

  testWidgets('hora picker SOLO ofrece slots :00 (12:00..21:00)', (tester) async {
    // Contrato estático: la lista de horas del wizard.
    expect(ReservaWizardScreen.horasSlot, hasLength(10));
    for (final h in ReservaWizardScreen.horasSlot) {
      expect(h.endsWith(':00'), isTrue, reason: '$h no es un slot :00');
    }
    expect(ReservaWizardScreen.horasSlot.first, '12:00');
    expect(ReservaWizardScreen.horasSlot.last, '21:00');
    expect(ReservaWizardScreen.horasSlot, isNot(contains('12:30')));

    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Avanzar al step Hora (elegir fecha primero).
    await tester.tap(find.text('Elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elige una hora'));
    await tester.pumpAndSettle();
    expect(find.text('12:30'), findsNothing);
    expect(find.text('13:00'), findsWidgets);
    expect(find.text('20:00'), findsWidgets);
  });

  testWidgets('num_personas queda entre 1 y 20', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elige una hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('19:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Default 2. Bajar 5 veces → clamp en 1.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
    }
    expect(find.text('1'), findsWidgets);

    // Subir 25 veces → clamp en 20.
    for (var i = 0; i < 25; i++) {
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
    }
    expect(find.text('20'), findsWidgets);
  });

  testWidgets('Confirmar crea la reserva en Firestore y muestra la mesa asignada',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await _llenarHastaConfirmar(tester);
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SnackBar con la mesa asignada automáticamente.
    expect(find.textContaining('¡Reserva confirmada! Mesa 1'), findsOneWidget);

    // El doc llegó a Firestore con el shape completo del slot.
    final docs = (await db.collection('reservas').get()).docs;
    expect(docs, hasLength(1));
    final data = docs.first.data();
    expect(data['restauranteId'], 'demo');
    expect(data['usuarioId'], 'test-uid');
    expect(data['hora'], 19);
    expect(data['numPersonas'], 2);
    expect(data['estado'], 'confirmada');
    expect(data['fechaStr'], _fechaStr(_slotDeManana()));
  });

  testWidgets('ante slot agotado muestra "Ese horario acaba de ser reservado"',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final slot = _slotDeManana();
    for (final mesaId in _mesasSeed) {
      await db.doc('reservas/${docIdReserva(mesaId, slot)}').set({
        'restauranteId': 'demo',
        'mesaId': mesaId,
        'usuarioId': 'otro',
        'estado': 'confirmada',
      });
    }

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await _llenarHastaConfirmar(tester);
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Ese horario acaba de ser reservado'),
        findsOneWidget);
    // Sin writes: las 3 del seed siguen siendo las únicas.
    expect((await db.collection('reservas').get()).docs, hasLength(3));
  });

  // ── Desbordamiento del resumen (11-13) ────────────────────────────────────
  //
  // `_ResumenRow` pintaba etiqueta y valor en un `Row(spaceBetween)` con los
  // dos `Text` sin acotar. Un `Row` da a sus hijos restricciones de ancho
  // INFINITAS, así que el valor se maquetaba a su ancho natural y, en cuanto
  // no cabía, salía la banda amarilla y negra de RenderFlex. Con un nombre de
  // restaurante largo (que el super_admin escribe a mano en el panel) y una
  // pantalla estrecha, es un caso corriente, no un extremo.
  //
  // PROHIBIDO cerrar esto filtrando la excepción: el desbordamiento se
  // arregla, no se silencia. Por eso el caso afirma también DÓNDE queda el
  // texto, no solo que no lance.
  group('_ResumenRow — no desborda con nombres largos', () {
    // 60 caracteres: "Restaurante " (12) + 48 más.
    const nombre60 = 'Restaurante El Rincón de la Abuela Doña Mercedes Bogotá D.C.';

    Future<void> pumpConfirmar(WidgetTester tester, double ancho,
        {String nombre = nombre60}) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = Size(ancho, 900);
      addTearDown(tester.view.reset);
      final db = await buildFakeFirestoreConSeed();
      await tester.pumpWidget(_wrap(db, nombre: nombre));
      await _llenarHastaConfirmar(tester);
    }

    testWidgets('a 320px con 60 caracteres no hay RenderFlex overflow',
        (tester) async {
      assert(nombre60.length == 60, 'el caso se define por su longitud');
      await pumpConfirmar(tester, 320);

      expect(tester.takeException(), isNull,
          reason: 'cualquier excepción aquí es el overflow: flutter_test '
              'convierte "A RenderFlex overflowed" en un FlutterError');
      expect(find.text(nombre60), findsOneWidget);
    });

    testWidgets('a 320px el valor se recorta y NO invade la etiqueta',
        (tester) async {
      await pumpConfirmar(tester, 320);

      final valor = tester.widget<Text>(find.text(nombre60));
      expect(valor.overflow, TextOverflow.ellipsis,
          reason: 'sin ellipsis el texto se corta a mitad de glifo o se '
              'reparte en tantas líneas que rompe el ritmo de la lista');

      final rEtiqueta = tester.getRect(find.text('Restaurante'));
      final rValor = tester.getRect(find.text(nombre60));
      expect(rValor.left, greaterThanOrEqualTo(rEtiqueta.right),
          reason: 'la etiqueta tiene que seguir siendo legible entera');
      expect(rValor.right, lessThanOrEqualTo(320.0),
          reason: 'y el valor no puede salirse de la pantalla');
    });

    testWidgets('a 480px un nombre largo no mueve ni la etiqueta ni el margen',
        (tester) async {
      // OJO CON LO QUE ESTO PRUEBA Y LO QUE NO. Al meter el valor en un
      // `Expanded`, la CAJA del párrafo pasa a ocupar todo el hueco libre, así
      // que su `left` ya no es el del texto: los glifos siguen pegados a la
      // derecha por el `textAlign: end`, pero un widget test NO puede afirmar
      // la posición de un glifo. Lo que sí se puede afirmar —y es lo que
      // importa— es que la fila ocupa el MISMO rectángulo con un nombre corto
      // que con uno de 60 caracteres. Sin el arreglo, el largo empujaba la
      // fila 616px fuera de la pantalla.
      const corto = 'Demo';

      await pumpConfirmar(tester, 480, nombre: corto);
      final etiquetaCorto = tester.getRect(find.text('Restaurante'));
      final valorCorto = tester.getRect(find.text(corto));

      await pumpConfirmar(tester, 480, nombre: nombre60);
      final etiquetaLargo = tester.getRect(find.text('Restaurante'));
      final valorLargo = tester.getRect(find.text(nombre60));

      expect(etiquetaLargo, etiquetaCorto,
          reason: 'la etiqueta no puede moverse por lo que valga el valor');
      expect(valorLargo.right, valorCorto.right,
          reason: 'y el valor sigue terminando en el mismo borde derecho');
      expect(valorLargo.right, lessThanOrEqualTo(480.0));
      expect(valorLargo.height, valorCorto.height,
          reason: 'una sola línea: el ellipsis evita que el nombre largo '
              'estire la fila a lo alto y descuadre el resumen');
    });
  });

}
