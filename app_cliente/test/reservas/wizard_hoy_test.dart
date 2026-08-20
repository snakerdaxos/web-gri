// test/reservas/wizard_hoy_test.dart — el wizard deja de esconder el día de
// HOY (11-31).
//
// Hasta ahora `firstDate` era MAÑANA y hoy simplemente no se podía tocar. El
// usuario decidió el 2026-08-20: «sí [reservar el mismo día] pero con un
// margen de 4 horas, ya que no se puede reservar para la misma hora».
//
// Lo que este archivo custodia es la COHERENCIA entre las dos caras del
// margen dentro de la UI:
//
//   · qué días abre el calendario  (`firstDate`)
//   · qué horas ofrece el desplegable
//   · qué deja confirmar el botón
//
// Las tres salen de `slotRespetaMargen` (reserva_controller.dart). Un picker
// que ofrece una hora que el validador rechaza es la contradicción que hace
// perder el tiempo al usuario, así que aquí se comprueba de punta a punta:
// se elige la hora EN LA UI y se mira el doc que llega a Firestore.
//
// El reloj está FIJADO (`relojProvider`): sin eso estos casos pasarían o no
// según la hora a la que se corriera la suite.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/reloj.dart';
import 'package:gri_cliente/features/reservas/reserva_wizard_screen.dart';

import '../helpers/firebase_fakes.dart';

Widget _wrap(FakeFirebaseFirestore db, DateTime Function() reloj,
        {String nombre = 'Restaurante Demo GRI'}) =>
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        firestoreProvider.overrideWithValue(db),
        relojProvider.overrideWithValue(reloj),
      ],
      child: MaterialApp(
        home: ReservaWizardScreen(
          key: ValueKey(nombre),
          restauranteId: 'demo',
          restauranteNombre: nombre,
        ),
      ),
    );

/// Abre el calendario y acepta la fecha que el propio wizard propone
/// (= `firstDate`, porque `initialDate` arranca ahí).
Future<void> _aceptarFechaPropuesta(WidgetTester tester) async {
  await tester.tap(find.text('Elegir fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _abrirDesplegableDeHoras(WidgetTester tester) async {
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Elige una hora'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a las 14:30 el calendario YA abre en hoy y el desplegable empieza en '
      'las 19:00', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(
        _wrap(db, () => DateTime(2026, 8, 20, 14, 30), nombre: 'A'));
    await tester.pumpAndSettle();

    await _aceptarFechaPropuesta(tester);
    // El día de HOY según el reloj inyectado. Antes de este plan aquí salía
    // 2026-08-21: hoy no era seleccionable en absoluto.
    expect(find.text('2026-08-20'), findsOneWidget);

    await _abrirDesplegableDeHoras(tester);
    // 14:30 + 4 h = 18:30 → el primer slot en punto que cabe es el de las 19.
    expect(find.text('19:00'), findsWidgets);
    expect(find.text('20:00'), findsWidgets);
    expect(find.text('21:00'), findsWidgets);
    expect(find.text('18:00'), findsNothing);
    expect(find.text('12:00'), findsNothing);
    expect(find.text('17:00'), findsNothing);
  });

  testWidgets('a las 14:00 EN PUNTO el desplegable sí ofrece las 18:00',
      (tester) async {
    // El borde exacto de la regla: la igualdad cuenta. Un `>` en vez de un
    // `>=` en el filtro pone este caso rojo y el de arriba verde.
    final db = await buildFakeFirestoreConSeed();
    await tester
        .pumpWidget(_wrap(db, () => DateTime(2026, 8, 20, 14), nombre: 'B'));
    await tester.pumpAndSettle();

    await _aceptarFechaPropuesta(tester);
    await _abrirDesplegableDeHoras(tester);

    expect(find.text('18:00'), findsWidgets);
    expect(find.text('17:00'), findsNothing);
  });

  testWidgets(
      'a las 17:01 hoy ya no da de sí: el calendario abre en MAÑANA y ofrece '
      'la rejilla entera', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(
        _wrap(db, () => DateTime(2026, 8, 20, 17, 1), nombre: 'C'));
    await tester.pumpAndSettle();

    await _aceptarFechaPropuesta(tester);
    expect(find.text('2026-08-21'), findsOneWidget);

    await _abrirDesplegableDeHoras(tester);
    expect(find.text('12:00'), findsWidgets);
    expect(find.text('21:00'), findsWidgets);
  });

  testWidgets(
      'reservar para HOY desde la UI: el doc lleva la fecha de hoy y la mesa '
      'queda RESERVADA', (tester) async {
    // Esta es la primera vez que la rama `esHoy` del controller se ejecuta
    // DESDE EL PRODUCTO: hasta ahora era inalcanzable (SUMMARY 11-29).
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(
        _wrap(db, () => DateTime(2026, 8, 20, 14, 30), nombre: 'D'));
    await tester.pumpAndSettle();

    await _aceptarFechaPropuesta(tester);
    await _abrirDesplegableDeHoras(tester);
    await tester.tap(find.text('19:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar reserva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('¡Reserva confirmada! Mesa 1'), findsOneWidget);

    final docs = (await db.collection('reservas').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.first.data()['fechaStr'], '2026-08-20');
    expect(docs.first.data()['hora'], 19);
    // La reserva es de HOY, así que el estado de la mesa —que describe este
    // momento— sí se mueve.
    expect((await db.doc('mesas/GRI-MESA-demo-001').get()).data()!['estado'],
        'reservada');
  });

  testWidgets(
      'si el reloj corre y la hora elegida deja de cumplir el margen, el '
      'wizard lo dice y NO deja confirmar', (tester) async {
    // Escenario real: el usuario deja la app abierta. Es el único camino por
    // el que una hora ya ofrecida se queda sin margen, y el que demuestra que
    // el desplegable no es el único guard.
    var t = DateTime(2026, 8, 20, 15);
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db, () => t, nombre: 'E'));
    await tester.pumpAndSettle();

    await _aceptarFechaPropuesta(tester);
    await _abrirDesplegableDeHoras(tester);
    await tester.tap(find.text('20:00').last); // a las 15:00 quedan 5 h
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Confirmar reserva')).onPressed,
      isNotNull,
      reason: 'precondición: a las 15:00 las 20:00 sí se pueden confirmar',
    );

    // Pasan dos horas y media con la pantalla abierta.
    t = DateTime(2026, 8, 20, 17, 30);
    await tester.tap(find.text('Hora')); // onStepTapped → rebuild
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ya no cumple las 4 horas'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Confirmar reserva')).onPressed,
      isNull,
    );
    expect((await db.collection('reservas').get()).docs, isEmpty);
  });
}
