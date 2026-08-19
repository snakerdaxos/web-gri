// ============================================================================
// GRI — Cloud Function `bootstrapPlataforma` (Fase 11, plan 07)
//
// QUÉ HACE: crea el PRIMER `super_admin` de la plataforma, y solo si no existe
// ninguno. Después queda inerte para siempre. Es lo que permite arrancar GRI
// desde una pantalla en vez de desde `scripts/seed_firebase.mjs` con una clave
// de servicio en manos de una persona.
//
// ---------------------------------------------------------------------------
// POR QUÉ ESTA FUNCIÓN ES LA SUPERFICIE MÁS PELIGROSA DEL SISTEMA
// ---------------------------------------------------------------------------
// Concede `role: 'super_admin'`: el privilegio máximo. Está desplegada en
// internet e invocable por cualquiera que conozca su URL. Cada control de abajo
// es carga estructural — NO "simplificar" ninguno.
//
//  1. NO acepta uid ni email de destino. Promueve al llamador autenticado y a
//     nadie más (T-11-07-03). El payload solo lleva `nombre` y `secreto`.
//
//  2. DOS factores, no uno. El correo NO es un secreto: el registro con
//     email/contraseña está ABIERTO (lo usa la app cliente), así que cualquiera
//     que adivine el correo del fundador podría registrarlo primero. Por eso
//     hacen falta ADEMÁS:
//       · `email_verified === true` (prueba de control del buzón), y
//       · `BOOTSTRAP_SECRET`, fijado en el despliegue y comparado en tiempo
//         constante (T-11-07-01).
//
//  3. Los tres controles se evalúan SIN CORTOCIRCUITO y comparten un mensaje
//     IDÉNTICO. Si cada motivo tuviera su texto —o si el primer fallo cortara
//     la evaluación— la función sería un oráculo: un atacante sabría si acertó
//     el correo pero falló el secreto, o al revés (T-11-07-06).
//
//  4. La guarda de unicidad es ATÓMICA y va PRIMERO. `DocumentReference.create()`
//     es una sola operación de servidor que falla con ALREADY_EXISTS si el
//     documento ya existe: dos invocaciones concurrentes no pueden ganar las
//     dos (T-11-07-02).
//     ADVERTENCIA — EL ORDEN NO ES DECORATIVO. Si delante se pusiera una
//     consulta "¿ya hay algún super_admin?", esa consulta resolvería la carrera
//     por sí sola en el caso feliz y la rama ALREADY_EXISTS quedaría
//     INALCANZABLE — con lo que los tests pasarían idénticos aunque la guarda
//     no existiera. La comprobación por consulta va DESPUÉS y cubre otra cosa:
//     un proyecto sembrado con el seed, que tendría super_admin pero no
//     centinela.
//
//  5. `plataforma/bootstrap` está cerrado a cal y canto en `firestore.rules`
//     (`allow read, write: if false`): solo lo toca el Admin SDK, que salta las
//     rules por diseño. Si un cliente pudiera borrarlo, re-abriría el bootstrap
//     (T-11-07-04).
// ============================================================================

import crypto from 'node:crypto';

import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/https';

/** Ruta del centinela de un solo uso. Su mera existencia cierra la puerta. */
const RUTA_CENTINELA = 'plataforma/bootstrap';

/**
 * Mensaje ÚNICO de denegación. Los CINCO motivos por los que se puede negar
 * (secreto incorrecto · correo no autorizado · correo sin verificar ·
 * centinela de otro uid · ya existe un super_admin) devuelven exactamente este
 * texto y el mismo código. Cualquier variación convierte la función en un
 * oráculo de enumeración (T-11-07-06).
 */
const MSG_DENEGADO = 'No puedes inicializar esta plataforma.';

/**
 * Compara dos secretos en tiempo constante.
 *
 * `crypto.timingSafeEqual` LANZA si los buffers tienen distinta longitud, así
 * que hay que comprobar la longitud antes. Pero devolver `false` ahí mismo
 * filtraría la longitud del secreto por el tiempo de respuesta: una entrada de
 * longitud incorrecta costaría muchísimo menos que una correcta. Por eso, en el
 * camino de longitud distinta se ejecuta IGUALMENTE una comparación de relleno
 * contra un buffer del tamaño esperado, y solo después se devuelve false.
 *
 * @param {string} recibido secreto que llega en el payload
 * @param {string} esperado secreto configurado en el despliegue
 * @returns {boolean}
 */
function igualEnTiempoConstante(recibido, esperado) {
  const bufEsperado = Buffer.from(esperado, 'utf8');
  const bufRecibido = Buffer.from(recibido, 'utf8');

  if (bufRecibido.length !== bufEsperado.length) {
    // Trabajo de relleno: mismo coste que una comparación real, resultado
    // descartado a propósito.
    crypto.timingSafeEqual(Buffer.alloc(bufEsperado.length), bufEsperado);
    return false;
  }
  return crypto.timingSafeEqual(bufRecibido, bufEsperado);
}

/**
 * ¿El error del Admin SDK es ALREADY_EXISTS?
 *
 * `DocumentReference.create()` rechaza con un error gRPC cuyo `code` es 6
 * (ALREADY_EXISTS). Se aceptan también las formas de cadena por robustez ante
 * cambios de envoltorio entre versiones del SDK y del emulador.
 */
function esYaExiste(err) {
  return (
    err?.code === 6 ||
    err?.code === 'already-exists' ||
    /ALREADY_EXISTS/i.test(String(err?.message ?? ''))
  );
}

function textoNoVacio(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

export const bootstrapPlataforma = onCall(
  // La REGIÓN va declarada en los DOS extremos (aquí y en
  // `panel_admin/lib/core/firebase_providers.dart`): un desajuste da un 404
  // opaco que en Flutter Web se disfraza de error de CORS.
  // `maxInstances: 3` acota el coste de una invocación masiva (T-11-07-07).
  // App Check daría defensa real y queda como deuda conocida (DIFERIDO).
  { region: 'us-central1', maxInstances: 3 },
  async (request) => {
    // --- 1. Sesión ----------------------------------------------------------
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const uid = request.auth.uid;

    // --- 2. Configuración del despliegue · FAIL CLOSED ----------------------
    // Sin las dos variables la función NO promueve a nadie. Es deliberado: un
    // despliegue mal configurado debe quedar inerte, no abierto.
    const emailAutorizado = process.env.BOOTSTRAP_EMAIL;
    const secretoEsperado = process.env.BOOTSTRAP_SECRET;
    if (!textoNoVacio(emailAutorizado) || !textoNoVacio(secretoEsperado)) {
      throw new HttpsError(
        'failed-precondition',
        'La plataforma no tiene configurada la inicialización.',
      );
    }

    // --- 3. Forma del payload -----------------------------------------------
    const nombre = request.data?.nombre;
    const secreto = request.data?.secreto;
    if (!textoNoVacio(nombre) || !textoNoVacio(secreto)) {
      throw new HttpsError(
        'invalid-argument',
        'Faltan el nombre o el secreto de inicialización.',
      );
    }

    // --- 4. Los TRES controles de autorización, SIN cortocircuito -----------
    // Los tres se computan SIEMPRE y la decisión se toma al final: así el
    // mensaje y el trabajo realizado son los mismos falle el que falle.
    const correoLlamador = String(request.auth.token?.email ?? '')
      .trim()
      .toLowerCase();

    // (a) Control del buzón. Estricto con `===`: un truthy cualquiera no vale.
    //     Sin esto el filtro por correo tiene entropía NULA, porque el registro
    //     email/contraseña está abierto.
    const okVerificado = request.auth.token?.email_verified === true;

    // (b) El correo del llamador es el autorizado en el despliegue.
    const okCorreo =
      correoLlamador !== '' &&
      correoLlamador === emailAutorizado.trim().toLowerCase();

    // (c) El secreto, en tiempo constante.
    const okSecreto = igualEnTiempoConstante(
      secreto.trim(),
      secretoEsperado.trim(),
    );

    if (!(okVerificado && okCorreo && okSecreto)) {
      throw new HttpsError('permission-denied', MSG_DENEGADO);
    }

    const db = getFirestore();
    const centinela = db.doc(RUTA_CENTINELA);

    // --- 5. GUARDA ATÓMICA · va ANTES de cualquier consulta -----------------
    // Una sola operación de servidor. En una carrera de N llamadas exactamente
    // UNA sale por aquí con éxito; las otras N−1 caen en ALREADY_EXISTS.
    let creado = false;
    let reparado = false;
    try {
      await centinela.create({
        uid,
        email: correoLlamador,
        nombre: nombre.trim(),
        createdAt: FieldValue.serverTimestamp(),
        // Rastro de auditoría (T-11-07-05). Ambos pueden faltar en el
        // emulador: `rawRequest` existe, pero la IP y el user-agent dependen
        // del cliente y del transporte, así que se guardan como null si no hay.
        userAgent: request.rawRequest?.headers?.['user-agent'] ?? null,
        ip: request.rawRequest?.ip ?? null,
      });
      creado = true;
    } catch (err) {
      if (!esYaExiste(err)) {
        // NUNCA se devuelve el stack ni el mensaje del SDK al cliente.
        logger.error('bootstrap plataforma: fallo al crear el centinela', {
          uid,
          code: err?.code,
        });
        throw new HttpsError(
          'internal',
          'No se pudo inicializar la plataforma.',
        );
      }

      // El centinela ya existía. ¿De quién?
      const snap = await centinela.get();
      const duenio = snap.exists ? snap.data()?.uid : null;
      if (duenio !== uid) {
        // Otra persona ya inicializó la plataforma (T-11-07-03).
        throw new HttpsError('permission-denied', MSG_DENEGADO);
      }

      // CAMINO DE REPARACIÓN — el centinela es de esta misma persona.
      // Firestore y Auth no son atómicos entre sí: si una invocación murió
      // después de crear el centinela pero antes de escribir los claims, la
      // plataforma quedaría bloqueada para siempre. Reintentar converge.
      // Es también lo que hace que una carrera de N termine con
      // 1 `creado` + (N−1) `reparado` en vez de N−1 errores.
      reparado = true;
    }

    // --- 6. Comprobación secundaria · DESPUÉS de la guarda ------------------
    // Cubre un caso que la guarda no ve: un proyecto sembrado antes con
    // `scripts/seed_firebase.mjs`, que TIENE super_admin pero NO centinela.
    // Solo aplica cuando el centinela se acaba de crear en ESTA invocación: en
    // el camino de reparación el super_admin que encontraría la consulta sería
    // el propio llamador de un intento anterior, y negarle el paso rompería la
    // convergencia idempotente.
    if (creado) {
      const yaHaySuper = await db
        .collection('usuarios')
        .where('role', '==', 'super_admin')
        .limit(1)
        .get();

      if (!yaHaySuper.empty) {
        // Se borra el centinela recién creado: si se dejara, la plataforma
        // quedaría bloqueada por un documento huérfano que nadie puede
        // eliminar desde un cliente (las rules lo prohíben) (T-11-07-08).
        await centinela.delete();
        throw new HttpsError('permission-denied', MSG_DENEGADO);
      }
    }

    // --- 7. Claims ----------------------------------------------------------
    // MISMA forma que produce `scripts/seed_firebase.mjs:47`: el super_admin
    // NO lleva `rid` (elige restaurante en el selector del panel).
    await getAuth().setCustomUserClaims(uid, { role: 'super_admin', rid: null });

    // --- 8. Documento espejo ------------------------------------------------
    // Las rules NO permitirían este write desde un cliente (sería escalada
    // vertical); el Admin SDK las salta por diseño. `merge: true` mantiene el
    // camino de reparación idempotente.
    await db.doc(`usuarios/${uid}`).set(
      {
        nombre: nombre.trim(),
        email: correoLlamador,
        role: 'super_admin',
        restauranteId: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // --- 9. Auditoría -------------------------------------------------------
    logger.info('bootstrap plataforma', {
      uid,
      email: correoLlamador,
      reparado,
    });

    return { uid, creado, reparado };
  },
);
