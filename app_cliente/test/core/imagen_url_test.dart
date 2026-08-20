// test/core/imagen_url_test.dart — el saneado y el dimensionado de las URLs de
// foto de plato (11-30).
//
// POR QUÉ EXISTE. Las fotos de los platos son URLs EXTERNAS escritas a mano en
// el panel (Cloud Storage exige plan Blaze y el usuario lo descartó), así que
// el cliente recibe una cadena arbitraria de un tercero: puede venir vacía, mal
// formada, con un esquema que no es http, o apuntando a una imagen de 4000 px
// que en un móvil son megas de datos del comensal. Este archivo fija QUÉ hace
// la app con cada una de esas cadenas ANTES de que llegue a un `Image`.
//
// LO QUE ESTO NO PRUEBA: que la foto se vea (no hay red en `flutter test`),
// ni que el CDN respete el `w` que le pedimos. Eso es del widget y del humano.
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/imagen_url.dart';

void main() {
  group('urlFotoSegura', () {
    test('acepta http y https y devuelve la URL sin espacios sobrantes', () {
      const unsplash =
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=800';
      expect(urlFotoSegura(unsplash), unsplash);
      expect(urlFotoSegura('  $unsplash  '), unsplash);
      expect(urlFotoSegura('http://ejemplo.com/plato.jpg'),
          'http://ejemplo.com/plato.jpg');
    });

    test('descarta lo que no es una foto direccionable', () {
      expect(urlFotoSegura(null), isNull, reason: 'producto sin foto');
      expect(urlFotoSegura(''), isNull);
      expect(urlFotoSegura('   '), isNull, reason: 'campo dejado en blanco');
      expect(urlFotoSegura('plato.jpg'), isNull, reason: 'sin esquema ni host');
      expect(urlFotoSegura('https://'), isNull, reason: 'sin host');
    });

    test('descarta esquemas que no son http(s) — no se navega lo que llega '
        'de un campo de texto ajeno', () {
      expect(urlFotoSegura('javascript:alert(1)'), isNull);
      expect(urlFotoSegura('file:///etc/passwd'), isNull);
      expect(urlFotoSegura('ftp://ejemplo.com/plato.jpg'), isNull);
      expect(urlFotoSegura('data:image/png;base64,iVBORw0KGgo='), isNull);
    });
  });

  group('anchoFotoSolicitado', () {
    test('multiplica por el dpr y redondea HACIA ARRIBA al paso', () {
      expect(anchoFotoSolicitado(320, 1), 384, reason: '320 -> bucket de 384');
      expect(anchoFotoSolicitado(256, 1), 256, reason: 'ya es múltiplo');
      expect(anchoFotoSolicitado(352, 2), 768, reason: '704 -> 768');
    });

    test('el dpr se topa en $dprMaxFoto — un móvil 3x no descarga el triple',
        () {
      expect(anchoFotoSolicitado(360, 3), anchoFotoSolicitado(360, 2));
      expect(anchoFotoSolicitado(360, 4), 768, reason: '360×2 = 720 -> 768');
    });

    test('queda dentro de [$anchoFotoMin, $anchoFotoMax]', () {
      expect(anchoFotoSolicitado(10, 1), anchoFotoMin);
      expect(anchoFotoSolicitado(0, 1), anchoFotoMin);
      expect(anchoFotoSolicitado(-5, 1), anchoFotoMin);
      expect(anchoFotoSolicitado(double.infinity, 1), anchoFotoMax);
      expect(anchoFotoSolicitado(double.nan, 1), anchoFotoMin);
      expect(anchoFotoSolicitado(4000, 2), anchoFotoMax);
    });

    test('CACHÉ: anchos vecinos caen en el MISMO bucket', () {
      // La URL es la clave del ImageCache de Flutter. Si el ancho pedido
      // cambiase con cada píxel del layout (rotación, redimensionar la
      // ventana, la barra del teclado), cada frame sería una URL nueva y la
      // foto se volvería a descargar. El bucket es lo que lo impide.
      final buckets = <int>{
        for (var w = 300.0; w <= 384.0; w += 1) anchoFotoSolicitado(w, 1),
      };
      expect(buckets, <int>{384});
      // …y saltar de bucket sigue siendo posible (si no, el paso no serviría).
      expect(anchoFotoSolicitado(385, 1), 512);
    });
  });

  group('urlFotoConAncho', () {
    const unsplash =
        'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80';

    test('reescribe el w que la URL YA trae y conserva el resto', () {
      final u = Uri.parse(urlFotoConAncho(unsplash, 640));
      expect(u.queryParameters['w'], '640');
      expect(u.queryParameters['q'], '80', reason: 'no se toca lo demás');
      expect(u.host, 'images.unsplash.com');
      expect(u.path, '/photo-1544025162-d76694265947');
      expect(u.scheme, 'https');
    });

    test('la URL SIN parámetro de ancho se devuelve INTACTA', () {
      // No se le añade un `w` a ciegas: una URL ajena puede venir firmada
      // (Storage, S3) y un parámetro de más invalida la firma. Sin `w`, el
      // servidor no ha declarado que sepa redimensionar.
      const sinW = 'https://ejemplo.com/fotos/plato.jpg';
      const conToken = 'https://ejemplo.com/p.jpg?token=abc&sig=XYZ%2F1';
      expect(urlFotoConAncho(sinW, 640), sinW);
      expect(urlFotoConAncho(conToken, 640), conToken);
    });

    test('con w y h escala el alto en proporción — no deforma el recorte', () {
      final u = Uri.parse(
          urlFotoConAncho('https://cdn.ej/p.jpg?w=1200&h=800&fit=crop', 600));
      expect(u.queryParameters['w'], '600');
      expect(u.queryParameters['h'], '400', reason: '800 × 600/1200');
      expect(u.queryParameters['fit'], 'crop');
    });

    test('un w que no es un número se deja como está', () {
      const raro = 'https://cdn.ej/p.jpg?w=auto';
      expect(urlFotoConAncho(raro, 640), raro);
    });

    test('es idempotente: aplicarla dos veces da la MISMA cadena', () {
      final una = urlFotoConAncho(unsplash, 640);
      expect(urlFotoConAncho(una, 640), una,
          reason: 'si no, la clave del ImageCache bailaría entre frames');
    });
  });
}
