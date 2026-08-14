import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/configuracion/configuracion_screen.dart';
import 'package:gri_panel_admin/models/categoria_staff.dart';
import 'package:gri_panel_admin/models/restaurante.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests del tab 'Restaurantes' de /configuracion (PLAT-05, solo
/// super_admin): lista con inactivos (switch OFF), espía del wire
/// patchRestauranteActivo(id, activo) y ausencia total del tab para staff.
///
/// Overrides sin red (patrón cola_test): apiClientProvider → fake con
/// listRestaurantes + patchRestauranteActivo espías; authStateProvider
/// class-based con fixtures super_admin/admin_restaurante.

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient: listRestaurantes registra el flag incluir_inactivos;
/// patchRestauranteActivo registra el wire; getStaffMenu alimenta el tab
/// Menú (embebido en la misma pantalla) sin red.
class _FakeApiClient extends ApiClient {
  final List<bool> incluirInactivosCalls = [];
  final List<(int, bool)> patchCalls = [];
  List<Restaurante> restaurantes;

  _FakeApiClient(this.restaurantes);

  @override
  Future<List<Restaurante>> listRestaurantes({
    bool incluirInactivos = false,
  }) async {
    incluirInactivosCalls.add(incluirInactivos);
    return restaurantes;
  }

  @override
  Future<Restaurante> patchRestauranteActivo(int id, bool activo) async {
    patchCalls.add((id, activo));
    restaurantes = [
      for (final r in restaurantes)
        if (r.id == id) r.copyWith(activo: activo) else r,
    ];
    return restaurantes.firstWhere((r) => r.id == id);
  }

  @override
  Future<List<CategoriaStaff>> getStaffMenu({int? restauranteId}) async {
    return const [];
  }
}

const _superAdmin = User(
  id: 1,
  nombre: 'Super Admin',
  email: 'super@demo.gri.dev',
  role: 'super_admin',
  restaurantId: null,
);

const _staffUser = User(
  id: 2,
  nombre: 'Admin Demo',
  email: 'admin@demo.gri.dev',
  role: 'admin_restaurante',
  restaurantId: 1,
);

List<Restaurante> _fixtures() => [
      const Restaurante(
        id: 1,
        nombre: 'GRI Demo',
        tipoCocina: 'Colombiana',
        direccion: 'Calle 1',
        activo: true,
      ),
      const Restaurante(
        id: 2,
        nombre: 'Sushi House',
        tipoCocina: 'Japonesa',
        direccion: 'Calle 2',
        activo: false,
      ),
    ];

Future<void> _pump(
  WidgetTester tester,
  _FakeApiClient client, {
  User user = _superAdmin,
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
      child: const MaterialApp(home: Scaffold(body: ConfiguracionScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '(a) super_admin: tab Restaurantes con 2 restaurantes (1 activo, 1 inactivo OFF)',
    (tester) async {
      final client = _FakeApiClient(_fixtures());
      await _pump(tester, client);

      // TabBar: los 3 tabs existen para super_admin.
      expect(find.text('Menú'), findsOneWidget);
      expect(find.text('Restaurante'), findsOneWidget);
      expect(find.text('Restaurantes'), findsOneWidget);

      // Navegar al tab Restaurantes (TabBarView es lazy).
      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      // La lista pidió incluir_inactivos (única vista que los expone).
      expect(client.incluirInactivosCalls, [true]);
      // 2 restaurantes renderizados con su estado.
      expect(find.text('GRI Demo'), findsOneWidget);
      expect(find.text('Sushi House'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
      // Switch OFF en el inactivo (Sushi House, id 2).
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      expect(tester.widget<Switch>(switches.at(0)).value, isTrue);
      expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
    },
  );

  testWidgets('(b) toggle en el inactivo → espía patchRestauranteActivo(2, true)', (
    tester,
  ) async {
    final client = _FakeApiClient(_fixtures());
    await _pump(tester, client);

    await tester.tap(find.text('Restaurantes'));
    await tester.pumpAndSettle();

    // Encender el switch OFF (Sushi House).
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    // Wire exacto: PATCH /admin/restaurantes/2 {"activo": true}.
    expect(client.patchCalls, [(2, true)]);
    expect(find.text('Restaurante reactivado'), findsOneWidget);
  });

  testWidgets('(c) staff: tab Restaurantes AUSENTE; Menú/Restaurante presentes', (
    tester,
  ) async {
    final client = _FakeApiClient(_fixtures());
    await _pump(tester, client, user: _staffUser);

    expect(find.text('Restaurantes'), findsNothing);
    expect(find.text('Menú'), findsOneWidget);
    expect(find.text('Restaurante'), findsOneWidget);
    // El provider de admin jamás se construye para staff.
    expect(client.incluirInactivosCalls, isEmpty);
  });
}
