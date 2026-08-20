import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/carrito_controller.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/shared/producto_card.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';

/// Items de pedido de prueba (2× Pasta + 1× Jugo = 57000 COP).
const _items = [
  PedidoItem(productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 2),
  PedidoItem(productoId: 'p4', nombre: 'Jugo', precio: 7000, cantidad: 1),
];

/// Detalle con 2 categorías: Pasta/Pizza/Soda(agotada) en Platos (expandida
/// por defecto), Jugo en Bebidas (colapsada). Ids String (Phase 10).
RestauranteDetalle _detalle() => RestauranteDetalle(
      id: 'demo',
      nombre: 'Restaurante Demo GRI',
      tipoCocina: 'Internacional',
      descripcion: null,
      direccion: null,
      categorias: [
        Categoria(id: 'c1', restauranteId: 'demo', nombre: 'Platos', orden: 1,
            productos: [
          const Producto(
              id: 'p1',
              restauranteId: 'demo',
              categoriaId: 'c1',
              nombre: 'Pasta',
              descripcion: 'Con salsa de la casa',
              precio: 25000,
              disponible: true),
          const Producto(
              id: 'p2',
              restauranteId: 'demo',
              categoriaId: 'c1',
              nombre: 'Pizza',
              precio: 32000,
              disponible: true),
          const Producto(
              id: 'p3',
              restauranteId: 'demo',
              categoriaId: 'c1',
              nombre: 'Soda',
              precio: 5000,
              disponible: false),
        ]),
        Categoria(id: 'c2', restauranteId: 'demo', nombre: 'Bebidas', orden: 2,
            productos: [
          const Producto(
              id: 'p4',
              restauranteId: 'demo',
              categoriaId: 'c2',
              nombre: 'Jugo',
              precio: 8000,
              disponible: true),
        ]),
      ],
    );

/// Bombea el MenuMesaScreen con db+auth fakes y sesión REAL abierta en la
/// mesa 1 (vía abrirSesion — misma vía que producción).
Future<FakeFirebaseHandle> _pumpConSesion(WidgetTester tester) async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
      restauranteDetalleProvider('demo')
          .overrideWith((ref) async => _detalle()),
    ],
    child: const MaterialApp(home: MenuMesaScreen()),
  ));
  await tester.pumpAndSettle();
  return FakeFirebaseHandle(db);
}

/// Handle del db fake para que los widget tests puedan inspeccionar docs.
class FakeFirebaseHandle {
  FakeFirebaseHandle(this.db);

  final dynamic db;
}

/// El botón +/- del producto [nombre] (scoping por TARJETA — el orden global
/// de iconos cambia al insertar el [-]).
///
/// 11-30: el ancla era `ListTile`. El menú dejó de ser una lista de filas y
/// pasó a ser una carta de [ProductoCard]; el scoping es el mismo, sobre otro
/// tipo. Lo que se prueba —que el botón es el DE ESE plato— no cambia.
Finder _btnProducto(String nombre, IconData icon) => find.descendant(
      of: find.ancestor(
          of: find.text(nombre), matching: find.byType(ProductoCard)),
      matching: find.byIcon(icon),
    );

void main() {
  // ── Unidad: snapshot del carrito + tx crearPedido ───────────────────────

  test(
      'SNAPSHOT: agregar congela nombre/precio — cambiar el doc después NO altera carrito ni pedido',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    // Producto leído del doc (vía canonical fromDoc).
    final snap = await db.collection('productos').get();
    final docPasta =
        snap.docs.firstWhere((d) => d.data()['nombre'] == 'Bandeja paisa');
    final producto = Producto.fromDoc(docPasta);
    expect(producto.precio, 28000);

    // Agregar al carrito...
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(carritoProvider.notifier).agregar(producto);
    expect(container.read(carritoProvider).total, 28000);

    // ...el menú cambia después...
    await db.doc('productos/${docPasta.id}').update({
      'precio': 99000,
      'nombre': 'Bandeja XL',
    });

    // ...y el carrito SIGUE congelado.
    expect(container.read(carritoProvider).total, 28000);

    // El doc de pedido también nace con el precio ORIGINAL.
    final id = await crearPedido(db,
        uid: 'uid-a',
        mesaCodigo: _mesa,
        items: [
          for (final l in container.read(carritoProvider).values)
            l.toPedidoItem(),
        ]);
    final pedido = (await db.collection('pedidos').get())
        .docs
        .firstWhere((d) => d.id == id);
    expect(pedido.data()['items'],
      [
        {
          'productoId': docPasta.id,
          'nombre': 'Bandeja paisa',
          'precio': 28000,
          'cantidad': 1,
        }
      ],
      reason: 'items con snapshot original',
    );
    expect(pedido.data()['total'], 28000);
  });

  test(
      'crearPedido: doc estado enviado, items snapshot, total int, sesionId == mesaId',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    final id = await crearPedido(db,
        uid: 'uid-a',
        mesaCodigo: _mesa,
        clienteNombre: 'Carlos',
        items: _items);

    final pedido = (await db.collection('pedidos').get())
        .docs
        .firstWhere((d) => d.id == id);
    expect(pedido.data()['estado'], 'enviado');
    expect(pedido.data()['sesionId'], _mesa, reason: 'sesionId == mesaId');
    expect(pedido.data()['mesaId'], _mesa);
    expect(pedido.data()['restauranteId'], 'demo');
    expect(pedido.data()['usuarioId'], 'uid-a');
    expect(pedido.data()['clienteNombre'], 'Carlos');
    expect(pedido.data()['total'], 57000, reason: '25000×2 + 7000×1');
    expect((pedido.data()['items'] as List).length, 2);
  });

  test('crearPedido con sesión CERRADA → error controlado, sin doc creado',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);
    await db.doc('sesiones/$_mesa').update({'estado': 'cerrada'});

    await expectLater(
      crearPedido(db, uid: 'uid-a', mesaCodigo: _mesa, items: _items),
      throwsA(isA<PedidoException>()),
    );
    expect((await db.collection('pedidos').get()).docs, isEmpty);
  });

  test(
      'crearPedido con sesión de OTRO usuario → error controlado (anti-spoofing)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    await expectLater(
      crearPedido(db, uid: 'intruso', mesaCodigo: _mesa, items: _items),
      throwsA(isA<PedidoException>()),
    );
    expect((await db.collection('pedidos').get()).docs, isEmpty);
  });

  test('crearPedido con carrito vacío → error (UX anticipa la regla)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    await expectLater(
      crearPedido(db, uid: 'uid-a', mesaCodigo: _mesa, items: const []),
      throwsA(isA<PedidoException>()
          .having((e) => e.message, 'message', 'Tu carrito está vacío')),
    );
  });

  // ── Widgets: menú de la mesa + carrito (sesión real Firestore) ──────────

  testWidgets('menú de la mesa renderiza 2 categorías y carrito vacío',
      (tester) async {
    await _pumpConSesion(tester);

    expect(find.text('Mesa 1 · Restaurante Demo GRI'), findsOneWidget);
    expect(find.text('Platos'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Tu carrito está vacío'), findsOneWidget);

    // 'Bebidas' es la SEGUNDA categoría y hay que bajar hasta ella: desde
    // 11-30 cada plato es una tarjeta con foto (~280 px) en vez de una fila
    // de ~60, así que los 3 platos de la primera categoría ya no caben con
    // la cabecera siguiente en un viewport de 600 px de alto. Sigue
    // afirmando lo mismo —que las DOS categorías se pintan—, pero pagando
    // el scroll que también paga el comensal.
    await tester.scrollUntilVisible(find.text('Bebidas'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Bebidas'), findsOneWidget);
  });

  testWidgets('tap + agrega al carrito: badge (1) y total COP correcto',
      (tester) async {
    await _pumpConSesion(tester);

    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pump();

    expect(find.textContaining('Carrito (1)'), findsOneWidget);
    // El bar muestra el total Y la fila del menú sigue mostrando su precio.
    expect(find.textContaining('25.000'), findsAtLeastNWidgets(2));
  });

  testWidgets('+ + − : cantidades correctas y eliminación al llegar a 0',
      (tester) async {
    await _pumpConSesion(tester);

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
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('Pasta'), matching: find.byType(ProductoCard)),
            matching: find.byIcon(Icons.remove_circle_outline)),
        findsNothing);
  });

  testWidgets('producto agotado: sin botones y con etiqueta "Agotado"',
      (tester) async {
    await _pumpConSesion(tester);

    expect(find.text('Agotado'), findsOneWidget);
    // Solo Pasta y Pizza (disponibles, cat. expandida) tienen botón +.
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
  });

  testWidgets(
      'enviar pedido: doc con items snapshot + total, carrito limpio y navegación',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);

    final router = GoRouter(
      initialLocation: '/mesa',
      routes: [
        GoRoute(path: '/mesa', builder: (_, _) => const MenuMesaScreen()),
        GoRoute(
          path: '/mesa/pedidos',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('PEDIDOS_PAGE'))),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        restauranteDetalleProvider('demo')
            .overrideWith((ref) async => _detalle()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.textContaining('Carrito (1)'));
    await tester.pumpAndSettle();

    // Sheet del carrito: línea + total informativo. Sin campo de notas —
    // el doc shape de pedidos NO las incluye (Phase 10).
    expect(find.text('Tu pedido'), findsOneWidget);
    expect(find.text('Pasta ×1'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Enviar pedido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Confirmación + navegación al estado del pedido.
    expect(find.textContaining('¡Pedido enviado!'), findsOneWidget);
    expect(find.text('PEDIDOS_PAGE'), findsOneWidget);

    // El doc nace con el snapshot exacto del carrito.
    final pedidos = (await db.collection('pedidos').get()).docs;
    expect(pedidos, hasLength(1));
    expect(pedidos.first.data()['estado'], 'enviado');
    expect(pedidos.first.data()['sesionId'], _mesa);
    expect(pedidos.first.data()['total'], 25000);
    expect(pedidos.first.data()['items'],
      [
        {'productoId': 'p1', 'nombre': 'Pasta', 'precio': 25000, 'cantidad': 1}
      ],
    );
  });
}
