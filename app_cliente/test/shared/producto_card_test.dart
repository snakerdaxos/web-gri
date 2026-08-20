// test/shared/producto_card_test.dart — la tarjeta de plato de la carta y su
// rejilla (11-30).
//
// EL PROBLEMA QUE ARREGLA, en palabras del usuario probando la app real:
// «no se puede ver de una manera cómoda el menú… se ve como lista, no como
// carta». Eran filas de `ListTile` con el texto apretado y el precio en el
// `trailing`. Aquí se afirma lo que SÍ se puede medir de una carta: que cada
// plato es una tarjeta con su foto, que el precio es más grande que el texto
// de alrededor, que el plato agotado se distingue sin leer, y que nada de eso
// desborda ni a 320 px ni en una ventana ancha.
//
// LO QUE **NO** SE PRUEBA AQUÍ: que la carta resulte apetecible. Eso no lo
// mide ningún widget test — lo juzga el usuario, que es quien detectó el
// problema.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/design_tokens.dart';
import 'package:gri_cliente/core/format.dart';
import 'package:gri_cliente/core/theme.dart';
import 'package:gri_cliente/features/shared/foto_producto.dart';
import 'package:gri_cliente/features/shared/producto_card.dart';
import 'package:gri_cliente/models/producto.dart';

const _foto =
    'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80';

Producto _p({
  String id = 'p1',
  String nombre = 'Bandeja paisa',
  String? descripcion = 'Frijoles, chicharrón, chorizo, huevo y arepa',
  int precio = 28000,
  String? imagenUrl = _foto,
  bool disponible = true,
}) =>
    Producto(
      id: id,
      restauranteId: 'demo',
      categoriaId: 'c1',
      nombre: nombre,
      descripcion: descripcion,
      precio: precio,
      imagenUrl: imagenUrl,
      disponible: disponible,
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required Producto producto,
  double ancho = 320,
  Widget? accion,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: griTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: ancho,
          child: ProductoCard(
            producto: producto,
            accion: accion,
            onTap: onTap,
            etiquetaAccion: 'Agregar ${producto.nombre} al pedido',
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

TextStyle _estilo(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style!;

void main() {
  testWidgets('la tarjeta lleva la foto del plato, con el alto 16:9 del ancho',
      (tester) async {
    await _pumpCard(tester, producto: _p(), ancho: 320);

    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(FotoProducto), findsOneWidget);
    // 320 × 9/16 = 180 (dentro del acotado 120–200).
    expect(tester.getSize(find.byType(FotoProducto)), const Size(320, 180));
    expect(find.byType(Image), findsOneWidget, reason: 'la foto se pide');
  });

  testWidgets('el alto de la foto se acota en las ventanas anchas',
      (tester) async {
    await _pumpCard(tester, producto: _p(), ancho: 700);
    // 700 × 9/16 = 393,75 -> se topa en 200: en escritorio la carta no se
    // convierte en una tira de pósteres de un plato por pantalla.
    expect(tester.getSize(find.byType(FotoProducto)).height, 200);
  });

  testWidgets('nombre, descripción y PRECIO destacado', (tester) async {
    await _pumpCard(tester, producto: _p());

    expect(find.text('Bandeja paisa'), findsOneWidget);
    expect(find.text('Frijoles, chicharrón, chorizo, huevo y arepa'),
        findsOneWidget);
    // `formatCOP` mete un espacio DURO entre el símbolo y la cifra (es_CO):
    // escribir el literal a mano daría un finder que nunca casa.
    final etiquetaPrecio = formatCOP(28000);
    expect(etiquetaPrecio, contains('28.000'), reason: 'canario del formato');
    expect(find.text(etiquetaPrecio), findsOneWidget, reason: 'formatCOP');

    final precio = _estilo(tester, etiquetaPrecio);
    final nombre = _estilo(tester, 'Bandeja paisa');
    final desc = _estilo(tester, 'Frijoles, chicharrón, chorizo, huevo y arepa');

    expect(precio.color, GriColors.primary);
    expect(precio.fontWeight, FontWeight.bold);
    expect(precio.fontSize, GriText.tituloSeccion.fontSize);
    expect(precio.fontSize! > nombre.fontSize!, isTrue,
        reason: 'el precio era el `trailing` gris de un ListTile; en una '
            'carta es lo segundo que se mira');
    expect(precio.fontSize! > desc.fontSize!, isTrue);

    // …y no es solo el estilo declarado: la caja pintada es más alta.
    expect(tester.getSize(find.text(etiquetaPrecio)).height,
        greaterThan(tester.getSize(find.text('Bandeja paisa')).height));
  });

  testWidgets('sin descripción no deja un hueco', (tester) async {
    await _pumpCard(tester, producto: _p(descripcion: null));
    expect(find.text('Bandeja paisa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('descripción larga: 2 líneas y elipsis, la tarjeta no crece',
      (tester) async {
    final largo = 'palabra ' * 80;
    await _pumpCard(tester, producto: _p(descripcion: largo));
    final texto = tester.widget<Text>(find.textContaining('palabra'));
    expect(texto.maxLines, 2);
    expect(texto.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull, reason: 'ni un desbordamiento');
  });

  testWidgets('AGOTADO: etiqueta, foto en gris, precio apagado y sin acción',
      (tester) async {
    await _pumpCard(
      tester,
      producto: _p(disponible: false),
      accion: const Icon(Icons.add_circle_outline),
      onTap: () {},
    );

    expect(find.text('Agotado'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsWidgets,
        reason: 'la foto del plato agotado se ve en gris');
    expect(find.byIcon(Icons.add_circle_outline), findsNothing,
        reason: 'no se pide lo que no hay, aunque le pasen una acción');
    expect(_estilo(tester, formatCOP(28000)).color,
        GriColors.textoSecundarioAccesible);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull,
        reason: 'y la tarjeta tampoco es pulsable');
  });

  testWidgets('la tarjeta disponible es pulsable, con etiqueta y >= 48 dp',
      (tester) async {
    final handle = tester.ensureSemantics();
    var toques = 0;
    await _pumpCard(tester, producto: _p(), onTap: () => toques++);

    await tester.tap(find.byType(ProductoCard));
    expect(toques, 1, reason: 'pulsar el plato lo agrega, como en una carta');

    expect(find.bySemanticsLabel('Agregar Bandeja paisa al pedido'),
        findsOneWidget);
    final caja = tester.getSize(find.byType(ProductoCard));
    expect(caja.width, greaterThanOrEqualTo(48));
    expect(caja.height, greaterThanOrEqualTo(48));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('sin foto la tarjeta mantiene la misma forma', (tester) async {
    await _pumpCard(tester, producto: _p(imagenUrl: null), ancho: 320);
    expect(find.byType(PlaceholderPlato), findsOneWidget);
    expect(tester.getSize(find.byType(FotoProducto)), const Size(320, 180));
  });

  // ── Rejilla adaptativa ───────────────────────────────────────────────────

  Future<void> pumpLista(WidgetTester tester, double ancho) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(ancho, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: griTheme,
      home: Scaffold(
        body: ListView(children: [
          ListaProductos(
            productos: [
              _p(id: 'p1', nombre: 'Uno'),
              _p(id: 'p2', nombre: 'Dos'),
              _p(id: 'p3', nombre: 'Tres'),
            ],
            tarjeta: (p) => ProductoCard(producto: p),
          ),
        ]),
      ),
    ));
    await tester.pump();
  }

  testWidgets('en móvil (320) la carta va a UNA columna', (tester) async {
    await pumpLista(tester, 320);
    expect(tester.takeException(), isNull, reason: 'nada desborda a 320');
    final uno = tester.getRect(find.byType(ProductoCard).at(0));
    final dos = tester.getRect(find.byType(ProductoCard).at(1));
    expect(dos.top, greaterThan(uno.bottom - 1), reason: 'una debajo de otra');
    expect(uno.width, greaterThan(250), reason: 'ocupa el ancho disponible');
  });

  testWidgets('en ventana ancha (900) la carta va a DOS columnas',
      (tester) async {
    await pumpLista(tester, 900);
    expect(tester.takeException(), isNull);
    final uno = tester.getRect(find.byType(ProductoCard).at(0));
    final dos = tester.getRect(find.byType(ProductoCard).at(1));
    final tres = tester.getRect(find.byType(ProductoCard).at(2));

    expect(dos.left, greaterThan(uno.right - 1), reason: 'segunda al lado');
    expect(dos.top, uno.top);
    expect(tres.top, greaterThan(uno.bottom - 1), reason: 'tercera abajo');
    expect(uno.width, lessThan(500),
        reason: 'una tarjeta de 900 px de ancho no es una carta');
  });
}
