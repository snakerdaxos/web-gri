import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/clientes/clientes_provider.dart';
import 'package:gri_panel_admin/features/clientes/clientes_screen.dart';
import 'package:gri_panel_admin/models/cliente_resumen.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests de la tabla de clientes (ADMN-03): render de la DataTable2 con
/// formatCOP/conteos, tap en fila → historial dialog con los pedidos del
/// fixture (family clienteHistorialProvider alimentado por fake del
/// ApiClient), y empty state.
///
/// Overrides sin red (patrón mesas_screen_test).

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient: alimenta el family clienteHistorialProvider con los
/// pedidos fixture de Ana (usuario 9).
class _FakeApiClient extends ApiClient {
  @override
  Future<List<PedidoStaff>> getClienteHistorial(
    int usuarioId, {
    int? restauranteId,
  }) async {
    if (usuarioId != 9) return [];
    return _pedidosAna;
  }
}

const _adminUser = User(
  id: 2,
  nombre: 'Admin Demo',
  email: 'admin@demo.gri.dev',
  role: 'admin_restaurante',
  restaurantId: 1,
);

final _clientes = <ClienteResumen>[
  ClienteResumen(
    usuarioId: 9,
    nombre: 'Ana',
    email: 'ana@x.com',
    numPedidos: 3,
    totalGastado: 84500.0,
    ultimoPedidoAt: DateTime.parse('2026-08-14T20:15:03'),
  ),
  ClienteResumen(
    usuarioId: 10,
    nombre: 'Luis',
    email: 'luis@x.com',
    numPedidos: 1,
    totalGastado: 12000.0,
    ultimoPedidoAt: DateTime.parse('2026-08-13T13:05:00'),
  ),
];

final _pedidosAna = <PedidoStaff>[
  PedidoStaff(
    id: 'ped-ana-11',
    restauranteId: 'R1',
    mesaId: 'GRI-MESA-R1-002',
    sesionId: 'GRI-MESA-R1-002',
    mesaNumero: 2,
    estado: EstadoPedido.pagado,
    total: 59500,
    notas: null,
    createdAt: DateTime.parse('2026-08-14T20:15:03'),
    items: const [
      PedidoStaffItem(
        productoId: '5',
        nombre: 'Patacón',
        cantidad: 2,
        precio: 15500,
        subtotal: 31000,
      ),
    ],
    usuarioNombre: 'Ana',
    solicitaCuenta: false,
    solicitadaEn: null,
  ),
];

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<ClienteResumen> clientes,
}) async {
  // Viewport alto: la tabla + dialog necesitan espacio vertical.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        authStateProvider.overrideWith(() => _FakeAuthState(_adminUser)),
        clientesProvider.overrideWith((ref) => Future.value(clientes)),
      ],
      child: const MaterialApp(home: Scaffold(body: ClientesScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) tabla renderiza nombres, total via formatCOP y num pedidos', (tester) async {
    await _pumpScreen(tester, clientes: _clientes);

    // Headers + filas.
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Total gastado'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('ana@x.com'), findsOneWidget);

    // formatCOP: 84500.0 → "$ 84.500" (grouping es_CO).
    expect(find.textContaining('84.500'), findsOneWidget);
    expect(find.textContaining('12.000'), findsOneWidget);

    // Conteos de pedidos por cliente.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Fecha del último pedido (dd/MM/yyyy).
    expect(find.text('14/08/2026'), findsOneWidget);
  });

  testWidgets('(b) tap en fila → dialog historial con Mesa 2 y total del pedido', (tester) async {
    await _pumpScreen(tester, clientes: _clientes);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();

    // Dialog alimentado por clienteHistorialProvider(9) → fake getClienteHistorial.
    expect(find.text('Historial de Ana'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Pagado'), findsOneWidget);
    expect(find.textContaining('59.500'), findsOneWidget);
    // Items resumidos: '2× Patacón'.
    expect(find.text('2× Patacón'), findsOneWidget);

    // Cerrar hace pop del dialog.
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Historial de Ana'), findsNothing);
  });

  testWidgets('(c) empty state con lista vacía', (tester) async {
    await _pumpScreen(tester, clientes: const []);

    expect(find.text('Aún no hay clientes con pedidos'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });
}
