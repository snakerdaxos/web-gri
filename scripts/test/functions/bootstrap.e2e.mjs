// ============================================================================
// GRI — e2e de `bootstrapPlataforma` contra emuladores REALES (Fase 11, 11-07)
//
// Corre con: cd scripts && npm run test:functions
// (levanta auth + functions + firestore con --project demo-gri y pasa
//  BOOTSTRAP_EMAIL / BOOTSTRAP_SECRET al proceso de test vía --set-env).
//
// ---------------------------------------------------------------------------
// POR QUÉ LA CARRERA SE PRUEBA CON UN SOLO USUARIO Y NO CON CINCO
// ---------------------------------------------------------------------------
// Firebase Auth normaliza el correo y lo trata como único sin distinguir
// mayúsculas: "cinco usuarios con el mismo correo en distintas mayúsculas" es
// INEJECUTABLE (`auth/email-already-exists`). Y con el filtro por
// `BOOTSTRAP_EMAIL`, cinco correos distintos jamás llegarían a la guarda —
// cuatro morirían en los controles de autorización, mucho antes del `create()`.
// La única carrera realmente ALCANZABLE, y la que ocurre en la vida real
// (doble clic, reintento, pestaña duplicada), es N llamadas paralelas del
// MISMO usuario autorizado. El caso "otro uid ganó la carrera" se prueba de
// forma determinista sembrando el centinela ajeno con el Admin SDK.
//
// ---------------------------------------------------------------------------
// QUÉ HACE QUE ESTOS TESTS TENGAN DIENTES
// ---------------------------------------------------------------------------
// La rama `ALREADY_EXISTS` de `DocumentReference.create()` solo es alcanzable
// porque la guarda atómica va ANTES de la consulta secundaria. Los casos
// `CARRERA`, `SEGUNDA LLAMADA` y `CENTINELA AJENO` entran por esa rama: si se
// sustituye `create()` por `set()`, la carrera devuelve 5 `creado: true` y
// estos casos caen. Verificado rompiendo a propósito (ver 11-07-SUMMARY).
// ============================================================================

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  codigoDe,
  configEsperada,
  crearUsuario,
  desmontar,
  limpiar,
  llamarBootstrap,
  login,
  logout,
  montar,
} from './_emu.mjs';

const PASSWORD = 'Demo!1234';
const OTRO_CORREO = 'impostor@demo.gri.dev';

let adminAuth;
let db;

/** Falla el test si la promesa NO rechaza con ese código de `functions/`. */
async function esperarCodigo(promesa, codigo, mensaje) {
  try {
    await promesa;
    assert.fail(`${mensaje}: se esperaba ${codigo} y la llamada tuvo ÉXITO`);
  } catch (err) {
    assert.equal(codigoDe(err), codigo, `${mensaje} · error real: ${err?.message}`);
    return err;
  }
}

describe('bootstrapPlataforma — e2e contra emuladores reales', () => {
  let CFG;

  before(() => {
    CFG = configEsperada(); // falla ruidosamente si no llegaron por --set-env
    const h = montar();
    adminAuth = h.adminAuth;
    db = h.db;
  });

  after(async () => {
    await desmontar();
  });

  beforeEach(async () => {
    await logout().catch(() => {});
    await limpiar();
  });

  // --- Sesión ---------------------------------------------------------------

  it('sin autenticar → unauthenticated', async () => {
    await esperarCodigo(
      llamarBootstrap({ nombre: 'Fundador', secreto: CFG.secreto }),
      'functions/unauthenticated',
      'una llamada anónima no puede pasar del primer control',
    );
  });

  // --- Payload --------------------------------------------------------------

  it('autorizado pero sin nombre → invalid-argument', async () => {
    await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    await esperarCodigo(
      llamarBootstrap({ secreto: CFG.secreto }),
      'functions/invalid-argument',
      'la forma del payload se valida antes que la autorización',
    );
  });

  // --- Factor 1: el secreto -------------------------------------------------

  it('FACTOR SECRETO — correo autorizado y verificado, secreto INCORRECTO → permission-denied', async () => {
    await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    const err = await esperarCodigo(
      llamarBootstrap({ nombre: 'Fundador', secreto: 'secreto-que-no-es' }),
      'functions/permission-denied',
      'conocer el correo del fundador NO basta',
    );
    assert.equal(err.message, 'No puedes inicializar esta plataforma.');

    const centinela = await db.doc('plataforma/bootstrap').get();
    assert.equal(centinela.exists, false, 'un rechazo no puede dejar centinela');
  });

  it('FACTOR SECRETO — un secreto de longitud distinta tampoco pasa (timingSafeEqual no revienta)', async () => {
    await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    // Si la comparación en tiempo constante no tratara la diferencia de
    // longitud, `crypto.timingSafeEqual` LANZARÍA y el cliente vería
    // `internal` en vez de `permission-denied`.
    await esperarCodigo(
      llamarBootstrap({ nombre: 'Fundador', secreto: 'x' }),
      'functions/permission-denied',
      'longitud distinta debe denegar, no reventar',
    );
  });

  // --- Factor 2: el correo verificado ---------------------------------------

  it('FACTOR EMAIL_VERIFIED — correo autorizado y secreto correcto pero SIN verificar → permission-denied', async () => {
    await crearUsuario({ email: CFG.email, password: PASSWORD, emailVerified: false });
    await login(CFG.email, PASSWORD);

    const err = await esperarCodigo(
      llamarBootstrap({ nombre: 'Fundador', secreto: CFG.secreto }),
      'functions/permission-denied',
      'sin control del buzón el filtro por correo tiene entropía nula',
    );
    assert.equal(
      err.message,
      'No puedes inicializar esta plataforma.',
      'el mensaje debe ser IDÉNTICO al del secreto incorrecto: no revelar cuál falló',
    );

    const centinela = await db.doc('plataforma/bootstrap').get();
    assert.equal(centinela.exists, false);
  });

  // --- Correo no autorizado -------------------------------------------------

  it('OTRO CORREO — verificado y con el secreto correcto → permission-denied', async () => {
    await crearUsuario({ email: OTRO_CORREO, password: PASSWORD });
    await login(OTRO_CORREO, PASSWORD);

    const err = await esperarCodigo(
      llamarBootstrap({ nombre: 'Impostor', secreto: CFG.secreto }),
      'functions/permission-denied',
      'filtrar el secreto no debe permitir promover a cualquiera',
    );
    assert.equal(err.message, 'No puedes inicializar esta plataforma.');

    const usuarios = await db.collection('usuarios').get();
    assert.equal(usuarios.size, 0, 'nadie fue promovido');
  });

  // --- Camino feliz ---------------------------------------------------------

  it('CAMINO FELIZ — autorizado + verificado + secreto → super_admin con claims y doc espejo', async () => {
    const uid = await crearUsuario({ email: CFG.email, password: PASSWORD });
    const user = await login(CFG.email, PASSWORD);

    const res = await llamarBootstrap({ nombre: 'Fundador GRI', secreto: CFG.secreto });
    assert.deepEqual(res.data, { uid, creado: true, reparado: false });

    // Claims en el token REFRESCADO (no en el que se acuñó antes de la llamada).
    const token = await user.getIdTokenResult(true);
    assert.equal(token.claims.role, 'super_admin');
    assert.equal(
      token.claims.rid,
      null,
      'el super_admin NO lleva rid — misma forma que seed_firebase.mjs:47',
    );

    // Doc espejo.
    const doc = await db.doc(`usuarios/${uid}`).get();
    assert.equal(doc.exists, true);
    assert.equal(doc.data().role, 'super_admin');
    assert.equal(doc.data().restauranteId, null);
    assert.equal(doc.data().nombre, 'Fundador GRI');
    assert.equal(doc.data().email, CFG.email.toLowerCase());

    // Rastro auditable (T-11-07-05).
    const centinela = await db.doc('plataforma/bootstrap').get();
    assert.equal(centinela.exists, true);
    assert.equal(centinela.data().uid, uid);
    assert.ok(centinela.data().createdAt, 'createdAt de servidor');

    // Exactamente UN super_admin en toda la base.
    const supers = await db.collection('usuarios').where('role', '==', 'super_admin').get();
    assert.equal(supers.size, 1);
  });

  // --- Unicidad: segunda llamada -------------------------------------------

  it('SEGUNDA LLAMADA del mismo usuario → reparado, sin segundo centinela', async () => {
    const uid = await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    const primera = await llamarBootstrap({ nombre: 'Fundador', secreto: CFG.secreto });
    assert.equal(primera.data.creado, true);
    const createdAt1 = (await db.doc('plataforma/bootstrap').get()).data().createdAt;

    const segunda = await llamarBootstrap({ nombre: 'Fundador', secreto: CFG.secreto });
    assert.deepEqual(segunda.data, { uid, creado: false, reparado: true });

    const plataforma = await db.collection('plataforma').get();
    assert.equal(plataforma.size, 1, 'un solo documento en plataforma/');
    assert.equal(
      plataforma.docs[0].data().createdAt.toMillis(),
      createdAt1.toMillis(),
      'el centinela NO se reescribe: conserva el createdAt de la primera',
    );
  });

  // --- Unicidad: carrera real ----------------------------------------------

  it('CARRERA REAL — 5 llamadas en paralelo → exactamente 1 creado, 4 reparados, 1 centinela', async () => {
    const uid = await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    // Las cinco se lanzan SIN `await` intermedio: si hubiera uno, no habría
    // carrera y este caso pasaría por construcción.
    const enVuelo = [];
    for (let i = 0; i < 5; i++) {
      enVuelo.push(llamarBootstrap({ nombre: `Fundador ${i}`, secreto: CFG.secreto }));
    }
    const resultados = await Promise.allSettled(enVuelo);

    const rechazadas = resultados.filter((r) => r.status === 'rejected');
    assert.equal(
      rechazadas.length,
      0,
      `ninguna debe fallar (el camino de reparación converge): ${rechazadas
        .map((r) => r.reason?.code ?? r.reason)
        .join(', ')}`,
    );

    const datos = resultados.map((r) => r.value.data);
    assert.equal(datos.filter((d) => d.creado === true).length, 1, 'un solo ganador');
    assert.equal(datos.filter((d) => d.reparado === true).length, 4, 'cuatro reparados');
    assert.ok(datos.every((d) => d.uid === uid));

    // Un único centinela y un único createdAt: el de la primera.
    const plataforma = await db.collection('plataforma').get();
    assert.equal(plataforma.size, 1, 'la carrera no puede dejar dos centinelas');
    assert.equal(plataforma.docs[0].id, 'bootstrap');

    // Y exactamente un super_admin.
    const supers = await db.collection('usuarios').where('role', '==', 'super_admin').get();
    assert.equal(supers.size, 1);
    assert.equal(supers.docs[0].id, uid);
  });

  // --- Centinela ajeno ------------------------------------------------------

  it('CENTINELA AJENO — otro uid ya inicializó → permission-denied y el centinela NO se toca', async () => {
    await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    const ajeno = {
      uid: 'uid-de-otra-persona',
      email: 'otra@demo.gri.dev',
      nombre: 'Quien llegó primero',
      createdAt: new Date('2020-01-01T00:00:00Z'),
      userAgent: null,
      ip: null,
    };
    await db.doc('plataforma/bootstrap').set(ajeno);

    const err = await esperarCodigo(
      llamarBootstrap({ nombre: 'Fundador', secreto: CFG.secreto }),
      'functions/permission-denied',
      'la puerta ya está cerrada por otra persona',
    );
    assert.equal(err.message, 'No puedes inicializar esta plataforma.');

    const centinela = await db.doc('plataforma/bootstrap').get();
    assert.equal(centinela.data().uid, ajeno.uid, 'el centinela ajeno NO se modifica');
    assert.equal(centinela.data().nombre, ajeno.nombre);

    const usuarios = await db.collection('usuarios').get();
    assert.equal(usuarios.size, 0, 'nadie fue promovido');
  });

  // --- Proyecto sembrado con el seed (comprobación secundaria) --------------

  it('PROYECTO SEMBRADO — ya hay un super_admin pero no centinela → permission-denied y el centinela recién creado se borra', async () => {
    // Este es el ÚNICO caso que ejercita el paso 6. Cubre un proyecto que se
    // arrancó con `scripts/seed_firebase.mjs`: tiene super_admin y no centinela.
    await db.doc('usuarios/super-del-seed').set({
      nombre: 'Super del seed',
      email: 'super@demo.gri.dev',
      role: 'super_admin',
      restauranteId: null,
    });

    await crearUsuario({ email: CFG.email, password: PASSWORD });
    await login(CFG.email, PASSWORD);

    await esperarCodigo(
      llamarBootstrap({ nombre: 'Fundador', secreto: CFG.secreto }),
      'functions/permission-denied',
      'la plataforma ya estaba inicializada por el seed',
    );

    const plataforma = await db.collection('plataforma').get();
    assert.equal(
      plataforma.size,
      0,
      'el centinela creado por esta invocación debe borrarse: si quedara, ' +
        'bloquearía la plataforma con un documento huérfano que ningún ' +
        'cliente puede eliminar (las rules lo prohíben)',
    );

    // Y el llamador NO quedó promovido.
    const supers = await db.collection('usuarios').where('role', '==', 'super_admin').get();
    assert.equal(supers.size, 1);
    assert.equal(supers.docs[0].id, 'super-del-seed');
  });
});
