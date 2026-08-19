// GRI — generador determinista de TODOS los assets de marca de las DOS apps.
//
// Por qué existe este archivo en vez de un PNG commiteado a mano:
//   1. No hay ningún logo de GRI en el repo. `documentos/` solo tiene mockups
//      HTML, `mockup.png`, `flujograma.png` y `sdk.png`. El asset se GENERA.
//   2. Descargar imágenes o pedirle un binario al usuario deja un asset opaco
//      que nadie puede regenerar ni auditar. Aquí el logo ES código.
//
// Por qué NO se usa una fuente ni el emoji 🍽️ del mockup: el rasterizado de
// una fuente depende de la versión de la fuente, del hinting y del sistema —
// el mismo comando daría PNG distintos en dos máquinas. Todo el dibujo se hace
// con primitivas geométricas (SDF + antialias analítico), así que la salida es
// bit a bit idéntica en cualquier plataforma y el script es IDEMPOTENTE.
//
// Identidad (mockup `documentos/index.html`, líneas 74-86 y 613-625): cuadrado
// redondeado (border-radius 12px sobre 45x45 ≈ 27% del lado) relleno con
// `--primary` = #FF4C05, y el glifo de plato con cubiertos en blanco.
// La paleta está LOCKED por 11-CONTEXT.md: NO se inventa color nuevo.
//
// Uso:
//   cd app_cliente && dart run tool/gen_branding.dart
//   cd app_cliente && dart run tool/gen_branding.dart --out ../ruta/al/repo
//
// El gate que impide la regresión de estos assets es `npm run audit:branding`.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Naranja de marca GRI (#FF4C05). LOCKED — ver 11-CONTEXT.md.
const int brandR = 0xFF;
const int brandG = 0x4C;
const int brandB = 0x05;

/// Radio del cuadrado redondeado, como fracción del lado (12/45 ≈ 0.267).
const double cornerRadiusRatio = 0.27;

enum IconMode {
  /// Cuadrado redondeado de marca + glifo. Favicon, iconos web, icono base.
  rounded,

  /// Fondo de marca a sangre (el SO aplica su propia máscara) y el glifo
  /// reducido al 80% para respetar la zona segura de los iconos maskable.
  maskable,

  /// Solo el glifo sobre transparente, reducido al 58% para caber en la zona
  /// segura de un adaptive icon de Android SIN inset adicional: el punto más
  /// alejado del glifo queda a 0.284 del lienzo ≈ 30.7dp sobre los 108dp del
  /// adaptive icon, dentro de los 33dp de radio seguro. Por eso el pubspec
  /// declara `adaptive_icon_foreground_inset: 0` — con el 16% por defecto de
  /// flutter_launcher_icons el glifo quedaba diminuto sobre el naranja.
  /// El mismo asset alimenta el splash de Android 12, que enmascara a círculo.
  foreground,
}

double _glyphScaleFor(IconMode mode) => switch (mode) {
  IconMode.rounded => 1.0,
  IconMode.maskable => 0.8,
  IconMode.foreground => 0.58,
};

// ---------------------------------------------------------------------------
// Campos de distancia con signo (SDF). Devuelven la distancia en píxeles al
// borde de la figura: negativa dentro, positiva fuera.
// ---------------------------------------------------------------------------

double _sdRoundedRect(
  double px,
  double py,
  double cx,
  double cy,
  double hw,
  double hh,
  double r,
) {
  final qx = (px - cx).abs() - (hw - r);
  final qy = (py - cy).abs() - (hh - r);
  final ax = math.max(qx, 0.0);
  final ay = math.max(qy, 0.0);
  return math.min(math.max(qx, qy), 0.0) + math.sqrt(ax * ax + ay * ay) - r;
}

/// Anillo (aro) de radio [radius] y grosor 2*[halfThickness].
double _sdRing(
  double px,
  double py,
  double cx,
  double cy,
  double radius,
  double halfThickness,
) {
  final dx = px - cx;
  final dy = py - cy;
  return (math.sqrt(dx * dx + dy * dy) - radius).abs() - halfThickness;
}

/// Cápsula: segmento A→B engordado [r] píxeles. Es una barra de puntas
/// redondeadas — el cubierto.
double _sdCapsule(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
  double r,
) {
  final pax = px - ax;
  final pay = py - ay;
  final bax = bx - ax;
  final bay = by - ay;
  final len2 = bax * bax + bay * bay;
  final h = len2 == 0 ? 0.0 : ((pax * bax + pay * bay) / len2).clamp(0.0, 1.0);
  final dx = pax - bax * h;
  final dy = pay - bay * h;
  return math.sqrt(dx * dx + dy * dy) - r;
}

/// Cobertura del píxel a partir de la distancia con signo. Antialias analítico
/// de 1px: evita supermuestreo (que sería lento y no más determinista).
double _coverage(double d) => (0.5 - d).clamp(0.0, 1.0);

/// El glifo: un plato (aro exterior = borde del plato, aro interior = fondo)
/// flanqueado por dos cubiertos verticales de puntas redondeadas.
double _sdGlyph(double px, double py, double s, double c, double scale) {
  double n(double v) => v * s * scale;
  final platoBorde = _sdRing(px, py, c, c, n(0.220), n(0.019));
  final platoFondo = _sdRing(px, py, c, c, n(0.135), n(0.013));
  final cubiertoIzq = _sdCapsule(
    px,
    py,
    c - n(0.345),
    c - n(0.300),
    c - n(0.345),
    c + n(0.300),
    n(0.042),
  );
  final cubiertoDer = _sdCapsule(
    px,
    py,
    c + n(0.345),
    c - n(0.300),
    c + n(0.345),
    c + n(0.300),
    n(0.042),
  );
  return math.min(
    math.min(platoBorde, platoFondo),
    math.min(cubiertoIzq, cubiertoDer),
  );
}

// ---------------------------------------------------------------------------
// Rasterizado
// ---------------------------------------------------------------------------

/// Dibuja el icono a [size]x[size] en el modo pedido. Función pura: mismos
/// argumentos ⇒ mismos bytes, siempre.
img.Image render(int size, IconMode mode) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final s = size.toDouble();
  final c = s / 2;
  final radio = s * cornerRadiusRatio;
  final glyphScale = _glyphScaleFor(mode);

  for (var y = 0; y < size; y++) {
    final py = y + 0.5;
    for (var x = 0; x < size; x++) {
      final px = x + 0.5;

      final fondoA = switch (mode) {
        IconMode.rounded => _coverage(
          _sdRoundedRect(px, py, c, c, c, c, radio),
        ),
        // A sangre: el maskable NO puede tener transparencia, el SO recorta.
        IconMode.maskable => 1.0,
        IconMode.foreground => 0.0,
      };
      final glifoA = _coverage(_sdGlyph(px, py, s, c, glyphScale));

      // Composición «source-over»: glifo blanco sobre fondo de marca sobre
      // transparente.
      final outA = glifoA + fondoA * (1 - glifoA);
      if (outA <= 0) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      final fondoPeso = fondoA * (1 - glifoA);
      final r = (255 * glifoA + brandR * fondoPeso) / outA;
      final g = (255 * glifoA + brandG * fondoPeso) / outA;
      final b = (255 * glifoA + brandB * fondoPeso) / outA;
      image.setPixelRgba(
        x,
        y,
        r.round().clamp(0, 255),
        g.round().clamp(0, 255),
        b.round().clamp(0, 255),
        (outA * 255).round().clamp(0, 255),
      );
    }
  }
  return image;
}

// ---------------------------------------------------------------------------
// Salidas
// ---------------------------------------------------------------------------

typedef Target = ({String path, int size, IconMode mode, String para});

/// Rutas RELATIVAS A LA RAÍZ DEL REPO. Los cuatro nombres de `web/icons/`
/// coinciden EXACTAMENTE con los que ya declaran los dos `manifest.json`:
/// cambiarlos aquí rompe las rutas del PWA (y `audit:branding` lo detecta).
List<Target> targets() {
  final out = <Target>[
    (
      path: 'app_cliente/assets/branding/icon_1024.png',
      size: 1024,
      mode: IconMode.rounded,
      para: 'fuente de flutter_launcher_icons',
    ),
    (
      path: 'app_cliente/assets/branding/icon_512.png',
      size: 512,
      mode: IconMode.rounded,
      para: 'fuente de flutter_native_splash',
    ),
    (
      path: 'app_cliente/assets/branding/icon_foreground_1024.png',
      size: 1024,
      mode: IconMode.foreground,
      para: 'adaptive_icon_foreground de Android',
    ),
  ];
  for (final app in ['app_cliente', 'panel_admin']) {
    out.add((
      path: '$app/web/favicon.png',
      size: 64,
      mode: IconMode.rounded,
      para: 'pestaña del navegador',
    ));
    out.add((
      path: '$app/web/icons/Icon-192.png',
      size: 192,
      mode: IconMode.rounded,
      para: 'PWA / apple-touch-icon',
    ));
    out.add((
      path: '$app/web/icons/Icon-512.png',
      size: 512,
      mode: IconMode.rounded,
      para: 'PWA',
    ));
    out.add((
      path: '$app/web/icons/Icon-maskable-192.png',
      size: 192,
      mode: IconMode.maskable,
      para: 'PWA maskable',
    ));
    out.add((
      path: '$app/web/icons/Icon-maskable-512.png',
      size: 512,
      mode: IconMode.maskable,
      para: 'PWA maskable',
    ));
  }
  return out;
}

/// Sube por el árbol hasta encontrar la raíz del repo (el directorio que
/// contiene las DOS apps). Así el script funciona igual desde `app_cliente/`
/// que desde la raíz.
Directory? _buscarRaiz(Directory desde) {
  var dir = desde.absolute;
  for (var i = 0; i < 6; i++) {
    final a = Directory('${dir.path}${Platform.pathSeparator}app_cliente');
    final b = Directory('${dir.path}${Platform.pathSeparator}panel_admin');
    if (a.existsSync() && b.existsSync()) return dir;
    final padre = dir.parent;
    if (padre.path == dir.path) break;
    dir = padre;
  }
  return null;
}

void main(List<String> args) {
  String? outArg;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      outArg = args[i + 1];
    } else if (args[i].startsWith('--out=')) {
      outArg = args[i].substring('--out='.length);
    } else if (args[i] == '-h' || args[i] == '--help') {
      stdout.writeln(
        'Uso: dart run tool/gen_branding.dart [--out <raiz-del-repo>]',
      );
      return;
    }
  }

  final raiz = outArg != null
      ? Directory(outArg)
      : _buscarRaiz(Directory.current);
  if (raiz == null || !raiz.existsSync()) {
    stderr.writeln(
      'ERROR: no encuentro la raíz del repo (el directorio con app_cliente/ y '
      'panel_admin/). Pásala con --out.',
    );
    exitCode = 1;
    return;
  }

  // Una sola rasterización por (tamaño, modo); varios destinos la comparten.
  final cache = <String, List<int>>{};
  var escritos = 0;
  var iguales = 0;

  for (final t in targets()) {
    final clave = '${t.size}:${t.mode.name}';
    final bytes = cache.putIfAbsent(
      clave,
      () => img.encodePng(render(t.size, t.mode)),
    );

    final destino = File(
      '${raiz.path}${Platform.pathSeparator}'
      '${t.path.replaceAll('/', Platform.pathSeparator)}',
    );
    destino.parent.createSync(recursive: true);

    // Idempotencia observable: si el contenido ya coincide no se reescribe.
    if (destino.existsSync()) {
      final actual = destino.readAsBytesSync();
      if (actual.length == bytes.length) {
        var identico = true;
        for (var i = 0; i < bytes.length; i++) {
          if (actual[i] != bytes[i]) {
            identico = false;
            break;
          }
        }
        if (identico) {
          iguales++;
          stdout.writeln('  =  ${t.path}  (${t.size}px, ${t.mode.name})');
          continue;
        }
      }
    }
    destino.writeAsBytesSync(bytes);
    escritos++;
    stdout.writeln(
      '  →  ${t.path}  (${t.size}px, ${t.mode.name}) — ${t.para}',
    );
  }

  stdout.writeln(
    'BRANDING_OK: ${targets().length} assets '
    '($escritos escritos, $iguales sin cambios) en ${raiz.path}',
  );
}
