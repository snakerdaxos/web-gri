// ============================================================================
// GRI — Cloud Function `crearUsuarioStaff` (Fase 11, plan 08)
//
// QUÉ HACE: da de alta un usuario de STAFF (admin_restaurante / mesero /
// cocina) con sus custom claims `{role, rid}` y su doc espejo `usuarios/{uid}`.
//
// ---------------------------------------------------------------------------
// POR QUÉ ESTO TIENE QUE SER UNA CLOUD FUNCTION Y NO CÓDIGO DEL PANEL
// ---------------------------------------------------------------------------
// Dos motivos independientes, y cada uno bastaría:
//  1. `setCustomUserClaims` es EXCLUSIVO del Admin SDK. Un cliente no puede
//     escribir sus propios claims ni los de nadie — es justo lo que impide la
//     escalada de privilegios en todo el sistema.
//  2. `createUserWithEmailAndPassword` del SDK cliente INICIA SESIÓN con la
//     cuenta recién creada: crear un mesero desde el panel DESLOGUEARÍA al
//     admin que lo está creando. No hay atajo.
//
// ---------------------------------------------------------------------------
// DÓNDE VIVE LA AUTORIZACIÓN
// ---------------------------------------------------------------------------
// En `./auth-matrix.js`, y SOLO ahí. La UI del panel oculta lo que el usuario
// no puede hacer, pero eso es cortesía, no seguridad: el payload viaja desde un
// cliente que puede mentir en `rol` y en `restauranteId`. La decisión —incluido
// el rid efectivo— se toma aquí con los CLAIMS del token, no con el payload.
// Prohibido explícitamente por la decisión bloqueada del usuario validar el rol
// en Flutter (11-CONTEXT.md).
//
// ---------------------------------------------------------------------------
// NO-ATOMICIDAD ENTRE AUTH Y FIRESTORE — leer antes de "arreglarlo"
// ---------------------------------------------------------------------------
// Los pasos 6 (claims en Auth) y 7 (doc espejo en Firestore) son dos sistemas
// distintos y NO hay transacción que los abarque. Si la ejecución muere entre
// ambos, el usuario queda con permisos reales pero INVISIBLE en la lista de
// equipo del panel.
// La mitigación NO es un rollback (que también podría morir a mitad), sino la
// IDEMPOTENCIA: repetir el alta con el mismo correo converge al mismo estado
// final. `createUser` → `auth/email-already-exists` → `getUserByEmail` →
// se reescriben claims y espejo con `merge`. Ese hecho debe aparecer en el copy
// de la UI del plan 11-10: "volver a crear con el mismo correo repara un alta
// incompleta".
//
// ---------------------------------------------------------------------------
// ANTI-SECUESTRO DE CUENTA POR CORREO · las TRES ramas del paso 5
// ---------------------------------------------------------------------------
// El correo es la clave natural del alta, así que un correo YA REGISTRADO puede
// pertenecer a alguien que no es "un alta incompleta mía":
//   (a) una cuenta de PLATAFORMA (`super_admin`) → denegar;
//   (b) staff de OTRO restaurante → denegar (cruce de tenants);
//   (c) una cuenta de CLIENTE de la app móvil → denegar.
// La rama (c) es la menos obvia y la más real: sin ella, cualquiera que conozca
// el correo de un cliente registrado puede convertir su cuenta en staff de su
// restaurante SIN CONSENTIMIENTO. La víctima sigue pudiendo entrar, pero de
// pronto es `mesero` de un restaurante ajeno y ve sus pedidos y sus mesas.
// TRAMPA: un cliente auto-registrado NO lleva claim `role` (la ausencia de rol
// se interpreta como cliente en `firestore.rules`, helper `isCliente()`), así
// que mirar solo los claims NO detecta nada. Hay que consultar ADEMÁS el doc
// espejo `usuarios/{uid}`.
//
// RIESGO RESIDUAL ACEPTADO Y DOCUMENTADO: una cuenta en Auth sin claims Y sin
// doc espejo es indistinguible de un alta de staff incompleta, así que se deja
// pasar (es el camino de reparación). Un cliente cuyo `set()` del espejo falló
// caería en ese hueco. Es estrecho —la app escribe el espejo inmediatamente
// después del alta— y cerrarlo rompería la reparación idempotente, que es la
// única mitigación de la no-atomicidad de arriba.
// ============================================================================

import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/https';

import { autorizarAlta } from './auth-matrix.js';

/**
 * Longitud mínima de contraseña del PRODUCTO. Firebase exige 6; aquí se exige
 * 8 y el formulario del panel (11-10) debe pedir lo mismo — si divergieran, el
 * usuario vería un error del servidor tras un formulario que dio por válido.
 */
const MIN_PASSWORD = 8;

function textoNoVacio(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

export const crearUsuarioStaff = onCall(
  // La REGIÓN va declarada en los DOS extremos (aquí y en
  // `panel_admin/lib/core/firebase_providers.dart`): un desajuste da un 404
  // opaco que en Flutter Web se disfraza de error de CORS.
  // `maxInstances: 5` acota el coste de una creación masiva (T-11-08-07).
  // App Check daría defensa real y queda como deuda conocida (DIFERIDO).
  { region: 'us-central1', maxInstances: 5 },
  async (request) => {
    // --- 1. Sesión ----------------------------------------------------------
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    // --- 2. Forma del payload -----------------------------------------------
    // `invalid-argument` = "lo que me mandaste no tiene sentido". Nunca se
    // mezcla con `permission-denied`, que significa "sé quién eres y no puedes".
    const emailBruto = request.data?.email;
    const password = request.data?.password;
    const nombre = request.data?.nombre;
    const rol = request.data?.rol;
    const restauranteId = request.data?.restauranteId;

    if (!textoNoVacio(emailBruto) || !emailBruto.includes('@')) {
      throw new HttpsError('invalid-argument', 'El correo no es válido.');
    }
    if (typeof password !== 'string' || password.length < MIN_PASSWORD) {
      throw new HttpsError(
        'invalid-argument',
        `La contraseña debe tener al menos ${MIN_PASSWORD} caracteres.`,
      );
    }
    if (!textoNoVacio(nombre)) {
      throw new HttpsError('invalid-argument', 'El nombre es obligatorio.');
    }

    // Firebase Auth normaliza el correo; se normaliza también aquí para que el
    // doc espejo y la clave natural del alta coincidan siempre.
    const email = emailBruto.trim().toLowerCase();

    // --- 3. AUTORIZACIÓN · toda la decisión vive en auth-matrix.js ----------
    // Se usan los CLAIMS del token, jamás el payload, para saber quién llama.
    const decision = autorizarAlta({
      callerRole: request.auth.token?.role,
      callerRid: request.auth.token?.rid,
      rolPedido: rol,
      ridPedido: restauranteId,
    });
    if (!decision.ok) {
      throw new HttpsError(decision.code, decision.msg);
    }
    const rid = decision.rid;

    const db = getFirestore();
    const auth = getAuth();

    // --- 4. El restaurante destino tiene que existir -------------------------
    // Sin esto, un dedazo en el slug crearía staff HUÉRFANO: con claims válidos
    // para un `rid` que no existe, invisible en todos los paneles y sin forma de
    // limpiarlo desde el producto.
    const restaurante = await db.doc(`restaurantes/${rid}`).get();
    if (!restaurante.exists) {
      throw new HttpsError('not-found', `El restaurante ${rid} no existe.`);
    }

    // --- 5. Alta idempotente por correo + anti-secuestro ---------------------
    // Mismo patrón que `scripts/seed_firebase.mjs`: intentar crear y, si el
    // correo ya está, recuperar el usuario existente.
    let uid;
    let creado = false;
    try {
      const user = await auth.createUser({
        email,
        password,
        displayName: nombre.trim(),
        // El staff no pasa por verificación de correo: lo da de alta alguien
        // que ya está autenticado y responde por él.
        emailVerified: true,
      });
      uid = user.uid;
      creado = true;
    } catch (err) {
      if (err?.code !== 'auth/email-already-exists') {
        // NUNCA se devuelve al cliente el texto crudo del Admin SDK ni el
        // stack: puede contener detalles internos del proyecto. Solo el código
        // viaja, como tercer argumento (que Functions no expone al cliente).
        logger.error('staff alta: fallo al crear el usuario', {
          code: err?.code,
          por: request.auth.uid,
        });
        throw new HttpsError(
          'internal',
          'No se pudo crear el usuario.',
          err?.code,
        );
      }

      const existente = await auth.getUserByEmail(email);
      uid = existente.uid;
      const prev = existente.customClaims ?? {};

      // (a) PLATAFORMA. Degradar a un super_admin a `mesero` sería un
      //     apagón total de la plataforma, además de un secuestro.
      if (prev.role === 'super_admin') {
        throw new HttpsError('permission-denied', 'Esa cuenta es de plataforma.');
      }

      // (b) OTRO TENANT. `rid` se compara solo si es una cadena: el
      //     super_admin lo lleva a `null` a propósito y eso no es "otro rid".
      if (typeof prev.rid === 'string' && prev.rid !== rid) {
        throw new HttpsError(
          'already-exists',
          'Ese correo ya pertenece a otro restaurante.',
        );
      }

      // (c) CUENTA DE CLIENTE. Los claims NO bastan: un cliente auto-registrado
      //     no tiene ninguno. Se consulta el doc espejo, que la app cliente
      //     escribe con `role: 'cliente'` y `restauranteId: null`
      //     (`app_cliente/lib/features/auth/auth_controller.dart`) y que las
      //     rules obligan a tener esa forma exacta en el auto-registro.
      let esCliente = prev.role === 'cliente';
      if (!esCliente) {
        const espejo = await db.doc(`usuarios/${uid}`).get();
        if (espejo.exists) {
          const datos = espejo.data() ?? {};
          esCliente = datos.role === 'cliente' || datos.restauranteId === null;
        }
      }
      if (esCliente) {
        throw new HttpsError(
          'already-exists',
          'Ese correo ya tiene una cuenta de cliente; pide a esa persona que ' +
            'use otro correo para su cuenta de trabajo.',
        );
      }
    }

    // --- 6. Claims · la concesión de privilegio -----------------------------
    // Se reescriben SIEMPRE (también en el camino de reparación): es lo que
    // hace converger un alta que murió a medias.
    await auth.setCustomUserClaims(uid, { role: rol, rid });

    // --- 7. Doc espejo -------------------------------------------------------
    // Las rules NO permitirían este write desde un cliente (`role` distinto de
    // 'cliente' es escalada vertical); el Admin SDK las salta por diseño.
    // `createdAt` solo en el alta real, para no falsear la antigüedad al
    // reparar.
    await db.doc(`usuarios/${uid}`).set(
      {
        nombre: nombre.trim(),
        email,
        role: rol,
        restauranteId: rid,
        updatedAt: FieldValue.serverTimestamp(),
        ...(creado ? { createdAt: FieldValue.serverTimestamp() } : {}),
      },
      { merge: true },
    );

    // --- 8. Auditoría (T-11-08-08) ------------------------------------------
    // `por` es quién concedió el privilegio: sin eso, un alta indebida no tiene
    // responsable en Cloud Logging.
    logger.info('staff alta', { uid, rol, rid, por: request.auth.uid, creado });

    return { uid, creado, rol, restauranteId: rid };
  },
);
