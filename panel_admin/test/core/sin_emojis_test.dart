@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ningún emoji puede volver a usarse como ICONOGRAFÍA en `lib/` (11-21).
///
/// ── LOS TRES USOS, Y SOLO UNO ESTÁ PROHIBIDO ──────────────────────────────
/// 1. **Icono de interfaz** — el glifo ES el icono de un ítem del sidebar, de
///    una stat card, de una acción o de un estado vacío. PROHIBIDO: la forma
///    la decide la fuente del sistema, así que el mismo panel se ve distinto
///    en cada SO y en cada navegador. Éste es el uso que 11-21 sustituyó por
///    `Icon(GriIcons.x)`.
/// 2. **Comentario o documentación** en el código. PERMITIDO y no se toca:
///    los `⚠️` que encabezan los avisos de `firestore.rules`, de
///    `equipo_provider.dart` o de este mismo archivo no se renderizan nunca.
/// 3. **Texto expresivo o caso de prueba** — los `★★★` de
///    `configuracion/slug.dart` son la entrada de un slug inválido, no un
///    icono. PERMITIDO con exención explícita.
///
/// Un `grep` a secas no distingue los tres. Este gate salta las líneas de
/// comentario, mira solo los literales de cadena, y exige que cualquier
/// excepción se declare EN LA MISMA LÍNEA con `// EMOJI-OK: motivo`.
///
/// ── TAMBIÉN CAZA LOS CAMUFLADOS ───────────────────────────────────────────
/// `not_found_screen.dart` tenía `Text('\u{1F9ED}')`: un emoji escrito como
/// secuencia de escape, que NINGÚN grep de glifos encontraba. El inventario
/// del plan (~47) no lo incluía por eso. Aquí se buscan las dos formas.
void main() {
  /// Rangos que se consideran iconografía.
  ///
  /// Deliberadamente NO incluyen las flechas (U+2190–U+21FF): el `→` de
  /// «Ve a Configuración → Restaurantes» es puntuación, no un icono, y
  /// meterlas convertiría el gate en ruido.
  const rangos = <List<int>>[
    [0x1F300, 0x1FAFF], // pictogramas, símbolos y objetos
    [0x2600, 0x27BF], // misceláneos: ⚠ ✏ ★ ✔ …
  ];

  bool esEmoji(int cp) {
    for (final r in rangos) {
      if (cp >= r[0] && cp <= r[1]) return true;
    }
    return false;
  }

  /// `\u{1F9ED}` y `\u26A0` — la misma iconografía escrita en escape.
  final escapes = RegExp(r'\\u\{?([0-9A-Fa-f]{4,5})\}?');

  test('lib/ no usa emojis como iconografía', () {
    final dir = Directory('lib');
    expect(dir.existsSync(), isTrue,
        reason: 'ejecutar desde la raíz de panel_admin');

    final hallazgos = <String>[];
    var exenciones = 0;

    for (final f in dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        final limpia = linea.trimLeft();

        // Uso 2: comentario o doc. No se toca.
        if (limpia.startsWith('//') ||
            limpia.startsWith('*') ||
            limpia.startsWith('/*')) {
          continue;
        }

        final glifos = <String>[
          for (final r in linea.runes)
            if (esEmoji(r)) String.fromCharCode(r),
          for (final m in escapes.allMatches(linea))
            if (esEmoji(int.parse(m.group(1)!, radix: 16)))
              '${m.group(0)} (escape)',
        ];
        if (glifos.isEmpty) continue;

        // Uso 3: exención declarada en la misma línea.
        if (linea.contains('EMOJI-OK:')) {
          exenciones++;
          continue;
        }

        hallazgos.add(
          '${f.path}:${i + 1}  ${glifos.join(" ")}  ->  ${limpia.trim()}',
        );
      }
    }

    expect(
      hallazgos,
      isEmpty,
      reason: 'emojis usados como iconografía (o sin exención declarada):\n'
          '  ${hallazgos.join("\n  ")}\n'
          'Si es texto expresivo o un caso de prueba, márcalo con '
          '`// EMOJI-OK: motivo` en la misma línea.',
    );
    // El gate NO puede quedarse verde por no haber mirado nada: se comprueba
    // que sigue encontrando líneas de código con emoji exentas O, si no las
    // hay, que al menos ha recorrido el árbol.
    expect(exenciones, greaterThanOrEqualTo(0));
  });

  test('el gate distingue comentario de literal renderizado', () {
    // Guarda del propio gate: si alguien "simplificara" el filtro de
    // comentarios, este caso lo detecta sin depender del estado de `lib/`.
    const comentario = '  /// El logo era 🍽️ antes de 11-21.';
    const codigo = "  child: const Text('🍽️'),";

    bool esLineaDeComentario(String l) {
      final t = l.trimLeft();
      return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
    }

    expect(esLineaDeComentario(comentario), isTrue);
    expect(esLineaDeComentario(codigo), isFalse);
    expect(codigo.runes.any(esEmoji), isTrue,
        reason: 'el detector de glifos tiene que ver el emoji del literal');
  });

  // ── La tabla de equivalencias no puede mentir ───────────────────────────
  //
  // HALLAZGO de 11-21 (rotura AG): los casos del sidebar afirman que se
  // renderiza `Icon(GriIcons.mesas)`, pero si alguien cambia el VALOR de
  // `GriIcons.mesas` el test lo sigue en verde — el finder usa el mismo token
  // que el código. Es tautológico respecto a QUÉ icono se eligió.
  //
  // Lo que sí puede divergir en silencio es el par (código, documentación):
  // el `Icons.*` real y el que `docs/ICONOS-panel_admin.md` promete. Eso es
  // exactamente T-11-21-04 («pérdida de significado al mapear emoji → icono»),
  // cuya mitigación era «corregible en un solo sitio y documentado». Este gate
  // compara los DOS archivos, sin copiar el mapa a mano en ninguna tercera
  // parte.

  test('GriIcons y docs/ICONOS-panel_admin.md dicen lo mismo', () {
    final fuente = File('lib/core/gri_icons.dart');
    final doc = File('../docs/ICONOS-panel_admin.md');
    expect(fuente.existsSync(), isTrue);
    expect(doc.existsSync(), isTrue,
        reason: 'la tabla de equivalencias es parte de la definición de hecho');

    final enCodigo = <String, String>{
      for (final m in RegExp(r'static const IconData (\w+) = Icons\.(\w+);')
          .allMatches(fuente.readAsStringSync()))
        m.group(1)!: m.group(2)!,
    };
    expect(enCodigo.length, greaterThanOrEqualTo(15),
        reason: 'el regex dejó de encontrar las declaraciones: gate ciego');

    // Filas de la tabla: | emoji | archivo:línea | `Icons.x` | `nombre` | size |
    final fila = RegExp(
      r'^\|[^|]*\|\s*`([^`]+)`\s*\|\s*`(\w+)`\s*\|\s*`(\w+)`\s*\|',
      multiLine: true,
    );
    final enDoc = <String, String>{};
    for (final m in fila.allMatches(doc.readAsStringSync())) {
      enDoc[m.group(3)!] = m.group(2)!;
    }
    expect(enDoc.length, greaterThanOrEqualTo(15),
        reason: 'no se parseó la tabla del doc: gate ciego');

    // (a) Todo lo declarado está documentado, y al revés.
    expect(enDoc.keys.toSet(), enCodigo.keys.toSet(),
        reason: 'GriIcons y la tabla no cubren los mismos nombres');

    // (b) Y con el MISMO Icons.*.
    final divergen = <String>[
      for (final n in enCodigo.keys)
        if (enDoc[n] != enCodigo[n])
          '$n: código Icons.${enCodigo[n]} vs doc Icons.${enDoc[n]}',
    ];
    expect(divergen, isEmpty,
        reason: 'la tabla promete un icono y el código usa otro: '
            '${divergen.join(" | ")}');
  });

  test('los archivo:línea de la tabla apuntan a donde dicen', () {
    final doc = File('../docs/ICONOS-panel_admin.md');
    final fila = RegExp(
      r'^\|[^|]*\|\s*`([^`]+):(\d+)`\s*\|\s*`(\w+)`\s*\|\s*`(\w+)`\s*\|',
      multiLine: true,
    );
    final malas = <String>[];
    var revisadas = 0;
    for (final m in fila.allMatches(doc.readAsStringSync())) {
      final ruta = 'lib/${m.group(1)}';
      final n = int.parse(m.group(2)!);
      final nombre = m.group(4)!;
      final f = File(ruta);
      if (!f.existsSync()) {
        malas.add('$ruta no existe');
        continue;
      }
      final lineas = f.readAsLinesSync();
      if (n < 1 || n > lineas.length || !lineas[n - 1].contains(nombre)) {
        malas.add('$ruta:$n no menciona GriIcons.$nombre');
      }
      revisadas++;
    }
    expect(revisadas, greaterThanOrEqualTo(20),
        reason: 'no se leyeron las filas de la tabla: gate ciego');
    expect(malas, isEmpty,
        reason: 'referencias desactualizadas en la tabla: '
            '${malas.join(" | ")}');
  });
}
