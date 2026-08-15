import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/features/pagos/calificacion_sheet.dart';

/// Fake que registra los args de crearCalificacion (patrón cuenta_test).
class _CalifClient extends ApiClient {
  int? pedidoId;
  int? estrellas;
  String? comentario;
  int llamadas = 0;
  Object? error;

  @override
  Future<void> crearCalificacion(
    int pedidoId,
    int estrellas, {
    String? comentario,
  }) async {
    llamadas++;
    this.pedidoId = pedidoId;
    this.estrellas = estrellas;
    this.comentario = comentario;
    if (error != null) throw error!;
  }
}

DioException _e(Object? data, int status) {
  final opts = RequestOptions(path: '/cliente/calificaciones');
  return DioException(
    requestOptions: opts,
    response: Response<Object?>(requestOptions: opts, statusCode: status, data: data),
  );
}

/// Host: botón que abre el sheet (showModalBottomSheet necesita context
/// de Scaffold — patrón real de uso desde la PagoScreen).
Widget _wrap({required ApiClient client}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const CalificacionSheet(pedidoId: 7),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _abrirSheet(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('5 estrellas custom: tap en la 4ta → 4 llenas, valor 4',
      (tester) async {
    await tester.pumpWidget(_wrap(client: _CalifClient()));
    await _abrirSheet(tester);

    // Inicial: 5 vacías.
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.byIcon(Icons.star), findsNothing);

    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.byIcon(Icons.star_border), findsNWidgets(1));
  });

  testWidgets(
      'Enviar deshabilitado sin estrellas; con 4+comentario llama al backend, cierra y agradece',
      (tester) async {
    final client = _CalifClient();
    await tester.pumpWidget(_wrap(client: client));
    await _abrirSheet(tester);

    // Deshabilitado con 0 estrellas.
    var btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Enviar calificación'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();

    btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Enviar calificación'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNotNull);

    await tester.enterText(
      find.byType(TextField),
      '¡Excelente todo!',
    );
    await tester.pump();

    await tester.tap(find.text('Enviar calificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.llamadas, 1);
    expect(client.pedidoId, 7);
    expect(client.estrellas, 4);
    expect(client.comentario, '¡Excelente todo!');

    // Sheet cerrado + SnackBar de gracias.
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(find.text('¡Gracias por calificar! 🙌'), findsOneWidget);
  });

  testWidgets('409 ya calificado → mensaje específico, sheet NO cierra',
      (tester) async {
    final client = _CalifClient()
      ..error = _e({'detail': 'El pedido ya fue calificado'}, 409);
    await tester.pumpWidget(_wrap(client: client));
    await _abrirSheet(tester);

    await tester.tap(find.byIcon(Icons.star_border).at(4));
    await tester.pump();
    await tester.tap(find.text('Enviar calificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Este pedido ya fue calificado'), findsOneWidget);
    // El sheet sigue abierto para que el usuario vea el error.
    expect(find.byIcon(Icons.star), findsNWidgets(5));
  });
}
