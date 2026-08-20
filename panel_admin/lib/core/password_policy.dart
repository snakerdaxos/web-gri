// ============================================================================
// GRI — Politica de contrasenas (Fase 11, plan 11-22).
//
// Regla LOCKED por el usuario (11-CONTEXT.md, "Politica de contrasenas"):
// minimo 8 caracteres, al menos una MAYUSCULA, una MINUSCULA y un NUMERO.
// No se exige simbolo. No se prohiben espacios. No hay longitud maxima.
//
// ---------------------------------------------------------------------------
// ESTE ARCHIVO ESTA DUPLICADO A PROPOSITO — Y LA COPIA SE COMPRUEBA
// ---------------------------------------------------------------------------
// Existe identico en `app_cliente/lib/core/password_policy.dart` y en
// `panel_admin/lib/core/password_policy.dart`. Son dos proyectos Flutter
// independientes (pubspec propio, paleta propia), igual que `password_field.dart`
// y `design_tokens.dart`. La diferencia con aquellos es que aqui la sincronia no
// se pide en un comentario: hay un test que compara los dos archivos BYTE A BYTE
// (`test/core/password_policy_test.dart` en las dos apps).
//
// Si hay que cambiar la regla: se edita PRIMERO
// `scripts/password_policy_vectors.json` —la fuente canonica que leen los tests
// de los TRES runtimes, incluida la Cloud Function `functions/src/password-policy.js`—
// y despues se arreglan las implementaciones hasta que vuelvan a verde. Nunca al
// reves. Y este archivo se COPIA sobre el de la otra app, no se reescribe.
//
// ---------------------------------------------------------------------------
// EL DETALLE QUE HACE FALLAR A LA IMPLEMENTACION INGENUA
// ---------------------------------------------------------------------------
// `RegExp(r'[A-Z]')` NO reconoce la `Á` ni `RegExp(r'[a-z]')` la `ñ`, asi que una
// contrasena perfectamente legitima en espanol —"Ábcdefg1", "añoNuev0"— se
// rechazaria con un mensaje que ademas MIENTE ("te falta una mayuscula" cuando
// hay una). Se usan las categorias Unicode `\p{Lu}` y `\p{Ll}` con `unicode: true`.
// Hay vectores con acento y con enye justamente para poner eso en rojo.
//
// "Numero" significa DIGITO ASCII: `[0-9]`, no `\p{Nd}`. Escrito asi a proposito
// y con un vector que lo fija (un digito arabigo-indico NO cuenta), para que las
// tres implementaciones no se separen en silencio por el default de su runtime.
//
// ---------------------------------------------------------------------------
// DONDE APLICA Y DONDE NO
// ---------------------------------------------------------------------------
// Aplica al FIJAR una contrasena: registro del cliente, cambio desde el perfil,
// alta de staff desde el panel y bootstrap del primer super_admin. NO aplica al
// INICIAR SESION: una cuenta creada antes de esta politica tiene que poder
// entrar (T-11-22-04). Meter esta funcion en el formulario de login seria una
// denegacion de servicio contra los usuarios existentes.
//
// Y esto es UX + defensa en profundidad, no la frontera de seguridad: la misma
// politica la aplica el servidor en `functions/src/crear-usuario-staff.js`,
// porque si solo viviera aqui bastaria con invocar la callable directamente.
// ============================================================================

/// Longitud minima del PRODUCTO (8). Firebase Auth exige 6; esta es mas
/// estricta y vive de nuestro lado.
const int longitudMinimaPassword = 8;

/// Claves de incumplimiento, en el ORDEN fijo del contrato. De este orden
/// depende la redaccion del mensaje, asi que es parte del contrato y hay un
/// test que lo afirma.
const List<String> clavesPoliticaPassword = <String>[
  'longitud',
  'mayuscula',
  'minuscula',
  'numero',
];

final RegExp _mayuscula = RegExp(r'\p{Lu}', unicode: true);
final RegExp _minuscula = RegExp(r'\p{Ll}', unicode: true);
final RegExp _numero = RegExp(r'[0-9]');

/// Fragmento con el que se nombra cada carencia dentro del mensaje.
const Map<String, String> _fragmento = <String, String>{
  'mayuscula': 'una mayúscula',
  'minuscula': 'una minúscula',
  'numero': 'un número',
};

/// Lo que le falta a [password] para cumplir la politica, en el orden de
/// [clavesPoliticaPassword]. Lista vacia = cumple.
List<String> faltantes(String password) {
  final faltan = <String>[];
  if (password.length < longitudMinimaPassword) faltan.add('longitud');
  if (!_mayuscula.hasMatch(password)) faltan.add('mayuscula');
  if (!_minuscula.hasMatch(password)) faltan.add('minuscula');
  if (!_numero.hasMatch(password)) faltan.add('numero');
  return faltan;
}

/// `null` si [password] cumple la politica; si no, el mensaje CONCRETO en
/// espanol que nombra lo que falta.
///
/// El usuario lo pidio explicitamente: nada de "Contrasena invalida", que
/// obliga a adivinar. La composicion vive aqui —no en las pantallas— para que
/// los cuatro formularios digan exactamente lo mismo.
String? validarPassword(String password) {
  final faltan = faltantes(password);
  if (faltan.isEmpty) return null;

  final partes = <String>[];
  if (faltan.contains('longitud')) {
    partes.add('debe tener al menos $longitudMinimaPassword caracteres');
  }
  final tipos =
      faltan.where((f) => f != 'longitud').map((f) => _fragmento[f]!).toList();
  if (tipos.isNotEmpty) {
    // Concordancia: una sola carencia va en singular.
    partes.add('${tipos.length == 1 ? 'te falta' : 'te faltan'} '
        '${_enumerar(tipos)}');
  }

  final frase = partes.join(' y ');
  return '${frase[0].toUpperCase()}${frase.substring(1)}.';
}

/// "a" · "a y b" · "a, b y c" — enumeracion en espanol, sin coma de Oxford.
String _enumerar(List<String> items) {
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
}

/// Texto de ayuda que describe la politica ANTES de que el usuario falle.
/// Los cuatro formularios lo usan tal cual: si la regla cambia, el copy cambia
/// con ella en los cuatro sitios a la vez.
const String ayudaPolitica =
    'Mínimo $longitudMinimaPassword caracteres, con una mayúscula, una '
    'minúscula y un número';
