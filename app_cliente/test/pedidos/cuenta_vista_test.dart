// ============================================================================
// GRI — La cuenta EN PANTALLA (plan 11-32): lo que el comensal lee.
//
// `cuenta_calculo_test.dart` prueba la aritmética. Este archivo prueba lo
// único que evita que el cliente pague una cifra y vea otra: que la pantalla
// DISTINGA lo que ya se cobra de lo que sigue en la cocina.
//
// La regla del usuario («solo se cobra lo servido») tiene una consecuencia
// incómoda: el total SUBE solo mientras haya platos en curso. Un total a
// secas sería una cifra que se mueve sin explicación. Por eso lo que se
// afirma aquí no es "aparece el total", sino que junto al total aparece
// SIEMPRE el aviso de lo que falta, con su importe y su número de pedidos, y
// que cada tarjeta dice si ESE pedido se cobra o no.
//
// Patrón de montaje: overrides de `sesionActualProvider` y
// `pedidosSessionProvider` (el mismo de `estado_test.dart`). La CONSULTA real
// vive en `query_sesion_test.dart` y la aritmética en `cuenta_calculo_test`.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/format.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

/// El importe TAL Y COMO lo escribe `formatCOP`: el locale `es_CO` pone el
/// simbolo DETRAS y separa con ESPACIO DURO (U+00A0). Se escribe aqui con el
/// escape \u00A0 para que sea VISIBLE en el codigo: con un espacio de teclado
/// el finder NO encuentra nada y el fallo parece un bug de la pantalla.
///
/// Las CIFRAS siguen siendo literales escritas a mano -- este helper solo
/// pone la puntuacion, no calcula ningun total.
String cop(String cifra) => '$cifra\u00A0\$';

final _inicio = DateTime(2026, 8, 20, 20, 0);

SesionMesa _sesion({
  bool cuentaSolicitada = false,
  String estado = 'activa',
}) =>
    SesionMesa(
      id: 'GRI-MESA-demo-003',
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-003',
      usuarioId: 'test-uid',
      estado: estado,
      cuentaSolicitada: cuentaSolicitada,
      inicioAt: _inicio,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaNumero: 3,
    );

Pedido _p(
  String id,
  String estado,
  int total, {
  DateTime? createdAt,
}) =>
    Pedido(
      id: id,
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-003',
      sesionId: 'GRI-MESA-demo-003',
      usuarioId: 'test-uid',
      estado: estado,
      total: total,
      createdAt: createdAt ?? _inicio.add(const Duration(minutes: 10)),
      items: const [
        PedidoItem(
            productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 1),
      ],
    );

Widget _wrap(List<Pedido> pedidos, {SesionMesa? sesion}) => ProviderScope(
      overrides: [
        sesionActualProvider.overrideWith((ref) => Stream.value(
              sesion ?? _sesion(),
            )),
        pedidosSessionProvider.overrideWith((ref) => Stream.value(pedidos)),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    );

void main() {
  // ── El total: solo lo servido, con la cifra exacta en pantalla ──────────

  testWidgets('el total en pantalla son SOLO los servidos (50.000, no 90.000)',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _p('a', 'servido', 32000),
      _p('b', 'servido', 18000),
      _p('c', 'en_preparacion', 25000),
      _p('d', 'rechazado', 15000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Total a pagar'), findsOneWidget);
    // 32.000 + 18.000. Literal, no `formatCOP(a+b)`: si el widget sumara los
    // cuatro pedidos (90.000) o se olvidara del segundo (32.000), esto cae.
    expect(find.text(cop('50.000')), findsOneWidget);
    expect(find.text(cop('90.000')), findsNothing);
    expect(find.text(cop('65.000')), findsNothing,
        reason: '50.000 + el rechazado de 15.000 jamás');
  });

  // ── Lo pendiente: visible, con importe, y dicho como NO cobrado ─────────

  testWidgets('lo que falta por servir se anuncia con su importe aparte',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _p('a', 'servido', 32000),
      _p('b', 'en_preparacion', 25000),
      _p('c', 'enviado', 13000),
    ]));
    await tester.pumpAndSettle();

    expect(
      find.text(cop('32.000')),
      findsNWidgets(2),
      reason: 'la tarjeta Y el total; con una sola el total no viene del pedido',
    );
    // 25.000 + 13.000 pendientes, anunciados APARTE del total.
    expect(
      find.textContaining('2 pedidos por ${cop('38.000')}'),
      findsOneWidget,
      reason: 'el importe pendiente se dice, no se esconde',
    );
    expect(
      find.textContaining('cuando te los sirvan'),
      findsOneWidget,
      reason: 'y se dice CUÁNDO entrará en la cuenta',
    );
  });

  testWidgets('un solo pendiente se dice en singular', (tester) async {
    await tester.pumpWidget(_wrap([
      _p('a', 'servido', 10000),
      _p('b', 'aceptado', 5000),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 pedido por ${cop('5.000')}'), findsOneWidget);
    expect(find.textContaining('cuando te lo sirvan'), findsOneWidget);
  });

  testWidgets('sin pendientes NO se pinta el aviso (nada que aclarar)',
      (tester) async {
    await tester.pumpWidget(_wrap([_p('a', 'servido', 10000)]));
    await tester.pumpAndSettle();

    expect(find.textContaining('cuando te lo sirvan'), findsNothing);
    expect(find.textContaining('cuando te los sirvan'), findsNothing);
    expect(find.textContaining('en cocina'), findsNothing);
  });

  // ── El caso que el usuario notará: pide la cuenta con la cocina en curso ─

  testWidgets('nada servido todavía: total 0 y se explica por qué',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _p('a', 'en_preparacion', 25000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text(cop('0')), findsOneWidget);
    expect(find.textContaining('Todavía no te han servido'), findsOneWidget);
    expect(find.textContaining('1 pedido por ${cop('25.000')}'), findsOneWidget);
  });

  // ── Cada tarjeta dice si ESE pedido se cobra ────────────────────────────

  testWidgets('cada tarjeta declara si se cobra, no se cobra, o aún no',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _p('a', 'servido', 32000),
      _p('b', 'en_preparacion', 25000),
      _p('c', 'rechazado', 15000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Se cobra'), findsOneWidget);
    expect(find.text('Aún no se cobra'), findsOneWidget);
    expect(find.text('No se cobra'), findsOneWidget);
  });

  testWidgets('el rechazado se descuenta y se dice que no se cobra',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _p('a', 'servido', 20000),
      _p('b', 'rechazado', 15000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text(cop('20.000')), findsNWidgets(2),
        reason: 'la tarjeta y el total');
    expect(find.text(cop('35.000')), findsNothing);
    expect(find.text('No se cobra'), findsOneWidget);
  });

  // ── Sesión REUTILIZADA: la cena de la visita anterior no se cobra ───────

  testWidgets('pedido anterior a inicioAt: ni se lista ni se suma',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _p('hoy', 'servido', 20000),
      _p(
        'visitaPasada',
        'servido',
        99000,
        createdAt: DateTime(2026, 8, 13, 21, 0),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text(cop('20.000')), findsNWidgets(2),
        reason: 'la tarjeta y el total');
    expect(find.text(cop('119.000')), findsNothing,
        reason: 'cobrar la visita pasada sería cobrar dos veces');
    expect(find.text(cop('99.000')), findsNothing,
        reason: 'ni siquiera se lista: no es de esta cuenta');
  });

  // ── El resumen convive con el flujo que ya existía (no lo sustituye) ────

  testWidgets('el botón "Pedir la cuenta" sigue ahí junto al total',
      (tester) async {
    await tester.pumpWidget(_wrap([_p('a', 'servido', 10000)]));
    await tester.pumpAndSettle();

    expect(find.text('Total a pagar'), findsOneWidget);
    expect(find.text('Pedir la cuenta'), findsOneWidget);
  });

  testWidgets('con la cuenta ya pedida se sigue viendo el importe',
      (tester) async {
    await tester.pumpWidget(_wrap(
      [_p('a', 'servido', 10000)],
      sesion: _sesion(cuentaSolicitada: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta solicitada'), findsOneWidget);
    expect(find.text('Total a pagar'), findsOneWidget);
    expect(find.text(cop('10.000')), findsNWidgets(2),
        reason: 'la tarjeta y el total');
  });

  testWidgets('sesión cerrada: el importe final se sigue viendo',
      (tester) async {
    await tester.pumpWidget(_wrap(
      [_p('a', 'servido', 10000)],
      sesion: _sesion(estado: 'cerrada'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Total pagado'), findsOneWidget);
    expect(find.text(cop('10.000')), findsNWidgets(2),
        reason: 'la tarjeta y el total');
    expect(find.text('Pedir la cuenta'), findsNothing);
  });

  testWidgets('sin pedidos no hay resumen de cuenta que enseñar',
      (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('Total a pagar'), findsNothing);
    expect(find.text('Aún no hay pedidos en esta sesión'), findsOneWidget);
  });

  // ── El formato del dinero es el del helper, no una concatenación ────────

  test('el importe que la pantalla afirma es el que produce formatCOP', () {
    // Ancla: si algún día se cambia el locale o el helper, este test explica
    // por qué caen los literales de arriba en vez de dejarlos como misterio.
    expect(formatCOP(50000), cop('50.000'));
    expect(formatCOP(0), cop('0'));
  });
}
