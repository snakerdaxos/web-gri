import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/features/reservas/mis_reservas_screen.dart';
import 'package:gri_cliente/features/reservas/reservas_provider.dart';
import 'package:gri_cliente/models/reserva.dart';

/// Fake del ApiClient — graba los ids cancelados.
class _RecordingApiClient extends ApiClient {
  final List<String> cancelled = [];

  @override
  Future<Reserva> cancelReserva(String reservaId) async {
    cancelled.add(reservaId);
    return Reserva(
      id: reservaId,
      restauranteId: 'demo',
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: 'GRI-MESA-demo-001',
      mesaNumero: 1,
      usuarioId: 'test-uid',
      fecha: DateTime(2099, 1, 1, 19),
      fechaStr: '2099-01-01',
      hora: 19,
      numPersonas: 2,
      estado: 'cancelada',
    );
  }
}

String _hoy() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Reserva _reserva(
  int n,
  String fecha, {
  String estado = 'confirmada',
  String restaurante = 'Restaurante Demo GRI',
}) =>
    Reserva(
      id: 'r$n',
      restauranteId: 'demo',
      restauranteNombre: restaurante,
      mesaId: 'm$n',
      mesaNumero: n,
      usuarioId: 'test-uid',
      fecha: DateTime.parse('$fecha 19:00:00'),
      fechaStr: fecha,
      hora: 19,
      numPersonas: 4,
      estado: estado,
    );

Widget _wrap({required ApiClient client, required List<Reserva> reservas}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      reservasProvider.overrideWithValue(AsyncData(reservas)),
    ],
    child: const MaterialApp(home: Scaffold(body: MisReservasScreen())),
  );
}

void main() {
  testWidgets('divide próximas (fecha >= hoy) y pasadas (fecha < hoy)',
      (tester) async {
    final hoy = _hoy();
    await tester.pumpWidget(_wrap(
      client: _RecordingApiClient(),
      reservas: [
        _reserva(1, '2099-01-01'), // futura
        _reserva(2, hoy), // hoy → PRÓXIMA
        _reserva(3, '2020-01-01'), // pasada
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Próximas'), findsOneWidget);
    expect(find.text('Pasadas'), findsOneWidget);

    // La futura y la de hoy están bajo Próximas; la pasada en su sección
    // (fecha+hora combinadas estilo mockup → textContaining).
    expect(find.textContaining('2099-01-01'), findsOneWidget);
    expect(find.textContaining(hoy), findsOneWidget);
    expect(find.textContaining('2020-01-01'), findsOneWidget);
  });

  testWidgets(
      'cada reserva muestra restaurante, mesa, fecha, hora, personas y estado',
      (tester) async {
    await tester.pumpWidget(_wrap(
      client: _RecordingApiClient(),
      reservas: [
        _reserva(1, '2099-01-01', estado: 'confirmada'),
        _reserva(2, '2020-01-01', estado: 'cancelada'),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Restaurante Demo GRI'), findsNWidgets(2));
    expect(find.textContaining('Mesa 1'), findsOneWidget);
    expect(find.textContaining('Mesa 2'), findsOneWidget);
    expect(find.textContaining('2099-01-01'), findsOneWidget);
    expect(find.textContaining('19:00'), findsNWidgets(2));
    expect(find.textContaining('4 personas'), findsNWidgets(2));

    // Chips de estado: confirmada verde / cancelada roja (texto capitalizado).
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);

    // Colores exactos de los chips (mockup: #168a52 / #C83C2E).
    final confirmadaChip = tester.widget<Container>(
      find.ancestor(
        of: find.text('Confirmada'),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      (confirmadaChip.decoration as BoxDecoration).color,
      const Color(0xFFDFF7EB),
    );
  });

  testWidgets('Cancelar en futura confirmada llama controller.cancel(id)',
      (tester) async {
    final client = _RecordingApiClient();
    await tester.pumpWidget(_wrap(
      client: client,
      reservas: [
        _reserva(7, '2099-01-01', estado: 'confirmada'),
        _reserva(8, '2020-01-01', estado: 'cancelada'),
      ],
    ));
    await tester.pumpAndSettle();

    // Solo la futura confirmada tiene botón Cancelar.
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Dialog de confirmación.
    expect(find.textContaining('¿Cancelar'), findsOneWidget);
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.cancelled, ['r7']);
  });
}
