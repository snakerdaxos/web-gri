// ============================================================================
// GRI — e2e de `crearUsuarioStaff` contra emuladores REALES (Fase 11, 11-08)
//
// Corre con: cd scripts && npm run test:functions
// (levanta auth + functions + firestore con --project demo-gri).
//
// ---------------------------------------------------------------------------
// QUÉ AÑADE ESTO A `functions/test/auth-matrix.test.js`
// ---------------------------------------------------------------------------
// La combinatoria de la matriz ya está probada de forma exhaustiva y pura allí.
// Este archivo prueba OTRA cosa, y es la que de verdad protege al producto:
// que esa decisión es la que gobierna la función DESPLEGADA, alimentada por
// CLAIMS REALES de un idToken emitido por Firebase Auth. Un test que fabrica el
// `context.auth` (modo offline de `firebase-functions-test`) probaría el mock:
// PROHIBIDO aquí, igual que en el e2e de 11-07.
//
// ---------------------------------------------------------------------------
// EL ORDEN QUE HACE QUE ESTOS TESTS NO SEAN UN FALSO NEGATIVO
// ---------------------------------------------------------------------------
// `crearUsuarioConClaims()` fija los claims ANTES del `login()`. El idToken se
// acuña en el `signIn`: asignarlos después dejaría un token sin `role` y la
// función vería a un llamador sin rol. Con ese error, TODOS los casos
// "denegado" seguirían en verde —por el motivo equivocado— y los casos
// "permitido" fallarían de forma llamativa. Es decir: la señal de que este
// montaje está bien es que los casos FELICES pasan.
//
// ---------------------------------------------------------------------------
// LAS DOS PROHIBICIONES ABSOLUTAS (decisión BLOQUEADA del usuario)
// ---------------------------------------------------------------------------
//   (1) nadie puede asignar `super_admin`  → caso ESCALADA VERTICAL
//   (2) un admin_restaurante nunca toca otro rid → casos ESCALADA HORIZONTAL
//       y SECUESTRO ENTRE TENANTS
// Ambas se verificaron ROMPIENDO el control que dicen proteger (ver la tabla de
// roturas de 11-08-SUMMARY.md).
// ============================================================================

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  codigoDe,
  crearRestaurante,
  crearUsuario,
  crearUsuarioConClaims,
  desmontar,
  limpiar,
  llamarCrearStaff,
  login,
  logout,
  montar,
} from './_emu.mjs';

const PASSWORD = 'Demo!1234';

const SUPER = 'super@demo.gri.dev';
const ADMIN_DEMO = 'admin.demo@demo.gri.dev';
const ADMIN_OTRO = 'admin.otro@demo.gri.dev';
const MESERO_DEMO = 'mesero.demo@demo.gri.dev';

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

async function uidPorCorreo(email) {
  return (await adminAuth.getUserByEmail(email)).uid;
}

async function docsDeUsuarios() {
  return (await db.collection('usuarios').get()).docs;
}

describe('crearUsuarioStaff — e2e contra emuladores reales', () => {
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
    // Los DOS restaurantes existen en todos los casos: así, cuando un intento
    // cruzado se deniega, se deniega por AUTORIZACIÓN y no porque el
    // restaurante destino no exista (que sería verde por el motivo equivocado).
    await crearRestaurante('demo');
    await crearRestaurante('otro');
  });

  // ==========================================================================
  // Sesión
  // ==========================================================================

  it('sin autenticar → unauthenticated', async () => {
    await esperarCodigo(
      llamarCrearStaff({
        email: 'nadie@demo.gri.dev',
        password: PASSWORD,
        nombre: 'Nadie',
        rol: 'mesero',
        restauranteId: 'demo',
      }),
      'functions/unauthenticated',
      'una llamada anónima no puede crear staff',
    );
    assert.equal((await adminAuth.listUsers(10)).users.length, 0, 'no se creó ninguna cuenta');
  });

  // ==========================================================================
  // Camino feliz · admin_restaurante acotado a su propio rid
  // ==========================================================================

  it('CAMINO FELIZ — admin de demo crea un mesero SIN mandar restauranteId → rid del claim', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const res = await llamarCrearStaff({
      email: MESERO_DEMO,
      password: PASSWORD,
      nombre: '  Ana Mesera  ',
      rol: 'mesero',
      // restauranteId OMITIDO a propósito: el rid sale del claim del llamador.
    });

    assert.equal(res.data.creado, true);
    assert.equal(res.data.rol, 'mesero');
    assert.equal(res.data.restauranteId, 'demo');

    const uid = res.data.uid;
    assert.deepEqual(await claimsDe(uid), { role: 'mesero', rid: 'demo' });

    const espejo = await db.doc(`usuarios/${uid}`).get();
    assert.equal(espejo.exists, true, 'el nuevo usuario debe aparecer en la lista de equipo');
    assert.equal(espejo.data().role, 'mesero');
    assert.equal(espejo.data().restauranteId, 'demo');
    assert.equal(espejo.data().nombre, 'Ana Mesera', 'el nombre se recorta');
    assert.equal(espejo.data().email, MESERO_DEMO);
    assert.ok(espejo.data().createdAt, 'un alta real deja createdAt');

    // El usuario existe DE VERDAD en Auth y puede iniciar sesión con la
    // contraseña que se le dio: sin esto, "creado" sería solo una palabra.
    const u = await adminAuth.getUser(uid);
    assert.equal(u.email, MESERO_DEMO);
    assert.equal(u.displayName, 'Ana Mesera');
  });

  it('DECISIÓN DEL USUARIO — un admin de demo SÍ puede crear otro admin_restaurante de demo', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const res = await llamarCrearStaff({
      email: 'socio@demo.gri.dev',
      password: PASSWORD,
      nombre: 'Socio',
      rol: 'admin_restaurante',
      restauranteId: 'demo',
    });

    assert.equal(res.data.creado, true);
    assert.deepEqual(await claimsDe(res.data.uid), { role: 'admin_restaurante', rid: 'demo' });
  });

  // ==========================================================================
  // PROHIBICIÓN 2 · escalada horizontal
  // ==========================================================================

  it('ESCALADA HORIZONTAL — admin de demo con restauranteId "otro" → permission-denied', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCrearStaff({
        email: 'infiltrado@demo.gri.dev',
        password: PASSWORD,
        nombre: 'Infiltrado',
        rol: 'mesero',
        restauranteId: 'otro',
      }),
      'functions/permission-denied',
      'un admin de demo no pone personal en otro restaurante',
    );
    // EL MENSAJE, NO SOLO EL CÓDIGO. `permission-denied` es TAMBIÉN lo que
    // recibe un llamador sin rol: si este caso solo mirara el código, seguiría
    // en verde aunque los claims del admin jamás llegaran al token, es decir
    // sin haber ejercitado el control horizontal ni una vez. Detectado
    // rompiendo el arnés (rotura S del SUMMARY).
    assert.equal(err.message, 'No puedes crear usuarios de otro restaurante.');

    // Y, sobre todo: NO se creó la cuenta. Un rechazo que dejara el usuario en
    // Auth sería media escalada.
    await assert.rejects(() => adminAuth.getUserByEmail('infiltrado@demo.gri.dev'));
    assert.equal((await docsDeUsuarios()).length, 0);
  });

  // ==========================================================================
  // PROHIBICIÓN 1 · escalada vertical
  // ==========================================================================

  it('ESCALADA VERTICAL — admin de demo pidiendo rol super_admin → invalid-argument', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const errV = await esperarCodigo(
      llamarCrearStaff({
        email: 'falso.super@demo.gri.dev',
        password: PASSWORD,
        nombre: 'Falso Super',
        rol: 'super_admin',
        restauranteId: 'demo',
      }),
      'functions/invalid-argument',
      'nadie asigna super_admin por esta vía',
    );
    assert.match(errV.message, /rol debe ser uno de: admin_restaurante, mesero, cocina/);
    await assert.rejects(() => adminAuth.getUserByEmail('falso.super@demo.gri.dev'));
  });

  it('ESCALADA VERTICAL — ni siquiera el super_admin puede crear otro super_admin', async () => {
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await login(SUPER, PASSWORD);

    const errS = await esperarCodigo(
      llamarCrearStaff({
        email: 'segundo.super@demo.gri.dev',
        password: PASSWORD,
        nombre: 'Segundo Super',
        rol: 'super_admin',
        restauranteId: 'demo',
      }),
      'functions/invalid-argument',
      'la prohibición es absoluta, no relativa al rol del llamador',
    );
    assert.match(errS.message, /rol debe ser uno de: admin_restaurante, mesero, cocina/);
  });

  // ==========================================================================
  // super_admin
  // ==========================================================================

  it('super_admin crea un admin_restaurante en "otro" → éxito', async () => {
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await login(SUPER, PASSWORD);

    const res = await llamarCrearStaff({
      email: ADMIN_OTRO,
      password: PASSWORD,
      nombre: 'Admin de Otro',
      rol: 'admin_restaurante',
      restauranteId: 'otro',
    });

    assert.equal(res.data.creado, true);
    assert.equal(res.data.restauranteId, 'otro');
    assert.deepEqual(await claimsDe(res.data.uid), { role: 'admin_restaurante', rid: 'otro' });
  });

  it('super_admin con un restauranteId que NO existe → not-found (nada de staff huérfano)', async () => {
    await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await login(SUPER, PASSWORD);

    const err = await esperarCodigo(
      llamarCrearStaff({
        email: 'huerfano@demo.gri.dev',
        password: PASSWORD,
        nombre: 'Huérfano',
        rol: 'mesero',
        restauranteId: 'no-existe',
      }),
      'functions/not-found',
      'un dedazo en el slug no puede crear staff de un restaurante inexistente',
    );
    assert.match(err.message, /no existe/);
    await assert.rejects(() => adminAuth.getUserByEmail('huerfano@demo.gri.dev'));
  });

  // ==========================================================================
  // Llamador sin permiso
  // ==========================================================================

  it('un mesero llamando la callable → permission-denied', async () => {
    await crearUsuarioConClaims({
      email: MESERO_DEMO,
      password: PASSWORD,
      claims: { role: 'mesero', rid: 'demo' },
    });
    await login(MESERO_DEMO, PASSWORD);

    const errM = await esperarCodigo(
      llamarCrearStaff({
        email: 'colega@demo.gri.dev',
        password: PASSWORD,
        nombre: 'Colega',
        rol: 'cocina',
        restauranteId: 'demo',
      }),
      'functions/permission-denied',
      'el personal de sala no da de alta personal',
    );
    assert.equal(errM.message, 'Solo super_admin o admin_restaurante pueden dar de alta staff.');
  });

  // ==========================================================================
  // Forma del payload
  // ==========================================================================

  it('contraseña de menos de 8 caracteres → invalid-argument (contrato con el formulario de 11-10)', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    await esperarCodigo(
      llamarCrearStaff({
        email: 'corta@demo.gri.dev',
        password: 'Ab!2345', // 7 — Firebase aceptaría 6; el producto exige 8
        nombre: 'Clave Corta',
        rol: 'mesero',
        restauranteId: 'demo',
      }),
      'functions/invalid-argument',
      'el mínimo del producto es 8, no el 6 de Firebase',
    );
  });

  // --------------------------------------------------------------------------
  // 11-22 · La POLÍTICA de contraseñas también vive en el servidor
  // --------------------------------------------------------------------------
  // Estos dos casos son la prueba de T-11-22-01: la validación del formulario
  // del panel es UX y se salta invocando la callable directamente, que es
  // exactamente lo que hacen estos tests. Si la política solo estuviera en
  // Flutter, los dos pasarían con ÉXITO y `12345678` quedaría en Auth.
  //
  // Además de comprobar el código de error se comprueba que NO QUEDA CUENTA en
  // Auth: un rechazo que llegara después de `createUser` dejaría al usuario
  // creado con una contraseña que la política prohíbe, y el test seguiría verde
  // mirando solo el código.

  it('POLÍTICA · 12345678 → invalid-argument y NO se crea la cuenta en Auth', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const objetivo = 'solo.digitos@demo.gri.dev';
    const err = await esperarCodigo(
      llamarCrearStaff({
        email: objetivo,
        password: '12345678',
        nombre: 'Solo Dígitos',
        rol: 'mesero',
        restauranteId: 'demo',
      }),
      'functions/invalid-argument',
      'la política del cliente NO se puede saltar llamando a la función',
    );

    // El mensaje del servidor dice QUÉ falta: el panel lo muestra tal cual.
    assert.match(err.message, /mayúscula/);
    assert.match(err.message, /minúscula/);

    await assert.rejects(
      () => adminAuth.getUserByEmail(objetivo),
      (e) => e.code === 'auth/user-not-found',
      'la validación tiene que correr ANTES de tocar Auth',
    );
  });

  it('POLÍTICA · 7 caracteres CON los tres tipos → invalid-argument por longitud', async () => {
    // Aísla el borde: `Abcdef1` cumple mayúscula, minúscula y dígito, así que
    // lo único que puede rechazarlo es la longitud. El caso preexistente usa
    // `Ab!2345`, que también los cumple, pero este deja el borde explícito
    // junto al resto de la política.
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const objetivo = 'siete@demo.gri.dev';
    const err = await esperarCodigo(
      llamarCrearStaff({
        email: objetivo,
        password: 'Abcdef1',
        nombre: 'Siete Justos',
        rol: 'mesero',
        restauranteId: 'demo',
      }),
      'functions/invalid-argument',
      'siete caracteres no bastan aunque la composición sea correcta',
    );
    assert.match(err.message, /8 caracteres/);

    await assert.rejects(
      () => adminAuth.getUserByEmail(objetivo),
      (e) => e.code === 'auth/user-not-found',
    );
  });

  it('POLÍTICA · una contraseña que CUMPLE sigue creando el usuario', async () => {
    // Contrapeso: sin él, una validación que rechazara SIEMPRE dejaría los dos
    // casos de arriba en verde y el alta rota sin que nadie se enterara.
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const objetivo = 'valida@demo.gri.dev';
    const res = await llamarCrearStaff({
      email: objetivo,
      password: 'Abcdefg1', // exactamente 8, los tres tipos
      nombre: 'Justo Ocho',
      rol: 'mesero',
      restauranteId: 'demo',
    });

    assert.equal(res.data.creado, true);
    const creado = await adminAuth.getUserByEmail(objetivo);
    assert.equal(creado.uid, res.data.uid);
  });

  // ==========================================================================
  // Idempotencia (mitigación de la no-atomicidad Auth/Firestore)
  // ==========================================================================

  it('IDEMPOTENCIA — el mismo correo dos veces desde el mismo tenant: mismo uid, creado false, un solo doc', async () => {
    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const payload = {
      email: MESERO_DEMO,
      password: PASSWORD,
      nombre: 'Ana Mesera',
      rol: 'mesero',
      restauranteId: 'demo',
    };

    const uno = await llamarCrearStaff(payload);
    assert.equal(uno.data.creado, true);

    const dos = await llamarCrearStaff({ ...payload, rol: 'cocina' });
    assert.equal(dos.data.creado, false, 'la segunda vez NO se crea la cuenta');
    assert.equal(dos.data.uid, uno.data.uid, 'converge al MISMO uid');

    // Reintentar repara: el rol pedido en el segundo intento es el que queda.
    assert.deepEqual(await claimsDe(dos.data.uid), { role: 'cocina', rid: 'demo' });

    const docs = await docsDeUsuarios();
    assert.equal(docs.length, 1, 'un solo doc espejo, no dos');
    assert.equal(docs[0].id, uno.data.uid);
    assert.equal(docs[0].data().role, 'cocina');
  });

  // ==========================================================================
  // Anti-secuestro de cuenta por correo · las TRES ramas
  // ==========================================================================

  it('SECUESTRO ENTRE TENANTS — el admin de otro no puede apoderarse del staff de demo', async () => {
    // El mesero ya es staff de 'demo'.
    const uidVictima = await crearUsuarioConClaims({
      email: MESERO_DEMO,
      password: PASSWORD,
      claims: { role: 'mesero', rid: 'demo' },
    });
    await db.doc(`usuarios/${uidVictima}`).set({
      nombre: 'Ana Mesera',
      email: MESERO_DEMO,
      role: 'mesero',
      restauranteId: 'demo',
    });

    await crearUsuarioConClaims({
      email: ADMIN_OTRO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'otro' },
    });
    await login(ADMIN_OTRO, PASSWORD);

    await esperarCodigo(
      llamarCrearStaff({
        email: MESERO_DEMO,
        password: 'OtraClave!9',
        nombre: 'Ana Robada',
        rol: 'mesero',
        // Sin restauranteId: el rid efectivo sería 'otro', el del atacante.
      }),
      'functions/already-exists',
      'un correo que ya es staff de demo no se re-asigna a otro restaurante',
    );

    // LO IMPORTANTE NO ES EL CÓDIGO, ES QUE LA VÍCTIMA NO SE MOVIÓ.
    assert.deepEqual(
      await claimsDe(uidVictima),
      { role: 'mesero', rid: 'demo' },
      'los claims originales NO pueden cambiar',
    );
    const espejo = await db.doc(`usuarios/${uidVictima}`).get();
    assert.equal(espejo.data().restauranteId, 'demo');
    assert.equal(espejo.data().nombre, 'Ana Mesera', 'ni siquiera el nombre se sobrescribe');
  });

  it('SECUESTRO DE CLIENTE — una cuenta de la app cliente NO se convierte en staff sin consentimiento', async () => {
    // Un cliente auto-registrado: SIN claims (la ausencia de `role` se
    // interpreta como cliente en firestore.rules) y con el doc espejo que
    // escribe `app_cliente/lib/features/auth/auth_controller.dart`.
    const uidCliente = await crearUsuario({
      email: 'clienta@gmail.com',
      password: PASSWORD,
    });
    await db.doc(`usuarios/${uidCliente}`).set({
      nombre: 'Clienta Habitual',
      email: 'clienta@gmail.com',
      role: 'cliente',
      restauranteId: null,
    });
    assert.deepEqual(await claimsDe(uidCliente), {}, 'precondición: la víctima no tiene claims');

    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    await esperarCodigo(
      llamarCrearStaff({
        email: 'clienta@gmail.com',
        password: 'ClaveNueva!1',
        nombre: 'Clienta Mesera',
        rol: 'mesero',
        restauranteId: 'demo',
      }),
      'functions/already-exists',
      'conocer el correo de un cliente no da derecho a convertirlo en empleado',
    );

    // La comprobación que de verdad importa: la víctima SIGUE SIN CLAIMS. Si
    // esto fallara, esa persona sería mesera de un restaurante ajeno sin
    // haberlo pedido, y vería sus pedidos y sus mesas.
    assert.deepEqual(await claimsDe(uidCliente), {}, 'la víctima sigue sin claims');
    const espejo = await db.doc(`usuarios/${uidCliente}`).get();
    assert.equal(espejo.data().role, 'cliente');
    assert.equal(espejo.data().restauranteId, null);
  });

  it('PLATAFORMA — un correo de super_admin no se degrada a staff', async () => {
    const uidSuper = await crearUsuarioConClaims({
      email: SUPER,
      password: PASSWORD,
      claims: { role: 'super_admin', rid: null },
    });
    await db.doc(`usuarios/${uidSuper}`).set({
      nombre: 'Fundador',
      email: SUPER,
      role: 'super_admin',
      restauranteId: null,
    });

    await crearUsuarioConClaims({
      email: ADMIN_DEMO,
      password: PASSWORD,
      claims: { role: 'admin_restaurante', rid: 'demo' },
    });
    await login(ADMIN_DEMO, PASSWORD);

    const err = await esperarCodigo(
      llamarCrearStaff({
        email: SUPER,
        password: 'ClaveNueva!1',
        nombre: 'Fundador Degradado',
        rol: 'mesero',
        restauranteId: 'demo',
      }),
      'functions/permission-denied',
      'degradar al super_admin sería un apagón de la plataforma entera',
    );
    assert.equal(err.message, 'Esa cuenta es de plataforma.');

    assert.deepEqual(
      await claimsDe(uidSuper),
      { role: 'super_admin', rid: null },
      'los claims de plataforma quedan intactos',
    );
  });
});
