// test/core/sin_hex_crudos_test.dart — gate contra la reaparición de colores
// sueltos en la app cliente (11-19).
//
// GEMELO: `panel_admin/test/core/sin_hex_crudos_test.dart` (plan 11-12).
// MISMA lógica y MISMO mensaje de fallo en los dos archivos. Si tocas la
// exención, los rangos o el texto del `reason` aquí, hay que portarlo allí:
// son dos paquetes Dart independientes y ninguna suite puede importar a la
// otra (mismo motivo que `theme_tokens_test.dart` y `sin_emojis_test.dart`).
//
// AVISO (11-19): cuando se escribió este archivo, el plan 11-12 TODAVÍA no
// se había ejecutado, así que el gemelo del panel no existía y no había de
// dónde copiar. Este es el original; quien ejecute 11-12 debe portar ESTE
// archivo, no escribir otro distinto.
//
// ── POR QUÉ ────────────────────────────────────────────────────────────────
// Antes de 11-19 la app cliente tenía 20 `Color(0x…)` repartidos por 6
// pantallas: el ámbar de la calificación aparecía NUEVE veces y el degradado
// de cabecera estaba copiado en cuatro. Con la paleta escrita a mano en cada
// sitio, cambiar la identidad visual obliga a un barrido manual y cualquier
// despiste deja dos naranjas distintos conviviendo — que es exactamente lo
// que ya pasa entre esta app y el panel con los colores de estado de pedido
// (ver `GriSemanticColors`, hallazgo de 11-11).
//
// ── QUÉ CUENTA COMO INFRACCIÓN Y QUÉ NO ────────────────────────────────────
//   · `Color(0x…)` en `lib/**/*.dart`               → PROHIBIDO.
//   · `core/theme.dart` y `core/design_tokens.dart` → EXENTOS: son la fuente
//     única de verdad, y es justo donde tienen que vivir los hex.
//   · líneas de comentario                          → se saltan. La
//     documentación de un token cita su propio hex (`/// #f5a623 — …`), y un
//     archivo no puede autoinvalidarse por documentarse.
//   · `// TOKEN-IGNORE: motivo` en la MISMA línea o en la ANTERIOR → exento,
//     con el motivo escrito al lado del código.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un literal de color de Flutter: `Color(0xFF123456)`, `Color(0x0D000000)`.
///
/// No busca `Colors.red` ni `withValues(alpha:)` a propósito: son APIs con
/// nombre, no hex crudos, y perseguirlas aquí mezclaría dos problemas
/// distintos (el segundo lo trata 11-14).
final RegExp _hexCrudo = RegExp(r'Color\(0x[0-9a-fA-F]+\)');

/// Archivos donde un hex SÍ es legítimo, relativos a la raíz del paquete.
const _exentos = <String>[
  'lib/core/theme.dart',
  'lib/core/design_tokens.dart',
];

/// Comentario de línea, de bloque o continuación de doc comment.
bool _esComentario(String linea) {
  final t = linea.trimLeft();
  return t.startsWith('//') || t.startsWith('/*') || t.startsWith('*');
}

const _marcaExencion = 'TOKEN-IGNORE:';

/// True si la línea `i` está exenta por marca propia o de la línea anterior.
bool _exenta(List<String> lineas, int i) =>
    lineas[i].contains(_marcaExencion) ||
    (i > 0 && lineas[i - 1].contains(_marcaExencion));

String _rel(String path) => path.replaceAll(r'\', '/');

void main() {
  test('ningún color de la app cliente se declara con un hex crudo', () {
    final raiz = Directory('lib');
    expect(raiz.existsSync(), isTrue,
        reason: 'el test se ejecuta desde la raíz del paquete app_cliente');

    final infracciones = <String>[];
    var archivosLeidos = 0;
    var lineasLeidas = 0;
    var exentosVistos = 0;

    for (final f in raiz
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final ruta = _rel(f.path);
      if (_exentos.contains(ruta)) {
        exentosVistos++;
        continue;
      }
      archivosLeidos++;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        lineasLeidas++;
        final linea = lineas[i];
        if (_esComentario(linea)) continue;
        if (_exenta(lineas, i)) continue;
        for (final m in _hexCrudo.allMatches(linea)) {
          infracciones.add('$ruta:${i + 1}  ${m.group(0)}   ${linea.trim()}');
        }
      }
    }

    // Autocomprobación del propio gate: si el barrido no leyera nada, o si
    // los archivos exentos hubieran cambiado de nombre, la aserción de abajo
    // pasaría por el motivo equivocado — el modo de fallo que 11-08 documentó
    // para los gates de `grep` y que esta fase ya ha visto seis veces.
    expect(archivosLeidos, greaterThan(30),
        reason: 'el barrido no encontró los fuentes: gate ciego');
    expect(lineasLeidas, greaterThan(1000),
        reason: 'el barrido no leyó contenido: gate ciego');
    expect(exentosVistos, _exentos.length,
        reason: 'alguno de los archivos exentos ($_exentos) ya no existe con '
            'ese nombre: la exención está colgando y el gate dejaría pasar '
            'hex nuevos allí, o dejaría de mirar donde debe');

    expect(infracciones, isEmpty,
        reason: 'color(es) suelto(s) fuera del tema:\n'
            '  ${infracciones.join('\n  ')}\n\n'
            'Promueve el color a `GriColors` con un nombre semántico y el '
            'MISMO valor. Si de verdad tiene que vivir aquí, anota '
            '`// $_marcaExencion motivo` en esa línea o en la anterior.');
  });

  test('el gate detecta un hex nuevo (autocomprobación con dientes)', () {
    // Sin esto, una regexp mal escrita dejaría el test de arriba verde para
    // siempre. Las cuatro ramas de la decisión, cada una con su caso.
    const infractor = "  color: Color(0xFF123456),";
    expect(_esComentario(infractor), isFalse);
    expect(_hexCrudo.hasMatch(infractor), isTrue);

    // …dos en la misma línea se cuentan las dos (el degradado era así).
    expect(
        _hexCrudo
            .allMatches('colors: [Color(0xFFFF6B35), Color(0xFFFF9B5A)],')
            .length,
        2);

    // …un comentario que cita su propio hex NO es una infracción.
    expect(_esComentario('  /// #f5a623 — ámbar: Color(0xFFF5A623).'), isTrue);

    // …la exención vale en la misma línea y en la anterior.
    expect(
        _exenta(<String>['  color: Color(0xFF123456), // $_marcaExencion x'], 0),
        isTrue);
    expect(
        _exenta(<String>[
          '  // $_marcaExencion x',
          '  color: Color(0xFF123456),',
        ], 1),
        isTrue);
    expect(_exenta(<String>['  color: Color(0xFF123456),'], 0), isFalse);

    // …y `Colors.white` no entra en el alcance de este gate.
    expect(_hexCrudo.hasMatch('  color: Colors.white,'), isFalse);
  });
}
