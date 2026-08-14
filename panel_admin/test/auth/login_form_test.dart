import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/auth_storage.dart';
import 'package:gri_panel_admin/features/auth/login_screen.dart';
import 'package:gri_panel_admin/models/token_pair.dart';

/// Fake del ApiClient — nunca toca red (widget tests no abren Chrome).
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.loginError});

  final Object? loginError;

  @override
  Future<TokenPair> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    return const TokenPair(access: 'fake-access', refresh: 'fake-refresh');
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
  Future<void> clear() async => _store.clear();
}

Widget _wrapLoginScreen({required ApiClient client}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authStorageProvider.overrideWithValue(_FakeAuthStorage()),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

Future<void> _fillForm(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.pump();
}

void main() {
  testWidgets('form invalid email disables submit', (tester) async {
    await tester.pumpWidget(
      _wrapLoginScreen(client: _FakeApiClient()),
    );

    await _fillForm(tester, 'not-an-email', 'Demo!1234');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'email inválido debe deshabilitar el botón');
  });

  testWidgets('form short password disables submit', (tester) async {
    await tester.pumpWidget(
      _wrapLoginScreen(client: _FakeApiClient()),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'abc');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'password < 8 chars debe deshabilitar el botón');
  });

  testWidgets('form valid enables submit', (tester) async {
    await tester.pumpWidget(
      _wrapLoginScreen(client: _FakeApiClient()),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'Demo!1234');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull, reason: 'email válido + password 8+ chars habilita el botón');
  });

  testWidgets('submit fail shows error SnackBar', (tester) async {
    final client = _FakeApiClient(
      loginError: DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
        ),
      ),
    );
    await tester.pumpWidget(_wrapLoginScreen(client: client));

    await _fillForm(tester, 'admin@demo.gri.dev', 'Demo!1234');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    // Avanza la animación de entrada del SnackBar SIN pumpAndSettle para no
    // disparar el auto-dismiss (4s).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Credenciales inválidas'), findsOneWidget);
  });
}
