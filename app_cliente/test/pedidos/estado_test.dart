import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

SesionMesa _sesion() => SesionMesa(
      id: 10,
      restauranteId: 1,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: 3,
      mesaNumero: 3,
      abiertaEn: DateTime(2026, 8, 14, 12, 30),
      solicitaCuenta: false,
      solicitadaEn: null,
    );

Pedido _p(int id, String estado) => Pedido(
      id: id,
      sesionId: 10,
      mesaNumero: 3,
      estado: estado,
      total: 57000,
      notas: id == 1 ? 'Sin cebolla' : null,
      createdAt: DateTime(2026, 8, 14, 13, id),
      items: const [
        PedidoItem(
            productoId: 1,
            nombre: 'Pasta',
            cantidad: 2,
            precioUnitario: 25000,
            subtotal: 50000),
        PedidoItem(
            productoId: 4,
            nombre: 'Jugo',
            cantidad: 1,
            precioUnitario: 7000,
            subtotal: 7000),
      ],
    );

Widget _wrap({required List<Pedido> pedidos}) {
  return ProviderScope(
    overrides: [
      sesionProvider.overrideWithValue(AsyncData(_sesion())),
      pedidosSessionProvider.overrideWith((ref) => Stream.value(pedidos)),
    ],
    child: const MaterialApp(home: PedidoEstadoScreen()),
  );
}

void main() {
  testWidgets('cards con chips de estado, items, notas y total COP',
      (tester) async {
    await tester.pumpWidget(_wrap(pedidos: [_p(1, 'enviado'), _p(2, 'servido')]));
    await tester.pumpAndSettle();

    expect(find.text('Mis pedidos · Mesa 3'), findsOneWidget);
    expect(find.text('Se actualiza automáticamente'), findsOneWidget);

    // Chips de estado por pedido.
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('Servido'), findsOneWidget);
    // Items y total en cada card.
    expect(find.text('Pasta ×2'), findsNWidgets(2));
    expect(find.textContaining('57.000'), findsNWidgets(2));
    // Notas solo en el pedido 1.
    expect(find.textContaining('Sin cebolla'), findsOneWidget);
  });

  testWidgets('los 5 estados renderizan chips con labels y colores distintos',
      (tester) async {
    await tester.pumpWidget(_wrap(pedidos: [
      _p(1, 'enviado'),
      _p(2, 'aceptado'),
      _p(3, 'en_preparacion'),
      _p(4, 'servido'),
      _p(5, 'rechazado'),
    ]));
    await tester.pumpAndSettle();

    const esperados = {
      'Enviado': Color(0xFF2563EB),
      'Aceptado': Color(0xFFD97706),
      'En preparación': Color(0xFF7C3AED),
      'Servido': Color(0xFF168A52),
      'Rechazado': Color(0xFFC83C2E),
    };
    for (final entry in esperados.entries) {
      // ListView lazy: los cards fuera del viewport no se construyen.
      await tester.scrollUntilVisible(
        find.text(entry.key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      final chip = tester.widget<Text>(find.text(entry.key));
      expect(chip.style?.color, entry.value, reason: entry.key);
    }
  });

  testWidgets('lista vacía → mensaje + CTA al menú', (tester) async {
    await tester.pumpWidget(_wrap(pedidos: const []));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay pedidos en esta sesión'), findsOneWidget);
    expect(find.text('Ver el menú'), findsOneWidget);
    // Con sesión activa y sin cuenta pedida, el botón sigue visible.
    expect(find.text('Pedir la cuenta'), findsOneWidget);
  });
}
