import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/dashboard/dashboard_screen.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/dashboard/stats_provider.dart';
import 'package:gri_panel_admin/features/mesas/mesa_actions_sheet.dart';
import 'package:gri_panel_admin/models/dashboard_stats.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Suite ADMN-04 (08-03): el actions sheet del mapa ofrece SOLO las
/// transiciones válidas de kMesaTransitions por estado (mirror de
/// MESA_TRANSITIONS — el server sigue siendo la autoridad), la mutación
/// llama a setMesaEstado con el wire exacto, el 409 (carrera entre dos
/// staff) muestra SnackBar sin crash, y el tap del MesaTile del
/// dashboard abre el sheet.
///
/// Fakes con el patrón cola_test: ProviderScope inlineado por test.

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient que registra setMesaEstado (y puede lanzar 409).
class _RecordingApiClient extends ApiClient {
  _RecordingApiClient({this.throw409 = false});

  final bool throw409;
  final List<(int, String, int?)> estadoCalls = [];

  @override
  Future<Mesa> setMesaEstado(
    int mesaId,
    String estado, {
    int? restauranteId,
  }) async {
    estadoCalls.add((mesaId, estado, restauranteId));
    if (throw409) {
      final opts = RequestOptions(path: '/staff/mesas/$mesaId/estado');
      throw DioException(
        requestOptions: opts,
        response: Response(requestOptions: opts, statusCode: 409),
      );
    }
    return Mesa(
      id: mesaId,
      numero: 7,
      capacidad: 4,
      codigoQr: 'GRI-MESA-R1-007',
      estado: EstadoMesa.limpieza,
    );
  }
}

const _meseroUser = User(
  id: 10,
  nombre: 'Mesero Demo',
  email: 'mesero@demo.gri.dev',
  role: 'mesero',
  restaurantId: 1,
);

Mesa _m(EstadoMesa e, {int id = 7, int numero = 7}) => Mesa(
      id: id,
      numero: numero,
      capacidad: 4,
      codigoQr: 'GRI-MESA-R1-007',
      estado: e,
    );

/// Bombea un host mínimo (botón) que abre el sheet standalone con los
/// overrides del caso. showEdit false = vista mapa del dashboard.
Future<void> _pumpSheetHost(
  WidgetTester tester,
  Mesa mesa,
  _RecordingApiClient client, {
  bool showEdit = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(_meseroUser)),
      ],
      child: Consumer(
        builder: (consumerContext, ref, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              // Builder DENTRO del MaterialApp: el context del botón tiene
              // Localizations + Navigator + ScaffoldMessenger (el context
              // del Consumer queda POR ENCIMA del MaterialApp).
              child: Builder(
                builder: (buttonContext) => TextButton(
                  onPressed: () => showMesaActionsSheet(
                    buttonContext,
                    ref,
                    mesa,
                    showEdit: showEdit,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) disponible: exactamente reservada+ocupada; sin Editar', (tester) async {
    await _pumpSheetHost(
      tester,
      _m(EstadoMesa.disponible),
      _RecordingApiClient(),
      showEdit: false,
    );

    // Exactamente las 2 transiciones válidas desde disponible.
    expect(find.text('Marcar reservada'), findsOneWidget);
    expect(find.text('Marcar ocupada'), findsOneWidget);
    expect(find.text('Ver código QR'), findsOneWidget);
    // NINGUNA otra acción de estado.
    expect(find.text('Marcar en limpieza'), findsNothing);
    expect(find.text('Liberar reserva'), findsNothing);
    expect(find.text('Liberar'), findsNothing);
    // Mapa operacional: sin edición (vive en /mesas).
    expect(find.text('Editar mesa'), findsNothing);
  });

  testWidgets('(b) limpieza: solo Liberar', (tester) async {
    await _pumpSheetHost(
      tester,
      _m(EstadoMesa.limpieza),
      _RecordingApiClient(),
      showEdit: false,
    );

    expect(find.text('Liberar'), findsOneWidget);
    expect(find.text('Marcar reservada'), findsNothing);
    expect(find.text('Marcar ocupada'), findsNothing);
    expect(find.text('Marcar en limpieza'), findsNothing);
    expect(find.text('Liberar reserva'), findsNothing);
    expect(find.text('Ver código QR'), findsOneWidget);
  });

  testWidgets('(c) ocupada: solo Marcar en limpieza', (tester) async {
    await _pumpSheetHost(
      tester,
      _m(EstadoMesa.ocupada),
      _RecordingApiClient(),
      showEdit: false,
    );

    expect(find.text('Marcar en limpieza'), findsOneWidget);
    expect(find.text('Marcar reservada'), findsNothing);
    expect(find.text('Marcar ocupada'), findsNothing);
    expect(find.text('Liberar'), findsNothing);
    expect(find.text('Liberar reserva'), findsNothing);
  });

  testWidgets('(d) tap Marcar en limpieza → setMesaEstado(7, "limpieza") + sheet cerrado', (tester) async {
    final client = _RecordingApiClient();
    await _pumpSheetHost(tester, _m(EstadoMesa.ocupada, id: 7), client);

    await tester.tap(find.text('Marcar en limpieza'));
    await tester.pumpAndSettle();

    // Wire exacto: POST /staff/mesas/7/estado {"estado": "limpieza"}.
    expect(client.estadoCalls, [(7, 'limpieza', null)]);
    // El sheet se cerró y el feedback quedó en la pantalla.
    expect(find.text('Marcar en limpieza'), findsNothing);
    expect(find.text('Mesa 7 → limpieza'), findsOneWidget);
  });

  testWidgets('(e) 409 del server (carrera) → SnackBar "cambió de estado" sin crash', (tester) async {
    final client = _RecordingApiClient(throw409: true);
    await _pumpSheetHost(tester, _m(EstadoMesa.ocupada, id: 7), client);

    await tester.tap(find.text('Marcar en limpieza'));
    await tester.pumpAndSettle();

    // La autoridad (server) ganó la carrera: SnackBar accionable. El
    // refresh llega por el evento WS mesa.estado (kick-to-refetch).
    expect(find.textContaining('cambió de estado'), findsOneWidget);
    expect(client.estadoCalls.length, 1);
  });

  testWidgets('(f) tap en MesaTile del dashboard abre el sheet', (tester) async {
    final client = _RecordingApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authStateProvider.overrideWith(() => _FakeAuthState(_meseroUser)),
          statsProvider.overrideWithValue(
            AsyncData(_statsFixture()),
          ),
          mesasProvider.overrideWithValue(
            AsyncData([_m(EstadoMesa.ocupada, id: 7, numero: 7)]),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tap en el tile del mapa (InkWell con ValueKey del tile).
    await tester.tap(find.byKey(const ValueKey('mesa-tile-7')));
    await tester.pumpAndSettle();

    // El sheet abrió con las acciones de la mesa ocupada — y en el mapa
    // SIN edición.
    expect(find.text('Marcar en limpieza'), findsOneWidget);
    expect(find.text('Editar mesa'), findsNothing);
    expect(find.text('Ver código QR'), findsOneWidget);
  });
}

DashboardStats _statsFixture() => const DashboardStats(
      mesasDisponibles: 0,
      mesasOcupadas: 1,
      mesasReservadas: 0,
      mesasLimpieza: 0,
      totalMesas: 1,
      reservasHoy: 0,
      pedidosActivos: 0,
    );
