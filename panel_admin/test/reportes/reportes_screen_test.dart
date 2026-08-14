import 'package:data_table_2/data_table_2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/format.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/reportes/reportes_screen.dart';
import 'package:gri_panel_admin/models/reporte.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests de /reportes (REPO-01/02): consulta default sin params (el server
/// aplica últimos 7 días), render de cards+tabla por día+top platos con
/// formatCOP, validación client-side desde>hasta SIN llamada API, 422 del
/// server y estado vacío.
///
/// Overrides sin red (patrón cola_test): apiClientProvider → fake con
/// espías; authStateProvider class-based → overrideWith(Fake).

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient que registra las llamadas a los 2 endpoints de
/// reportes (espías de params exactos del wire).
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.ventas, this.top = const [], this.ventasError});

  final List<Map<String, dynamic>> ventasCalls = [];
  final List<Map<String, dynamic>> topCalls = [];

  VentasReporte? ventas;
  List<TopPlato> top;
  final DioException? ventasError;

  @override
  Future<VentasReporte> getReporteVentas({
    String? desde,
    String? hasta,
    int? restauranteId,
  }) async {
    ventasCalls.add({
      'desde': desde,
      'hasta': hasta,
      'restaurante_id': restauranteId,
    });
    if (ventasError != null) throw ventasError!;
    return ventas!;
  }

  @override
  Future<List<TopPlato>> getTopPlatos({
    String? desde,
    String? hasta,
    int? limit,
    int? restauranteId,
  }) async {
    topCalls.add({
      'desde': desde,
      'hasta': hasta,
      'limit': limit,
      'restaurante_id': restauranteId,
    });
    return top;
  }
}

const _adminUser = User(
  id: 2,
  nombre: 'Admin Demo',
  email: 'admin@demo.gri.dev',
  role: 'admin_restaurante',
  restaurantId: 1,
);

VentasReporte _fixtureVentas() => const VentasReporte(
      desde: '2026-08-08',
      hasta: '2026-08-14',
      total: 245000,
      numPedidos: 7,
      porDia: [
        VentaDia(fecha: '2026-08-13', total: 45000, numPedidos: 2),
        VentaDia(fecha: '2026-08-14', total: 200000, numPedidos: 5),
      ],
    );

const _fixtureTop = [
  TopPlato(productoId: 5, nombre: 'Patacón', cantidad: 12, total: 186000),
  TopPlato(productoId: 2, nombre: 'Pizza Hawaiana', cantidad: 7, total: 175000),
  TopPlato(productoId: 9, nombre: 'Limonada', cantidad: 3, total: 19500),
];

Future<void> _pump(
  WidgetTester tester,
  _FakeApiClient client, {
  User user = _adminUser,
}) async {
  // Viewport alto: el ListView de resultados es lazy (patrón cola_test).
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(user)),
      ],
      // Scaffold: SnackBar exige un Scaffold ancestor.
      child: const MaterialApp(home: Scaffold(body: ReportesScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('validarRango: invertido → mensaje; válido/partial → null', () {
    expect(
      ReportesScreenState.validarRango(DateTime(2026, 8, 20), DateTime(2026, 8, 10)),
      'La fecha inicial no puede ser mayor que la final',
    );
    expect(ReportesScreenState.validarRango(DateTime(2026, 8, 10), DateTime(2026, 8, 20)), isNull);
    expect(ReportesScreenState.validarRango(DateTime(2026, 8, 20), null), isNull);
    expect(ReportesScreenState.validarRango(null, DateTime(2026, 8, 10)), isNull);
  });

  testWidgets(
    '(a) Consultar sin tocar pickers → espías llamados SIN desde/hasta (default server)',
    (tester) async {
      final client = _FakeApiClient(
        ventas: _fixtureVentas(),
        top: _fixtureTop,
      );
      await _pump(tester, client);

      await tester.tap(find.text('Consultar'));
      await tester.pumpAndSettle();

      // Wire exacto: 0 params — el server aplica su default DB-side.
      expect(client.ventasCalls, [
        {'desde': null, 'hasta': null, 'restaurante_id': null},
      ]);
      expect(client.topCalls, [
        {'desde': null, 'hasta': null, 'limit': null, 'restaurante_id': null},
      ]);
    },
  );

  testWidgets('(b) cards con total COP + pedidos + filas de los 2 días', (
    tester,
  ) async {
    final client = _FakeApiClient(
      ventas: _fixtureVentas(),
      top: _fixtureTop,
    );
    await _pump(tester, client);

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    // Cards resumen (formatCOP es la única vía — Pitfall 3).
    expect(find.text('Total vendido'), findsOneWidget);
    expect(find.text(formatCOP(245000)), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    // Tabla por día: fechas + totales/pedidos por fila (descendant: los
    // numerales de los avatares del top también son '2'/'3' — el bare
    // find.text colisionaría).
    final tabla = find.byType(DataTable2);
    expect(find.text('2026-08-13'), findsOneWidget);
    expect(find.text('2026-08-14'), findsOneWidget);
    expect(find.descendant(of: tabla, matching: find.text(formatCOP(45000))), findsOneWidget);
    expect(find.descendant(of: tabla, matching: find.text(formatCOP(200000))), findsOneWidget);
    expect(find.descendant(of: tabla, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: tabla, matching: find.text('5')), findsOneWidget);
  });

  testWidgets('(c) top platos numerados 1..3 con ×12 en el primero', (
    tester,
  ) async {
    final client = _FakeApiClient(
      ventas: _fixtureVentas(),
      top: _fixtureTop,
    );
    await _pump(tester, client);

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(find.text('Platos más vendidos'), findsOneWidget);
    expect(find.text('Patacón'), findsOneWidget);
    expect(find.text('×12'), findsOneWidget);
    expect(find.text('×7'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    // Numeración 1..3 en los CircleAvatar leading (descendant para no
    // chocar con los numPedidos '2'/'5' de la tabla).
    final avatars = find.byType(CircleAvatar);
    expect(avatars, findsNWidgets(3));
    expect(find.descendant(of: avatars, matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: avatars, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: avatars, matching: find.text('3')), findsOneWidget);
    // Orden por cantidad DESC: Patacón(12) encima de Pizza(7).
    expect(
      tester.getTopLeft(find.text('Patacón')).dy
          < tester.getTopLeft(find.text('Pizza Hawaiana')).dy,
      isTrue,
    );
  });

  testWidgets(
    '(d) desde > hasta → SnackBar visible Y espías NO llamados',
    (tester) async {
      final client = _FakeApiClient(
        ventas: _fixtureVentas(),
        top: _fixtureTop,
      );
      await _pump(tester, client);

      // Rango invertido fijado vía el setter @visibleForTesting (el plan
      // habilita esta vía como alternativa a manejar los pickers).
      final state = tester.state<ReportesScreenState>(
        find.byType(ReportesScreen),
      );
      state.debugSetFechas(DateTime(2026, 8, 20), DateTime(2026, 8, 10));
      await tester.pump();

      await tester.tap(find.text('Consultar'));
      await tester.pump();

      expect(
        find.text('La fecha inicial no puede ser mayor que la final'),
        findsOneWidget,
      );
      expect(client.ventasCalls, isEmpty, reason: 'no debe llamar la API');
      expect(client.topCalls, isEmpty, reason: 'no debe llamar la API');
    },
  );

  testWidgets('(e) fixture vacío → Sin ventas en el rango', (tester) async {
    final client = _FakeApiClient(
      ventas: const VentasReporte(
        desde: '2020-01-01',
        hasta: '2020-01-07',
        total: 0,
        numPedidos: 0,
        porDia: [],
      ),
      top: const [],
    );
    await _pump(tester, client);

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin ventas en el rango'), findsOneWidget);
  });

  testWidgets('(f) 422 del server → SnackBar con el detail del backend', (
    tester,
  ) async {
    final client = _FakeApiClient(
      ventas: _fixtureVentas(),
      top: _fixtureTop,
      ventasError: DioException(
        requestOptions: RequestOptions(path: '/staff/reportes/ventas'),
        response: Response(
          requestOptions: RequestOptions(path: '/staff/reportes/ventas'),
          statusCode: 422,
          data: {'detail': 'desde no puede ser mayor que hasta'},
        ),
      ),
    );
    await _pump(tester, client);

    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();

    expect(
      find.text('desde no puede ser mayor que hasta'),
      findsOneWidget,
    );
    expect(find.text('Total vendido'), findsNothing);
  });
}
