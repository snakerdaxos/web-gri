// test/core/sin_hex_crudos_test.dart — gate contra la reaparición de colores
// sueltos en el panel admin (11-12).
//
// GEMELO: `app_cliente/test/core/sin_hex_crudos_test.dart` (plan 11-19).
// MISMA lógica y MISMO mensaje de fallo en los dos archivos. Si tocas la
// exención, la regexp o el texto del `reason` aquí, hay que portarlo allí:
// son dos paquetes Dart independientes y ninguna suite puede importar a la
// otra (mismo motivo que `theme_tokens_test.dart` y `sin_emojis_test.dart`).
//
// PROCEDENCIA (11-12): el original es el de `app_cliente`. 11-19 se ejecutó
// ANTES que este plan, así que escribió el gate primero y dejó dicho que
// 11-12 debía PORTAR ese archivo, no inventar otro. Esto es ese port: la
// lógica es idéntica y solo cambian los umbrales de la autocomprobación (el
// panel tiene 96 fuentes y ~15 500 líneas, la app cliente menos) y el texto
// que describe de dónde venían los literales.
//
// ── POR QUÉ ────────────────────────────────────────────────────────────────
// Antes de 11-12 el panel tenía 18 `Color(0x…)` repartidos por 12 archivos,
// pese a que `core/theme.dart` afirmaba en su doc comment ser «fuente única
// de verdad visual para TODO el panel». El #E65100 estaba escrito tres veces
// y la sombra de tarjeta siete. Con la paleta escrita a mano en cada sitio,
// cambiar la identidad visual obliga a un barrido manual y cualquier despiste
// deja dos naranjas distintos conviviendo — que es exactamente lo que ya pasa
// entre esta app y la del cliente con los colores de estado de pedido (ver
// `GriSemanticColors`, hallazgo de 11-11).
//
// ── QUÉ CUENTA COMO INFRACCIÓN Y QUÉ NO ────────────────────────────────────
//   · `Color(0x…)` en `lib/**/*.dart`               → PROHIBIDO.
//   · `core/theme.dart` y `core/design_tokens.dart` → EXENTOS: son la fuente
//     única de verdad, y es justo donde tienen que vivir los hex.
//   · líneas de comentario                          → se saltan. La
//     documentación de un token cita su propio hex (`/// #ff4c05 — …`), y un
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
  test('ningún color del panel se declara con un hex crudo', () {
    final raiz = Directory('lib');
    expect(raiz.existsSync(), isTrue,
        reason: 'el test se ejecuta desde la raíz del paquete panel_admin');

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
    // para los gates de `grep` y que esta fase ya ha visto siete veces.
    expect(archivosLeidos, greaterThan(60),
        reason: 'el barrido no encontró los fuentes: gate ciego');
    expect(lineasLeidas, greaterThan(10000),
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

    // …dos en la misma línea se cuentan las dos (los badges del menú
    // llegaron a tener dos en la misma expresión).
    expect(
        _hexCrudo
            .allMatches("_MenuBadge('a', Color(0xFFE65100), Color(0xFFFF8F00))")
            .length,
        2);

    // …la sombra de tarjeta, que es el caso con alpha corto, también casa.
    expect(_hexCrudo.hasMatch('  color: Color(0x0D000000),'), isTrue);

    // …un comentario que cita su propio hex NO es una infracción.
    expect(_esComentario('  /// #ff4c05 — naranja: Color(0xFFFF4C05).'), isTrue);

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
