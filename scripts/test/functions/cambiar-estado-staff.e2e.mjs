// ============================================================================
// GRI — e2e de `cambiarEstadoStaff` contra emuladores REALES (Fase 11, 11-24)
//
// Corre con: cd scripts && npm run test:functions
// (levanta auth + functions + firestore con --project demo-gri).
//
// ---------------------------------------------------------------------------
// QUÉ AÑADE ESTO A `functions/test/baja-matrix.test.js`
// ---------------------------------------------------------------------------
// La combinatoria de la matriz ya está probada de forma exhaustiva y pura allí
// (19 filas x 2 sentidos + ~400 casos de propiedad, en 234 ms). Este archivo
// prueba OTRA cosa, y es la que de verdad protege al producto:
//   (a) que esa decisión es la que gobierna la función real, alimentada con
//       CLAIMS REALES de un idToken emitido por Firebase Auth;
//   (b) que la baja SIRVE PARA ALGO: la persona desactivada YA NO PUEDE ENTRAR.
//       Que el espejo diga `activo: false` es una etiqueta; lo que importa es
//       el `signInWithEmailAndPassword` que falla.
//   (c) que es REVERSIBLE DE VERDAD: reactivar devuelve exactamente el rol que
//       tenía, leyéndolo del espejo — el único sitio donde sobrevivió.
//   (d) que NO se pierde historial: los pedidos del mesero siguen ahí.
//
// ---------------------------------------------------------------------------
// EL ORDEN QUE HACE QUE ESTOS TESTS NO SEAN UN FALSO NEGATIVO (11-08)
// ---------------------------------------------------------------------------
// `crearUsuarioConClaims()` fija los claims ANTES del `login()`. El idToken se
// acuña en el `signIn`: asignarlos después dejaría un token sin `role`, la
// función vería un llamador sin rol y TODOS los casos "denegado" seguirían en
// verde por el motivo equivocado. La señal de que el montaje está bien es que
// los casos FELICES pasan.
//
// ---------------------------------------------------------------------------
// POR QUÉ CADA DENEGACIÓN ASSERTA EL MENSAJE LITERAL
// ---------------------------------------------------------------------------
// Los cinco controles de la matriz devuelven `permission-denied`. 11-08 midió
// que un caso que solo comprueba el código puede estar verde denegado por otro
// control (su ESCALADA HORIZONTAL sobrevivía con el arnés roto). Aquí eso es
// aún más fácil de que pase, porque las dos prohibiciones nuevas se solapan.
// ============================================================================

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  codigoDe,
  crearPedido,
  crearRestaurante,
  crearUsuario,
  crearUsuarioConClaims,
  desmontar,
  intentarLogin,
  limpiar,
  llamarCambiarEstado,
  login,
  logout,
  montar,
} from './_emu.mjs';

const PASSWORD = 'Demo!1234';

const SUPER = 'super@demo.gri.dev';
const SUPER_2 = 'super2@demo.gri.dev';
const ADMIN_DEMO = 'admin.demo@demo.gri.dev';
const ADMIN_OTRO = 'admin.otro@demo.gri.dev';
const MESERO_DEMO = 'mesero.demo@demo.gri.dev';
const MESERO_OTRO = 'mesero.otro@demo.gri.dev';

// Mensajes de `functions/src/baja-matrix.js`, ESCRITOS A MANO (ver cabecera).
const MSG_LLAMADOR = 'Solo super_admin o admin_restaurante pueden cambiar el estado del personal.';
const MSG_SUPER = 'No se puede cambiar el estado de una cuenta de plataforma.';
const MSG_SELF = 'No puedes cambiar el estado de tu propia cuenta.';
const MSG_TENANT = 'No puedes cambiar el estado de personal de otro restaurante.';

let adminAuth;
let db;

/** Falla el test si la promesa NO rechaza con ese código de `functions/`. */
async function esperarCodigo(promesa, codigo, mensaje) {
  try {
    const res = await promesa;
    assert.fail(
      `${mensaje}: se esperaba ${codigo} y la llamada tuvo ÉXITO → ${JSON.stringify(res?.data)}`,
    );
  } catch (err) {
    assert.equal(codigoDe(err), codigo, `${mensaje} · error real: ${err?.message}`);
    return err;
  }
}

/** Claims de un usuario, normalizados a objeto ({} si no tiene ninguno). */
async function claimsDe(uid) {
  const u = await adminAuth.getUser(uid);
  return u.customClaims ?? {};
}

async function espejoDe(uid) {
  const snap = await db.doc(`usuarios/${uid}`).get();
  return snap.exists ? snap.data() : null;
}

/** Siembra staff completo: cuenta con claims + doc espejo, como el alta real. */
async function sembrarStaff({ email, rol, rid, nombre = 'Persona' }) {
  const uid = await crearUsuarioConClaims({
    email,
    password: PASSWORD,
    claims: { role: rol, rid },
  });
  await db.doc(`usuarios/${uid}`).set({
    nombre,
    email,
    role: rol,
    restauranteId: rid,
    activo: true,
  });
  return uid;
}

describe('cambiarEstadoStaff — e2e contra emuladores reales', () => {
  before(() => {
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
    // Los DOS restaurantes existen siempre: así, cuando un intento cruzado se
    // deniega, se deniega por AUTORIZACIÓN y no porque falte el restaurante.
    await crearRestaurante('demo');
    await crearRestaurante('otro');
  });

  // ==========================================================================
  // Sesión y forma del payload
  // ==========================================================================

  it('sin autenticar → unauthenticated', async () => {
    const uid = await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });

    await esperarCodigo(
      llamarCambiarEstado({ uid, activo: false }),
      'functions/unauthenticated',
      'una llamada anónima no puede dar de baja a nadie',
    );

    const u = await adminAuth.getUser(uid);
    assert.equal(u.disabled, false, 'la víctima sigue habilitada');
    assert.deepEqual(await claimsDe(uid), { role: 'mesero', rid: 'demo' }, 'claims intactos');
  });

  it('uid ausente → invalid-argument', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    await login(ADMIN_DEMO, PASSWORD);

    await esperarCodigo(
      llamarCambiarEstado({ activo: false }),
      'functions/invalid-argument',
      'sin uid no hay a quién dar de baja',
    );
  });

  it('activo no booleano ("false" como cadena) → invalid-argument, NO reactivación', async () => {
    // Con `!!activo`, la cadena "false" —lo que produce un formulario web mal
    // serializado— es TRUTHY y REACTIVARÍA a quien se quiso desactivar. El
    // fallo tiene que ser ruidoso.
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const uid = await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });
    await login(ADMIN_DEMO, PASSWORD);

    await esperarCodigo(
      llamarCambiarEstado({ uid, activo: 'false' }),
      'functions/invalid-argument',
      'el estado tiene que ser booleano estricto',
    );

    const u = await adminAuth.getUser(uid);
    assert.equal(u.disabled, false, 'no se tocó la cuenta');
  });

  it('uid inexistente → not-found', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    await login(ADMIN_DEMO, PASSWORD);

    await esperarCodigo(
      llamarCambiarEstado({ uid: 'uid-que-no-existe', activo: false }),
      'functions/not-found',
      'un uid inventado no existe en Auth',
    );
  });

  // ==========================================================================
  // CAMINO FELIZ · la baja de verdad, con todo lo que implica
  // ==========================================================================

  it('CAMINO FELIZ — admin de demo desactiva a un mesero de demo: no entra, pero su historial queda', async () => {
    const admin = await sembrarStaff({
      email: ADMIN_DEMO,
      rol: 'admin_restaurante',
      rid: 'demo',
      nombre: 'Ana Admin',
    });
    const uid = await sembrarStaff({
      email: MESERO_DEMO,
      rol: 'mesero',
      rid: 'demo',
      nombre: 'Zoe Mesera',
    });
    // Historial: un pedido suyo. Es la razón por la que la decisión bloqueada
    // del usuario es desactivar y NO borrar.
    await crearPedido('ped-1', { rid: 'demo', meseroUid: uid, total: 42000 });

    // ANTES: la cuenta funciona. Sin esta comprobación, el "ya no puede entrar"
    // de abajo podría estar verde porque nunca pudo entrar.
    assert.equal(await intentarLogin(MESERO_DEMO, PASSWORD), null, 'antes de la baja SÍ entraba');
    await logout();

    await login(ADMIN_DEMO, PASSWORD);
    const res = await llamarCambiarEstado({ uid, activo: false });

    assert.equal(res.data.uid, uid);
    assert.equal(res.data.activo, false);
    assert.equal(res.data.rol, 'mesero');
    assert.equal(res.data.restauranteId, 'demo');

    // 1. Cuenta deshabilitada.
    const u = await adminAuth.getUser(uid);
    assert.equal(u.disabled, true, 'la cuenta queda deshabilitada en Auth');

    // 2. Sin claims: aunque conservara un token vivo, las rules dejan de verlo
    //    como staff (sin `role` se evalúa como cliente).
    assert.deepEqual(await claimsDe(uid), {}, 'los custom claims se retiran');

    // 3. Espejo marcado PERO conservando rol y restaurante: es lo que permite
    //    reactivar y lo que usan los reportes históricos.
    const espejo = await espejoDe(uid);
    assert.equal(espejo.activo, false);
    assert.equal(espejo.role, 'mesero', 'el rol SOBREVIVE a la baja');
    assert.equal(espejo.restauranteId, 'demo', 'el restaurante SOBREVIVE a la baja');
    assert.equal(espejo.nombre, 'Zoe Mesera', 'el merge no se lleva por delante el perfil');
    assert.equal(espejo.desactivadoPor, admin, 'trazabilidad: quién revocó el acceso');
    assert.ok(espejo.desactivadoAt, 'trazabilidad: cuándo');

    // 4. LO QUE DE VERDAD IMPORTA: ya no puede entrar.
    await logout();
    const codigo = await intentarLogin(MESERO_DEMO, PASSWORD);
    assert.ok(codigo, 'la persona desactivada NO puede iniciar sesión');
    assert.match(String(codigo), /disabled|user-disabled/, `código real: ${codigo}`);

    // 5. Su historial sigue intacto: nada se borró.
    const ped = await db.doc('pedidos/ped-1').get();
    assert.equal(ped.exists, true, 'el pedido del mesero sigue en Firestore');
    assert.equal(ped.data().meseroUid, uid, 'y sigue atribuido a él: nada quedó huérfano');
    assert.equal(ped.data().total, 42000);
  });

  it('la REVOCACIÓN de refresh tokens ocurre de verdad (T-11-24-04)', async () => {
    // MEDIDO: sin este caso, quitar `revokeRefreshTokens` del código NO ponía
    // rojo NADA (rotura T: 0 caídas). Y no es que el e2e estuviera mal escrito:
    // mientras `disabled: true` siga puesto, revocar o no revocar es
    // indistinguible por comportamiento —el emulador rechaza igual el login y
    // el refresh—. Los dos controles se solapan a propósito (defensa en
    // profundidad), pero eso dejaba el tercer paso de la baja AFIRMADO y no
    // verificado. Aquí se observa su efecto directo: `tokensValidAfterTime`,
    // la marca que invalida los refresh tokens ya emitidos.
    //
    // La espera de 1,1 s no es decorativa: esa marca tiene precisión de SEGUNDO
    // y sin ella la del alta y la de la revocación caerían en el mismo segundo,
    // dejando la comparación estricta sin dientes (verde por construcción).
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const uid = await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });
    const antes = new Date((await adminAuth.getUser(uid)).tokensValidAfterTime).getTime();

    await new Promise((r) => setTimeout(r, 1100));

    await login(ADMIN_DEMO, PASSWORD);
    await llamarCambiarEstado({ uid, activo: false });

    const despues = new Date((await adminAuth.getUser(uid)).tokensValidAfterTime).getTime();
    assert.ok(
      despues > antes,
      `los refresh tokens no se revocaron: tokensValidAfterTime sigue en ${new Date(antes).toISOString()}`,
    );
  });

  it('REVERSIBLE — reactivar restaura EXACTAMENTE el rol, leído del espejo', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const uid = await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });
    await login(ADMIN_DEMO, PASSWORD);

    await llamarCambiarEstado({ uid, activo: false });
    // Estado intermedio REAL: sin claims. La reactivación no tiene de dónde
    // sacar el rol salvo del espejo — que es justo lo que se está probando.
    assert.deepEqual(await claimsDe(uid), {});

    const res = await llamarCambiarEstado({ uid, activo: true });
    assert.equal(res.data.activo, true);
    assert.equal(res.data.rol, 'mesero');
    assert.equal(res.data.restauranteId, 'demo');

    const u = await adminAuth.getUser(uid);
    assert.equal(u.disabled, false, 'vuelve a estar habilitada');
    assert.deepEqual(
      await claimsDe(uid),
      { role: 'mesero', rid: 'demo' },
      'los claims vuelven a ser los de antes, ni más ni menos',
    );

    const espejo = await espejoDe(uid);
    assert.equal(espejo.activo, true);
    assert.ok(espejo.reactivadoAt);
    assert.ok(espejo.desactivadoAt, 'la baja anterior sigue registrada: es historial');

    // Y vuelve a poder entrar, que es la prueba de que la readmisión es real.
    await logout();
    assert.equal(await intentarLogin(MESERO_DEMO, PASSWORD), null, 'la persona readmitida entra');
  });

  it('IDEMPOTENCIA — desactivar dos veces seguidas converge, sin error', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const uid = await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });
    await login(ADMIN_DEMO, PASSWORD);

    await llamarCambiarEstado({ uid, activo: false });
    // La SEGUNDA llamada es el caso interesante: el objetivo ya no tiene
    // claims, así que su rol solo se puede derivar del espejo. Si el fallback
    // no existiera, esta llamada moriría con permission-denied.
    const res = await llamarCambiarEstado({ uid, activo: false });

    assert.equal(res.data.activo, false);
    assert.equal(res.data.rol, 'mesero', 'el rol se sigue conociendo tras la primera baja');

    const espejo = await espejoDe(uid);
    assert.equal(espejo.activo, false);
    assert.equal(espejo.role, 'mesero');
    assert.equal((await adminAuth.getUser(uid)).disabled, true);
  });

  it('el super_admin alcanza cualquier tenant', async () => {
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    const uid = await sembrarStaff({ email: MESERO_OTRO, rol: 'mesero', rid: 'otro' });
    await login(SUPER, PASSWORD);

    const res = await llamarCambiarEstado({ uid, activo: false });
    assert.equal(res.data.restauranteId, 'otro');
    assert.equal((await adminAuth.getUser(uid)).disabled, true);
  });

  it('DECISIÓN DEL USUARIO — un admin de demo SÍ puede dar de baja al otro admin de demo', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const socio = await sembrarStaff({
      email: 'socio@demo.gri.dev',
      rol: 'admin_restaurante',
      rid: 'demo',
    });
    await login(ADMIN_DEMO, PASSWORD);

    const res = await llamarCambiarEstado({ uid: socio, activo: false });
    assert.equal(res.data.rol, 'admin_restaurante');
    assert.equal((await adminAuth.getUser(socio)).disabled, true);
  });

  // ==========================================================================
  // PROHIBICIÓN 1 · nadie puede tocar a un super_admin
  // ==========================================================================

  it('PROHIBICIÓN 1 — un admin_restaurante sobre un super_admin → permission-denied', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const superUid = await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: superUid, activo: false }),
      'functions/permission-denied',
      'un admin no puede apagar la plataforma',
    );
    assert.equal(err.message, MSG_SUPER, 'denegado por la PROHIBICIÓN 1, no por otro control');

    const u = await adminAuth.getUser(superUid);
    assert.equal(u.disabled, false, 'el super sigue habilitado');
    assert.deepEqual(await claimsDe(superUid), { role: 'super_admin', rid: null });
  });

  it('PROHIBICIÓN 1 — ni siquiera OTRO super_admin puede hacerlo', async () => {
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    const victima = await crearUsuarioConClaims({
      email: SUPER_2,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await login(SUPER, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: victima, activo: false }),
      'functions/permission-denied',
      'la prohibición es ABSOLUTA, no relativa al llamador',
    );
    assert.equal(err.message, MSG_SUPER);
    assert.equal((await adminAuth.getUser(victima)).disabled, false);
  });

  it('PROHIBICIÓN 1 — tampoco REACTIVANDO a un super_admin desactivado a mano', async () => {
    // El sentido de la operación no cambia la autorización: si valiera solo
    // para `activo: false`, quedaría abierta la vía de resucitar privilegios.
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const superUid = await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await adminAuth.updateUser(superUid, { disabled: true });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: superUid, activo: true }),
      'functions/permission-denied',
      'reactivar a un super_admin tampoco está permitido',
    );
    assert.equal(err.message, MSG_SUPER);
    assert.equal((await adminAuth.getUser(superUid)).disabled, true, 'sigue deshabilitado');
  });

  // ==========================================================================
  // PROHIBICIÓN 2 · nadie puede desactivarse a sí mismo
  // ==========================================================================

  it('PROHIBICIÓN 2 — un admin_restaurante sobre su PROPIO uid → permission-denied', async () => {
    // El escenario real: el único admin del restaurante se deja fuera y solo se
    // recupera a mano con la clave de servicio.
    const yo = await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: yo, activo: false }),
      'functions/permission-denied',
      'nadie se deja fuera a sí mismo',
    );
    assert.equal(err.message, MSG_SELF, 'denegado por la PROHIBICIÓN 2, no por otro control');

    const u = await adminAuth.getUser(yo);
    assert.equal(u.disabled, false, 'sigue pudiendo administrar su restaurante');
    assert.deepEqual(await claimsDe(yo), { role: 'admin_restaurante', rid: 'demo' });
  });

  it('PROHIBICIÓN 2 — un super_admin sobre su propio uid también se deniega (pero por la 1, por el ORDEN)', async () => {
    // MEDIDO, no supuesto. La primera versión de este caso sembraba un super
    // con doc espejo `role: 'mesero'` para AISLAR la prohibición 2 a nivel e2e,
    // y salió rojo: la callable deriva el rol del objetivo de sus CLAIMS y solo
    // cae al espejo si no hay ninguno (que es el camino de la reactivación).
    // Con claims presentes, el objetivo es `super_admin` y lo caza la
    // prohibición 1. O sea: con un llamador VÁLIDO —que por definición es
    // super_admin o admin_restaurante— el único aislamiento posible en e2e es
    // el `admin_restaurante` sobre sí mismo, que es el caso de arriba y el que
    // se pone rojo al quitar el control (rotura N del SUMMARY). El aislamiento
    // exhaustivo vive en la matriz pura, donde el rol del objetivo es un
    // parámetro libre.
    const yo = await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await login(SUPER, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: yo, activo: false }),
      'functions/permission-denied',
      'el super tampoco se deja fuera a sí mismo',
    );
    assert.equal(err.message, MSG_SUPER, 'gana la prohibición 1: va antes en el orden');
    assert.equal((await adminAuth.getUser(yo)).disabled, false);
  });

  // ==========================================================================
  // PROHIBICIÓN 3 · alcance de tenant (la misma del alta)
  // ==========================================================================

  it('CRUCE DE TENANT — admin de demo sobre un mesero de otro → permission-denied', async () => {
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const victima = await sembrarStaff({ email: MESERO_OTRO, rol: 'mesero', rid: 'otro' });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: victima, activo: false }),
      'functions/permission-denied',
      'un admin no toca personal de otro restaurante',
    );
    assert.equal(err.message, MSG_TENANT, 'denegado por el alcance de tenant');

    const u = await adminAuth.getUser(victima);
    assert.equal(u.disabled, false, 'la víctima no se movió');
    assert.deepEqual(await claimsDe(victima), { role: 'mesero', rid: 'otro' });
    assert.equal((await espejoDe(victima)).activo, true);
  });

  it('CRUCE DE TENANT — el admin de otro tampoco alcanza a un mesero YA desactivado de demo', async () => {
    // Sin claims, la única fuente del rid del objetivo es el espejo. Si el
    // fallback leyera mal, este cruce quedaría abierto justo contra las
    // personas más vulnerables: las que ya están de baja.
    const adminDemo = await sembrarStaff({
      email: ADMIN_DEMO,
      rol: 'admin_restaurante',
      rid: 'demo',
    });
    await sembrarStaff({ email: ADMIN_OTRO, rol: 'admin_restaurante', rid: 'otro' });
    const victima = await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });

    await login(ADMIN_DEMO, PASSWORD);
    await llamarCambiarEstado({ uid: victima, activo: false });
    assert.deepEqual(await claimsDe(victima), {}, 'quedó sin claims');
    await logout();

    await login(ADMIN_OTRO, PASSWORD);
    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: victima, activo: true }),
      'functions/permission-denied',
      'el admin de otro no puede readmitir a alguien de demo',
    );
    assert.equal(err.message, MSG_TENANT);
    assert.equal((await adminAuth.getUser(victima)).disabled, true, 'sigue de baja');
    assert.notEqual(adminDemo, victima);
  });

  // ==========================================================================
  // Llamadores no autorizados
  // ==========================================================================

  it('un mesero llamando la callable → permission-denied', async () => {
    await sembrarStaff({ email: MESERO_DEMO, rol: 'mesero', rid: 'demo' });
    const victima = await sembrarStaff({
      email: 'cocina@demo.gri.dev',
      rol: 'cocina',
      rid: 'demo',
    });
    await login(MESERO_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid: victima, activo: false }),
      'functions/permission-denied',
      'gestionar personal no es tarea de un mesero',
    );
    assert.equal(err.message, MSG_LLAMADOR);
    assert.equal((await adminAuth.getUser(victima)).disabled, false);
  });

  it('FUERA DE ALCANCE — nadie desactiva a un CLIENTE de la app móvil por esta vía', async () => {
    // Un cliente auto-registrado no lleva claim `role` (11-04) y su espejo dice
    // `role: 'cliente'`, `restauranteId: null`. Para un admin lo corta el
    // alcance de tenant; para el super_admin, que no tiene rid con el que
    // comparar, solo lo corta la allow-list de objetivos.
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    const cliente = await crearUsuario({ email: 'comensal@demo.gri.dev', password: PASSWORD });
    await db.doc(`usuarios/${cliente}`).set({
      nombre: 'Comensal',
      email: 'comensal@demo.gri.dev',
      role: 'cliente',
      restauranteId: null,
    });
    await login(SUPER, PASSWORD);

    await esperarCodigo(
      llamarCambiarEstado({ uid: cliente, activo: false }),
      'functions/permission-denied',
      'esto es gestión de PERSONAL',
    );
    assert.equal((await adminAuth.getUser(cliente)).disabled, false);
  });

  it('sin rol en ninguna fuente → permission-denied (no se sabe quién es)', async () => {
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    // Cuenta en Auth sin claims y sin doc espejo.
    const huerfano = await crearUsuario({ email: 'huerfano@demo.gri.dev', password: PASSWORD });
    await login(SUPER, PASSWORD);

    await esperarCodigo(
      llamarCambiarEstado({ uid: huerfano, activo: false }),
      'functions/permission-denied',
      'sin rol conocido no se puede autorizar nada',
    );
    assert.equal((await adminAuth.getUser(huerfano)).disabled, false);
  });

  it('reactivar a alguien cuya ficha perdió el rol → failed-precondition ACCIONABLE', async () => {
    // Reachable de verdad: el objetivo CONSERVA sus claims (así se autoriza la
    // operación) pero su doc espejo no tiene `role`. Es el estado que deja un
    // alta que murió entre Auth y Firestore.
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const uid = await crearUsuarioConClaims({
      email: MESERO_DEMO,
      password: PASSWORD,
      claims: { role: 'mesero', rid: 'demo' },
    });
    await db.doc(`usuarios/${uid}`).set({ nombre: 'Ficha rota', email: MESERO_DEMO });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCambiarEstado({ uid, activo: true }),
      'functions/failed-precondition',
      'sin rol en la ficha no hay nada que restaurar',
    );
    assert.match(err.message, /Vuelve a darlo de alta con el mismo correo/, 'mensaje accionable');
  });

  it('REPARACIÓN — dar de baja con la ficha incompleta CONSERVA el rol de los claims', async () => {
    // Si la baja se limitara a marcar `activo: false`, aquí se perdería el
    // último rastro del rol (los claims se borran en el paso 2) y la persona
    // no podría volver nunca. La rama de reparación lo escribe desde los
    // claims ANTES de borrarlos.
    await sembrarStaff({ email: ADMIN_DEMO, rol: 'admin_restaurante', rid: 'demo' });
    const uid = await crearUsuarioConClaims({
      email: MESERO_DEMO,
      password: PASSWORD,
      claims: { role: 'mesero', rid: 'demo' },
    });
    await db.doc(`usuarios/${uid}`).set({ nombre: 'Ficha rota', email: MESERO_DEMO });
    await login(ADMIN_DEMO, PASSWORD);

    await llamarCambiarEstado({ uid, activo: false });

    const espejo = await espejoDe(uid);
    assert.equal(espejo.role, 'mesero', 'el rol se rescató de los claims antes de borrarlos');
    assert.equal(espejo.restauranteId, 'demo');

    // Y por tanto la baja SIGUE SIENDO REVERSIBLE, que es el punto.
    const res = await llamarCambiarEstado({ uid, activo: true });
    assert.equal(res.data.rol, 'mesero');
    assert.deepEqual(await claimsDe(uid), { role: 'mesero', rid: 'demo' });
  });
});
