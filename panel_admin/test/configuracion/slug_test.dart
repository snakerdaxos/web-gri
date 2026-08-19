import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/features/configuracion/slug.dart';

/// Tests de `generarSlug` / `slugEsValido` (11-05, Tarea 1).
///
/// Por qué este archivo importa más de lo que parece: el doc ID del
/// restaurante es el `rid`, y el doc ID de cada mesa DERIVA de él
/// (`GRI-MESA-{rid}-{NNN}`, mesas_crud.dart:10). El escáner de la app
/// cliente valida `^GRI-MESA-[a-z0-9-]+-\d{3}$`
/// (app_cliente/lib/features/sesion_qr/scan_screen.dart:41). Un rid con
/// mayúsculas, tildes o espacios produce mesas cuyo QR NUNCA se puede
/// escanear — y el fallo aparece semanas después, con los QR impresos.
///
/// El grupo "puente con el escáner" es la aserción explícita de ese
/// contrato entre las dos apps.

/// La MISMA regexp que compila el escáner del cliente. Copiada a propósito
/// (el panel no depende del paquete de la app cliente): si alguien la
/// cambia allá, este test queda desalineado y hay que actualizarlo a mano.
final _regexpDelEscaner = RegExp(r'^GRI-MESA-[a-z0-9-]+-\d{3}$');

void main() {
  group('generarSlug', () {
    test('quita tildes y ñ (dominio español)', () {
      expect(generarSlug('Pizzería Doña Ana'), 'pizzeria-dona-ana');
    });

    test('colapsa espacios dobles, guiones repetidos y recorta bordes', () {
      expect(generarSlug('  El  Fogón--47  '), 'el-fogon-47');
    });

    test('acentos varios', () {
      expect(generarSlug('Café Olé'), 'cafe-ole');
    });

    test('solo símbolos → cadena vacía (el formulario debe pedir uno manual)',
        () {
      expect(generarSlug('★★★'), '');
    });

    test('pasa a minúsculas', () {
      expect(generarSlug('DEMO'), 'demo');
    });

    test('cadena vacía → cadena vacía', () {
      expect(generarSlug(''), '');
      expect(generarSlug('   '), '');
    });
  });

  group('slugEsValido', () {
    test('acepta un slug simple', () {
      expect(slugEsValido('demo'), isTrue);
    });

    test('acepta segmentos separados por un guion', () {
      expect(slugEsValido('pizzeria-dona-ana'), isTrue);
      expect(slugEsValido('el-fogon-47'), isTrue);
    });

    test('rechaza la cadena vacía', () {
      expect(slugEsValido(''), isFalse);
    });

    test('rechaza mayúsculas', () {
      expect(slugEsValido('Demo'), isFalse);
    });

    test('rechaza guion al final', () {
      expect(slugEsValido('demo-'), isFalse);
    });

    test('rechaza guion al inicio', () {
      expect(slugEsValido('-demo'), isFalse);
    });

    test('rechaza guiones dobles', () {
      expect(slugEsValido('de--mo'), isFalse);
    });

    test('rechaza tildes y ñ', () {
      expect(slugEsValido('pizzería'), isFalse);
      expect(slugEsValido('doña'), isFalse);
    });

    test('rechaza espacios', () {
      expect(slugEsValido('el fogon'), isFalse);
    });

    test('rechaza 41 caracteres (máximo 40)', () {
      expect(slugEsValido('a' * 41), isFalse);
    });

    // Borde PERMITIDO (lección 11-04): sin este caso, un `<= 40` convertido
    // en `< 40` no rompería ninguna aserción.
    test('acepta exactamente 40 caracteres', () {
      expect(slugEsValido('a' * 40), isTrue);
    });
  });

  group('puente con el escáner del cliente', () {
    // Nombres realistas de restaurante colombiano: tildes, ñ, signos,
    // números, dobles espacios y mayúsculas.
    const nombres = <String>[
      'Pizzería Doña Ana',
      'El Fogón Paisa',
      'Café Olé',
      'Asadero El Buen Sabor',
      'La Cocina de la Abuela Ñoña',
      'Sushi & Rolls 24/7',
      'Restaurante  Demo  GRI',
      'Andrés Carne de Res',
      'Empanadas "La Esquina"',
      'Crepes y Waffles — Centro',
      'Bar 47',
      'Ajiacos del Chicó',
      'MONDONGO\'S',
      'Panadería San José #2',
      'Tostao Café & Pan',
    ];

    test('todo slug generado desde un nombre real es válido', () {
      for (final nombre in nombres) {
        final slug = generarSlug(nombre);
        expect(slug, isNotEmpty, reason: 'nombre: $nombre');
        expect(slugEsValido(slug), isTrue,
            reason: 'nombre: $nombre → slug: $slug');
      }
    });

    test(
        'GRI-MESA-{slug}-001 lo acepta la regexp REAL del escáner del cliente',
        () {
      for (final nombre in nombres) {
        final slug = generarSlug(nombre);
        expect(_regexpDelEscaner.hasMatch('GRI-MESA-$slug-001'), isTrue,
            reason: 'nombre: $nombre → GRI-MESA-$slug-001');
      }
    });

    // Control negativo: sin esto, la aserción de arriba podría estar verde
    // por construcción. Los nombres CRUDOS (sin slugificar) deben ser
    // RECHAZADOS por la misma regexp — eso demuestra que la regexp discrimina
    // y que es generarSlug quien hace el trabajo.
    test('control negativo: el nombre CRUDO no pasa la regexp del escáner',
        () {
      const crudos = <String>[
        'Pizzería Doña Ana',
        'El Fogón Paisa',
        'DEMO',
        'Café Olé',
      ];
      for (final crudo in crudos) {
        expect(_regexpDelEscaner.hasMatch('GRI-MESA-$crudo-001'), isFalse,
            reason: 'el crudo "$crudo" NO debería ser escaneable');
      }
    });

    test('un slug de 3 dígitos no rompe el sufijo de número de mesa', () {
      // 'Bar 47' → 'bar-47'; un nombre puramente numérico da un slug de
      // dígitos, que la regexp sigue aceptando sin ambigüedad de sufijo.
      expect(generarSlug('123'), '123');
      expect(_regexpDelEscaner.hasMatch('GRI-MESA-123-001'), isTrue);
    });
  });
}
