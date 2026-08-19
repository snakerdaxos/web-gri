// ============================================================================
// GRI — Montaje compartido de los tests e2e de Cloud Functions (Fase 11, 11-07)
//
// Lo reutiliza el plan 11-08 (`crearUsuarioStaff`). No meter aquí aserciones:
// esto es SOLO el andamiaje.
//
// ---------------------------------------------------------------------------
// POR QUÉ CONTRA EMULADORES REALES Y NO CON `firebase-functions-test` OFFLINE
// ---------------------------------------------------------------------------
// El modo offline permite INVENTAR el `context.auth` que recibe la función.
// Aplicado a `bootstrapPlataforma` eso sería catastrófico: el control que hay
// que probar es precisamente que un token real, emitido por Firebase Auth, con
// `email_verified` real, es lo único que pasa. Un test que fabrica el auth
// prueba el mock, no la función. PROHIBIDO en este archivo.
//
// ---------------------------------------------------------------------------
// DOS SDK, DOS PAPELES
// ---------------------------------------------------------------------------
//  · Admin SDK  → sembrar y limpiar (salta rules y auth). Nunca invoca.
//  · SDK cliente JS → invoca la callable EXACTAMENTE como el panel: con un
//    idToken real obtenido del emulador de Auth.
//
// El entorno (`FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`) lo
// inyecta `firebase emulators:exec` en el proceso hijo; por eso estos tests
// SOLO corren a través de `npm run test:functions`, nunca con `node --test`
// suelto. `exigirEntornoEmulador()` lo comprueba y falla con un mensaje claro.
// ============================================================================

import { deleteApp as borrarAppAdmin, initializeApp as initAdmin } from 'firebase-admin/app';
import { getAuth as getAuthAdmin } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import { deleteApp as borrarAppCliente, initializeApp as initCliente } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth as getAuthCliente,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';

export const PROJECT_ID = 'demo-gri';

/** Debe coincidir con el `region` del `onCall`. Un desajuste da un 404 opaco. */
export const REGION = 'us-central1';

export const PUERTO_FUNCTIONS = 5001;
export const HOST_AUTH = 'http://127.0.0.1:9099';

/**
 * Los valores que el test espera encontrar CONFIGURADOS en la función.
 *
 * Ojo con la asimetría, que es la trampa nº1 de este montaje:
 *  · el EMULADOR DE FUNCTIONS los lee de `functions/.env.demo-gri` AL ARRANCAR,
 *    antes de que este proceso exista — escribir un `.env` desde un `before()`
 *    llega tarde;
 *  · este PROCESO DE TEST los recibe por `--set-env` del wrapper
 *    `scripts/run_emulators.mjs`.
 * Son dos caminos distintos hacia el mismo valor. Si divergen, la suite se
 * pondría verde o roja por el motivo equivocado, así que aquí se exige que
 * lleguen y se falla ruidosamente si no.
 */
export function configEsperada() {
  const email = process.env.BOOTSTRAP_EMAIL;
  const secreto = process.env.BOOTSTRAP_SECRET;
  if (!email || !secreto) {
    throw new Error(
      'Faltan BOOTSTRAP_EMAIL / BOOTSTRAP_SECRET en el entorno del test.\n' +
        'Estos tests SOLO corren vía `cd scripts && npm run test:functions`, que\n' +
        'los pasa con `--set-env`. Sin ellos la suite se pondría verde por\n' +
        'configuración ausente en vez de por comportamiento correcto.',
    );
  }
  return { email, secreto };
}

export function exigirEntornoEmulador() {
  const faltan = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST'].filter(
    (k) => !process.env[k],
  );
  if (faltan.length > 0) {
    throw new Error(
      `Faltan variables de emulador: ${faltan.join(', ')}.\n` +
        'Correr con `cd scripts && npm run test:functions` (levanta auth, ' +
        'functions y firestore y las inyecta).',
    );
  }
}

// --- Handles ----------------------------------------------------------------

let appAdmin;
let appCliente;
let fns;

export function montar() {
  exigirEntornoEmulador();

  appAdmin = initAdmin({ projectId: PROJECT_ID }, `admin-${Date.now()}`);

  appCliente = initCliente(
    {
      // El emulador de Auth no valida la apiKey; el SDK exige que exista.
      apiKey: 'fake-api-key-para-emulador',
      projectId: PROJECT_ID,
      authDomain: `${PROJECT_ID}.firebaseapp.com`,
    },
    `cliente-${Date.now()}`,
  );

  const authCliente = getAuthCliente(appCliente);
  connectAuthEmulator(authCliente, HOST_AUTH, { disableWarnings: true });

  fns = getFunctions(appCliente, REGION);
  connectFunctionsEmulator(fns, '127.0.0.1', PUERTO_FUNCTIONS);

  return { adminAuth: getAuthAdmin(appAdmin), db: getFirestore(appAdmin), authCliente, fns };
}

export async function desmontar() {
  if (appCliente) await borrarAppCliente(appCliente);
  if (appAdmin) await borrarAppAdmin(appAdmin);
  appCliente = undefined;
  appAdmin = undefined;
  fns = undefined;
}

// --- Helpers ----------------------------------------------------------------

/**
 * Crea un usuario en el emulador de Auth con el Admin SDK.
 *
 * `emailVerified` se fija AQUÍ, antes del login: el idToken se acuña en el
 * `signIn`, así que verificar después dejaría el token con
 * `email_verified: false` y el test mediría lo contrario de lo que cree.
 */
export async function crearUsuario({ email, password, emailVerified = true }) {
  const user = await getAuthAdmin(appAdmin).createUser({
    email,
    password,
    emailVerified,
  });
  return user.uid;
}

/** Inicia sesión con el SDK cliente. El idToken resultante es REAL. */
export async function login(email, password) {
  const auth = getAuthCliente(appCliente);
  const cred = await signInWithEmailAndPassword(auth, email, password);
  return cred.user;
}

export async function logout() {
  await signOut(getAuthCliente(appCliente));
}

/** Invoca `bootstrapPlataforma` como el panel: misma región, mismo payload. */
export function llamarBootstrap(data) {
  return httpsCallable(fns, 'bootstrapPlataforma')(data);
}

/** Invoca `crearUsuarioStaff` como el panel (plan 11-08). */
export function llamarCrearStaff(data) {
  return httpsCallable(fns, 'crearUsuarioStaff')(data);
}

/**
 * Siembra un usuario CON claims y devuelve su uid (plan 11-08).
 *
 * EL ORDEN ES LO ÚNICO QUE IMPORTA AQUÍ: los claims se fijan ANTES de que el
 * test haga `login()`. El idToken se acuña en el `signIn`, así que asignar
 * claims después dejaría un token SIN ellos y la función vería un llamador
 * anónimo de rol. Un e2e escrito al revés y sin `getIdToken(true)` es un falso
 * negativo garantizado: todos los casos "denegado" pasarían por el motivo
 * equivocado.
 */
export async function crearUsuarioConClaims({ email, password, claims }) {
  const uid = await crearUsuario({ email, password });
  await getAuthAdmin(appAdmin).setCustomUserClaims(uid, claims);
  return uid;
}

/**
 * Siembra un restaurante mínimo (plan 11-08). `crearUsuarioStaff` exige que el
 * restaurante destino EXISTA para no crear staff huérfano.
 */
export async function crearRestaurante(rid, extra = {}) {
  await getFirestore(appAdmin)
    .doc(`restaurantes/${rid}`)
    .set({ nombre: `Restaurante ${rid}`, activo: true, ...extra });
}

/**
 * Deja el emulador como recién arrancado: sin usuarios de Auth, sin centinela
 * y sin documentos en `usuarios`.
 *
 * Se ejecuta ANTES de cada caso, no después: si un caso muere a medias, el
 * siguiente no debe heredar su basura (y un centinela heredado convertiría
 * cualquier caso feliz en un `reparado` silencioso).
 */
export async function limpiar() {
  const db = getFirestore(appAdmin);
  const adminAuth = getAuthAdmin(appAdmin);

  const { users } = await adminAuth.listUsers(1000);
  if (users.length > 0) {
    await adminAuth.deleteUsers(users.map((u) => u.uid));
  }

  // `restaurantes` se añadió en 11-08: `crearUsuarioStaff` exige que el
  // restaurante destino exista, así que cada caso siembra el suyo y no puede
  // heredar el del anterior (heredarlo convertiría el caso `not-found` en un
  // verde por el motivo equivocado).
  for (const col of ['usuarios', 'plataforma', 'restaurantes']) {
    const snap = await db.collection(col).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

/** Código de error de una `FirebaseError` del SDK cliente: `functions/xxx`. */
export function codigoDe(err) {
  return err?.code ?? String(err);
}
