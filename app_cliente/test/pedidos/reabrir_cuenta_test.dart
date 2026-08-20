// ============================================================================
// GRI — REABRIR LA CUENTA (plan 11-34).
//
// EL BUG, reproducido por el usuario contra producción: pidió la cuenta,
// después pidió un café. El café se aceptó y pasó a preparación, pero no se
// sumó a la cuenta (solo se cobra lo `servido`) y el botón «Pedir la cuenta»
// ya no volvió, porque `cuentaSolicitada` seguía en true. La mesa quedaba en
// un estado del que no se salía: el comensal no podía volver a pedir la
// cuenta y el mesero tenía en su lista un importe viejo.
//
// DECISIÓN DEL USUARIO (2026-08-20): se REABRE la cuenta. Crear un pedido con
// la sesión en `cuentaSolicitada: true` apaga la bandera EN LA MISMA
// transacción.
//
// LO QUE ESTA SUITE CUBRE, en dos capas:
//   · DOMINIO — `crearPedido` apaga la bandera, borra el timestamp, no toca
//     nada más, y NO escribe cuando la bandera ya estaba apagada.
//   · PANTALLA — el botón vuelve. Esto NO es redundante con lo anterior: la
//     pantalla tenía un espejo local (`_cuentaYaPedida`) que era un latch de
//     una sola dirección y habría tapado el arreglo del dominio entero.
//
// LO QUE NO CUBRE: que las rules lo permitan. Eso vive en
// `scripts/test/rules/sesiones.test.mjs` → «update — reabrir la cuenta»,
// contra el emulador, porque `fake_cloud_firestore` NO evalúa firestore.rules
// (aquí toda escritura pasa). Decirlo importa: esta suite en verde con las
// rules mal seguiría en verde.
// ============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-003';

/// Mesa del seed compartido (`buildFakeFirestoreConSeed`), la que usa el
/// recorrido completo con `abrirSesion`.
const _mesaSeed = 'GRI-MESA-demo-001';
const _uid = 'test-uid';

/// Instante FIJO. No se calcula con `DateTime.now()` ni con la misma
/// expresión que usa el código: 11-31 encontró cinco archivos de test que
/// dependían en silencio del reloj de la máquina y se habrían puesto rojos a
/// partir de las 19:01.
final _inicio = DateTime(2026, 8, 20, 20, 0);
final _pedidaA = DateTime(2026, 8, 20, 21, 14);

Future<FakeFirebaseFirestore> _db({
  required bool cuentaSolicitada,
  String estadoSesion = 'activa',
}) async {
  final db = FakeFirebaseFirestore();
  await db.doc('mesas/$_mesa').set({
    'restauranteId': 'demo',
    'numero': 3,
    'capacidad': 4,
    'estado': 'ocupada',
  });
  await db.doc('sesiones/$_mesa').set({
    'restauranteId': 'demo',
    'mesaId': _mesa,
    'usuarioId': _uid,
    'estado': estadoSesion,
    'cuentaSolicitada': cuentaSolicitada,
    'cuentaPedidaAt': cuentaSolicitada ? _pedidaA : null,
    'inicioAt': _inicio,
  });
  return db;
}

const _items = [
  PedidoItem(productoId: 'p-cafe', nombre: 'Café', precio: 4500, cantidad: 1),
];

Future<Map<String, dynamic>?> _sesionDoc(FakeFirebaseFirestore db) async =>
    (await db.doc('sesiones/$_mesa').get()).data();

// --- capa PANTALLA ----------------------------------------------------------

SesionMesa _sesion({required bool cuentaSolicitada}) => SesionMesa(
      id: _mesa,
      restauranteId: 'demo',
      mesaId: _mesa,
      usuarioId: _uid,
      estado: 'activa',
      cuentaSolicitada: cuentaSolicitada,
      inicioAt: _inicio,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaNumero: 3,
    );

Pedido _pedido(String id, String estado) => Pedido(
      id: id,
      restauranteId: 'demo',
      mesaId: _mesa,
      sesionId: _mesa,
      usuarioId: _uid,
      estado: estado,
      total: 25000,
      createdAt: _inicio.add(const Duration(minutes: 10)),
      items: const [
        PedidoItem(
            productoId: 'p1', nombre: 'Bandeja paisa', precio: 25000,
            cantidad: 1),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dominio — crearPedido apaga la bandera', () {
    test('con la cuenta PEDIDA: el pedido nuevo la apaga y borra el timestamp',
        () async {
      final db = await _db(cuentaSolicitada: true);

      await crearPedido(db, uid: _uid, mesaCodigo: _mesa, items: _items);

      final s = await _sesionDoc(db);
      expect(s?['cuentaSolicitada'], false,
          reason: 'la bandera tiene que quedar apagada tras pedir de nuevo');
      expect(s?['cuentaPedidaAt'], isNull,
          reason: 'un timestamp viejo con la bandera apagada es el estado '
              'inconsistente que se viene a evitar');
    });

    test('el pedido SÍ se crea (apagar la bandera no lo impide)', () async {
      final db = await _db(cuentaSolicitada: true);

      final id = await crearPedido(
          db, uid: _uid, mesaCodigo: _mesa, items: _items);

      final pedido = await db.doc('pedidos/$id').get();
      expect(pedido.exists, isTrue);
      expect(pedido.data()?['estado'], 'enviado');
      expect(pedido.data()?['total'], 4500);
    });

    test('la sesión NO cambia de estado ni de dueño al reabrir la cuenta',
        () async {
      // Las rules solo admiten `hasOnly(['cuentaSolicitada','cuentaPedidaAt'])`
      // en esta rama: cualquier campo de más haría fallar la transacción
      // ENTERA en producción, y el pedido tampoco se crearía.
      final db = await _db(cuentaSolicitada: true);

      await crearPedido(db, uid: _uid, mesaCodigo: _mesa, items: _items);

      final s = await _sesionDoc(db);
      expect(s?['estado'], 'activa');
      expect(s?['usuarioId'], _uid);
      expect((s?['inicioAt'] as Timestamp).toDate(), _inicio);
      expect(s?['restauranteId'], 'demo');
      expect(s?.containsKey('updatedAt'), isFalse,
          reason: 'colar updatedAt rompería el hasOnly de la regla');
    });

    test('con la cuenta NO pedida: la bandera se queda como estaba', () async {
      final db = await _db(cuentaSolicitada: false);

      await crearPedido(db, uid: _uid, mesaCodigo: _mesa, items: _items);

      final s = await _sesionDoc(db);
      expect(s?['cuentaSolicitada'], false);
      expect(s?['cuentaPedidaAt'], isNull);
    });

    test('si el pedido FALLA, la solicitud de cuenta sigue en pie', () async {
      // Mismo commit o ninguno: la tx aborta antes de escribir nada porque la
      // sesión no es del emisor. Sin la atomicidad, el comensal podría perder
      // su solicitud de cuenta por un pedido que nunca llegó a existir.
      final db = await _db(cuentaSolicitada: true);

      await expectLater(
        crearPedido(db, uid: 'otro-uid', mesaCodigo: _mesa, items: _items),
        throwsA(isA<PedidoException>()),
      );

      final s = await _sesionDoc(db);
      expect(s?['cuentaSolicitada'], true);
      expect((s?['cuentaPedidaAt'] as Timestamp).toDate(), _pedidaA);
    });
  });

  group('pantalla — el botón «Pedir la cuenta» VUELVE', () {
    /// Bombea la pantalla con un stream de sesión CONTROLADO, para poder
    /// emitir la reapertura a mano.
    Future<void> montar(
      WidgetTester tester,
      Stream<SesionMesa?> sesiones,
    ) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sesionActualProvider.overrideWith((ref) => sesiones),
          pedidosSessionProvider
              .overrideWith((ref) => Stream.value([_pedido('a', 'servido')])),
        ],
        child: const MaterialApp(home: PedidoEstadoScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('con la cuenta pedida el botón NO está', (tester) async {
      await montar(
          tester, Stream.value(_sesion(cuentaSolicitada: true)));
      expect(find.text('Pedir la cuenta'), findsNothing);
    });

    testWidgets('al reabrirse la cuenta el botón REAPARECE', (tester) async {
      final ctrl = StreamController<SesionMesa?>();
      addTearDown(ctrl.close);

      await montar(tester, ctrl.stream);
      ctrl.add(_sesion(cuentaSolicitada: true));
      await tester.pumpAndSettle();
      expect(find.text('Pedir la cuenta'), findsNothing,
          reason: 'punto de partida: la cuenta está pedida');

      // El comensal pide un café → crearPedido apaga la bandera → el stream
      // del doc de sesión emite con la bandera en false.
      ctrl.add(_sesion(cuentaSolicitada: false));
      await tester.pumpAndSettle();

      expect(find.text('Pedir la cuenta'), findsOneWidget,
          reason: 'este es el bug: sin la reapertura el botón no volvía');
    });

    testWidgets(
        'RECORRIDO COMPLETO sobre la base real: pulsar → pedir un café → el '
        'botón vuelve', (tester) async {
      // EL CASO QUE DE VERDAD IMPORTA, y sin ningún stream inventado: base
      // fake, sesión real abierta con `abrirSesion`, y los providers de
      // verdad. `_cuentaYaPedida` se enciende al pulsar el botón y era un
      // latch de una sola dirección: aunque el dominio apagase la bandera,
      // la pantalla seguía escondiendo el botón. Con overrides de stream ese
      // fallo se podría no ver; aquí no hay dónde esconderlo.
      final db = await buildFakeFirestoreConSeed();
      await abrirSesion(db, uid: 'test-uid', codigoQR: _mesaSeed);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseAuthProvider.overrideWithValue(mockAuth()),
        ],
        child: const MaterialApp(home: PedidoEstadoScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pedir la cuenta'), findsOneWidget);

      // 1) El comensal pulsa. El espejo local se enciende y el botón se va.
      await tester.tap(find.text('Pedir la cuenta'));
      await tester.pumpAndSettle();
      expect((await db.doc('sesiones/$_mesaSeed').get())
          .data()!['cuentaSolicitada'], true);
      expect(find.text('Pedir la cuenta'), findsNothing);
      expect(find.text('Cuenta solicitada'), findsOneWidget);

      // 2) Pide un café. La MISMA transacción del pedido apaga la bandera.
      await crearPedido(
          db, uid: 'test-uid', mesaCodigo: _mesaSeed, items: _items);
      await tester.pumpAndSettle();

      expect((await db.doc('sesiones/$_mesaSeed').get())
          .data()!['cuentaSolicitada'], false);
      expect(find.text('Pedir la cuenta'), findsOneWidget,
          reason: 'el espejo local tiene que apagarse con la reapertura; '
              'este es el bug entero');
      expect(find.text('Cuenta solicitada'), findsNothing);

      // 3) Y se puede volver a pedir: el ciclo se cierra.
      await tester.tap(find.text('Pedir la cuenta'));
      await tester.pumpAndSettle();
      expect((await db.doc('sesiones/$_mesaSeed').get())
          .data()!['cuentaSolicitada'], true);
    });
  });
}
