// ============================================================================
// GRI — La cuenta de la mesa vista por el MESERO (plan 11-32).
//
// EL HUECO QUE CIERRA
// ---------------------------------------------------------------------------
// El aviso «la mesa 3 pidió la cuenta» llegaba SIN CIFRA. El mesero pulsaba
// «Entregar cuenta», la sesión se cerraba, la mesa se iba a limpieza… y él
// cobraba sin saber cuánto. La única forma de averiguarlo era abrir Firestore
// y sumar a mano.
//
// LO QUE SE PRUEBA AQUÍ
//   1. El CÁLCULO (`cuentaDeMesa`), con cifras literales escritas a mano.
//   2. La CONSULTA (`pedidosServidosMesaProvider`) contra fake_cloud_firestore:
//      qué pedidos entran y cuáles no.
//   3. La PANTALLA: el importe aparece en el aviso ANTES de cobrar, y el aviso
//      dice cuánto se queda fuera por no estar servido.
//
// ── LO QUE ESTE ARCHIVO NO PUEDE PROBAR ────────────────────────────────────
// `fake_cloud_firestore` no evalúa security rules NI valida índices
// compuestos. Que la consulta funcione aquí no dice nada sobre si Firestore la
// aceptaría. La paridad rules↔query la vigila `scripts/audit_indexes.mjs` y la
// prueba real es `scripts/probar_consultas_reales.mjs` contra `p-gri-b5b40`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/format.dart';
import 'package:gri_panel_admin/features/cocina/cocina_screen.dart';
import 'package:gri_panel_admin/features/cocina/cuenta_mesa.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-003';
const _otraMesa = 'GRI-MESA-demo-002';

/// El importe TAL Y COMO lo escribe `formatCOP`: `es_CO` pone el símbolo
/// DETRÁS y separa con ESPACIO DURO (U+00A0). Se escribe con el escape para
/// que se VEA en el código: con un espacio de teclado el finder no encuentra
/// nada y el fallo parece un bug de la pantalla. Las cifras siguen siendo
/// literales — este helper solo pone la puntuación.
String cop(String cifra) => '$cifra\u00A0\$';

PedidoStaff _p(
  String id,
  EstadoPedido estado,
  int total, {
  String mesaId = _mesa,
}) =>
    PedidoStaff(
      id: id,
      restauranteId: 'demo',
      mesaId: mesaId,
      sesionId: mesaId,
      mesaNumero: 3,
      estado: estado,
      total: total,
      notas: null,
      createdAt: DateTime(2026, 8, 20, 21, 0),
      items: const [],
      usuarioNombre: 'Carlos',
    );

Future<void> _sesion(
  FakeFirebaseFirestore db, {
  String mesaId = _mesa,
  String estado = 'activa',
  bool cuentaSolicitada = true,
  DateTime? inicioAt,
}) =>
    db.doc('sesiones/$mesaId').set({
      'restauranteId': 'demo',
      'mesaId': mesaId,
      'usuarioId': 'uid-cli',
      'estado': estado,
      'cuentaSolicitada': cuentaSolicitada,
      'inicioAt':
          Timestamp.fromDate(inicioAt ?? DateTime(2026, 8, 20, 20, 0)),
    });

Future<String> _pedidoDoc(
  FakeFirebaseFirestore db, {
  required String estado,
  required int total,
  String mesaId = _mesa,
  DateTime? createdAt,
  String restauranteId = 'demo',
}) =>
    db.collection('pedidos').add({
      'restauranteId': restauranteId,
      'mesaId': mesaId,
      'sesionId': mesaId,
      'usuarioId': 'uid-cli',
      'clienteNombre': 'Carlos',
      'estado': estado,
      'items': const [
        {
          'productoId': 'p1',
          'nombre': 'Pizza',
          'precio': 25000,
          'cantidad': 1,
        }
      ],
      'total': total,
      'createdAt':
          Timestamp.fromDate(createdAt ?? DateTime(2026, 8, 20, 21, 0)),
      'updatedAt': FieldValue.serverTimestamp(),
    }).then((r) => r.id);

ProviderContainer _container(FakeFirebaseFirestore db) {
  final c = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    claimsProvider.overrideWith((ref) async => (role: 'mesero', rid: 'demo')),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Lee el provider RETENIENDOLO con un `listen`. Sin el listener, un provider
/// autoDispose se destruye en el mismo tick en que se pide y el `read` muere
/// con «disposed during loading state» — no es un fallo de la consulta.
Future<List<PedidoStaff>> _servidos(
  FakeFirebaseFirestore db, {
  String mesaId = _mesa,
}) async {
  final c = _container(db);
  final sub = c.listen(pedidosServidosMesaProvider(mesaId), (_, _) {});
  addTearDown(sub.close);
  return c.read(pedidosServidosMesaProvider(mesaId).future);
}

Widget _cocina(FakeFirebaseFirestore db) => ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider
            .overrideWith((ref) async => (role: 'mesero', rid: 'demo')),
      ],
      child: const MaterialApp(home: Scaffold(body: CocinaScreen())),
    );

void main() {
  // ══ 1. EL CÁLCULO ════════════════════════════════════════════════════════

  group('cuentaDeMesa — cifras literales', () {
    test('el total son solo los servidos: 32.000 + 18.000 = 50.000', () {
      final cuenta = cuentaDeMesa(
        mesaId: _mesa,
        servidos: [
          _p('a', EstadoPedido.servido, 32000),
          _p('b', EstadoPedido.servido, 18000),
        ],
        enCurso: [_p('c', EstadoPedido.enPreparacion, 25000)],
      );
      expect(cuenta.total, 50000);
      expect(cuenta.totalPendiente, 25000);
      expect(cuenta.hayPendientes, isTrue);
      expect(cuenta.pendientes.length, 1);
    });

    test('los pedidos de OTRA mesa no entran en esta cuenta', () {
      final cuenta = cuentaDeMesa(
        mesaId: _mesa,
        servidos: [
          _p('mio', EstadoPedido.servido, 10000),
          _p('ajeno', EstadoPedido.servido, 90000, mesaId: _otraMesa),
        ],
        enCurso: [
          _p('ajeno2', EstadoPedido.enviado, 70000, mesaId: _otraMesa),
        ],
      );
      expect(cuenta.total, 10000);
      expect(cuenta.totalPendiente, 0);
      expect(cuenta.hayPendientes, isFalse);
    });

    test('un rechazado que llegue por la cola no se cobra ni se anuncia', () {
      final cuenta = cuentaDeMesa(
        mesaId: _mesa,
        servidos: [_p('a', EstadoPedido.servido, 10000)],
        enCurso: [_p('r', EstadoPedido.rechazado, 40000)],
      );
      expect(cuenta.total, 10000);
      expect(cuenta.totalPendiente, 0);
    });

    test('mesa sin nada servido: total 0 y la cuenta no es cobrable', () {
      final cuenta = cuentaDeMesa(
        mesaId: _mesa,
        servidos: const [],
        enCurso: [_p('c', EstadoPedido.enviado, 25000)],
      );
      expect(cuenta.total, 0);
      expect(cuenta.totalPendiente, 25000);
      expect(cuenta.vacia, isFalse);
    });

    test('las dos apps dan el MISMO número para el mismo caso', () {
      // Vector idéntico al de `app_cliente/test/pedidos/cuenta_calculo_test`:
      // 32.000 + 18.000 servidos, 25.000 en preparación, 40.000 rechazado.
      // La regla vive duplicada (las apps no comparten paquete) y esto es lo
      // que detecta que una de las dos copias derive.
      final cuenta = cuentaDeMesa(
        mesaId: _mesa,
        servidos: [
          _p('a', EstadoPedido.servido, 32000),
          _p('b', EstadoPedido.servido, 18000),
        ],
        enCurso: [
          _p('c', EstadoPedido.enPreparacion, 25000),
          _p('d', EstadoPedido.rechazado, 40000),
        ],
      );
      expect(cuenta.total, 50000);
      expect(cuenta.totalPendiente, 25000);
    });
  });

  // ══ 2. LA CONSULTA ═══════════════════════════════════════════════════════

  group('pedidosServidosMesaProvider', () {
    test('solo trae los SERVIDOS de ESA mesa', () async {
      final db = await buildFakeFirestoreConSeed();
      await _sesion(db);
      await _pedidoDoc(db, estado: 'servido', total: 32000);
      await _pedidoDoc(db, estado: 'servido', total: 18000);
      await _pedidoDoc(db, estado: 'en_preparacion', total: 25000);
      await _pedidoDoc(db, estado: 'rechazado', total: 40000);
      await _pedidoDoc(db,
          estado: 'servido', total: 90000, mesaId: _otraMesa);

      final servidos = await _servidos(db);

      expect(servidos.map((p) => p.total).toList()..sort(), [18000, 32000]);
    });

    test('los pedidos de la VISITA ANTERIOR a esa mesa no entran', () async {
      // `sesiones/{mesaId}` se REUTILIZA (tx.set con doc ID determinista): los
      // pedidos viejos conservan el mismo sesionId. Cobrarlos sería cobrarle
      // al comensal de ahora la cena del comensal de antes.
      final db = await buildFakeFirestoreConSeed();
      await _sesion(db, inicioAt: DateTime(2026, 8, 20, 20, 0));
      await _pedidoDoc(db,
          estado: 'servido',
          total: 99000,
          createdAt: DateTime(2026, 8, 13, 21, 0));
      await _pedidoDoc(db,
          estado: 'servido',
          total: 30000,
          createdAt: DateTime(2026, 8, 20, 20, 30));

      final servidos = await _servidos(db);

      expect(servidos.map((p) => p.total).toList(), [30000]);
    });

    test('los pedidos de OTRO restaurante nunca aparecen (tenant)', () async {
      final db = await buildFakeFirestoreConSeed();
      await _sesion(db);
      await _pedidoDoc(db, estado: 'servido', total: 12000);
      await _pedidoDoc(db,
          estado: 'servido', total: 77000, restauranteId: 'norte');

      final servidos = await _servidos(db);

      expect(servidos.map((p) => p.total).toList(), [12000]);
    });
  });

  // ══ 3. LA PANTALLA ═══════════════════════════════════════════════════════

  group('el aviso de cuenta lleva el importe', () {
    testWidgets('el mesero ve cuánto cobrar ANTES de entregar la cuenta',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
      await _sesion(db);
      await _pedidoDoc(db, estado: 'servido', total: 32000);
      await _pedidoDoc(db, estado: 'servido', total: 18000);

      await tester.pumpWidget(_cocina(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 mesa pidió la cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Mesa 3'), findsOneWidget);
      // 32.000 + 18.000, literal. Si se sumara mal, o si el importe no
      // llegara, esta línea cae.
      expect(find.text(cop('50.000')), findsOneWidget);
    });

    testWidgets('avisa de lo que NO se cobra por no estar servido',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
      await _sesion(db);
      await _pedidoDoc(db, estado: 'servido', total: 20000);
      await _pedidoDoc(db, estado: 'en_preparacion', total: 15000);

      await tester.pumpWidget(_cocina(db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 mesa pidió la cuenta'));
      await tester.pumpAndSettle();

      expect(find.text(cop('20.000')), findsOneWidget);
      // Cerrar la sesión con un plato en el fuego significa que ese plato no
      // se cobra NUNCA. El mesero tiene que saberlo antes de pulsar.
      expect(
        find.textContaining('1 pedido sin servir'),
        findsOneWidget,
      );
      expect(find.textContaining(cop('15.000')), findsOneWidget);
    });

    testWidgets('sin nada servido el importe es 0 y se dice', (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
      await _sesion(db);
      await _pedidoDoc(db, estado: 'en_preparacion', total: 25000);

      await tester.pumpWidget(_cocina(db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 mesa pidió la cuenta'));
      await tester.pumpAndSettle();

      expect(find.text(cop('0')), findsOneWidget);
      expect(find.textContaining('1 pedido sin servir'), findsOneWidget);
    });

    testWidgets('al entregar, el snackbar repite el importe cobrado',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
      await _sesion(db);
      await _pedidoDoc(db, estado: 'servido', total: 74000);

      await tester.pumpWidget(_cocina(db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 mesa pidió la cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mesa 3'));
      await tester.pumpAndSettle();

      // El flujo NO cambia: sigue cerrando la sesión y mandando la mesa a
      // limpieza (11-32 añade el importe, no toca `entregarCuenta`).
      expect(
        (await db.doc('sesiones/$_mesa').get()).data()?['estado'],
        'cerrada',
      );
      expect(
        (await db.doc('mesas/$_mesa').get()).data()?['estado'],
        'limpieza',
      );
      // Y la última vez que la cifra se ve es en la confirmación.
      expect(find.textContaining(cop('74.000')), findsOneWidget);
    });
  });
}
