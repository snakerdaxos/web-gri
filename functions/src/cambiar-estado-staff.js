// ============================================================================
// GRI — Cloud Function `cambiarEstadoStaff` (Fase 11, plan 24)
//
// QUÉ HACE: da de BAJA a una persona del equipo... sin borrar nada. Deshabilita
// su cuenta en Firebase Auth, le retira los custom claims y revoca sus refresh
// tokens. Y la operación inversa: la readmite restaurando exactamente el rol
// que tenía.
//
// ---------------------------------------------------------------------------
// POR QUÉ DESACTIVAR Y NO BORRAR — decisión BLOQUEADA del usuario
// ---------------------------------------------------------------------------
// (11-CONTEXT.md, «Baja de personal»). Borrar la cuenta dejaría PEDIDOS
// HUÉRFANOS apuntando a un uid inexistente y rompería los reportes de ventas
// por mesero, que es historial contable del restaurante. Además, en hostelería
// la gente vuelve: readmitir a alguien tiene que ser un clic, no un alta desde
// cero. No re-abrir, no "simplificar" con un `deleteUser`.
//
// ---------------------------------------------------------------------------
// QUÉ SIGNIFICA EXACTAMENTE "DESACTIVAR" (los cuatro pasos, y por qué CADA uno)
// ---------------------------------------------------------------------------
//  1. `updateUser(uid, {disabled: true})` — no puede volver a iniciar sesión.
//  2. `setCustomUserClaims(uid, null)`    — pierde `{role, rid}`, así que
//     aunque conservara un token vivo, `firestore.rules` deja de tratarlo como
//     staff (sin claim `role` se evalúa como cliente, helper `isCliente()`).
//  3. `revokeRefreshTokens(uid)`          — no puede RENOVAR el token que ya
//     tiene: sin esto, el paso 1 no cerraría la sesión en curso.
//  4. El doc espejo `usuarios/{uid}` se marca `activo: false` **conservando
//     `role` y `restauranteId`**.
//
// ⚠️⚠️ EL PASO 4 ES LA PIEZA QUE HACE POSIBLE LA REVERSIBILIDAD. Si alguien
// "limpiara" `role`/`restauranteId` al desactivar —parece lo lógico: la persona
// ya no es mesero de nadie— la REACTIVACIÓN quedaría rota para siempre: no
// habría ninguna fuente de la que averiguar qué rol tenía, porque los claims ya
// se borraron en el paso 2. Readmitir a esa persona exigiría reconfigurarla a
// mano. Los reportes históricos por mesero también leen ese campo. NO TOCAR.
//
// ---------------------------------------------------------------------------
// VENTANA RESIDUAL CONOCIDA · riesgo ACEPTADO y documentado (T-11-24-04)
// ---------------------------------------------------------------------------
// Un ID token ya emitido vive hasta ~1 hora. Durante ese rato la persona
// desactivada conserva los claims que ya viajan dentro de su token en curso, de
// modo que la baja NO expulsa instantáneamente una sesión abierta. La ventana
// está ACOTADA por los pasos 1 y 3 (ni entra de nuevo ni renueva) y no se puede
// extender. Cerrarla del todo exigiría que `firestore.rules` consultara un
// documento POR REQUEST, lo que rompería el presupuesto de access-calls que
// documenta la cabecera de `firestore.rules`. Es una decisión, no un olvido:
// no "arreglarlo" en silencio.
//
// ---------------------------------------------------------------------------
// DÓNDE VIVE LA AUTORIZACIÓN
// ---------------------------------------------------------------------------
// En `./baja-matrix.js`, y SOLO ahí — la misma matriz del alta más las dos
// prohibiciones nuevas (nadie toca a un `super_admin`; nadie se toca a sí
// mismo). La UI del panel oculta las acciones que no se pueden hacer, pero eso
// es cortesía: el payload viene de un cliente que puede mentir en `uid`. Quien
// llama se identifica con los CLAIMS DEL TOKEN, nunca con el payload.
//
// ---------------------------------------------------------------------------
// IDEMPOTENCIA Y NO-ATOMICIDAD (mismo criterio que el alta, plan 11-08)
// ---------------------------------------------------------------------------
// Auth y Firestore son dos sistemas y no hay transacción que los abarque. Si la
// ejecución muere entre el paso 3 y el 4, la cuenta queda deshabilitada pero la
// lista de equipo la sigue pintando como activa. La mitigación NO es un
// rollback (que también podría morir a medias) sino la IDEMPOTENCIA: repetir la
// misma operación converge al mismo estado final. Desactivar dos veces seguidas
// no es un error, es la reparación.
// ============================================================================

import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/https';

import { autorizarCambioEstado } from './baja-matrix.js';

/** Devuelve el primer valor que sea una cadena no vacía, o `undefined`. */
function primerTexto(...valores) {
  for (const v of valores) {
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return undefined;
}

export const cambiarEstadoStaff = onCall(
  // La REGIÓN va declarada en los DOS extremos (aquí y en
  // `panel_admin/lib/core/firebase_providers.dart`): un desajuste da un 404
  // opaco que en Flutter Web se disfraza de error de CORS.
  { region: 'us-central1', maxInstances: 5 },
  async (request) => {
    // --- 1. Sesión ----------------------------------------------------------
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    // --- 2. Forma del payload -----------------------------------------------
    const uid = request.data?.uid;
    const activo = request.data?.activo;

    if (typeof uid !== 'string' || uid.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Falta el usuario a modificar.');
    }
    // Booleano ESTRICTO, no truthy: con `!!activo`, mandar la cadena "false"
    // —que es lo que produce un formulario web mal serializado— REACTIVARÍA a
    // alguien que se quiso desactivar. El fallo tiene que ser ruidoso.
    if (typeof activo !== 'boolean') {
      throw new HttpsError('invalid-argument', 'El estado debe ser verdadero o falso.');
    }

    const auth = getAuth();
    const db = getFirestore();

    // --- 3. El objetivo tiene que existir en Auth ---------------------------
    let objetivo;
    try {
      objetivo = await auth.getUser(uid);
    } catch (err) {
      if (err?.code === 'auth/user-not-found') {
        throw new HttpsError('not-found', 'Ese usuario ya no existe.');
      }
      // NUNCA se devuelve el texto crudo del Admin SDK ni el stack: pueden
      // contener detalles internos del proyecto. Solo viaja el código, como
      // tercer argumento (que Functions no expone al cliente).
      logger.error('staff cambio de estado: fallo al leer el usuario', {
        code: err?.code,
        por: request.auth.uid,
      });
      throw new HttpsError('internal', 'No se pudo cambiar el estado del usuario.', err?.code);
    }

    // --- 4. Quién es el objetivo · claims primero, doc espejo después -------
    // El FALLBACK AL ESPEJO NO ES DEFENSA EN PROFUNDIDAD, ES EL CAMINO NORMAL
    // DE LA REACTIVACIÓN: a una persona ya desactivada le quitamos los claims
    // en su día (paso 2 de la cabecera), así que `customClaims` está vacío y la
    // ÚNICA fuente que queda de su rol es `usuarios/{uid}`. Por eso el paso 6
    // no puede tocar esos dos campos.
    const espejoRef = db.doc(`usuarios/${uid}`);
    const espejoSnap = await espejoRef.get();
    const espejo = espejoSnap.exists ? (espejoSnap.data() ?? {}) : {};
    const claims = objetivo.customClaims ?? {};

    const objetivoRole = primerTexto(claims.role, espejo.role);
    const objetivoRid = primerTexto(claims.rid, espejo.restauranteId);

    // --- 5. AUTORIZACIÓN · toda la decisión vive en baja-matrix.js ----------
    // `callerUid` sale del TOKEN, jamás del payload: es lo que hace
    // infalsificable la prohibición de auto-baja.
    const decision = autorizarCambioEstado({
      callerRole: request.auth.token?.role,
      callerRid: request.auth.token?.rid,
      callerUid: request.auth.uid,
      objetivoRole,
      objetivoRid,
      objetivoUid: uid,
    });
    if (!decision.ok) {
      throw new HttpsError(decision.code, decision.msg);
    }

    let rol;
    let rid;

    if (activo === false) {
      // --- 6. DESACTIVAR ----------------------------------------------------
      rol = objetivoRole;
      rid = objetivoRid;

      await auth.updateUser(uid, { disabled: true });
      await auth.setCustomUserClaims(uid, null);
      await auth.revokeRefreshTokens(uid);

      // `merge: true` y NI UNA MENCIÓN a `role` / `restauranteId` cuando ya
      // están: son los campos que permiten reactivar (ver cabecera) y los que
      // usan los reportes históricos por mesero.
      // La única excepción es una ficha INCOMPLETA (espejo inexistente o sin
      // rol, p. ej. porque un alta murió entre Auth y Firestore): en ese caso
      // se ESCRIBEN, tomados de los claims que estamos a punto de borrar. Sin
      // esto, desactivar a esa persona destruiría el último rastro de su rol y
      // la baja dejaría de ser reversible — que es justo lo que la decisión
      // bloqueada prohíbe.
      const reparacion = {};
      if (typeof espejo.role !== 'string' && rol) reparacion.role = rol;
      if (typeof espejo.restauranteId !== 'string' && rid) reparacion.restauranteId = rid;

      await espejoRef.set(
        {
          activo: false,
          desactivadoAt: FieldValue.serverTimestamp(),
          desactivadoPor: request.auth.uid,
          ...reparacion,
        },
        { merge: true },
      );
    } else {
      // --- 7. REACTIVAR -----------------------------------------------------
      // El rol se lee del ESPEJO, que es donde sobrevivió a la baja.
      rol = primerTexto(espejo.role);
      rid = primerTexto(espejo.restauranteId);

      if (!rol || !rid) {
        // Mensaje ACCIONABLE: reintentar no puede arreglarlo, así que se dice
        // qué hacer. `crearUsuarioStaff` con el mismo correo repara la ficha
        // (es idempotente por diseño, 11-08).
        throw new HttpsError(
          'failed-precondition',
          'No se puede reactivar: falta el rol en su ficha. Vuelve a darlo de ' +
            'alta con el mismo correo para repararla.',
        );
      }

      await auth.updateUser(uid, { disabled: false });
      await auth.setCustomUserClaims(uid, { role: rol, rid });

      await espejoRef.set(
        {
          activo: true,
          reactivadoAt: FieldValue.serverTimestamp(),
          reactivadoPor: request.auth.uid,
        },
        { merge: true },
      );
    }

    // --- 8. Auditoría (T-11-24-06) ------------------------------------------
    // `por` es quién revocó el acceso: sin eso, una baja indebida no tiene
    // responsable en Cloud Logging.
    logger.info('staff cambio de estado', { uid, activo, por: request.auth.uid, rol, rid });

    return { uid, activo, rol, restauranteId: rid };
  },
);
