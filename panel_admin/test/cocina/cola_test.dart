import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/format.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/cocina/cocina_screen.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests de la cola de cocina (ADMN-05): render de cards (mesa/items/
/// total COP), badge "pidió la cuenta" (PAGO-01), botones según matriz
/// rol×estado (PEDI-05) y estado vacío.
///
/// Overrides sin red (patrón 04-02): pedidosStaffProvider funcional →
/// overrideWithValue(AsyncData); authStateProvider class-based →
/// overrideWith(Fake).

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient que registra las llamadas a avanzarPedido (test e).
class _RecordingApiClient extends ApiClient {
  final List<(int, String)> avanzarCalls = [];

  @override
  Future<PedidoStaff> avanzarPedido(
    int pedidoId,
    String estado, {
    int? restauranteId,
  }) async {
    avanzarCalls.add((pedidoId, estado));
    return _pedido(id: pedidoId, estado: EstadoPedido.aceptado);
  }
}

const _cocinaUser = User(
  id: 9,
  nombre: 'Cocina Demo',
  email: 'cocina@demo.gri.dev',
  role: 'cocina',
  restaurantId: 1,
);

const _meseroUser = User(
  id: 10,
  nombre: 'Mesero Demo',
  email: 'mesero@demo.gri.dev',
  role: 'mesero',
  restaurantId: 1,
);

PedidoStaff _pedido({
  int id = 1,
  int mesa = 3,
  EstadoPedido estado = EstadoPedido.enviado,
  bool solicitaCuenta = false,
  double total = 63000,
  String? notas,
}) => PedidoStaff(
  id: id,
  sesionId: 11,
  mesaNumero: mesa,
  estado: estado,
  total: total,
  notas: notas,
  createdAt: DateTime(2026, 8, 14, 13, 5),
  items: const [
    PedidoStaffItem(
      productoId: 1,
      nombre: 'Pizza Hawaiana',
      cantidad: 2,
      precioUnitario: 25000,
      subtotal: 50000,
    ),
    PedidoStaffItem(
      productoId: 2,
      nombre: 'Limonada',
      cantidad: 2,
      precioUnitario: 6500,
      subtotal: 13000,
    ),
  ],
  usuarioNombre: 'Carlos Pérez',
  solicitaCuenta: solicitaCuenta,
  solicitadaEn: null,
);

// NOTE: Riverpod 3.4.2 no exporta el tipo `Override` públicamente, así que
// cada test inlinea el ProviderScope con su lista de overrides (patrón
// stats_render_test) en vez de un helper tipado.

void main() {
  testWidgets('(a) renderiza cards con mesa, items ×cantidad y total COP', (
    tester,
  ) async {
    // Viewport alto: el ListView es lazy y la 2ª card queda fuera del
    // viewport default (800x600) sin esto.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _FakeAuthState(null)),
          pedidosStaffProvider.overrideWithValue(
            AsyncData([
              _pedido(id: 1, mesa: 3, estado: EstadoPedido.enviado),
              _pedido(
                id: 2,
                mesa: 5,
                estado: EstadoPedido.enPreparacion,
                total: 76000,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: CocinaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mesa 3'), findsOneWidget);
    expect(find.text('Mesa 5'), findsOneWidget);
    // Items "nombre ×cantidad" en ambos cards.
    expect(find.textContaining('Pizza Hawaiana ×2'), findsNWidgets(2));
    expect(find.textContaining('Limonada ×2'), findsNWidgets(2));
    // Totales COP formateados (formatCOP es la única vía — Pitfall 3).
    // 63.000/76.000 son los totals; 50.000 es el subtotal de la Pizza en
    // ambos cards.
    expect(find.text(formatCOP(63000)), findsOneWidget);
    expect(find.text(formatCOP(76000)), findsOneWidget);
    expect(find.text(formatCOP(50000)), findsNWidgets(2));
    // Chips de estado + usuario + hora.
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('En preparación'), findsOneWidget);
    expect(find.textContaining('Carlos Pérez'), findsNWidgets(2));
    expect(find.text('13:05'), findsNWidgets(2));
  });

  testWidgets('(b) badge "pidió la cuenta" solo cuando solicitaCuenta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _FakeAuthState(null)),
          pedidosStaffProvider.overrideWithValue(
            AsyncData([
              _pedido(id: 1, mesa: 3, solicitaCuenta: true),
              _pedido(id: 2, mesa: 5),
            ]),
          ),
        ],
        child: const MaterialApp(home: CocinaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Un solo pedido de los dos pidió la cuenta.
    expect(find.textContaining('pidió la cuenta'), findsOneWidget);
  });

  testWidgets('(c) rol cocina sobre enviado ve Aceptar y Rechazar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _FakeAuthState(_cocinaUser)),
          pedidosStaffProvider.overrideWithValue(
            AsyncData([_pedido(id: 1, mesa: 3, estado: EstadoPedido.enviado)]),
          ),
        ],
        child: const MaterialApp(home: CocinaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });

  testWidgets('(d) cola vacía → estado vacío', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _FakeAuthState(null)),
          pedidosStaffProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const MaterialApp(home: CocinaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay pedidos activos 🎉'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets(
    '(e) tap Aceptar llama avanzarPedido(id, "aceptado") e invalida la cola',
    (tester) async {
      final client = _RecordingApiClient();
      var providerDisposed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            authStateProvider.overrideWith(() => _FakeAuthState(_cocinaUser)),
            // Override funcional con onDispose espía: invalidar → rebuild →
            // dispose del override anterior.
            pedidosStaffProvider.overrideWith((ref) {
              ref.onDispose(() => providerDisposed = true);
              return Stream.value(
                [_pedido(id: 7, mesa: 3, estado: EstadoPedido.enviado)],
              );
            }),
          ],
          child: const MaterialApp(home: CocinaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      // Wire exacto: POST /staff/pedidos/7/estado {"estado": "aceptado"}.
      expect(client.avanzarCalls, [(7, 'aceptado')]);
      expect(providerDisposed, isTrue, reason: 'debe invalidar el provider');
    },
  );

  testWidgets(
    '(f) mesero: sin Aceptar/Rechazar sobre enviado; solo Marcar servido en en_preparación',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _FakeAuthState(_meseroUser)),
            pedidosStaffProvider.overrideWithValue(
              AsyncData([
                _pedido(id: 1, mesa: 3, estado: EstadoPedido.enviado),
                _pedido(id: 2, mesa: 5, estado: EstadoPedido.enPreparacion),
              ]),
            ),
          ],
          child: const MaterialApp(home: CocinaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Matriz PEDI-05 lado mesero: no acepta ni rechaza.
      expect(find.text('Aceptar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);
      // Y sobre en_preparación SOLO ve "Marcar servido" (label mesero).
      expect(find.text('Marcar servido'), findsOneWidget);
      expect(find.text('Servido'), findsNothing);
    },
  );
}
