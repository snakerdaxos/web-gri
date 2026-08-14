import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/features/dashboard/dashboard_screen.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/dashboard/stats_provider.dart';
import 'package:gri_panel_admin/models/dashboard_stats.dart';
import 'package:gri_panel_admin/models/mesa.dart';

/// Tests del dashboard (ADMN-01): verifica que se rendericen las 4 stat cards
/// con datos mock, el spinner de loading y el mensaje de error.
///
/// Overrideamos statsProvider y mesasProvider con AsyncData/Loading/Error para
/// evitar tocar la red en el test runner.

DashboardStats _statsFixture() => const DashboardStats(
      mesasDisponibles: 3,
      mesasOcupadas: 2,
      mesasReservadas: 1,
      mesasLimpieza: 1,
      totalMesas: 7,
      reservasHoy: 5,
      pedidosActivos: 2,
    );

const _mesasFixture = <Mesa>[
  Mesa(
    id: 1,
    numero: 1,
    capacidad: 4,
    codigoQr: 'GRI-MESA-001',
    estado: EstadoMesa.disponible,
  ),
  Mesa(
    id: 2,
    numero: 2,
    capacidad: 2,
    codigoQr: 'GRI-MESA-002',
    estado: EstadoMesa.ocupada,
  ),
  Mesa(
    id: 3,
    numero: 3,
    capacidad: 6,
    codigoQr: 'GRI-MESA-003',
    estado: EstadoMesa.reservada,
  ),
];

void main() {
  testWidgets('renders 4 stat cards with mock data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsProvider.overrideWithValue(AsyncData(_statsFixture())),
          mesasProvider.overrideWithValue(const AsyncData(_mesasFixture)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Labels de los 4 cards presentes.
    expect(find.text('Mesas disponibles'), findsOneWidget);
    expect(find.text('Mesas ocupadas'), findsOneWidget);
    expect(find.text('Reservas hoy'), findsOneWidget);
    expect(find.text('Pedidos activos'), findsOneWidget);

    // Valores (3, 2, 5, 2 del fixture) — busca Text widgets con esos strings.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2)); // ocupadas + pedidos activos
    expect(find.text('5'), findsOneWidget);

    // Mesas: tiles presentes con sus números.
    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
  });

  testWidgets('renders loading indicator while stats loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsProvider.overrideWithValue(const AsyncLoading()),
          mesasProvider.overrideWithValue(const AsyncData(_mesasFixture)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    // No hacer pumpAndSettle: AsyncLoading infinito nunca se settle.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders error message on stats error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsProvider.overrideWithValue(
            AsyncError('boom', StackTrace.current),
          ),
          mesasProvider.overrideWithValue(const AsyncData(_mesasFixture)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.text('Reintentar'), findsWidgets);
  });
}
