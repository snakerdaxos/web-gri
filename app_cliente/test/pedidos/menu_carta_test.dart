// test/pedidos/menu_carta_test.dart — el CABLEADO de la carta en las dos
// pantallas de menú (11-30).
//
// POR QUÉ ESTE ARCHIVO EXISTE APARTE de `test/shared/producto_card_test.dart`:
// aquel prueba la TARJETA con la URL que le pasan. Este prueba que la pantalla
// le pasa la del PRODUCTO. Es exactamente el fallo que reportó el usuario —
// «el cliente en el menú no puede ver la imagen»—: los 16 productos tenían su
// `imagenUrl` guardada desde Phase 10 y las dos pantallas no la leían. Un test
// de tarjeta no lo habría cazado nunca; este sí.
//
// LO QUE **NO** PRUEBA: que la foto se vea. En `flutter test` no hay red.
// Aquí se comprueba QUÉ URL se pide, no qué píxeles llegan.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/design_tokens.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/theme.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurante_detalle_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/features/shared/foto_producto.dart';
import 'package:gri_cliente/features/shared/producto_card.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';

/// Las URLs REALES del proyecto son de Unsplash y traen su `w` (las 16).
const _urlPasta =
    'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80';
const _urlPizza =
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1600&q=80';

/// Una categoría con dos platos CON foto y uno SIN — el escenario que viene:
/// el seed escribe `imagenUrl: null`, así que los productos nuevos no la
/// tendrán aunque los 16 de hoy sí.
RestauranteDetalle _detalleConFotos() => RestauranteDetalle(
      id: 'demo',
      nombre: 'Restaurante Demo GRI',
      tipoCocina: 'Internacional',
      descripcion: null,
      direccion: null,
      categorias: [
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
              descripcion: 'Con salsa de la casa',
              precio: 25000,
              imagenUrl: _urlPasta,
            ),
            Producto(
              id: 'p2',
              restauranteId: 'demo',
              categoriaId: 'c1',
              nombre: 'Pizza',
              precio: 32000,
              imagenUrl: _urlPizza,
            ),
            Producto(
              id: 'p3',
              restauranteId: 'demo',
              categoriaId: 'c1',
              nombre: 'Ajiaco',
              precio: 21000,
              // Sin foto: el producto que se cree mañana desde el panel.
              imagenUrl: null,
            ),
          ],
        ),
      ],
    );

Future<void> _pumpMenuMesa(WidgetTester tester) async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
      restauranteDetalleProvider('demo')
          .overrideWith((ref) async => _detalleConFotos()),
    ],
    child: MaterialApp(theme: griTheme, home: const MenuMesaScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpDetalle(WidgetTester tester) async {
  final FakeFirebaseFirestore db = await buildFakeFirestoreConSeed();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      restauranteDetalleProvider('demo')
          .overrideWith((ref) async => _detalleConFotos()),
    ],
    child: MaterialApp(
      theme: griTheme,
      home: const RestauranteDetalleScreen(restauranteId: 'demo'),
    ),
  ));
  await tester.pumpAndSettle();
}

/// La URL que de verdad se le pide a la red para el plato [nombre].
String _urlPedida(WidgetTester tester, String nombre) {
  final imagen = tester.widget<Image>(find.descendant(
    of: find.ancestor(
        of: find.text(nombre), matching: find.byType(ProductoCard)),
    matching: find.byType(Image),
  ));
  final resize = imagen.image as ResizeImage;
  return (resize.imageProvider as NetworkImage).url;
}

void main() {
  testWidgets('MENÚ DE LA MESA: cada plato pide SU foto, con el w del layout',
      (tester) async {
    await _pumpMenuMesa(tester);

    final pasta = Uri.parse(_urlPedida(tester, 'Pasta'));
    final pizza = Uri.parse(_urlPedida(tester, 'Pizza'));

    expect(pasta.path, Uri.parse(_urlPasta).path,
        reason: 'la foto DEL plato, no una genérica');
    expect(pizza.path, Uri.parse(_urlPizza).path);
    expect(pasta.path, isNot(pizza.path), reason: 'canario: dos fotos, no una');

    // El `w` original (1200 y 1600) se sustituye por el que cabe en pantalla.
    expect(pasta.queryParameters['w'], isNot('1200'));
    expect(pizza.queryParameters['w'], isNot('1600'));
    expect(pasta.queryParameters['w'], pizza.queryParameters['w'],
        reason: 'misma columna, mismo ancho pedido');
    expect(int.parse(pasta.queryParameters['w']!), lessThan(1200));
    expect(pasta.queryParameters['q'], '80', reason: 'lo demás se respeta');
  });

  testWidgets('MENÚ DE LA MESA: el plato sin foto sale con el marcador',
      (tester) async {
    await _pumpMenuMesa(tester);

    final tarjetaAjiaco = find.ancestor(
        of: find.text('Ajiaco'), matching: find.byType(ProductoCard));
    expect(
        find.descendant(of: tarjetaAjiaco, matching: find.byType(Image)),
        findsNothing);
    expect(
        find.descendant(
            of: tarjetaAjiaco, matching: find.byType(PlaceholderPlato)),
        findsOneWidget);

    // …y su caja mide lo mismo que la de un plato con foto: la carta no
    // cambia de ritmo por un producto sin imagen.
    final conFoto = tester.getSize(find.descendant(
        of: find.ancestor(
            of: find.text('Pasta'), matching: find.byType(ProductoCard)),
        matching: find.byType(FotoProducto)));
    final sinFoto = tester.getSize(
        find.descendant(of: tarjetaAjiaco, matching: find.byType(FotoProducto)));
    expect(sinFoto, conFoto);
  });

  testWidgets('MENÚ DE LA MESA: la carta sigue pidiendo — agregar funciona',
      (tester) async {
    await _pumpMenuMesa(tester);

    // Pulsar la TARJETA agrega el plato (la interacción nueva)…
    await tester.tap(find.ancestor(
        of: find.text('Pasta'), matching: find.byType(ProductoCard)));
    await tester.pump();
    expect(find.textContaining('Carrito (1)'), findsOneWidget);

    // …y el botón + sigue estando y sumando (la interacción de siempre).
    await tester.tap(find.descendant(
      of: find.ancestor(
          of: find.text('Pasta'), matching: find.byType(ProductoCard)),
      matching: find.byIcon(Icons.add_circle_outline),
    ));
    await tester.pump();
    expect(find.textContaining('Carrito (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DETALLE DEL RESTAURANTE: también pinta la foto del plato',
      (tester) async {
    await _pumpDetalle(tester);

    expect(find.byType(ProductoCard), findsWidgets);
    final pasta = Uri.parse(_urlPedida(tester, 'Pasta'));
    expect(pasta.path, Uri.parse(_urlPasta).path);
    expect(pasta.queryParameters['w'], isNot('1200'));

    // Escaparate: aquí no se pide nada, así que no hay controles de carrito.
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el nombre de la CATEGORÍA manda sobre el del plato',
      (tester) async {
    await _pumpMenuMesa(tester);
    final categoria = tester.widget<Text>(find.text('Platos')).style!;
    final plato = tester.widget<Text>(find.text('Pasta')).style!;
    expect(categoria.fontSize, GriText.tituloSeccion.fontSize);
    expect(categoria.fontWeight, FontWeight.bold);
    expect(categoria.fontSize! > plato.fontSize!, isTrue,
        reason: 'una carta se lee por secciones');
  });

  testWidgets('las fotos se anuncian con el nombre de su plato', (tester) async {
    await _pumpMenuMesa(tester);
    final etiquetas = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.semanticLabel)
        .toList();
    expect(etiquetas, contains('Foto de Pasta'));
    expect(etiquetas, contains('Foto de Pizza'));
  });
}
