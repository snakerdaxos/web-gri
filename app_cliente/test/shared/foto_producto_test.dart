// test/shared/foto_producto_test.dart — la foto de un plato (11-30).
//
// EL AGUJERO QUE CIERRA: los 16 productos del proyecto tienen `imagenUrl`
// desde el primer día y el cliente NO pintaba ni una. No había un solo
// `Image` en las dos pantallas de menú: el dato estaba ahí, sin usar.
//
// ── LO QUE ESTE ARCHIVO PRUEBA DE VERDAD ──────────────────────────────────
// Que el widget CONSTRUYE el `Image` correcto (la URL que pide, el ancho que
// pide, la etiqueta que expone) y que su caja mide lo mismo haya foto o no.
//
// ── LO QUE **NO** PRUEBA ──────────────────────────────────────────────────
// Que la foto se VEA. En `flutter test` no hay red: el `HttpClient` del
// binding devuelve 400 a todo, así que aquí NINGUNA imagen llega a
// decodificarse. Eso convierte a este entorno en el banco de pruebas perfecto
// del caso "la URL no responde" —que es justo uno de los tests de abajo— pero
// significa que "la foto se ve y se ve bien" sigue siendo verificación humana.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/gri_icons.dart';
import 'package:gri_cliente/core/imagen_url.dart';
import 'package:gri_cliente/features/shared/foto_producto.dart';

const _unsplash =
    'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80';

/// Monta la foto en una caja de [ancho] pt sobre una pantalla de densidad
/// [dpr] (3.0 = el móvil típico, y el valor por defecto del tester).
Future<void> _pump(
  WidgetTester tester, {
  required String? url,
  double ancho = 300,
  double alto = 168,
  double dpr = 3.0,
  bool atenuada = false,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(400 * dpr, 800 * dpr);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: ancho,
          child: FotoProducto(
            url: url,
            nombre: 'Bandeja paisa',
            alto: alto,
            atenuada: atenuada,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

NetworkImage _network(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image as NetworkImage;

void main() {
  testWidgets('con foto: pide la URL con el ancho del LAYOUT, no la original',
      (tester) async {
    await _pump(tester, url: _unsplash, ancho: 300, dpr: 3);

    // 300 pt × dpr topado en 2 = 600 px -> bucket de 640.
    final esperado = anchoFotoSolicitado(300, 3);
    expect(esperado, 640);

    final uri = Uri.parse(_network(tester).url);
    expect(uri.queryParameters['w'], '640',
        reason: 'la original venía en w=1200: son datos del comensal');
    expect(uri.queryParameters['q'], '80');
    expect(uri.host, 'images.unsplash.com');

    // …y la decodificación también se acota, que es memoria del móvil.
    expect(tester.widget<Image>(find.byType(Image)).cacheWidth, esperado);
  });

  testWidgets('la foto se anuncia con el nombre del plato', (tester) async {
    await _pump(tester, url: _unsplash);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Foto de Bandeja paisa');
  });

  testWidgets('CACHÉ: dos anchos vecinos piden la MISMA URL', (tester) async {
    await _pump(tester, url: _unsplash, ancho: 300);
    final a = _network(tester).url;
    await _pump(tester, url: _unsplash, ancho: 316);
    final b = _network(tester).url;
    expect(a, b,
        reason: 'si la URL cambiara con cada píxel, la clave del ImageCache '
            'cambiaría y la foto se redescargaría al redimensionar');
  });

  testWidgets('sin foto: marcador de posición, NO un hueco', (tester) async {
    await _pump(tester, url: null);

    expect(find.byType(Image), findsNothing, reason: 'no hay nada que pedir');
    expect(find.byType(PlaceholderPlato), findsOneWidget);
    expect(find.byIcon(GriIcons.menu), findsOneWidget);
  });

  testWidgets('una URL que no es http(s) se trata como "sin foto"',
      (tester) async {
    for (final basura in <String>[
      '   ',
      'plato.jpg',
      'javascript:alert(1)',
      'data:image/png;base64,iVBORw0KGgo=',
    ]) {
      await _pump(tester, url: basura);
      expect(find.byType(Image), findsNothing, reason: 'URL: $basura');
      expect(find.byType(PlaceholderPlato), findsOneWidget, reason: basura);
    }
  });

  testWidgets('UNIFORMIDAD: la caja mide lo mismo con foto y sin foto',
      (tester) async {
    await _pump(tester, url: _unsplash, ancho: 300, alto: 168);
    final conFoto = tester.getSize(find.byType(FotoProducto));
    await _pump(tester, url: null, ancho: 300, alto: 168);
    final sinFoto = tester.getSize(find.byType(FotoProducto));

    expect(conFoto, const Size(300, 168));
    expect(sinFoto, conFoto,
        reason: 'una rejilla con agujeros de distinto tamaño se ve peor que '
            'una sin fotos');
  });

  testWidgets(
      'URL rota o inalcanzable: cae al marcador, sin icono de imagen rota y '
      'SIN excepción', (tester) async {
    // En `flutter test` toda petición de red responde 400: esta es la
    // situación real de un host caído, un 404 o un bloqueo de red.
    await _pump(tester, url: 'https://host.que.no.responde/plato.jpg?w=900');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'un host ajeno que falla NO puede tumbar el menú');
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byType(PlaceholderPlato), findsOneWidget);
  });

  testWidgets('agotado: la foto se atenúa (tratamiento visual, no ausencia)',
      (tester) async {
    await _pump(tester, url: _unsplash, atenuada: true);
    expect(find.byType(ColorFiltered), findsWidgets);
    expect(find.byType(Image), findsOneWidget,
        reason: 'atenuar no es dejar de pedir la foto');

    await _pump(tester, url: _unsplash, atenuada: false);
    expect(find.byType(ColorFiltered), findsNothing);
  });
}
