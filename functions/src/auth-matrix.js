// ============================================================================
// GRI — Matriz de autorización del alta de staff (Fase 11, plan 08)
//
// QUÉ ES: la decisión de "¿puede este llamador crear ESTE rol en ESTE
// restaurante?", aislada como función PURA.
//
// ---------------------------------------------------------------------------
// REQUISITO DURO: CERO IMPORTS DE FIREBASE
// ---------------------------------------------------------------------------
// Ni `firebase-admin` ni `firebase-functions`. No es estética: es lo que
// permite ejecutar la combinatoria COMPLETA de escaladas de privilegios en
// milisegundos, sin emuladores, en `functions/test/auth-matrix.test.js`. La
// seguridad de la matriz vive en esa combinatoria; si este módulo arrastrara
// el Admin SDK, probarla exigiría tres emuladores y en la práctica se probarían
// cuatro casos en vez de todos. Hay un test que verifica esta ausencia.
//
// ---------------------------------------------------------------------------
// LA MATRIZ · decisión BLOQUEADA del usuario (11-CONTEXT.md, 2026-08-19)
// ---------------------------------------------------------------------------
//   | Llamador            | Puede crear usuarios de | Roles que puede asignar |
//   | super_admin         | cualquier restaurante   | admin_restaurante, mesero, cocina |
//   | admin_restaurante   | SOLO su propio rid      | admin_restaurante, mesero, cocina |
//
// Un `admin_restaurante` SÍ puede crear otro `admin_restaurante` acotado a su
// propio rid: permite dos socios o gerentes y evita que el restaurante quede
// bloqueado si esa única persona pierde el acceso. No re-abrir, no "simplificar".
//
// DOS PROHIBICIONES ABSOLUTAS, cada una con test dedicado + test de propiedad:
//   (1) NADIE puede asignar `super_admin` por esta vía. El único super_admin
//       nace de `bootstrapPlataforma` (11-07), una sola vez en la vida del
//       proyecto. Que ni el propio super pueda crear otro es deliberado: cierra
//       la vía de escalada vertical entera en vez de dejarla condicionada.
//   (2) Un `admin_restaurante` NUNCA toca un rid distinto al suyo. No basta
//       con rechazar un rid ajeno: el rid efectivo se DERIVA del claim del
//       llamador, no del payload. El cliente no puede elegirlo aunque miente.
//
// ---------------------------------------------------------------------------
// POR QUÉ UNA SOLA CALLABLE Y NO DOS
// ---------------------------------------------------------------------------
// Los dos llamadores asignan el MISMO conjunto de roles y solo difieren en cómo
// se resuelve el rid efectivo. Toda la diferencia cabe en el valor devuelto
// `rid`, así que dos funciones serían el mismo código duplicado con dos
// superficies de ataque que mantener sincronizadas.
//
// ---------------------------------------------------------------------------
// REGLA DE CÓDIGOS DE ERROR (no mezclarlos nunca)
// ---------------------------------------------------------------------------
//   permission-denied  → "sé quién eres y no puedes". Fallo de AUTORIZACIÓN.
//   invalid-argument   → "lo que me mandaste no tiene sentido". Fallo de FORMA.
//   failed-precondition→ el llamador está mal aprovisionado (sin rid). No es
//                        culpa de su payload, así que no es invalid-argument.
// Ningún mensaje revela estado interno del sistema ni de otros tenants.
// ============================================================================

/**
 * Roles que esta callable puede ASIGNAR. Allow-list, no deny-list: añadir un
 * rol nuevo al producto no lo hace asignable por accidente.
 * `super_admin` NO está aquí y no debe estarlo nunca (prohibición 1).
 */
export const ROLES_ASIGNABLES = ['admin_restaurante', 'mesero', 'cocina'];

/** Roles que pueden LLAMAR a la callable. También allow-list. */
export const ROLES_LLAMADORES = ['super_admin', 'admin_restaurante'];

/**
 * Slug canónico del doc ID de restaurante. Copia deliberada de la validación de
 * 11-05: de este rid derivan los doc ID de mesa (`GRI-MESA-{rid}-{NNN}`) y por
 * tanto los QR IMPRESOS, y el escáner del cliente exige
 * `^GRI-MESA-[a-z0-9-]+-\d{3}$` (`app_cliente/.../scan_screen.dart`). Un rid con
 * mayúsculas o acentos deja las mesas inescaneables.
 */
export const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

/**
 * Decide si un alta de staff está autorizada y con qué restaurante efectivo.
 *
 * ORDEN DE LAS COMPROBACIONES (no es arbitrario):
 *   1. ¿quién llama?  → si no es llamador válido no se le dice nada más.
 *   2. ¿qué rol pide? → la prohibición vertical se aplica ANTES de mirar rids,
 *      así que `super_admin@cualquier-cosa` muere siempre igual.
 *   3. ¿qué rid?      → aquí se bifurca por tipo de llamador.
 *
 * @param {object} args
 * @param {string|undefined} args.callerRole claim `role` del llamador. Un
 *   cliente auto-registrado NO tiene este claim (hallazgo de 11-04): llega
 *   `undefined` y se deniega, que es lo correcto.
 * @param {string|null|undefined} args.callerRid claim `rid` del llamador. El
 *   super_admin lo tiene en `null` a propósito (elige restaurante en el panel).
 * @param {string|undefined} args.rolPedido rol solicitado en el payload.
 * @param {string|undefined} args.ridPedido restaurante solicitado en el payload.
 *   Para un `admin_restaurante` es OPCIONAL y, si viene, solo puede coincidir
 *   con el suyo.
 * @returns {{ok: true, rid: string} | {ok: false, code: string, msg: string}}
 */
export function autorizarAlta({ callerRole, callerRid, rolPedido, ridPedido }) {
  // --- 1. ¿Quién llama? -----------------------------------------------------
  if (!ROLES_LLAMADORES.includes(callerRole)) {
    return {
      ok: false,
      code: 'permission-denied',
      msg: 'Solo super_admin o admin_restaurante pueden dar de alta staff.',
    };
  }

  // --- 2. PROHIBICIÓN 1 · escalada vertical ---------------------------------
  // Allow-list estricta y sensible a mayúsculas: NO se normaliza el valor
  // recibido. Normalizarlo abriría la puerta a variantes ('Super_Admin',
  // ' super_admin ') que un futuro comparador laxo podría aceptar.
  if (!ROLES_ASIGNABLES.includes(rolPedido)) {
    return {
      ok: false,
      code: 'invalid-argument',
      msg: `rol debe ser uno de: ${ROLES_ASIGNABLES.join(', ')}.`,
    };
  }

  // --- 3a. super_admin: cualquier restaurante, pero DEBE indicarlo ----------
  if (callerRole === 'super_admin') {
    // El super no tiene rid propio del que tirar, así que omitirlo no puede
    // "heredar" nada: sería un alta de staff sin restaurante.
    if (typeof ridPedido !== 'string' || !SLUG_RE.test(ridPedido)) {
      return {
        ok: false,
        code: 'invalid-argument',
        msg: 'restauranteId es obligatorio y debe ser un slug [a-z0-9-].',
      };
    }
    return { ok: true, rid: ridPedido };
  }

  // --- 3b. admin_restaurante: SOLO su propio rid ----------------------------
  // Cuenta mal aprovisionada (claim `role` sin `rid`). Estado que no debería
  // existir; se corta aquí en vez de dejar que `rid` sea undefined aguas abajo.
  if (typeof callerRid !== 'string' || !callerRid) {
    return {
      ok: false,
      code: 'failed-precondition',
      msg: 'Tu cuenta no tiene restaurante asignado.',
    };
  }

  // PROHIBICIÓN 2 · escalada horizontal.
  // Mandar el rid propio es redundante pero legítimo (el formulario lo hace);
  // mandar cualquier otro es un intento de cruzar de tenant y se rechaza en
  // vez de ignorarse en silencio, para que el panel muestre el motivo real.
  if (ridPedido !== undefined && ridPedido !== callerRid) {
    return {
      ok: false,
      code: 'permission-denied',
      msg: 'No puedes crear usuarios de otro restaurante.',
    };
  }

  // El rid efectivo se DERIVA del claim, nunca del payload. Aunque el cliente
  // mienta, este es el único valor que sale de aquí.
  return { ok: true, rid: callerRid };
}
