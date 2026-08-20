// ============================================================================
// GRI — EL RECIBO DEL COBRO NO PUEDE LLEVAR UNA CIFRA INVENTADA (plan 11-33).
//
// Este es el instante más delicado del panel. El mesero toca la fila de una
// mesa que pidió la cuenta y pasan tres cosas seguidas:
//
//   1. se lee el importe (`_importeMesa`, con `read`, no `watch`);
//   2. `entregarCuenta` cierra la sesión y manda la mesa a limpieza;
//   3. un snackbar hace de recibo: «cuenta entregada por N».
//
// El importe se leía con `.value ?? const []`, así que un listener DENEGADO
// daba lista vacía, `cuentaDeMesa` sumaba 0 y el recibo afirmaba
// «cuenta entregada por 0 $». Con la sesión ya cerrada detrás y sin forma de
// deshacerlo: el aviso desaparece y con él la fila que mostraba la cifra.
//
// Es el mismo defecto que la fila (cubierto en `errores_de_stream_test.dart`)
// pero en el punto donde más caro sale, y por un camino distinto —`read` en
// vez de `watch`—, así que necesita su propio caso: arreglar la fila no
// arreglaba esto.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/async_fallo.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/cocina/cocina_screen.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-003';

/// El importe cero TAL Y COMO lo escribe `formatCOP`: el locale `es_CO` pone
/// el símbolo detrás y separa con ESPACIO DURO. Se escribe con el escape
///   VISIBLE para que nadie se pelee con un carácter invisible (lección
/// de 11-32: el diff decía `0 $` / `0 $`, idénticos a la vista).
const cero = '0 \$';

String _texto(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('con el importe ilegible el recibo NO dice «entregada por 0»',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
    await db.doc('sesiones/$_mesa').set({
      'restauranteId': 'demo',
      'mesaId': _mesa,
      'usuarioId': 'uid-cli',
      'estado': 'activa',
      'cuentaSolicitada': true,
      'inicioAt': DateTime(2026, 8, 20, 19, 30),
    });

    await tester.pumpWidget(ProviderScope(
      // La política real de producción: sin ella el provider pasaría ~38 s en
      // AsyncLoading y el caso no llegaría a ver el estado de error.
      retry: reintentoGri,
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider
            .overrideWith((ref) async => (role: 'mesero', rid: 'demo')),
        pedidosServidosMesaProvider(_mesa).overrideWith(
            (ref) => Stream<List<PedidoStaff>>.error(FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                ))),
      ],
      child: const MaterialApp(home: Scaffold(body: CocinaScreen())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Abrir la hoja de cobro y tocar la mesa: es el gesto real del mesero.
    await tester.tap(find.textContaining('pidió la cuenta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Mesa 3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final texto = _texto(tester);
    expect(texto, isNot(contains('entregada por $cero')),
        reason: 'un recibo con una cifra inventada es peor que uno sin cifra');
    expect(texto, contains('NO pudimos calcular el importe'),
        reason: 'la sesión ya se cerró: callar deja al mesero sin cobrar y '
            'sin saber que no lo sabemos');
  });

  testWidgets('con el importe legible el recibo SÍ lleva la cifra',
      (tester) async {
    // La contraparte. Sin este caso, un cambio que hiciera que el recibo
    // NUNCA llevara importe pasaría en verde con el caso de arriba solo.
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
    await db.doc('sesiones/$_mesa').set({
      'restauranteId': 'demo',
      'mesaId': _mesa,
      'usuarioId': 'uid-cli',
      'estado': 'activa',
      'cuentaSolicitada': true,
      'inicioAt': DateTime(2026, 8, 20, 19, 30),
    });
    await db.collection('pedidos').add({
      'restauranteId': 'demo',
      'mesaId': _mesa,
      'sesionId': _mesa,
      'usuarioId': 'uid-cli',
      'clienteNombre': 'Carlos',
      'estado': 'servido',
      'items': [
        {'productoId': 'p1', 'nombre': 'Pasta', 'precio': 32000, 'cantidad': 1},
      ],
      'total': 32000,
      'createdAt': DateTime(2026, 8, 20, 19, 45),
      'updatedAt': DateTime(2026, 8, 20, 19, 45),
    });

    await tester.pumpWidget(ProviderScope(
      retry: reintentoGri,
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider
            .overrideWith((ref) async => (role: 'mesero', rid: 'demo')),
      ],
      child: const MaterialApp(home: Scaffold(body: CocinaScreen())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.textContaining('pidió la cuenta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Mesa 3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Cifra LITERAL, no `formatCOP(32000)`: comparar contra el helper sería
    // comparar la pantalla consigo misma (los once tests de dinero del repo
    // hacen eso y pasarían con cualquier formato — nota de 11-32).
    expect(_texto(tester), contains('entregada por 32.000 \$'));
  });
}
