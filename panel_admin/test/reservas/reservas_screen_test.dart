import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/reservas/reservas_screen.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/models/reserva.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests de /reservas (RESV-05 UI): render del día con chips de estado,
/// botón 'Marcar ocupada' SOLO en confirmadas, espía del wire
/// setMesaEstado(mesaId, 'ocupada') y manejo del 409 (mesa cambió por
/// otra vía) con SnackBar + refresh.
///
/// Overrides sin red (patrón cola_test): apiClientProvider → fake con
/// getReservas fixture + setMesaEstado espía (ejercita la cadena
/// screen→provider→client completa); authStateProvider class-based.

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient: getReservas devuelve el fixture del día; setMesaEstado
/// registra el wire exacto (o lanza el [estadoError] para el test del 409).
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.reservas = const [], this.estadoError});

  final List<Map<String, dynamic>> reservasCalls = [];
  final List<(String, String)> setEstadoCalls = [];

  List<Reserva> reservas;
  final DioException? estadoError;

  @override
  Future<List<Reserva>> getReservas({
    String? fecha,
    int? restauranteId,
  }) async {
    reservasCalls.add({'fecha': fecha, 'restaurante_id': restauranteId});
    return reservas;
  }

  @override
  Future<Mesa> setMesaEstado(
    String mesaId,
    String estado, {
    int? restauranteId,
  }) async {
    setEstadoCalls.add((mesaId, estado));
    if (estadoError != null) throw estadoError!;
    return Mesa(
      id: mesaId,
      restauranteId: 'R1',
      numero: 2,
      capacidad: 4,
      estado: EstadoMesa.ocupada,
    );
  }
}

const _adminUser = User(
  id: 2,
  nombre: 'Admin Demo',
  email: 'admin@demo.gri.dev',
  role: 'admin_restaurante',
  restaurantId: 1,
);

List<Reserva> _fixtureDia() => const [
      Reserva(
        id: 3,
        restauranteNombre: 'Demo',
        mesaId: 2,
        mesaNumero: 2,
        fecha: '2026-08-14',
        horaInicio: '19:00:00',
        numPersonas: 4,
        estado: 'confirmada',
      ),
      Reserva(
        id: 5,
        restauranteNombre: 'Demo',
        mesaId: 4,
        mesaNumero: 4,
        fecha: '2026-08-14',
        horaInicio: '20:30:00',
        numPersonas: 2,
        estado: 'cancelada',
      ),
    ];

DioException _conflict409() => DioException(
      requestOptions: RequestOptions(path: '/staff/mesas/2/estado'),
      response: Response(
        requestOptions: RequestOptions(path: '/staff/mesas/2/estado'),
        statusCode: 409,
        data: {'detail': 'Transición inválida'},
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeApiClient client, {
  User user = _adminUser,
}) async {
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
      child: const MaterialApp(home: Scaffold(body: ReservasScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) renderiza las 2 reservas con chips de estado', (
    tester,
  ) async {
    final client = _FakeApiClient(reservas: _fixtureDia());
    await _pump(tester, client);

    // El fetch del día viajó con la fecha de HOY (estado local inicial).
    expect(client.reservasCalls, [
      {'fecha': DateTime.now().toIso8601String().substring(0, 10), 'restaurante_id': null},
    ]);
    // Cards: hora HH:MM, mesa, personas, chips.
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('20:30'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Mesa 4'), findsOneWidget);
    expect(find.text('4 personas'), findsOneWidget);
    expect(find.text('2 personas'), findsOneWidget);
    expect(find.text('confirmada'), findsOneWidget);
    expect(find.text('cancelada'), findsOneWidget);
    // Cancelada va TACHADA (semántica visual).
    final chip = tester.widget<Text>(find.text('cancelada'));
    expect(chip.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('(b) Marcar ocupada SOLO en la confirmada', (tester) async {
    final client = _FakeApiClient(reservas: _fixtureDia());
    await _pump(tester, client);

    expect(find.text('Marcar ocupada'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Sin reservas para este día'), findsNothing);
  });

  testWidgets(
    '(c) tap Marcar ocupada → espía setMesaEstado(mesaId, "ocupada") + SnackBar',
    (tester) async {
      final client = _FakeApiClient(reservas: _fixtureDia());
      await _pump(tester, client);

      await tester.tap(find.text('Marcar ocupada'));
      await tester.pumpAndSettle();

      // Wire exacto: POST /staff/mesas/2/estado {"estado": "ocupada"} —
      // mesaId viaja como String (doc ID = código QR, Phase 10-05).
      expect(client.setEstadoCalls, [('2', 'ocupada')]);
      expect(find.text('Mesa 2 marcada ocupada'), findsOneWidget);
    },
  );

  testWidgets('(d) 409 del server → SnackBar "La mesa ya cambió de estado"', (
    tester,
  ) async {
    final client = _FakeApiClient(
      reservas: _fixtureDia(),
      estadoError: _conflict409(),
    );
    await _pump(tester, client);

      await tester.tap(find.text('Marcar ocupada'));
      await tester.pumpAndSettle();

      expect(client.setEstadoCalls, [('2', 'ocupada')]);
    expect(find.text('La mesa ya cambió de estado'), findsOneWidget);
    // El listado se refrescó (invalidate → re-fetch del día).
    expect(client.reservasCalls.length, greaterThanOrEqualTo(2));
  });

  testWidgets('(e) día vacío → estado vacío', (tester) async {
    final client = _FakeApiClient(reservas: const []);
    await _pump(tester, client);

    expect(find.text('Sin reservas para este día'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });
}
