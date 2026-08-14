import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/core/auth_storage.dart';
import 'package:gri_cliente/features/auth/login_screen.dart';
import 'package:gri_cliente/features/auth/register_screen.dart';
import 'package:gri_cliente/models/token_pair.dart';
import 'package:gri_cliente/models/user.dart';

/// Fake del ApiClient — nunca toca red (widget tests no abren Chrome).
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.loginCompleter});

  /// Si se setea, el login cuelga hasta completarse (test de loading).
  final Completer<TokenPair>? loginCompleter;

  int registerCalls = 0;

  @override
  Future<TokenPair> login(String email, String password) async {
    final c = loginCompleter;
    if (c != null) return c.future;
    return const TokenPair(access: 'fake-access', refresh: 'fake-refresh');
  }

  @override
  Future<User> register(String nombre, String email, String password) async {
    registerCalls++;
    return User(
      id: 7,
      nombre: nombre,
      email: email,
      role: 'cliente',
      restaurantId: null,
    );
  }
}

/// Fake en memoria del AuthStorage — evita MissingPluginException de
/// flutter_secure_storage en el test runner.
class _FakeAuthStorage extends AuthStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> readAccess() async => _store['access'];

  @override
  Future<String?> readRefresh() async => _store['refresh'];

  @override
  Future<void> write(String access, String refresh) async {
    _store['access'] = access;
    _store['refresh'] = refresh;
  }

  @override
  Future<void> clear() => Future.value(_store.clear());
}

Widget _wrap({
  required ApiClient client,
  Widget child = const LoginScreen(),
}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authStorageProvider.overrideWithValue(_FakeAuthStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _fill(
  WidgetTester tester,
  List<String> values,
) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
  await tester.pump();
}

void main() {
  testWidgets('login: email inválido deshabilita el botón', (tester) async {
    await tester.pumpWidget(_wrap(client: _FakeApiClient()));

    await _fill(tester, ['not-an-email', 'Demo!1234']);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'email inválido debe deshabilitar Ingresar (validación pre-red)');
  });

  testWidgets('login: password < 8 deshabilita el botón', (tester) async {
    await tester.pumpWidget(_wrap(client: _FakeApiClient()));

    await _fill(tester, ['carlos@demo.gri.dev', 'abc']);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'password < 8 chars debe deshabilitar Ingresar');
  });

  testWidgets('login: toggle navega a la pantalla de registro', (tester) async {
    await tester.pumpWidget(_wrap(client: _FakeApiClient()));

    expect(find.text('Ingresar'), findsOneWidget);

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets(
      'register: requiere nombre + email válido + password ≥ 8 para habilitar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(client: _FakeApiClient(), child: const RegisterScreen()),
    );
    // GoRouter arranca en /login; llevamos el router a /register.
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    // Vacío → disabled.
    expect(button.onPressed, isNull, reason: 'form vacío deshabilita Crear');

    // Solo nombre → disabled.
    await _fill(tester, ['Carlos']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'sin email/password deshabilita Crear');

    // Nombre + email inválido → disabled.
    await _fill(tester, ['Carlos', 'not-an-email', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'email inválido deshabilita Crear');

    // Todo válido → enabled.
    await _fill(
        tester, ['Carlos Pérez', 'carlos@test.gri.dev', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
        reason: 'nombre + email válido + password 8+ habilita Crear');
  });

  testWidgets('login: botón disabled mientras el submit está en curso',
      (tester) async {
    final completer = Completer<TokenPair>();
    await tester.pumpWidget(_wrap(client: _FakeApiClient(loginCompleter: completer)));

    await _fill(tester, ['carlos@demo.gri.dev', 'Demo!1234']);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
      reason: 'isLoading del controller debe deshabilitar el botón',
    );

    completer.complete(
        const TokenPair(access: 'a', refresh: 'r'));
    await tester.pumpAndSettle();
  });
}
