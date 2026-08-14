import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

/// Fake del ApiClient — graba el pedido que llega a createPedido.
class _FakeClient extends ApiClient {
  List<({int productoId, int cantidad})>? lastItems;
  String? lastNotas;

  @override
  Future<Pedido> createPedido({
    required List<({int productoId, int cantidad})> items,
    String? notas,
  }) async {
    lastItems = items;
    lastNotas = notas;
    return Pedido(
      id: 77,
      sesionId: 10,
      mesaNumero: 3,
      estado: 'enviado',
      total: 25000,
      notas: notas,
      createdAt: DateTime(2026, 8, 14, 13),
      items: const [],
    );
  }
}

SesionMesa _sesion() => SesionMesa(
      id: 10,
      restauranteId: 1,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: 3,
      mesaNumero: 3,
      abiertaEn: DateTime(2026, 8, 14, 12, 30),
      solicitaCuenta: false,
      solicitadaEn: null,
    );

/// Detalle con 2 categorías: Pasta/Pizza/Soda(agotada) en Platos (expandida
/// por defecto), Jugo en Bebidas (colapsada).
RestauranteDetalle _detalle() => RestauranteDetalle(
      id: 1,
      nombre: 'Restaurante Demo GRI',
      tipoCocina: 'Internacional',
      descripcion: null,
      direccion: null,
      calificacion: null,
      categorias: [
        Categoria(id: 1, nombre: 'Platos', orden: 1, productos: [
          const Producto(
              id: 1,
              nombre: 'Pasta',
              descripcion: 'Con salsa de la casa',
              precio: 25000,
              disponible: true),
          const Producto(
              id: 2, nombre: 'Pizza', precio: 32000, disponible: true),
          const Producto(
              id: 3, nombre: 'Soda', precio: 5000, disponible: false),
        ]),
        Categoria(id: 2, nombre: 'Bebidas', orden: 2, productos: [
          const Producto(
              id: 4, nombre: 'Jugo', precio: 8000, disponible: true),
        ]),
      ],
    );

Widget _wrap({ApiClient? client}) {
  final router = GoRouter(
    initialLocation: '/mesa',
    routes: [
      GoRoute(path: '/mesa', builder: (_, _) => const MenuMesaScreen()),
      GoRoute(
        path: '/mesa/pedidos',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('PEDIDOS_PAGE'))),
      ),
      GoRoute(
        path: '/sesion/scan',
        builder: (_, _) => const Scaffold(body: Text('SCAN_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client ?? _FakeClient()),
      sesionProvider.overrideWithValue(AsyncData(_sesion())),
      restauranteDetalleProvider(1).overrideWith((ref) async => _detalle()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// El botón +/- del producto [nombre] (scoping por fila — el orden global
/// de iconos cambia al insertar el [-]).
Finder _btnProducto(String nombre, IconData icon) => find.descendant(
      of: find.ancestor(of: find.text(nombre), matching: find.byType(ListTile)),
      matching: find.byIcon(icon),
    );

void main() {
  testWidgets('menú de la mesa renderiza 2 categorías y carrito vacío',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Mesa 3 · Restaurante Demo GRI'), findsOneWidget);
    expect(find.text('Platos'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('tap + agrega al carrito: badge (1) y total COP correcto',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pump();

    expect(find.textContaining('Carrito (1)'), findsOneWidget);
    // El bar muestra el total Y la fila del menú sigue mostrando su precio.
    expect(find.textContaining('25.000'), findsAtLeastNWidgets(2));
  });

  testWidgets('+ + − : cantidades correctas y eliminación al llegar a 0',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final mas = _btnProducto('Pasta', Icons.add_circle_outline);
    final menos = _btnProducto('Pasta', Icons.remove_circle_outline);

    await tester.tap(mas);
    await tester.pump();
    await tester.tap(mas);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('Carrito (2)'), findsOneWidget);
    expect(find.textContaining('50.000'), findsOneWidget);

    await tester.tap(menos);
    await tester.pump();
    expect(find.textContaining('Carrito (1)'), findsOneWidget);

    // Cantidad 1 → la línea desaparece (carrito vacío otra vez).
    await tester.tap(menos);
    await tester.pump();
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
    expect(find.descendant(
            of: find.ancestor(
                of: find.text('Pasta'), matching: find.byType(ListTile)),
            matching: find.byIcon(Icons.remove_circle_outline)),
        findsNothing);
  });

  testWidgets('producto agotado: sin botones y con etiqueta "Agotado"',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Agotado'), findsOneWidget);
    // Solo Pasta y Pizza (disponibles, cat. expandida) tienen botón +.
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
  });

  testWidgets('enviar pedido: items + notas al backend, carrito limpio y navegación',
      (tester) async {
    final client = _FakeClient();
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.textContaining('Carrito (1)'));
    await tester.pumpAndSettle();

    // Sheet del carrito: línea, notas, total informativo y envío.
    expect(find.text('Tu pedido'), findsOneWidget);
    expect(find.text('Pasta ×1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sin cebolla');
    await tester.tap(find.text('Enviar pedido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Llegaron items + notas exactas (sesión implícita server-side).
    expect(client.lastItems, const [(productoId: 1, cantidad: 1)]);
    expect(client.lastNotas, 'Sin cebolla');
    // Confirmación + navegación al estado del pedido.
    expect(find.textContaining('¡Pedido enviado!'), findsOneWidget);
    expect(find.text('PEDIDOS_PAGE'), findsOneWidget);
  });
}
