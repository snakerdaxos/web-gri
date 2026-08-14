import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/mesas/mesas_screen.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests de la pantalla /mesas (MESA-01): render del grid vivo, creación
/// vía FAB (espía createMesa), edición vía actions sheet (espía
/// updateMesa con SOLO campos modificados) y warning de regeneración de
/// QR al cambiar el número.
///
/// Overrides sin red (patrón cola_test): apiClientProvider por fake con
/// espías, authStateProvider class-based, mesasProvider por valor.

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient que registra create/update (getMesas no se usa:
/// mesasProvider se overridea por valor).
class _RecordingApiClient extends ApiClient {
  final List<(int, int, int?)> createCalls = [];
  final List<(int, int?, int?, int?)> updateCalls = [];

  @override
  Future<Mesa> createMesa(
    int numero,
    int capacidad, {
    int? restauranteId,
  }) async {
    createCalls.add((numero, capacidad, restauranteId));
    return Mesa(
      id: 99,
      numero: numero,
      capacidad: capacidad,
      codigoQr: 'GRI-MESA-R1-${numero.toString().padLeft(3, '0')}',
      estado: EstadoMesa.disponible,
    );
  }

  @override
  Future<Mesa> updateMesa(
    int mesaId, {
    int? numero,
    int? capacidad,
    int? restauranteId,
  }) async {
    updateCalls.add((mesaId, numero, capacidad, restauranteId));
    return Mesa(
      id: mesaId,
      numero: numero ?? 1,
      capacidad: capacidad ?? 4,
      codigoQr: 'GRI-MESA-R1-006',
      estado: EstadoMesa.disponible,
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

const _mesas = <Mesa>[
  Mesa(
    id: 1,
    numero: 1,
    capacidad: 4,
    codigoQr: 'GRI-MESA-R1-001',
    estado: EstadoMesa.disponible,
  ),
  Mesa(
    id: 5,
    numero: 5,
    capacidad: 2,
    codigoQr: 'GRI-MESA-R1-005',
    estado: EstadoMesa.ocupada,
  ),
];

Future<void> _pumpScreen(WidgetTester tester, _RecordingApiClient client) async {
  // Viewport alto: el 2º tile queda fuera del viewport default (800x600)
  // y los taps del sheet de edición lo necesitan visible.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(_adminUser)),
        mesasProvider.overrideWithValue(const AsyncData(_mesas)),
      ],
      child: const MaterialApp(home: MesasScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) renderiza el grid con las mesas del provider + FAB', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);

    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 5'), findsOneWidget);
    expect(find.text('Nueva mesa'), findsOneWidget);
    // Header de la pantalla.
    expect(find.text('Mesas'), findsOneWidget);
  });

  testWidgets('(b) FAB → form → numero 9 + capacidad 4 → createMesa(9, 4)', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);

    await tester.tap(find.text('Nueva mesa'));
    await tester.pumpAndSettle();

    // Dialog de creación: 2 campos vacíos.
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '9');
    await tester.enterText(fields.at(1), '4');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Wire exacto: POST /staff/mesas {numero: 9, capacidad: 4}; staff →
    // sin query param.
    expect(client.createCalls, [(9, 4, null)]);
    // Confirmación al usuario (el refresh del grid es por WS, no aquí).
    expect(find.text('Mesa 9 creada'), findsOneWidget);
  });

  testWidgets('(c) edición: cambiar numero 5→6 muestra warning regenera QR y updateMesa solo manda numero', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);

    // Sin warning antes de editar.
    expect(find.textContaining('regenera'), findsNothing);

    // Tile → actions sheet (con edición en /mesas) → Editar mesa.
    await tester.tap(find.text('Mesa 5'));
    await tester.pumpAndSettle();
    expect(find.text('Editar mesa'), findsOneWidget);
    await tester.tap(find.text('Editar mesa'));
    await tester.pumpAndSettle();

    // Form en modo edición pre-cargado (5 / 2).
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '6');
    await tester.pump();

    // El warning de regeneración aparece SOLO al cambiar el número.
    expect(find.textContaining('regenera'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Wire exacto: PATCH /staff/mesas/5 {numero: 6} — capacidad sin
    // cambios NO viaja.
    expect(client.updateCalls, [(5, 6, null, null)]);
  });
}
