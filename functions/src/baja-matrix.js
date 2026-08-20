// ============================================================================
// GRI — Matriz de autorización de la BAJA de staff (Fase 11, plan 24)
//
// QUÉ ES: la decisión de "¿puede este llamador cambiar el estado (activo /
// desactivado) de ESTA persona?", aislada como función PURA.
//
// ---------------------------------------------------------------------------
// POR QUÉ UN ARCHIVO HERMANO Y NO UNA FUNCIÓN MÁS EN auth-matrix.js
// ---------------------------------------------------------------------------
// Son decisiones DISTINTAS: `autorizarAlta` responde "¿puede CREAR este rol
// aquí?" y devuelve un rid efectivo; esto responde "¿puede REVOCAR a esta
// persona concreta?" y necesita los uid de los dos lados. Sus tablas de casos
// no se solapan y mezclarlas haría ilegible la combinatoria, que es justo donde
// vive la seguridad. Lo que SÍ se comparte —las constantes de roles de
// llamador— se IMPORTA, no se copia: dos allow-lists paralelas divergen en
// silencio en cuanto alguien añade un rol al producto. Hay un test que verifica
// esa importación y que prohíbe redeclararlas aquí.
//
// ---------------------------------------------------------------------------
// REQUISITO DURO: CERO IMPORTS DE FIREBASE (heredado de 11-08)
// ---------------------------------------------------------------------------
// Ni `firebase-admin` ni `firebase-functions`. Es lo que permite ejecutar la
// combinatoria COMPLETA —incluidos los ~400 casos de los tests de propiedad—
// en milisegundos, sin emuladores. `auth-matrix.js` cumple lo mismo, así que
// importar de él no rompe la pureza. Hay un test que lo verifica leyendo la
// fuente.
//
// ---------------------------------------------------------------------------
// LA MATRIZ · decisión BLOQUEADA del usuario (11-CONTEXT.md, «Baja de
// personal», 2026-08-19)
// ---------------------------------------------------------------------------
//   | Llamador            | Puede desactivar / reactivar a          |
//   | super_admin         | staff de CUALQUIER restaurante          |
//   | admin_restaurante   | SOLO staff de su propio rid             |
//
// Es la MISMA matriz del alta (11-08) más DOS PROHIBICIONES NUEVAS, cada una
// con test unitario, test de propiedad y caso e2e con token real:
//
//   (1) NADIE puede cambiar el estado de un `super_admin` por esta vía, ni
//       siquiera otro `super_admin`. Igual que en el alta, la prohibición es
//       ABSOLUTA y no relativa al llamador: así se cierra el vector entero en
//       vez de dejarlo condicionado a una comprobación de rol que alguien
//       podría relajar. Desactivar al único super dejaría la plataforma sin
//       administrador y `bootstrapPlataforma` (11-07) ya está inerte, así que
//       no habría forma de recuperarla desde el producto.
//   (2) NADIE puede cambiar su propio estado. El escenario que cierra es el
//       admin único que se da de baja a sí mismo por error: el restaurante
//       queda sin administrador y solo se recupera a mano con la clave de
//       servicio. Es exactamente lo que la decisión de permitir DOS
//       `admin_restaurante` (11-08) buscaba evitar.
//
// ---------------------------------------------------------------------------
// EL ORDEN DE LAS COMPROBACIONES ES PARTE DEL CONTRATO
// ---------------------------------------------------------------------------
//   1. ¿quién llama?      → a un desconocido no se le dice nada más.
//   2. ¿el objetivo es super_admin?  → prohibición 1, ANTES de mirar uid o rid,
//      para que muera siempre igual y con el mismo mensaje.
//   3. ¿el objetivo soy yo? → prohibición 2.
//   4. ¿alcance de rid?     → solo aplica a `admin_restaurante`.
//   5. ¿el objetivo es personal? → allow-list de objetivos (ver abajo).
//
// Consecuencia que hay que conocer al leer los tests: un `super_admin` sobre SÍ
// MISMO muere por (2)... no, muere por (1), porque él ES super_admin y la
// comprobación 1 va antes. Por eso la prohibición 2 tiene además un caso
// AISLADO cuyo objetivo NO es super_admin: es el único que se pone rojo si se
// quita su control, y sin él la prohibición 2 estaría verde por el motivo
// equivocado.
//
// ---------------------------------------------------------------------------
// REGLA DE CÓDIGOS DE ERROR (la misma de 11-08, no mezclarlos nunca)
// ---------------------------------------------------------------------------
//   permission-denied   → "sé quién eres y no puedes". Fallo de AUTORIZACIÓN.
//   failed-precondition → el LLAMADOR está mal aprovisionado (claim `role` sin
//                         `rid`). No es culpa de su payload.
// Los CINCO mensajes de denegación son DISTINTOS entre sí a propósito: el
// llamador ya es staff autenticado (no hay riesgo de oráculo frente a un
// anónimo, al revés que en 11-07) y un mensaje propio por control es lo único
// que da dientes a los tests — un caso que solo asserta el código puede estar
// verde denegado por OTRO control (verde por el motivo equivocado de 11-08).
// ============================================================================

import { ROLES_LLAMADORES } from './auth-matrix.js';

/**
 * Roles cuyo estado se puede cambiar por esta vía: el PERSONAL de un
 * restaurante. Allow-list, no deny-list.
 *
 * `super_admin` NO está y no debe estarlo nunca (prohibición 1).
 * `cliente` tampoco, y no es lo mismo que "no hace falta": el plan declara
 * los clientes fuera de alcance razonando que «un cliente no pertenece a
 * ningún rid», pero ese razonamiento solo cierra la puerta al
 * `admin_restaurante` —a quien lo corta el alcance de tenant—. El
 * `super_admin` no tiene rid contra el que comparar, así que sin esta lista
 * podría deshabilitar la cuenta de un comensal de la app móvil desde la
 * pantalla de equipo. Esta es la comprobación que lo impide.
 */
export const ROLES_GESTIONABLES = ['admin_restaurante', 'mesero', 'cocina'];

/**
 * Decide si un cambio de estado de staff está autorizado.
 *
 * NO recibe `activo` a propósito: la autorización es la MISMA para desactivar
 * y para reactivar. Reactivar a un `super_admin` o a uno mismo tampoco está
 * permitido, así que condicionar cualquier rama al sentido de la operación
 * sería un agujero. Hay un test que compara la decisión con `activo: true` y
 * con `activo: false` para las 19 filas de la tabla.
 *
 * @param {object} args
 * @param {string|undefined} args.callerRole claim `role` del llamador. Un
 *   cliente auto-registrado NO lleva este claim (11-04): llega `undefined` y
 *   se deniega, que es lo correcto.
 * @param {string|null|undefined} args.callerRid claim `rid` del llamador. El
 *   `super_admin` lo tiene en `null` a propósito.
 * @param {string} args.callerUid uid del llamador (`request.auth.uid`), no del
 *   payload: es lo que hace infalsificable la prohibición 2.
 * @param {string|undefined} args.objetivoRole rol del objetivo, derivado de sus
 *   custom claims o —si ya está desactivado y los perdió— del doc espejo.
 * @param {string|null|undefined} args.objetivoRid restaurante del objetivo,
 *   por la misma vía.
 * @param {string} args.objetivoUid uid del objetivo.
 * @returns {{ok: true} | {ok: false, code: string, msg: string}}
 */
export function autorizarCambioEstado({
  callerRole,
  callerRid,
  callerUid,
  objetivoRole,
  objetivoRid,
  objetivoUid,
}) {
  // --- 1. ¿Quién llama? -----------------------------------------------------
  if (!ROLES_LLAMADORES.includes(callerRole)) {
    return {
      ok: false,
      code: 'permission-denied',
      msg: 'Solo super_admin o admin_restaurante pueden cambiar el estado del personal.',
    };
  }

  // --- 2. PROHIBICIÓN 1 · el objetivo no puede ser plataforma ---------------
  // Comparación estricta y sin normalizar, igual que la allow-list del alta:
  // normalizar abriría variantes ('Super_Admin', ' super_admin ') que un futuro
  // comparador laxo podría aceptar.
  if (objetivoRole === 'super_admin') {
    return {
      ok: false,
      code: 'permission-denied',
      msg: 'No se puede cambiar el estado de una cuenta de plataforma.',
    };
  }

  // --- 3. PROHIBICIÓN 2 · nadie se toca a sí mismo --------------------------
  // El uid del llamador viene del TOKEN (`request.auth.uid`), no del payload,
  // así que esta comparación no se puede burlar mintiendo en el body.
  if (typeof callerUid === 'string' && callerUid === objetivoUid) {
    return {
      ok: false,
      code: 'permission-denied',
      msg: 'No puedes cambiar el estado de tu propia cuenta.',
    };
  }

  // --- 4. Alcance de rid · solo para admin_restaurante ----------------------
  if (callerRole === 'admin_restaurante') {
    // Cuenta mal aprovisionada (claim `role` sin `rid`). Estado que no debería
    // existir; se corta aquí en vez de comparar contra `undefined` aguas abajo,
    // donde un objetivo sin rid casaría por accidente.
    if (typeof callerRid !== 'string' || !callerRid) {
      return {
        ok: false,
        code: 'failed-precondition',
        msg: 'Tu cuenta no tiene restaurante asignado.',
      };
    }
    if (objetivoRid !== callerRid) {
      return {
        ok: false,
        code: 'permission-denied',
        msg: 'No puedes cambiar el estado de personal de otro restaurante.',
      };
    }
  }

  // --- 5. El objetivo tiene que ser PERSONAL --------------------------------
  // Va al final a propósito: si fuese antes que (2), un objetivo `super_admin`
  // moriría aquí en vez de por la prohibición 1 y su test quedaría verde por
  // el motivo equivocado. Para un `admin_restaurante` esta rama es casi
  // inalcanzable (el alcance de rid corta antes a clientes y desconocidos);
  // quien la necesita de verdad es el `super_admin`, que no tiene rid.
  if (!ROLES_GESTIONABLES.includes(objetivoRole)) {
    return {
      ok: false,
      code: 'permission-denied',
      msg: 'Esta operación es solo para personal del restaurante.',
    };
  }

  return { ok: true };
}
