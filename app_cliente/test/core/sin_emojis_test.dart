// test/core/sin_emojis_test.dart — gate contra la reaparición de emojis
// usados como iconografía en la app cliente (11-13).
//
// GEMELO: `panel_admin/test/core/sin_emojis_test.dart` (plan 11-21).
//
// ── POR QUÉ ────────────────────────────────────────────────────────────────
// Un emoji NO es un icono: su forma la decide la fuente del sistema, así que
// el mismo glifo se ve distinto en Android, en iOS y en cada navegador, y
// puede no existir. La app cliente tenía 4 de ellos como iconos de la barra
// inferior. El usuario pidió expresamente sustituirlos (11-CONTEXT, «Emojis
// como iconos»).
//
// ── QUÉ CUENTA COMO INFRACCIÓN Y QUÉ NO ────────────────────────────────────
// Solo el USO 1 de los tres que distingue el plan:
//   1. iconografía de interfaz  → PROHIBIDO (esto es lo que caza el gate)
//   2. comentario/documentación → permitido: no se renderiza. Se detecta
//      saltando las líneas de comentario.
//   3. texto expresivo (🙌 👋 😕) → permitido SOLO con exención explícita
//      `// EMOJI-OK: motivo` en la misma línea.
//
// La exención es deliberadamente ruidosa: obliga a escribir el motivo al lado
// del código, y `docs/ICONOS-app_cliente.md` recoge la lista completa.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rangos Unicode de pictogramas. NO incluyen las flechas (U+2190–U+21FF),
/// porque `→` se usa a mansalva en los comentarios y en los mensajes de
/// [TransicionInvalidaException] y es tipografía, no un icono.
///
/// OJO CON U+2B00–U+2BFF: ahí vive `⭐` (U+2B50). El `grep` que proponía el
/// plan (`[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]`) NO lo cubre, así que se le
/// escapaban las 4 estrellas de calificación — justo una de las filas de su
/// propia tabla de equivalencias.
const _rangos = <(int, int)>[
  (0x1F300, 0x1FAFF), // pictogramas, emoticonos, símbolos suplementarios
  (0x2600, 0x27BF), // símbolos misceláneos + dingbats (⚠ ✓ ✅ ☕)
  (0x2B00, 0x2BFF), // flechas y estrellas suplementarias (⭐)
  (0x1F000, 0x1F2FF), // fichas, cartas, ideogramas encerrados
];

bool _esEmoji(int r) => _rangos.any((x) => r >= x.$1 && r <= x.$2);

/// Comentario de línea, comentario de bloque o continuación de doc comment.
bool _esComentario(String linea) {
  final t = linea.trimLeft();
  return t.startsWith('//') || t.startsWith('/*') || t.startsWith('*');
}

const _marcaExencion = 'EMOJI-OK:';

void main() {
  test('ningún emoji se usa como iconografía en lib/ de la app cliente', () {
    final raiz = Directory('lib');
    expect(raiz.existsSync(), isTrue,
        reason: 'el test se ejecuta desde la raíz del paquete app_cliente');

    final infracciones = <String>[];
    var archivosLeidos = 0;
    var lineasLeidas = 0;

    for (final f in raiz
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      archivosLeidos++;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        lineasLeidas++;
        final linea = lineas[i];
        if (_esComentario(linea)) continue;
        if (linea.contains(_marcaExencion)) continue;

        final glifos = linea.runes.where(_esEmoji).toList();
        if (glifos.isEmpty) continue;
        final texto = glifos.map(String.fromCharCode).join(' ');
        infracciones.add(
            '${f.path.replaceAll(r'\', '/')}:${i + 1}  $texto   ${linea.trim()}');
      }
    }

    // Autocomprobación del propio gate: si el recorrido no leyera nada, la
    // aserción de abajo pasaría por el motivo equivocado (el modo de fallo
    // que 11-08 documentó para los gates de grep).
    expect(archivosLeidos, greaterThan(30),
        reason: 'el barrido no encontró los fuentes: gate ciego');
    expect(lineasLeidas, greaterThan(1000),
        reason: 'el barrido no leyó contenido: gate ciego');

    expect(infracciones, isEmpty,
        reason: 'emoji(s) en literales renderizados:\n'
            '  ${infracciones.join('\n  ')}\n\n'
            'Usa GriIcons + Icon(). Si de verdad es texto expresivo y no un '
            'icono, anota `// $_marcaExencion motivo` en esa misma línea y '
            'añádelo a la sección «Conservados» de docs/ICONOS-app_cliente.md');
  });

  test('el gate detecta un emoji nuevo (autocomprobación con dientes)', () {
    // Sin esto, un fallo en los rangos o en el filtro de comentarios dejaría
    // el test de arriba verde para siempre sin que nadie se enterara.
    const linea = "  const Text('\u{1F355}'), // pizza";
    expect(_esComentario(linea), isFalse);
    expect(linea.runes.any(_esEmoji), isTrue);

    // …y respeta la exención.
    const exenta = "  const Text('\u{1F355}'), // $_marcaExencion es una pizza";
    expect(exenta.contains(_marcaExencion), isTrue);

    // …y NO confunde la flecha de los mensajes de dominio con un icono.
    expect('→'.runes.any(_esEmoji), isFalse);

    // …y SÍ cubre la estrella que el grep del plan se dejaba fuera.
    expect('⭐'.runes.any(_esEmoji), isTrue);
  });
}
