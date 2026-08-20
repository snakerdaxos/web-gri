// ============================================================================
// GRI — La politica de contrasenas de ESTA app frente a los vectores CANONICOS
// (Fase 11, plan 11-22).
//
// QUE PRUEBA ESTE ARCHIVO Y POR QUE ESTA ESCRITO ASI
// ---------------------------------------------------------------------------
// La regla la fijo el usuario (11-CONTEXT.md, "Politica de contrasenas", LOCKED)
// y hay TRES runtimes que tienen que aplicarla igual: las dos apps Flutter y la
// Cloud Function. Tres implementaciones son tres oportunidades de divergir en
// silencio, asi que ninguna de ellas trae sus casos escritos a mano: las tres
// leen el MISMO archivo, `scripts/password_policy_vectors.json`. Anadir un
// vector alli pone a trabajar a los tres sin tocar ningun test; si una
// implementacion se desvia, su test se pone rojo el mismo dia.
//
// El segundo gate es la comparacion BYTE A BYTE de los dos archivos Dart. La
// duplicacion entre apps es deliberada (mismo motivo que `password_field.dart` y
// `design_tokens.dart`: son dos proyectos Flutter independientes), pero aqui no
// se confia en un comentario que pida sincronizar: se comprueba.
//
// OJO CON LA RUTA: `flutter test` corre con el directorio de trabajo en la RAIZ
// DEL PAQUETE (no en el del archivo de test), asi que el JSON esta en
// `../scripts/…` y el archivo de la otra app en `../<otra_app>/lib/core/…`.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/password_policy.dart';

/// Ruta del JSON canonico, relativa a la raiz del paquete.
const _rutaVectores = '../scripts/password_policy_vectors.json';

/// Los dos archivos que tienen que ser identicos byte a byte.
const _rutaEsta = 'lib/core/password_policy.dart';
const _rutaOtra = '../app_cliente/lib/core/password_policy.dart';

/// Trozo de mensaje que DEBE aparecer cuando falta cada cosa, y que NO debe
/// aparecer cuando no falta. Escrito a mano: comparar contra la propia
/// implementacion dejaria el caso verde justo cuando la implementacion cambia.
const _huella = <String, String>{
  'longitud': '8 caracteres',
  'mayuscula': 'mayúscula',
  'minuscula': 'minúscula',
  'numero': 'número',
};

List<Map<String, dynamic>> _cargarVectores() {
  final f = File(_rutaVectores);
  expect(
    f.existsSync(),
    isTrue,
    reason: 'no encuentro $_rutaVectores desde ${Directory.current.path}. '
        'Los tres runtimes leen ESE archivo; si se movio, hay que actualizar '
        'las tres rutas a la vez.',
  );
  final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return (doc['vectores'] as List).cast<Map<String, dynamic>>();
}

/// Etiqueta legible para el nombre del test (la cadena vacia y la muy larga no
/// se pueden imprimir tal cual).
String _etiqueta(String p) {
  if (p.isEmpty) return '(vacía)';
  if (p.length > 20) return '${p.substring(0, 12)}…(${p.length} car.)';
  return p;
}

void main() {
  final vectores = _cargarVectores();

  test('los vectores canonicos se cargan y traen los bordes obligatorios', () {
    expect(vectores.length, greaterThanOrEqualTo(12));
    final passwords = vectores.map((v) => v['password'] as String).toSet();
    // Bordes que el usuario pidio explicitamente. Si alguien los borra del
    // JSON, este caso lo dice en vez de dejar de probarlos en silencio.
    for (final obligatorio in <String>[
      'Abcdefg1', // exactamente 8, valida
      'Abcdef1', // 7, valida por composicion pero corta
      'abcdefg1', // sin mayuscula
      'ABCDEFG1', // sin minuscula
      'Abcdefgh', // sin numero
      'ABCDEFGH', // solo mayusculas
      '12345678', // solo digitos: el caso que hoy pasa
      '', // vacia
      'Abc def1', // con espacios
      'Ábcdefg1', // acento
      'añoNuev0', // enye
    ]) {
      expect(
        passwords,
        contains(obligatorio),
        reason: 'falta un borde obligatorio en $_rutaVectores',
      );
    }
    expect(
      passwords.any((p) => p.length >= 100),
      isTrue,
      reason: 'falta el vector "muy larga" (no hay longitud maxima)',
    );
  });

  group('faltantes() coincide con los vectores canonicos', () {
    for (final v in vectores) {
      final password = v['password'] as String;
      final esperadas = (v['faltan'] as List).cast<String>();
      final nota = v['nota'] as String? ?? '';
      test('«${_etiqueta(password)}» → [${esperadas.join(', ')}]  ($nota)', () {
        expect(faltantes(password), esperadas);
      });
    }
  });

  group('validarPassword() coincide con los vectores canonicos', () {
    for (final v in vectores) {
      final password = v['password'] as String;
      final valida = v['valida'] as bool;
      final esperadas = (v['faltan'] as List).cast<String>();
      test('«${_etiqueta(password)}» → ${valida ? 'valida' : 'invalida'}', () {
        final msg = validarPassword(password);
        expect(
          msg == null,
          valida,
          reason: msg == null
              ? 'se acepto una contrasena que el JSON marca invalida'
              : 'se rechazo con «$msg» una que el JSON marca valida',
        );
        if (valida) return;

        // El mensaje NOMBRA lo que falta y NO nombra lo que no falta. Es la
        // diferencia entre "te falta una mayuscula" y "contrasena invalida".
        for (final entrada in _huella.entries) {
          final debeAparecer = esperadas.contains(entrada.key);
          expect(
            msg!.contains(entrada.value),
            debeAparecer,
            reason: debeAparecer
                ? 'el mensaje «$msg» no nombra lo que falta (${entrada.key})'
                : 'el mensaje «$msg» nombra ${entrada.key}, que NO falta',
          );
        }
      });
    }
  });

  test('el orden de faltantes() es SIEMPRE longitud, mayuscula, minuscula, '
      'numero', () {
    const orden = ['longitud', 'mayuscula', 'minuscula', 'numero'];
    for (final v in vectores) {
      final lista = faltantes(v['password'] as String);
      final indices = lista.map(orden.indexOf).toList();
      expect(
        indices,
        everyElement(greaterThanOrEqualTo(0)),
        reason: 'clave desconocida en $lista',
      );
      final ordenados = [...indices]..sort();
      expect(
        indices,
        ordenados,
        reason: 'orden roto para «${_etiqueta(v['password'] as String)}»',
      );
    }
  });

  group('redaccion concreta del mensaje (concordancia singular/plural)', () {
    const esperados = <String, String?>{
      'Abcdefg1': null,
      'abcdefg1': 'Te falta una mayúscula.',
      'ABCDEFG1': 'Te falta una minúscula.',
      'Abcdefgh': 'Te falta un número.',
      'ABCDEFGH': 'Te faltan una minúscula y un número.',
      '12345678': 'Te faltan una mayúscula y una minúscula.',
      'Abcdef1': 'Debe tener al menos 8 caracteres.',
      'Abcdefg': 'Debe tener al menos 8 caracteres y te falta un número.',
      '': 'Debe tener al menos 8 caracteres y te faltan una mayúscula, '
          'una minúscula y un número.',
    };
    esperados.forEach((password, esperado) {
      test('«${_etiqueta(password)}»', () {
        expect(validarPassword(password), esperado);
      });
    });
  });

  test('ningun mensaje es el generico que el usuario prohibio', () {
    for (final v in vectores) {
      final msg = validarPassword(v['password'] as String);
      if (msg == null) continue;
      expect(msg.toLowerCase(), isNot(contains('inválida')));
      // Un mensaje util nombra algo concreto: al menos una de las huellas.
      expect(
        _huella.values.any(msg.contains),
        isTrue,
        reason: 'el mensaje «$msg» no dice QUE falta',
      );
    }
  });

  test('los dos archivos password_policy.dart son identicos BYTE A BYTE', () {
    final esta = File(_rutaEsta);
    final otra = File(_rutaOtra);
    expect(esta.existsSync(), isTrue, reason: 'no encuentro $_rutaEsta');
    expect(
      otra.existsSync(),
      isTrue,
      reason: 'no encuentro $_rutaOtra desde ${Directory.current.path}',
    );
    expect(
      otra.readAsBytesSync(),
      esta.readAsBytesSync(),
      reason: 'los dos archivos han divergido. NO los reescribas a mano: COPIA '
          'uno sobre el otro y deja que los vectores canonicos digan si la '
          'regla nueva es correcta.',
    );
  });
}
