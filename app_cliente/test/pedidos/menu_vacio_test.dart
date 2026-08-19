import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/features/shared/empty_state.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';

/// EL CASO CRÍTICO DE ESTE ARCHIVO (11-09).
///
/// `menu_mesa_screen.dart` es la pantalla a la que se llega DESPUÉS de escanear
/// el QR de la mesa — o sea, a mitad del flujo del cliente, sentado ya en el
/// restaurante. Su rama `data:` renderizaba un `ListView` cuyos únicos hijos
/// salían de `for (cat in detalle.categorias)`: con un restaurante de 0
/// categorías el cuerpo quedaba COMPLETAMENTE EN BLANCO, sin una sola palabra.
/// Una pantalla en blanco es la forma que tiene una app de decirle al usuario
/// que está rota.
///
/// Su hermana `restaurante_detalle_screen.dart` ya trataba bien el mismo caso,
/// lo que confirma que era un olvido y no una decisión.
///
/// Los dos casos van juntos a propósito: el vacío y su CONTRARIO. Un guard mal
/// puesto (p.ej. `isEmpty` invertido, o un `return` que se come el ListView)
/// deja verde el primer test y rompe el segundo.
RestauranteDetalle _detalle({required List<Categoria> categorias}) =>
    RestauranteDetalle(
      id: 'demo',
      nombre: 'Restaurante Demo GRI',
      tipoCocina: 'Internacional',
      descripcion: null,
      direccion: null,
      categorias: categorias,
    );

List<Categoria> _conPlatos() => [
      Categoria(
        id: 'c1',
        restauranteId: 'demo',
        nombre: 'Platos',
        orden: 1,
        productos: const [
          Producto(
            id: 'p1',
            restauranteId: 'demo',
            categoriaId: 'c1',
            nombre: 'Pasta',
            precio: 25000,
            disponible: true,
          ),
        ],
      ),
    ];

/// Bombea `MenuMesaScreen` con una sesión REAL abierta en la mesa 1 (misma vía
/// que producción: `abrirSesion`) y el detalle del restaurante inyectado.
Future<void> _pumpMenu(
  WidgetTester tester, {
  required List<Categoria> categorias,
}) async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
      restauranteDetalleProvider('demo')
          .overrideWith((ref) async => _detalle(categorias: categorias)),
    ],
    child: const MaterialApp(home: MenuMesaScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('menú de la mesa con 0 categorías (el caso post-escaneo del QR)', () {
    testWidgets(
        'muestra titular + guía accionable en lugar de un cuerpo en blanco',
        (tester) async {
      await _pumpMenu(tester, categorias: const []);

      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(
        find.text('Este restaurante aún no publicó su menú'),
        findsOneWidget,
      );
      // La guía dice QUÉ HACER, no solo qué pasa. Sin esto el estado vacío
      // informa pero no resuelve, que es la mitad del problema.
      expect(
        find.text('Avísale al mesero para que tome tu pedido en la mesa.'),
        findsOneWidget,
      );
      // Y no hay ningún resto del menú: el guard sustituye al ListView.
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('sigue siendo la pantalla de la mesa: AppBar y barra inferior',
        (tester) async {
      await _pumpMenu(tester, categorias: const []);

      // Si el guard hubiera devuelto un Scaffold nuevo (en vez de ocupar solo
      // el `body`), el cliente perdería el título de su mesa y el carrito.
      expect(
        find.text('Mesa 1 · Restaurante Demo GRI'),
        findsOneWidget,
        reason: 'el AppBar de la mesa debe sobrevivir al estado vacío',
      );
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
    });
  });

  group('EL CONTRARIO: menú CON categorías (no-regresión)', () {
    testWidgets('renderiza los ExpansionTile y NO muestra la guía de vacío',
        (tester) async {
      await _pumpMenu(tester, categorias: _conPlatos());

      expect(tester.takeException(), isNull);
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Platos'), findsOneWidget);
      expect(find.text('Pasta'), findsOneWidget);

      // El guard no puede dispararse cuando SÍ hay menú.
      expect(find.byType(EmptyState), findsNothing);
      expect(
        find.text('Este restaurante aún no publicó su menú'),
        findsNothing,
      );
    });
  });
}
