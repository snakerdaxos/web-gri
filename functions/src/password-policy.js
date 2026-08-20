// ============================================================================
// GRI — Politica de contrasenas del SERVIDOR (Fase 11, plan 11-22).
//
// Regla LOCKED por el usuario (11-CONTEXT.md, "Politica de contrasenas"):
// minimo 8 caracteres, al menos una MAYUSCULA, una MINUSCULA y un NUMERO.
// No se exige simbolo. No se prohiben espacios. No hay longitud maxima.
//
// ---------------------------------------------------------------------------
// POR QUE ESTO EXISTE HABIENDO YA UNA VALIDACION EN LOS FORMULARIOS
// ---------------------------------------------------------------------------
// Porque la validacion del formulario es UX, no seguridad (T-11-22-01). El
// payload de `crearUsuarioStaff` llega de un cliente que puede mentir: se puede
// invocar la callable directamente con `12345678` sin pasar por ninguna pantalla
// de Flutter. Si la politica solo viviera en el cliente, seria decorativa. Mismo
// criterio que `auth-matrix.js` con la autorizacion.
//
// ---------------------------------------------------------------------------
// UNA SOLA FUENTE DE VERDAD ENTRE TRES RUNTIMES
// ---------------------------------------------------------------------------
// Hay tres implementaciones —esta y las dos de Flutter, `password_policy.dart`,
// identicas entre si byte a byte— porque no hay forma de compartir codigo entre
// Node y Dart. Lo que SI es unico son los VECTORES: los tres tests leen
// `scripts/password_policy_vectors.json`. Quien cambie la regla edita ese
// archivo PRIMERO y despues arregla las tres implementaciones hasta que sus
// tests vuelvan a verde. Nunca al reves.
//
// ---------------------------------------------------------------------------
// EL DETALLE QUE HACE FALLAR A LA IMPLEMENTACION INGENUA
// ---------------------------------------------------------------------------
// `/[A-Z]/` NO reconoce la `Á` ni `/[a-z]/` la `ñ`: una contrasena legitima en
// espanol —"Ábcdefg1", "añoNuev0"— se rechazaria con un mensaje que ademas
// MIENTE. Se usan las categorias Unicode `\p{Lu}` y `\p{Ll}`, que EXIGEN la
// bandera `u`: sin ella, `/\p{Lu}/` es la cadena literal "p{Lu}" y el control
// deja de existir en silencio.
//
// "Numero" significa DIGITO ASCII: `/[0-9]/`, no `\p{Nd}`. Escrito asi a
// proposito y con un vector que lo fija (un digito arabigo-indico NO cuenta).
// ============================================================================

/**
 * Longitud minima del PRODUCTO. Firebase Auth exige 6; esta es mas estricta y
 * vive de nuestro lado.
 */
export const LONGITUD_MINIMA_PASSWORD = 8;

/**
 * Claves de incumplimiento, en el ORDEN fijo del contrato. De este orden depende
 * la redaccion del mensaje, asi que es parte del contrato y hay un test que lo
 * afirma.
 */
export const CLAVES_POLITICA_PASSWORD = [
  'longitud',
  'mayuscula',
  'minuscula',
  'numero',
];

const RE_MAYUSCULA = /\p{Lu}/u;
const RE_MINUSCULA = /\p{Ll}/u;
const RE_NUMERO = /[0-9]/;

/** Fragmento con el que se nombra cada carencia dentro del mensaje. */
const FRAGMENTO = {
  mayuscula: 'una mayúscula',
  minuscula: 'una minúscula',
  numero: 'un número',
};

/**
 * Lo que le falta a `password` para cumplir la politica, en el orden de
 * `CLAVES_POLITICA_PASSWORD`. Array vacio = cumple.
 *
 * Todo lo que no sea una cadena se trata como cadena vacia: el payload viene de
 * un cliente que puede mandar un numero, un objeto o nada, y esta funcion no
 * puede reventar antes de que la callable decida.
 */
export function faltantes(password) {
  const s = typeof password === 'string' ? password : '';
  const faltan = [];
  if (s.length < LONGITUD_MINIMA_PASSWORD) faltan.push('longitud');
  if (!RE_MAYUSCULA.test(s)) faltan.push('mayuscula');
  if (!RE_MINUSCULA.test(s)) faltan.push('minuscula');
  if (!RE_NUMERO.test(s)) faltan.push('numero');
  return faltan;
}

/** "a" · "a y b" · "a, b y c" — enumeracion en espanol, sin coma de Oxford. */
function enumerar(items) {
  if (items.length === 1) return items[0];
  return `${items.slice(0, -1).join(', ')} y ${items[items.length - 1]}`;
}

/**
 * `null` si `password` cumple la politica; si no, el mensaje CONCRETO en espanol
 * que nombra lo que falta.
 *
 * Este mensaje SI viaja al usuario (es el unico caso en el que el criterio de
 * 11-08 lo permite: describe la politica publica, que ademas aparece en el texto
 * de ayuda del formulario, y no revela nada del estado del sistema —
 * T-11-22-03). La redaccion es identica a la de las dos apps, palabra por
 * palabra, y hay un caso de test en los tres runtimes que lo fija: si divergiera,
 * el panel mostraria un texto distinto segun el error venga del formulario o del
 * servidor.
 */
export function validarPassword(password) {
  const faltan = faltantes(password);
  if (faltan.length === 0) return null;

  const partes = [];
  if (faltan.includes('longitud')) {
    partes.push(`debe tener al menos ${LONGITUD_MINIMA_PASSWORD} caracteres`);
  }
  const tipos = faltan.filter((f) => f !== 'longitud').map((f) => FRAGMENTO[f]);
  if (tipos.length > 0) {
    // Concordancia: una sola carencia va en singular.
    partes.push(`${tipos.length === 1 ? 'te falta' : 'te faltan'} ${enumerar(tipos)}`);
  }

  const frase = partes.join(' y ');
  return `${frase[0].toUpperCase()}${frase.slice(1)}.`;
}
