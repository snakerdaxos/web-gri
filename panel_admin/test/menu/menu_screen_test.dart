import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/features/menu/menu_provider.dart';
import 'package:gri_panel_admin/features/menu/menu_screen.dart';
import 'package:gri_panel_admin/models/categoria_staff.dart';
import 'package:gri_panel_admin/models/producto_staff.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests de la gestión del menú (MENU-01/02, tab Menú de /configuracion):
/// render de categorías/productos con badges, creación de categoría vía
/// espía + invalidate observable, toggle 'Agotado' → updateProducto
/// (disponible: false) y badge 'Inactiva' para categoría inactiva.
///
/// Overrides sin red (patrón mesas_screen_test): apiClientProvider fake con
/// espías, authStateProvider class-based y staffMenuProvider override CON
/// CONTADOR de builds (el invalidate de los forms es observable).

/// Fake del AuthState (class-based) — evita secure storage en el runner.
class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fake del ApiClient que registra los writes de menú (getStaffMenu no se
/// usa: staffMenuProvider se overridea con contador).
class _RecordingApiClient extends ApiClient {
  int menuBuilds = 0;

  final List<(String, int?, int?)> createCategoriaCalls = [];
  final List<(int, String?, int?, bool?, int?)> updateCategoriaCalls = [];
  final List<(int, String?, String?, double?, String?, bool?, bool?, int?)>
      updateProductoCalls = [];

  @override
  Future<CategoriaStaff> createCategoria(
    String nombre, {
    int? orden,
    int? restauranteId,
  }) async {
    createCategoriaCalls.add((nombre, orden, restauranteId));
    return CategoriaStaff(
      id: 99,
      nombre: nombre,
      orden: orden ?? 0,
      activo: true,
      productos: const [],
    );
  }

  @override
  Future<CategoriaStaff> updateCategoria(
    int categoriaId, {
    String? nombre,
    int? orden,
    bool? activo,
    int? restauranteId,
  }) async {
    updateCategoriaCalls.add(
      (categoriaId, nombre, orden, activo, restauranteId),
    );
    return CategoriaStaff(
      id: categoriaId,
      nombre: nombre ?? 'x',
      orden: orden ?? 0,
      activo: activo ?? true,
      productos: const [],
    );
  }

  @override
  Future<ProductoStaff> updateProducto(
    int productoId, {
    String? nombre,
    String? descripcion,
    double? precio,
    String? imagenUrl,
    bool? disponible,
    bool? activo,
    int? restauranteId,
  }) async {
    updateProductoCalls.add(
      (productoId, nombre, descripcion, precio, imagenUrl, disponible, activo,
          restauranteId),
    );
    return ProductoStaff(
      id: productoId,
      categoriaId: 1,
      nombre: nombre ?? 'x',
      descripcion: descripcion,
      precio: precio ?? 0,
      imagenUrl: imagenUrl,
      disponible: disponible ?? true,
      activo: activo ?? true,
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

/// Fixtures: 'Entradas' activa (Patacón disponible + Arepa AGOTADA) y
/// 'Postres' INACTIVA (badge) — el staff ve TODO (08-01).
final _menu = <CategoriaStaff>[
  const CategoriaStaff(
    id: 1,
    nombre: 'Entradas',
    orden: 0,
    activo: true,
    productos: [
      ProductoStaff(
        id: 5,
        categoriaId: 1,
        nombre: 'Patacón',
        descripcion: null,
        precio: 15500.0,
        imagenUrl: null,
        disponible: true,
        activo: true,
      ),
      ProductoStaff(
        id: 6,
        categoriaId: 1,
        nombre: 'Arepa rellena',
        descripcion: 'Con hogao',
        precio: 12000.0,
        imagenUrl: null,
        disponible: false,
        activo: true,
      ),
    ],
  ),
  const CategoriaStaff(
    id: 2,
    nombre: 'Postres',
    orden: 1,
    activo: false,
    productos: [],
  ),
];

Future<void> _pumpScreen(WidgetTester tester, _RecordingApiClient client) async {
  // Viewport alto: ExpansionTiles expandidos + dialogs visibles.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(_adminUser)),
        // Override CON contador: el ref.invalidate(staffMenuProvider) de los
        // forms es observable (builds > 1 tras guardar).
        staffMenuProvider.overrideWith((ref) {
          client.menuBuilds++;
          return Future.value(_menu);
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: MenuScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) renderiza categorías; expandida muestra productos con formatCOP y badge Agotado', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);

    // Las 2 categorías colapsadas (badge 'Inactiva' en título de Postres).
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Postres'), findsOneWidget);

    // Expandir Entradas → productos + precio formateado + badge del agotado.
    await tester.tap(find.text('Entradas'));
    await tester.pumpAndSettle();

    expect(find.text('Patacón'), findsOneWidget);
    expect(find.text('Arepa rellena'), findsOneWidget);
    expect(find.textContaining('15.500'), findsOneWidget);
    expect(find.textContaining('12.000'), findsOneWidget);
    // Badge ámbar SOLO en el producto agotado (semántica visible).
    expect(find.text('Agotado'), findsOneWidget);
    // 'Nuevo producto' visible SOLO expandido.
    expect(find.text('Nuevo producto'), findsOneWidget);
    // Patacón disponible/activo → sin badges extra.
    expect(find.text('Inactivo'), findsNothing);
  });

  testWidgets('(b) Nueva categoría → dialog → Bebidas → espía createCategoria + invalidate', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);
    expect(client.menuBuilds, 1);

    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();

    // Dialog: nombre + orden (default 0).
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Bebidas');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Wire exacto: POST /staff/categorias {nombre: 'Bebidas', orden: 0};
    // staff (admin_restaurante) → sin query param.
    expect(client.createCategoriaCalls, [('Bebidas', 0, null)]);
    // Confirmación + refresh on-demand (invalidate → rebuild del provider).
    expect(find.text('Categoría "Bebidas" creada'), findsOneWidget);
    expect(client.menuBuilds, greaterThan(1));
  });

  testWidgets('(c) toggle Agotado ON en un producto → espía updateProducto(id, disponible: false)', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);

    // Expandir y abrir la edición del Patacón.
    await tester.tap(find.text('Entradas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patacón'));
    await tester.pumpAndSettle();

    // Switch 'Agotado' (SwitchListTile del dialog — NO el badge de la fila).
    final agotadoSwitch = find.widgetWithText(SwitchListTile, 'Agotado');
    expect(agotadoSwitch, findsOneWidget);
    await tester.tap(agotadoSwitch);
    await tester.pump();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Wire exacto: PATCH /staff/productos/5 {disponible: false} — SOLO el
    // campo que cambió (nombre/precio/etc. sin cambios NO viajan).
    // 'Agotado' = !disponible → switch ON → disponible: false.
    expect(client.updateProductoCalls, [
      (5, null, null, null, null, false, null, null),
    ]);
    expect(find.text('Producto actualizado'), findsOneWidget);
  });

  testWidgets('(d) badge Inactiva visible para la categoría inactiva', (tester) async {
    final client = _RecordingApiClient();
    await _pumpScreen(tester, client);

    // 'Postres' (activo: false) muestra el badge en el título SIN expandir.
    expect(find.text('Inactiva'), findsOneWidget);
    // La categoría activa no lo muestra.
    expect(find.text('Entradas'), findsOneWidget);
  });
}
