// ============================================================================
// GRI — El resumen de la cuenta en un móvil ESTRECHO (plan 11-33).
//
// 11-32 lo dejó escrito en su SUMMARY como el riesgo que nadie había mirado:
//
//   «El resumen del comensal va en el `bottomNavigationBar` y crece hasta
//    tres bloques; en un viewport corto eso es exactamente el tipo de cosa
//    que revienta.»
//
// Este plan toca esa misma pantalla, así que se comprueba. El caso peor es el
// que junta los tres bloques a la vez —total, aviso de pendientes y botón— y
// además con las cifras largas: 320 px es el ancho del iPhone SE de primera
// generación y del Galaxy Fold cerrado, que es el suelo realista.
//
// Cómo se detecta el desbordamiento: Flutter emite una excepción de
// `RenderFlex overflowed` durante el layout y el binding la registra. Se
// captura `FlutterError.onError` y se afirma que no hubo ninguna. NO vale
// mirar solo que el widget exista: un `Column` desbordado sigue existiendo,
// simplemente pinta la franja amarilla y negra.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

final _inicio = DateTime(2026, 8, 20, 20, 0);

SesionMesa _sesion({bool cuentaSolicitada = false, String estado = 'activa'}) =>
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

Pedido _p(String id, String estado, int total) => Pedido(
      id: id,
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-003',
      sesionId: 'GRI-MESA-demo-003',
      usuarioId: 'test-uid',
      estado: estado,
      total: total,
      createdAt: _inicio.add(const Duration(minutes: 10)),
      items: const [
        PedidoItem(
            productoId: 'p1',
            nombre: 'Bandeja paisa con chicharrón',
            precio: 25000,
            cantidad: 1),
      ],
    );

/// Bombea la pantalla al ancho dado y devuelve los desbordes detectados.
Future<List<String>> _desbordes(
  WidgetTester tester, {
  required double ancho,
  required List<Pedido> pedidos,
  required SesionMesa sesion,
}) async {
  final errores = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (details) {
    errores.add(details.exceptionAsString());
  };
  // La restauración va en el CUERPO del caso y no en un addTearDown: en
  // `testWidgets`, `_verifyInvariants` corre ANTES de los tearDown y el caso
  // fallaría con «a foundation debug variable was changed» (medición de
  // 11-23, VERDE 1).
  try {
    tester.view.physicalSize = Size(ancho, 640);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sesionActualProvider.overrideWith((ref) => Stream.value(sesion)),
        pedidosSessionProvider.overrideWith((ref) => Stream.value(pedidos)),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    ));
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = anterior;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
  return errores.where((e) => e.contains('overflowed')).toList();
}

void main() {
  testWidgets('a 320 px el resumen de la cuenta NO desborda (caso peor)',
      (tester) async {
    // Los TRES bloques a la vez: total, aviso de pendientes y botón.
    final desbordes = await _desbordes(
      tester,
      ancho: 320,
      sesion: _sesion(),
      pedidos: [
        _p('a', 'servido', 132000),
        _p('b', 'servido', 118000),
        _p('c', 'en_preparacion', 125000),
        _p('d', 'enviado', 113000),
      ],
    );
    expect(desbordes, isEmpty, reason: desbordes.join('\n'));
  });

  testWidgets('a 320 px tampoco desborda con la cuenta ya pedida',
      (tester) async {
    final desbordes = await _desbordes(
      tester,
      ancho: 320,
      sesion: _sesion(cuentaSolicitada: true),
      pedidos: [
        _p('a', 'servido', 132000),
        _p('b', 'en_preparacion', 125000),
      ],
    );
    expect(desbordes, isEmpty, reason: desbordes.join('\n'));
  });

  testWidgets('a 320 px tampoco desborda tras el cierre de la sesión',
      (tester) async {
    final desbordes = await _desbordes(
      tester,
      ancho: 320,
      sesion: _sesion(estado: 'cerrada'),
      pedidos: [_p('a', 'servido', 132000)],
    );
    expect(desbordes, isEmpty, reason: desbordes.join('\n'));
  });

  // CANARIO: si el detector no viera NADA nunca, los tres casos de arriba
  // pasarían por vacío. Este caso comprueba que sí detecta un desborde real,
  // forzando un ancho absurdo donde la barra no cabe de ninguna manera.
  testWidgets('el detector de desbordes funciona (canario)', (tester) async {
    final desbordes = await _desbordes(
      tester,
      ancho: 60,
      sesion: _sesion(),
      pedidos: [
        _p('a', 'servido', 132000),
        _p('b', 'en_preparacion', 125000),
      ],
    );
    expect(desbordes, isNotEmpty,
        reason: 'sin esto los tres casos anteriores podrían estar en verde '
            'porque el detector no mira, no porque quepa');
  });
}
