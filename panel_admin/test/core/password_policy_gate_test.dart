// ============================================================================
// GRI — Gate: NINGUNA pantalla vuelve a escribir la regla de contrasena
// (Fase 11, plan 11-22).
//
// ---------------------------------------------------------------------------
// POR QUE ESTE GATE NO ES EL QUE PEDIA EL PLAN
// ---------------------------------------------------------------------------
// El plan proponia, como <verify> de la Tarea 2:
//     test $(grep -rn "length >= 8\|length < 8\|_minPassword" lib/features | wc -l) -eq 0
// Ese gate NO SE PUEDE SATISFACER, y no por pereza: `lib/features` tiene NUEVE
// coincidencias y solo seis son puntos donde se FIJA una contrasena. Las otras
// tres estan en el camino de INICIAR SESION (`login_screen.dart` x2 y
// `LoginController.submit`), donde la politica NO debe aplicarse: una cuenta
// creada antes de esta politica tiene que poder seguir entrando. Aplicarla alli
// seria exactamente la denegacion de servicio que el propio plan declara fuera
// de alcance en T-11-22-04. Cumplir el grep al pie de la letra habria dejado sin
// acceso a los usuarios existentes.
//
// Asi que el gate se reescribe con la distincion que importa —FIJAR frente a
// INICIAR SESION— y las excepciones se DECLARAN en el codigo con el marcador
// `POLICY-LOGIN-OK`, mismo patron que `// AUDIT-STAFF` (11-03) y
// `// TOKEN-IGNORE` (11-19). Una exencion silenciosa cuenta como fallo.
//
// Y como DIEZ gates de grep de esta fase resultaron defectuosos, aqui el
// DETECTOR se prueba a si mismo con las lineas REALES que existian antes del
// plan. Un gate que no puede ponerse rojo cuando el control falta es decoracion.
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Unico archivo donde la regla PUEDE estar escrita: la implementacion.
const _implementacion = 'lib/core/password_policy.dart';

/// Marcador obligatorio para declarar una comprobacion de longitud que NO es
/// la politica (el camino de inicio de sesion).
const _marcador = 'POLICY-LOGIN-OK';

/// Puntos de esta app donde se FIJA una contrasena y que, por tanto, tienen que
/// delegar en la politica. Escrito a mano: si alguien anade un punto nuevo,
/// esta lista no lo sabra — pero el gate de abajo si vera la regla suelta que
/// escriba.
const _puntosQueFijan = <String>[
  'lib/features/equipo/staff_form_dialog.dart',
  'lib/features/bootstrap/bootstrap_screen.dart',
];

// El operando de la derecha puede ser un NUMERO o un IDENTIFICADOR: la
// constante `_minPassword` del panel es tan regla escrita a mano como un 8
// literal, y con `[0-9]` a secas el detector no la veia (medido).
final _reLongitud = RegExp(r'\.length\s*(<=|>=|<|>|==|!=)\s*[0-9A-Za-z_]');
final _rePassword = RegExp('password|pass|contrase|clave', caseSensitive: false);
final _reMinimoLiteral = RegExp(r'M[ií]nimo\s+[0-9]+\s+caracteres');

/// Cuantas lineas ANTERIORES cuentan como contexto de una comparacion de
/// longitud. Hacen falta: `perfil_controller.dart` comparaba `nueva.length < 8`
/// dentro de `cambiarPassword(String actual, String nueva)`. Mirando SOLO la
/// linea, el identificador no dice en ningun sitio que sea una contrasena y el
/// detector se quedaba CIEGO justo en el punto mas debil de los cuatro
/// (medido: la primera version de este gate no lo veia).
const _lineasDeContexto = 5;

/// `true` si [linea] escribe a mano una regla de contrasena. [contexto] son esa
/// linea y las anteriores: es lo que permite reconocerla cuando el identificador
/// se llama `nueva` y quien dice "contrasena" es la firma de la funcion.
bool esReglaDeContrasena(String linea, String contexto) {
  if (_reMinimoLiteral.hasMatch(linea)) return true;
  return _reLongitud.hasMatch(linea) && _rePassword.hasMatch(contexto);
}

List<File> _fuentesDeLib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _normalizar(String p) => p.replaceAll(r'\', '/');

/// Juzga la ULTIMA linea de [fragmento] usando el resto como contexto.
bool _juzgar(String fragmento) {
  final lineas = fragmento.split('\n');
  return esReglaDeContrasena(lineas.last, fragmento);
}

void main() {
  test('el DETECTOR reconoce las reglas REALES que habia antes del plan', () {
    // Fragmentos del arbol tal y como estaba en el commit anterior a 11-22. La
    // ULTIMA linea de cada uno es la que se juzga; las de arriba son contexto.
    final reales = <String>[
      'bool get _canSubmit {\n'
          '  return !submitting &&\n'
          '      _passCtrl.text.length >= 8 &&',
      'PasswordField(\n'
          "  labelText: 'Contraseña',\n"
          "  validator: (v) => (v ?? '').length >= 8 ? null : 'Mínimo 8 caracteres',",
      'Future<bool> submit(String nombre, String email, String password) async {\n'
          '  if (password.length < 8) {',
      // EL CASO QUE DEJABA CIEGO AL DETECTOR SIMPLE: el identificador no dice
      // "contrasena" por ningun lado; lo dice la firma, una linea mas arriba.
      'Future<bool> cambiarPassword(String actual, String nueva) async {\n'
          '  if (nueva.length < 8) {',
      'String? _validarPassword(String? v) {\n'
          '    if (s.length < _minPassword) {',
    ];
    for (final fragmento in reales) {
      expect(
        _juzgar(fragmento),
        isTrue,
        reason: 'el detector NO ve «${fragmento.split('\n').last.trim()}»: '
            'el gate seria decorativo',
      );
    }

    // Y no marca lo que no es una regla de contrasena.
    final inocentes = <String>[
      'void _guardar(String nombre) {\n  if (nombre.length < 3) {',
      'final lista = await pedidos();\n'
          '  final recientes = lista.length > 8 ? lista.sublist(0, 8) : lista;',
      '// La politica vive en password_policy.dart',
    ];
    for (final fragmento in inocentes) {
      expect(
        _juzgar(fragmento),
        isFalse,
        reason: 'falso positivo con «${fragmento.split('\n').last.trim()}»',
      );
    }
  });

  test('ninguna regla de contrasena suelta en lib/, salvo las DECLARADAS', () {
    final sinDeclarar = <String>[];
    final declaradas = <String>[];

    for (final f in _fuentesDeLib()) {
      final ruta = _normalizar(f.path);
      if (ruta.endsWith(_implementacion)) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final desde = i - _lineasDeContexto < 0 ? 0 : i - _lineasDeContexto;
        final ventana = lineas.sublist(desde, i + 1).join('\n');
        if (!esReglaDeContrasena(lineas[i], ventana)) continue;
        final entrada = '$ruta:${i + 1}: ${lineas[i].trim()}';
        // La exencion se declara en la propia linea o en el bloque de
        // comentario inmediatamente anterior. La ventana es la MISMA que la
        // de contexto: una exencion que hay que justificar no cabe en dos
        // lineas (medido: con una ventana de 2 el gate rechazaba las dos
        // exenciones legitimas del camino de login).
        final declaracion = ventana;
        if (declaracion.contains(_marcador)) {
          declaradas.add(entrada);
        } else {
          sinDeclarar.add(entrada);
        }
      }
    }

    expect(
      sinDeclarar,
      isEmpty,
      reason:
          'estas lineas escriben la regla de contrasena a mano. O delegan en '
          '`validarPassword` de $_implementacion, o —si son del camino de '
          'INICIAR SESION, donde la politica NO se aplica— declaran la '
          'excepcion con un comentario $_marcador que diga por que.',
    );

    // Las exenciones existen y son POCAS. Si desaparecieran, seria senal de que
    // a alguien le aplicaron la politica al login; si crecieran, de que el
    // marcador se esta usando para silenciar el gate en vez de para declarar.
    expect(
      declaradas,
      isNotEmpty,
      reason: 'el camino de login conserva su comprobacion de longitud',
    );
    expect(declaradas.length, lessThanOrEqualTo(4));
    for (final d in declaradas) {
      expect(
        d.toLowerCase(),
        anyOf(contains('login'), contains('auth_controller')),
        reason: 'una exencion fuera del camino de inicio de sesion: $d',
      );
    }
  });

  test('los puntos que FIJAN contrasena delegan en la politica', () {
    for (final ruta in _puntosQueFijan) {
      final fuente = File(ruta).readAsStringSync();
      expect(
        fuente,
        contains('password_policy.dart'),
        reason: '$ruta no importa la politica',
      );
      expect(
        fuente,
        contains('validarPassword'),
        reason: '$ruta no llama a validarPassword',
      );
    }
  });
}
