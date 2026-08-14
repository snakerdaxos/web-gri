import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/core/token_provider.dart';
import 'package:gri_cliente/features/perfil/perfil_screen.dart';
import 'package:gri_cliente/models/user.dart';

/// Tests del perfil (AUTH-05 UI): muestra User, email immutable, Guardar
/// invoca al controller con el nombre nuevo (fake ApiClient graba la call).

class _RecordingApiClient extends ApiClient {
  final List<({String nombre, String? password})> updateCalls = [];

  @override
  Future<User> updatePerfil({required String nombre, String? password}) async {
    updateCalls.add((nombre: nombre, password: password));
    return _user.copyWith(nombre: nombre);
  }
}

const _user = User(
  id: 5,
  nombre: 'Carlos Pérez',
  email: 'carlos@demo.gri.dev',
  role: 'cliente',
  restaurantId: null,
);

Widget _wrap({required ApiClient client}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      // authState con User mockeado (AsyncData no-null = logueado).
      authStateProvider.overrideWithValue(const AsyncData(_user)),
    ],
    child: const MaterialApp(home: PerfilScreen()),
  );
}

void main() {
  testWidgets('muestra nombre y email del User', (tester) async {
    await tester.pumpWidget(_wrap(client: _RecordingApiClient()));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('carlos@demo.gri.dev'), findsOneWidget);
  });

  testWidgets('email disabled; nombre editable', (tester) async {
    await tester.pumpWidget(_wrap(client: _RecordingApiClient()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField).evaluate();
    final nombreField = tester.widget<TextFormField>(find.byType(TextFormField).at(0));
    final emailField = tester.widget<TextFormField>(find.byType(TextFormField).at(1));

    expect(emailField.enabled, isFalse,
        reason: 'email es immutable server-side — SIEMPRE disabled');
    expect(nombreField.enabled, isTrue);

    // Editar el nombre funciona.
    await tester.enterText(find.byType(TextFormField).at(0), 'Carlitos');
    await tester.pump();
    expect(find.text('Carlitos'), findsOneWidget);
    expect(fields.length, greaterThanOrEqualTo(2));
  });

  testWidgets('Guardar llama al controller con el nombre nuevo',
      (tester) async {
    final client = _RecordingApiClient();
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Carlitos Rey');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.updateCalls, hasLength(1));
    expect(client.updateCalls.first.nombre, 'Carlitos Rey');
    expect(client.updateCalls.first.password, isNull,
        reason: 'password vacía → no se envía (no cambia)');
  });
}
