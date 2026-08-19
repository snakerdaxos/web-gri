@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ningún test del panel puede SUPRIMIR un desborde de RenderFlex (11-21).
///
/// ── POR QUÉ NO BASTA UN `grep` ────────────────────────────────────────────
/// El plan proponía este gate:
///
///     test $(grep -rn "RenderFlex overflowed" test | wc -l) -eq 0
///
/// y es DEFECTUOSO: no distingue un filtro que se traga el desborde para
/// quedarse verde de un detector que lo recoge para AFIRMAR que no hay
/// ninguno. Los dos contienen la misma cadena. Con ese gate, la única forma
/// de pasarlo sería quedarse sin detectores — justo lo contrario de lo que la
/// fase quiere.
///
/// La regla real es: si un archivo de test menciona el desborde, tiene que
/// (a) declararse detector con `// OVERFLOW-DETECTOR: <motivo>` y
/// (b) contener una aserción de vacío (`isEmpty`) sobre lo recogido.
/// Un filtro de los que había antes de 11-21 no cumple ninguna de las dos.
///
/// Filtros retirados en 11-21 y vigilados por este caso:
///   · `test/bootstrap/bootstrap_router_test.dart` (11-07)
///   · `test/router_404_test.dart`                 (11-09)
///   · `test/equipo/equipo_gating_test.dart`       (11-10)
void main() {
  const aguja = 'A RenderFlex overflowed';
  const marcador = 'OVERFLOW-DETECTOR:';

  test('ningún test del panel filtra desbordes de RenderFlex', () {
    final raiz = Directory('test');
    expect(raiz.existsSync(), isTrue,
        reason: 'el test debe ejecutarse desde la raíz de panel_admin');

    final sospechosos = <String>[];
    var detectores = 0;

    for (final f in raiz
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Este mismo archivo menciona la aguja y el marcador por definición:
        // contarlo como detector inflaría la cuenta de abajo.
        .where((f) => !f.path.endsWith('sin_filtros_overflow_test.dart'))) {
      final lineas = f.readAsLinesSync();
      final hits = <int>[
        for (var i = 0; i < lineas.length; i++)
          if (lineas[i].contains(aguja)) i + 1,
      ];
      if (hits.isEmpty) continue;

      final texto = lineas.join('\n');
      final esDetector = texto.contains(marcador);
      final afirmaVacio = texto.contains('isEmpty');

      if (esDetector && afirmaVacio) {
        detectores++;
        continue;
      }
      sospechosos.add(
        '${f.path} (líneas ${hits.join(", ")}) — '
        'declara $marcador: $esDetector · afirma isEmpty: $afirmaVacio',
      );
    }

    expect(
      sospechosos,
      isEmpty,
      reason: 'estos archivos mencionan "$aguja" sin ser detectores '
          'declarados:\n  ${sospechosos.join("\n  ")}',
    );
    // Y que HAYA detectores: si alguien borrase los que vigilan la geometría,
    // este archivo se quedaría verde por vacuidad.
    expect(detectores, greaterThanOrEqualTo(2),
        reason: 'debe haber al menos 2 detectores declarados (shell + '
            'dashboard); encontrados: $detectores');
  });
}
