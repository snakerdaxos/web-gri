// ============================================================================
// GRI — `pedidosSessionProvider`: la QUERY, no la pantalla (plan 11-28).
//
// POR QUÉ EXISTE ESTE ARCHIVO
// ---------------------------------------------------------------------------
// Los tests de pedidos que ya había (`estado_test.dart`) sobreescriben
// `pedidosSessionProvider` con un `Stream.value([...])`: prueban la PANTALLA
// dando la lista por buena. Nadie ejercitaba la CONSULTA. Por eso, cuando en
// producción el listener del cliente se quedó denegado —query sin
// `where('usuarioId')` frente a una regla que exige `usuarioId == uid`— la
// suite siguió en verde: 345 tests y ni uno tocaba la query real.
//
// Aquí se monta el provider DE VERDAD contra `fake_cloud_firestore`, con los
// mismos overrides que usa la app (`firestoreProvider` + `firebaseAuthProvider`)
// y una sesión abierta con `abrirSesion()`.
//
// ── LO QUE ESTE TEST **NO** PUEDE PROBAR (leer antes de confiar) ────────────
// `fake_cloud_firestore` NO tiene motor de security rules. Que la query pase
// aquí no dice NADA sobre si Firestore la aceptaría: el bug de producción
// habría pasado este test igual de verde si solo comprobara "se ven mis
// pedidos". Lo que sí prueba es el efecto OBSERVABLE del filtro —que el pedido
// de otro comensal en la misma mesa no aparece—, que es lo que se rompería si
// alguien borra el `where`.
// La prueba de autorización vive en `scripts/test/rules/pedidos.test.mjs`
// (bloque «QUERY vs RULES»), contra el emulador y con las rules de verdad; y
// la comprobación estática, en `scripts/audit_indexes.mjs` (AUDIT 2/4).
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';
const _yo = 'test-uid'; // el uid que devuelve mockAuth()
const _otro = 'uid-del-comensal-anterior';

/// Un pedido en la mesa [_mesa] con `sesionId == mesaId` (así los escribe
/// `crearPedido`) a nombre de [uid].
Future<void> _pedido(
  FirebaseFirestore db, {
  required String uid,
  required String plato,
  required DateTime creado,
}) async {
  await db.collection('pedidos').add(<String, dynamic>{
    'restauranteId': 'demo',
    'mesaId': _mesa,
    'sesionId': _mesa,
    'usuarioId': uid,
    'clienteNombre': '',
    'estado': 'enviado',
    'items': [
      {'productoId': 'p1', 'nombre': plato, 'precio': 25000, 'cantidad': 1},
    ],
    'total': 25000,
    'createdAt': Timestamp.fromDate(creado),
    'updatedAt': Timestamp.fromDate(creado),
  });
}

void main() {
  testWidgets(
      'la sesión de la mesa se REUTILIZA: el cliente solo ve SUS pedidos, no los del comensal anterior',
      (tester) async {
    // `abrirSesion()` hace `tx.set(sesiones/{mesaId})`, así que el doc de
    // sesión —y con él el `sesionId` de los pedidos— es el MISMO para todos
    // los comensales que pasen por la mesa a lo largo del día. Sin el
    // `where('usuarioId')` de la query, el segundo vería lo que pidió el
    // primero.
    final db = await buildFakeFirestoreConSeed();
    await _pedido(db,
        uid: _otro,
        plato: 'Ajiaco del comensal anterior',
        creado: DateTime(2026, 8, 20, 12));
    await abrirSesion(db, uid: _yo, codigoQR: _mesa);
    await _pedido(db,
        uid: _yo, plato: 'Bandeja mia', creado: DateTime(2026, 8, 20, 13));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bandeja mia ×1'), findsOneWidget,
        reason: 'mi pedido de esta sesión sí se ve');
    expect(find.text('Ajiaco del comensal anterior ×1'), findsNothing,
        reason:
            'el where("usuarioId") deja fuera los pedidos de otro usuario con el MISMO sesionId');
  });

  testWidgets('con varios pedidos propios los muestra todos, el último arriba',
      (tester) async {
    // El provider pide `orderBy('createdAt')` ASC y la lista se invierte
    // client-side (`.reversed`): el más reciente encabeza la pantalla. Si
    // alguien cambia el sentido del orderBy para "aprovechar" otro índice,
    // este test lo nota.
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: _yo, codigoQR: _mesa);
    await _pedido(db,
        uid: _yo, plato: 'Primero pedido', creado: DateTime(2026, 8, 20, 13));
    await _pedido(db,
        uid: _yo, plato: 'Segundo pedido', creado: DateTime(2026, 8, 20, 14));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    ));
    await tester.pumpAndSettle();

    final primero = tester.getTopLeft(find.text('Primero pedido ×1')).dy;
    final segundo = tester.getTopLeft(find.text('Segundo pedido ×1')).dy;
    expect(segundo < primero, isTrue,
        reason: 'el pedido más reciente va arriba (orderBy ASC + reversed)');
  });

  testWidgets('sin usuario autenticado no hay consulta ni pedidos',
      (tester) async {
    // La query lleva el uid de Auth: sin sesión de usuario no se lanza. Sin
    // esta guarda, `uid` sería null y el `where` compararía contra null.
    final db = await buildFakeFirestoreConSeed();
    await _pedido(db,
        uid: _yo, plato: 'Bandeja mia', creado: DateTime(2026, 8, 20, 13));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth(signedIn: false)),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    ));
    // `pump()` y no `pumpAndSettle()`: sin sesión el provider no emite nunca y
    // la pantalla se queda en su `CircularProgressIndicator`, que es una
    // animación perpetua — `pumpAndSettle` no puede converger. Ese spinner
    // eterno del usuario sin sesión es comportamiento PREVIO a 11-28 (pasaba
    // igual con `sesion == null`) y queda anotado en deferred-items.md.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Bandeja mia ×1'), findsNothing);
  });
}
