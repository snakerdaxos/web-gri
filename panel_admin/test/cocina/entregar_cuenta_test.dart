import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/cocina/cocina_screen.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';

import '../helpers/firebase_fakes.dart';

/// Suite 10-07 (Rule 2): "Entregar cuenta" — el cierre de sesión que el
/// flujo e2e exige (PAGO-04 manual, pagos diferidos v1). `entregarCuenta`
/// cierra `sesiones/{mesaId}` (activa→cerrada) y pasa la mesa ocupada→
/// limpieza EN UNA tx; el badge de cocina desaparece SOLO (avisoCuenta
/// filtra por sesión activa). Sin esto el cliente jamás podría calificar
/// (su tx exige sesión cerrada) y el promedio del restaurante nunca se
/// actualizaría — el smoke A-P de 10-07 depende de este ciclo.

/// Sesión de mesa (doc shape 10-04: sesiones/{mesaId}).
Future<void> _sesion(
  FakeFirebaseFirestore db, {
  required String mesaId,
  required String estado,
  bool cuentaSolicitada = false,
}) {
  return db.doc('sesiones/$mesaId').set({
    'restauranteId': 'demo',
    'mesaId': mesaId,
    'usuarioId': 'uid-cli',
    'estado': estado,
    'cuentaSolicitada': cuentaSolicitada,
    if (cuentaSolicitada) 'cuentaPedidaAt': null,
    'inicioAt': DateTime(2026, 8, 16, 19, 30),
  });
}

Future<Map<String, dynamic>?> _doc(FakeFirebaseFirestore db, String path) async =>
    (await db.doc(path).get()).data();

Widget _cocina(FakeFirebaseFirestore db, {String role = 'mesero'}) {
  // Scaffold envolvente: en producción lo provee el AppShell (el snackbar
  // de entrega necesita un Scaffold al que presentarse).
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith((ref) async => (role: role, rid: 'demo')),
    ],
    child: const MaterialApp(home: Scaffold(body: CocinaScreen())),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('(a) data: sesión activa+ocupada → cerrada y mesa a limpieza (una tx)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-003').update({'estado': 'ocupada'});
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: true);

    await entregarCuenta(db, mesaId: 'GRI-MESA-demo-003');

    expect((await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'],
        'cerrada');
    expect(
        (await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'limpieza');
  });

  test('(b) data: sesión ya cerrada → StateError SIN escribir la mesa',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-003').update({'estado': 'ocupada'});
    await _sesion(db, mesaId: 'GRI-MESA-demo-003', estado: 'cerrada');

    await expectLater(
        entregarCuenta(db, mesaId: 'GRI-MESA-demo-003'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'contains sesión',
                contains('ya no está activa'))));

    // Nada cambió: la carrera la ganó otro staff (o ya se entregó).
    expect((await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'ocupada');
    expect((await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'],
        'cerrada');
  });

  test('(c) data: mesa NO ocupada → la sesión cierra igual y la mesa queda',
      () async {
    final db = await buildFakeFirestoreConSeed();
    // Mesa sigue 'disponible' (edge: sesión activa con mesa en otro estado).
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: true);

    await entregarCuenta(db, mesaId: 'GRI-MESA-demo-003');

    expect((await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'],
        'cerrada');
    expect(
        (await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'disponible');
  });

  testWidgets(
      '(d) widget: badge → sheet "Entregar cuenta" → sesión cerrada + mesa '
      'limpieza y el aviso DESAPARECE del header en vivo', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-003').update({'estado': 'ocupada'});
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: true);

    await tester.pumpWidget(_cocina(db));
    await tester.pumpAndSettle();

    // Badge en vivo (sesión activa con cuentaSolicitada).
    expect(find.text('1 mesa pidió la cuenta'), findsOneWidget);

    // Tap → sheet con la mesa y la acción.
    await tester.tap(find.text('1 mesa pidió la cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mesas que pidieron la cuenta'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
    expect(find.textContaining('Entregar cuenta cierra la sesión'),
        findsOneWidget);

    // Entregar → sheet cierra, snackbar y el badge DESAPARECE solo
    // (avisoCuenta re-emite: la sesión ya no está activa).
    await tester.tap(find.text('Mesa 3'));
    await tester.pumpAndSettle();

    expect(find.text('Mesas que pidieron la cuenta'), findsNothing);
    expect(find.text('1 mesa pidió la cuenta'), findsNothing);
    expect(find.textContaining('cuenta entregada'), findsOneWidget);

    // Estado final en Firestore (lo que el cliente verá en su stream).
    expect((await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'],
        'cerrada');
    expect(
        (await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'limpieza');
  });

  // ══════════════════════════════════════════════════════════════════════
  // LA CARRERA CON EL PEDIDO DE ÚLTIMA HORA (11-34)
  //
  // El mesero pulsa «entregar cuenta» en el MISMO instante en que el comensal
  // manda otro pedido. Hasta 11-34 daba igual: `entregarCuenta` miraba solo
  // `estado == 'activa'` y cerraba la sesión, dejando el pedido nuevo dentro
  // de una sesión cerrada — sin cobrar y sin poder cobrarse nunca, porque
  // `cerrada` es terminal en las rules.
  //
  // La señal de que la carrera se perdió es `cuentaSolicitada == false` con la
  // sesión todavía activa: es exactamente lo que escribe `crearPedido` del
  // comensal al reabrir la cuenta. La comprobación va DENTRO de la
  // transacción, sobre el snapshot leído en ella, que es lo que la convierte
  // en una barrera y no en un vistazo a un modelo viejo.
  // ══════════════════════════════════════════════════════════════════════

  test('(e) carrera: la cuenta se REABRIÓ → CuentaReabiertaException y NADA '
      'se escribe', () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-003').update({'estado': 'ocupada'});
    // Sesión ACTIVA pero con la bandera ya apagada: el comensal ganó.
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: false);

    await expectLater(
      entregarCuenta(db, mesaId: 'GRI-MESA-demo-003'),
      throwsA(isA<CuentaReabiertaException>()),
    );

    // La sesión sigue viva y la mesa ocupada: el comensal puede terminar de
    // comer y volver a pedir la cuenta.
    expect((await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'], 'activa');
    expect((await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'ocupada');
  });

  test('(f) el mensaje de la reapertura NO se confunde con el de sesión '
      'cerrada', () async {
    // Los dos desenlaces son distintos y dicen cosas contrarias: en uno la
    // sesión ya no existe, en el otro sigue viva con un plato más. Aplastarlos
    // contra el mismo StateError mandaría al mesero a buscar el problema
    // donde no está.
    final db = await buildFakeFirestoreConSeed();
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: false);

    await expectLater(
      entregarCuenta(db, mesaId: 'GRI-MESA-demo-003'),
      throwsA(isA<CuentaReabiertaException>()
          .having((e) => e.message, 'mensaje', contains('pidió algo más'))),
    );
    // Y NO es un StateError: la rama del catch de la pantalla los separa.
    await expectLater(
      entregarCuenta(db, mesaId: 'GRI-MESA-demo-003'),
      throwsA(isNot(isA<StateError>())),
    );
  });

  test('(g) el cierre administrativo sigue siendo posible con '
      'exigirCuentaSolicitada: false', () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-003').update({'estado': 'ocupada'});
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: false);

    await entregarCuenta(db,
        mesaId: 'GRI-MESA-demo-003', exigirCuentaSolicitada: false);

    expect(
        (await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'], 'cerrada');
    expect((await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'limpieza');
  });

  testWidgets(
      '(h) widget: si el comensal reabre la cuenta mientras el sheet está '
      'abierto, el mesero recibe la explicación y la fila desaparece sola',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/GRI-MESA-demo-003').update({'estado': 'ocupada'});
    await _sesion(db,
        mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: true);

    await tester.pumpWidget(_cocina(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 mesa pidió la cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mesa 3'), findsOneWidget);

    // ── El comensal manda un café: la bandera se apaga (esto es lo que hace
    //    `crearPedido` en app_cliente, dentro de su transacción).
    await db.doc('sesiones/GRI-MESA-demo-003').update({
      'cuentaSolicitada': false,
      'cuentaPedidaAt': null,
    });
    await tester.pumpAndSettle();

    // El mesero pulsa igualmente (tenía el sheet abierto desde antes).
    await tester.tap(find.text('Mesa 3'));
    await tester.pumpAndSettle();

    expect(find.textContaining('la cuenta se reabrió'), findsOneWidget);
    expect(find.textContaining('cuenta entregada'), findsNothing);

    // La sesión sigue viva: el comensal no se ha quedado sin poder pagar.
    expect((await _doc(db, 'sesiones/GRI-MESA-demo-003'))?['estado'], 'activa');
    expect((await _doc(db, 'mesas/GRI-MESA-demo-003'))?['estado'], 'ocupada');
    // Y el aviso ya no está: el badge lo quita `avisoCuenta` por sí solo.
    expect(find.text('1 mesa pidió la cuenta'), findsNothing);
  });
}
