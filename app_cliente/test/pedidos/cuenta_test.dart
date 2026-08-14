import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

/// Fake que cuenta las llamadas a pedirCuenta y devuelve la sesión con el
/// flag prendido (respuesta del backend real).
class _CuentaClient extends ApiClient {
  int llamadas = 0;

  @override
  Future<SesionMesa> pedirCuenta() async {
    llamadas++;
    return _sesion(solicitaCuenta: true);
  }
}

SesionMesa _sesion({bool solicitaCuenta = false}) => SesionMesa(
      id: 10,
      restauranteId: 1,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: 3,
      mesaNumero: 3,
      abiertaEn: DateTime(2026, 8, 14, 12, 30),
      solicitaCuenta: solicitaCuenta,
      solicitadaEn: solicitaCuenta ? DateTime(2026, 8, 14, 14) : null,
    );

Pedido _p() => Pedido(
      id: 1,
      sesionId: 10,
      mesaNumero: 3,
      estado: 'servido',
      total: 57000,
      notas: null,
      createdAt: DateTime(2026, 8, 14, 13),
      items: const [
        PedidoItem(
            productoId: 1,
            nombre: 'Pasta',
            cantidad: 2,
            precioUnitario: 25000,
            subtotal: 50000)
      ],
    );

Widget _wrap({required SesionMesa sesion, required ApiClient client}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      sesionProvider.overrideWithValue(AsyncData(sesion)),
      pedidosSessionProvider.overrideWith((ref) => Stream.value([_p()])),
    ],
    child: const MaterialApp(home: PedidoEstadoScreen()),
  );
}

void main() {
  testWidgets('sesión sin cuenta → botón "Pedir la cuenta" visible',
      (tester) async {
    await tester.pumpWidget(
        _wrap(sesion: _sesion(), client: _CuentaClient()));
    await tester.pumpAndSettle();

    expect(find.text('Pedir la cuenta'), findsOneWidget);
    expect(find.text('Cuenta solicitada ✓'), findsNothing);
  });

  testWidgets('tap → 1 llamada al backend + confirmación + botón reemplazado',
      (tester) async {
    final client = _CuentaClient();
    await tester.pumpWidget(_wrap(sesion: _sesion(), client: client));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedir la cuenta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.llamadas, 1);
    expect(find.textContaining('el mesero viene en camino'), findsOneWidget);
    // El botón desaparece y queda la confirmación visible (idempotente UX).
    expect(find.text('Cuenta solicitada ✓'), findsOneWidget);
    expect(find.text('Pedir la cuenta'), findsNothing);
  });

  testWidgets('sesión con solicitaCuenta=true → sin botón, solo ✓',
      (tester) async {
    final client = _CuentaClient();
    await tester.pumpWidget(
        _wrap(sesion: _sesion(solicitaCuenta: true), client: client));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta solicitada ✓'), findsOneWidget);
    expect(find.text('Pedir la cuenta'), findsNothing);
    expect(client.llamadas, 0);
  });
}
