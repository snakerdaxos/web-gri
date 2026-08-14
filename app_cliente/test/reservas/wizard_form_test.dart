import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/features/reservas/reserva_controller.dart';
import 'package:gri_cliente/features/reservas/reserva_wizard_screen.dart';
import 'package:gri_cliente/models/reserva.dart';
import 'package:gri_cliente/models/reserva_create.dart';

/// Fake del ApiClient — graba el ReservaCreate que llega a createReserva y
/// puede lanzar un 409 para testear el mensaje user-friendly.
class _RecordingApiClient extends ApiClient {
  final Object? createError;

  _RecordingApiClient({this.createError});

  ReservaCreate? lastCreate;

  @override
  Future<Reserva> createReserva(ReservaCreate body) async {
    lastCreate = body;
    final e = createError;
    if (e != null) throw e;
    return Reserva(
      id: 99,
      restauranteId: body.restauranteId,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: 4,
      mesaNumero: 4,
      fecha: body.fecha,
      horaInicio: body.horaInicio,
      numPersonas: body.numPersonas,
      estado: 'confirmada',
      createdAt: '2026-08-14T10:00:00',
    );
  }
}

Widget _wrap({required ApiClient client}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: const MaterialApp(
      home: ReservaWizardScreen(
        restauranteId: 1,
        restauranteNombre: 'Restaurante Demo GRI',
      ),
    ),
  );
}

String _fechaDeManana() {
  final t = DateTime.now().add(const Duration(days: 1));
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Llena el wizard completo (fecha mañana vía dialog OK, hora 19:00,
/// personas por defecto) y avanza hasta Confirmar.
Future<void> _llenarHastaConfirmar(WidgetTester tester) async {
  // Step Fecha: abre el dialog y acepta la fecha por defecto (firstDate
  // = mañana → selectedDate = mañana).
  await tester.tap(find.text('Elegir fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  // Step Hora: dropdown de slots :00 → 19:00.
  await tester.tap(find.text('Elige una hora'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('19:00').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  // Step Personas: dejar el default (2) y continuar.
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Stepper de 4 pasos: Fecha / Hora / Personas / Confirmar',
      (tester) async {
    await tester.pumpWidget(_wrap(client: _RecordingApiClient()));
    await tester.pumpAndSettle();

    expect(find.byType(Stepper), findsOneWidget);
    // El step activo muestra "Fecha"; los títulos del plan están en el
    // stepper (los inactivos se renderizan también).
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.text('Hora'), findsOneWidget);
    expect(find.text('Personas'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
  });

  testWidgets('hora picker SOLO ofrece slots :00 (12:00..21:00)', (tester) async {
    // Contrato estático: la lista de horas del wizard.
    expect(ReservaWizardScreen.horasSlot, hasLength(10));
    for (final h in ReservaWizardScreen.horasSlot) {
      expect(h.endsWith(':00'), isTrue, reason: '$h no es un slot :00');
    }
    expect(ReservaWizardScreen.horasSlot.first, '12:00');
    expect(ReservaWizardScreen.horasSlot.last, '21:00');
    expect(ReservaWizardScreen.horasSlot, isNot(contains('12:30')));

    // Y en la UI: el dropdown ofrece solo esos ítems.
    await tester.pumpWidget(_wrap(client: _RecordingApiClient()));
    await tester.pumpAndSettle();

    // Avanzar al step Hora (elegir fecha primero).
    await tester.tap(find.text('Elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elige una hora'));
    await tester.pumpAndSettle();
    expect(find.text('12:30'), findsNothing);
    expect(find.text('13:00'), findsWidgets);
    expect(find.text('20:00'), findsWidgets);
  });

  testWidgets('num_personas queda entre 1 y 20', (tester) async {
    await tester.pumpWidget(_wrap(client: _RecordingApiClient()));
    await tester.pumpAndSettle();

    // Avanzar hasta Personas.
    await tester.tap(find.text('Elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elige una hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('19:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Default 2. Bajar 5 veces → clamp en 1.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
    }
    expect(find.text('1'), findsWidgets);

    // Subir 25 veces → clamp en 20.
    for (var i = 0; i < 25; i++) {
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
    }
    expect(find.text('20'), findsWidgets);
  });

  testWidgets('Confirmar llama al controller con el ReservaCreate armado',
      (tester) async {
    final client = _RecordingApiClient();
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await _llenarHastaConfirmar(tester);

    // Step Confirmar: resumen + submit.
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.lastCreate, isNotNull);
    expect(client.lastCreate!.restauranteId, 1);
    expect(client.lastCreate!.fecha, _fechaDeManana());
    expect(client.lastCreate!.horaInicio, '19:00:00');
    expect(client.lastCreate!.numPersonas, 2);
  });

  testWidgets('ante 409 muestra "Ese horario acaba de ser reservado"',
      (tester) async {
    final client = _RecordingApiClient(
      createError: DioException(
        requestOptions: RequestOptions(path: '/cliente/reservas'),
        response: Response(
          requestOptions: RequestOptions(path: '/cliente/reservas'),
          statusCode: 409,
          data: {'detail': 'Slot ocupado'},
        ),
      ),
    );
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await _llenarHastaConfirmar(tester);
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Ese horario acaba de ser reservado'),
        findsOneWidget);
  });
}
