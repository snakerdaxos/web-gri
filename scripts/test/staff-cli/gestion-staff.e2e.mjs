// ============================================================================
// GRI — e2e del CLI de gestión de personal (Fase 11, plan 11-20)
//
// QUÉ PRUEBA: que `scripts/gestion_staff.mjs` deja el sistema EXACTAMENTE en el
// mismo estado en que lo dejaban `crearUsuarioStaff` y `cambiarEstadoStaff`.
//
// ---------------------------------------------------------------------------
// CÓMO ESTÁ MONTADO, Y POR QUÉ ASÍ
// ---------------------------------------------------------------------------
//  · El CLI se ejecuta como PROCESO HIJO de verdad (`node gestion_staff.mjs …`),
//    no importando sus funciones. Importarlas saltaría el parseo de argumentos,
//    el arranque del SDK y los códigos de salida, que son justamente la mitad de
//    lo que hay que probar.
//  · Se AFIRMA SOBRE EL ESTADO (claims en Auth, docs en Firestore), no sobre el
//    texto de la salida... salvo en los casos de RECHAZO, donde el mensaje SÍ
//    importa: un caso denegado que solo comprueba «salió con 1» puede estar
//    verde por otro control (el «verde por el motivo equivocado» de 11-08). Se
//    exige el mensaje LITERAL de la matriz.
//  · Los actores se siembran con el Admin SDK y sus claims, porque el CLI los
//    lee de Auth: sin claims sembrados no habría autorización que evaluar.
//
// SOLO CORRE CON EMULADORES:  cd scripts && npm run test:staff
// ============================================================================

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import test, { after, before, beforeEach } from 'node:test';
import { fileURLToPath } from 'node:url';

import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ_REPO = path.resolve(AQUI, '..', '..', '..');
const CLI = path.join(RAIZ_REPO, 'scripts', 'gestion_staff.mjs');

const RID = 'demo';
const RID_AJENO = 'otro';
const PASSWORD_OK = 'Demo!1234';

let app;
let auth;
let db;

before(() => {
  const faltan = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST'].filter(
    (k) => !process.env[k],
  );
  if (faltan.length > 0) {
    throw new Error(
      `Faltan variables de emulador: ${faltan.join(', ')}.\n` +
        'Estos tests SOLO corren vía `cd scripts && npm run test:staff`.',
    );
  }
  const projectId = process.env.GCLOUD_PROJECT || 'demo-gri';
  app = initializeApp({ projectId }, `staff-cli-${Date.now()}`);
  auth = getAuth(app);
  db = getFirestore(app);
});

after(async () => {
  if (app) await deleteApp(app);
});

/** Deja el emulador como recién arrancado. ANTES de cada caso, no después. */
beforeEach(async () => {
  const { users } = await auth.listUsers(1000);
  if (users.length > 0) await auth.deleteUsers(users.map((u) => u.uid));
  for (const col of ['usuarios', 'restaurantes']) {
    const snap = await db.collection(col).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
});

// --- Helpers ---------------------------------------------------------------

/**
 * Ejecuta el CLI como proceso hijo. Devuelve `{code, out}` con stdout+stderr
 * juntos, que es como lo ve el operador.
 *
 * `stdin` se escribe siempre y el flujo se cierra: si un caso alcanzara una
 * confirmación interactiva que no esperaba, el timeout lo mata y falla
 * ruidosamente en vez de colgar la suite entera.
 */
function cli(args, { stdin = '' } = {}) {
  return new Promise((resolve, reject) => {
    const hijo = spawn(process.execPath, [CLI, ...args], {
      cwd: RAIZ_REPO,
      env: process.env,
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
    });
    let out = '';
    hijo.stdout.on('data', (d) => { out += d; });
    hijo.stderr.on('data', (d) => { out += d; });
    const temporizador = setTimeout(() => {
      hijo.kill();
      reject(new Error(`El CLI no terminó en 30s. Salida parcial:\n${out}`));
    }, 30_000);
    hijo.on('error', reject);
    hijo.on('close', (code) => {
      clearTimeout(temporizador);
      resolve({ code, out });
    });
    hijo.stdin.end(stdin);
  });
}

/**
 * Inicia sesión de VERDAD contra el emulador de Auth (REST de Identity Toolkit).
 *
 * Existe porque «se imprimió una contraseña» no prueba nada: si el script
 * generara una candidata y creara la cuenta con otra, la salida seguiría siendo
 * idéntica y la persona no podría entrar. Devuelve `null` si entró, o el código
 * de error si no.
 */
async function intentarLogin(email, password) {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const res = await fetch(
    `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const cuerpo = await res.json();
  if (res.ok && cuerpo.idToken) return null;
  return cuerpo?.error?.message ?? `HTTP ${res.status}`;
}

async function sembrarRestaurante(rid) {
  await db.doc(`restaurantes/${rid}`).set({ nombre: `Restaurante ${rid}`, activo: true });
}

async function sembrarActor({ email, claims }) {
  const u = await auth.createUser({ email, password: PASSWORD_OK, emailVerified: true });
  await auth.setCustomUserClaims(u.uid, claims);
  await db.doc(`usuarios/${u.uid}`).set({
    nombre: email,
    email,
    role: claims.role,
    restauranteId: claims.rid ?? null,
  });
  return u.uid;
}

const SUPER = 'plataforma@gri.dev';
const ADMIN = 'admin@demo.gri.dev';

/** El montaje habitual: restaurante demo + un super_admin + un admin del demo. */
async function escenarioBase() {
  await sembrarRestaurante(RID);
  const uidSuper = await sembrarActor({ email: SUPER, claims: { role: 'super_admin', rid: null } });
  const uidAdmin = await sembrarActor({
    email: ADMIN,
    claims: { role: 'admin_restaurante', rid: RID },
  });
  return { uidSuper, uidAdmin };
}

// ============================================================================
// ALTA
// ============================================================================

test('alta correcta → claims y doc espejo como los deja la callable', async () => {
  await escenarioBase();

  const r = await cli([
    'crear', '--como', ADMIN,
    '--email', 'ana@demo.gri.dev', '--nombre', 'Ana Mesera',
    '--rol', 'mesero', '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 0, r.out);

  const u = await auth.getUserByEmail('ana@demo.gri.dev');
  assert.deepEqual(u.customClaims, { role: 'mesero', rid: RID });
  assert.equal(u.displayName, 'Ana Mesera');
  assert.equal(u.emailVerified, true);

  const espejo = (await db.doc(`usuarios/${u.uid}`).get()).data();
  assert.equal(espejo.nombre, 'Ana Mesera');
  assert.equal(espejo.email, 'ana@demo.gri.dev');
  assert.equal(espejo.role, 'mesero');
  assert.equal(espejo.restauranteId, RID);
  assert.ok(espejo.createdAt, 'el alta real debe sellar createdAt');
});

test('alta sin --password genera una contraseña que CUMPLE la política y sirve para entrar', async () => {
  await escenarioBase();

  const r = await cli([
    'crear', '--como', ADMIN,
    '--email', 'gen@demo.gri.dev', '--nombre', 'Con Generada', '--rol', 'cocina',
  ]);
  assert.equal(r.code, 0, r.out);

  const m = r.out.match(/CONTRASEÑA TEMPORAL:\s*(\S+)/);
  assert.ok(m, `no se imprimió la contraseña temporal:\n${r.out}`);

  const { validarPassword } = await import('../../../functions/src/password-policy.js');
  assert.equal(validarPassword(m[1]), null, 'la contraseña generada incumple la política');

  // La asercion con dientes: entrar DE VERDAD con la contraseña impresa. Sin
  // esto, un script que generara una candidata y creara la cuenta con otra
  // pasaría este test igual y el operador dictaría una contraseña inservible.
  assert.equal(
    await intentarLogin('gen@demo.gri.dev', m[1]),
    null,
    'la contraseña impresa no sirve para iniciar sesión',
  );

  const u = await auth.getUserByEmail('gen@demo.gri.dev');
  assert.deepEqual(u.customClaims, { role: 'cocina', rid: RID });
});

test('alta con 12345678 → rechazada por la política y SIN crear nada en Auth', async () => {
  await escenarioBase();

  const r = await cli([
    'crear', '--como', ADMIN,
    '--email', 'debil@demo.gri.dev', '--nombre', 'Débil',
    '--rol', 'mesero', '--password', '12345678',
  ]);
  assert.equal(r.code, 1, r.out);
  // El mensaje CONCRETO de validarPassword, no un genérico. Va con la primera
  // letra en mayúscula porque la política capitaliza la frase resultante.
  assert.match(r.out, /Te faltan una mayúscula y una minúscula\./);

  await assert.rejects(
    auth.getUserByEmail('debil@demo.gri.dev'),
    (e) => e.code === 'auth/user-not-found',
    'la cuenta NO puede existir: la política se aplica ANTES de tocar Auth',
  );
});

test('alta con un rid ajeno siendo admin_restaurante → rechazada por la matriz', async () => {
  await escenarioBase();
  await sembrarRestaurante(RID_AJENO);

  const r = await cli([
    'crear', '--como', ADMIN, '--rid', RID_AJENO,
    '--email', 'intruso@otro.gri.dev', '--nombre', 'Intruso',
    '--rol', 'mesero', '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /No puedes crear usuarios de otro restaurante\./);
  assert.match(r.out, /permission-denied/);

  await assert.rejects(
    auth.getUserByEmail('intruso@otro.gri.dev'),
    (e) => e.code === 'auth/user-not-found',
  );
});

test('alta con --rol super_admin → rechazada por la matriz (prohibición absoluta)', async () => {
  await escenarioBase();

  // Ni siquiera la propia cuenta de plataforma puede crear otra por esta vía.
  const r = await cli([
    'crear', '--como', SUPER, '--rid', RID,
    '--email', 'otrosuper@gri.dev', '--nombre', 'Otro Super',
    '--rol', 'super_admin', '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /rol debe ser uno de: admin_restaurante, mesero, cocina\./);

  await assert.rejects(
    auth.getUserByEmail('otrosuper@gri.dev'),
    (e) => e.code === 'auth/user-not-found',
  );
});

test('alta sobre el correo de un CLIENTE → rechazada (anti-secuestro, rama c)', async () => {
  await escenarioBase();

  // Un cliente auto-registrado NO lleva claim `role`: mirar los claims no ve
  // nada y hay que consultar el doc espejo. Sembrado tal cual: sin claims.
  const cliente = await auth.createUser({ email: 'carlos@gmail.com', password: PASSWORD_OK });
  await db.doc(`usuarios/${cliente.uid}`).set({
    nombre: 'Carlos Comensal', email: 'carlos@gmail.com', role: 'cliente', restauranteId: null,
  });

  const r = await cli([
    'crear', '--como', ADMIN,
    '--email', 'carlos@gmail.com', '--nombre', 'Carlos Mesero',
    '--rol', 'mesero', '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /ya tiene una cuenta de cliente/);

  const u = await auth.getUser(cliente.uid);
  assert.ok(!u.customClaims?.role, 'la cuenta del cliente NO puede quedar con claims de staff');
});

test('alta repetida con el mismo correo es IDEMPOTENTE (repara, no duplica)', async () => {
  await escenarioBase();

  const args = [
    'crear', '--como', ADMIN,
    '--email', 'repe@demo.gri.dev', '--nombre', 'Repetida',
    '--rol', 'mesero', '--password', PASSWORD_OK,
  ];
  const r1 = await cli(args);
  assert.equal(r1.code, 0, r1.out);
  const uid1 = (await auth.getUserByEmail('repe@demo.gri.dev')).uid;

  const r2 = await cli(args);
  assert.equal(r2.code, 0, r2.out);
  assert.match(r2.out, /REPARADA/);

  const { users } = await auth.listUsers(1000);
  const conEseCorreo = users.filter((u) => u.email === 'repe@demo.gri.dev');
  assert.equal(conEseCorreo.length, 1, 'no puede haber dos cuentas con el mismo correo');
  assert.equal(conEseCorreo[0].uid, uid1, 'el uid debe converger al mismo');
  assert.deepEqual(conEseCorreo[0].customClaims, { role: 'mesero', rid: RID });
});

// ============================================================================
// ACTOR
// ============================================================================

test('sin --como → error claro y salida 1, sin tocar nada', async () => {
  await escenarioBase();

  const r = await cli([
    'crear', '--email', 'x@demo.gri.dev', '--nombre', 'X', '--rol', 'mesero',
    '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /Falta --como/);

  await assert.rejects(
    auth.getUserByEmail('x@demo.gri.dev'),
    (e) => e.code === 'auth/user-not-found',
  );
});

test('--como de una cuenta SIN claims → error claro y salida 1', async () => {
  await escenarioBase();
  await auth.createUser({ email: 'sinclaims@gri.dev', password: PASSWORD_OK });

  const r = await cli([
    'crear', '--como', 'sinclaims@gri.dev',
    '--email', 'y@demo.gri.dev', '--nombre', 'Y', '--rol', 'mesero',
    '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /no tiene custom claims/);
});

// ============================================================================
// LISTAR
// ============================================================================

test('listar muestra el equipo del restaurante del actor, y solo ese', async () => {
  await escenarioBase();
  await sembrarRestaurante(RID_AJENO);
  await sembrarActor({ email: 'ajeno@otro.gri.dev', claims: { role: 'mesero', rid: RID_AJENO } });
  await cli([
    'crear', '--como', ADMIN, '--email', 'ana@demo.gri.dev', '--nombre', 'Ana Mesera',
    '--rol', 'mesero', '--password', PASSWORD_OK,
  ]);

  const r = await cli(['listar', '--como', ADMIN]);
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /ana@demo\.gri\.dev/);
  assert.match(r.out, /Ana Mesera/);
  assert.ok(
    !r.out.includes('ajeno@otro.gri.dev'),
    `el listado NO puede incluir a personal de otro restaurante:\n${r.out}`,
  );
});

// ============================================================================
// BAJA
// ============================================================================

async function altaDe(email, nombre, rol = 'mesero') {
  const r = await cli([
    'crear', '--como', ADMIN, '--email', email, '--nombre', nombre,
    '--rol', rol, '--password', PASSWORD_OK,
  ]);
  assert.equal(r.code, 0, r.out);
  return (await auth.getUserByEmail(email)).uid;
}

test('baja → disabled, sin claims, espejo activo:false CONSERVANDO role y restauranteId', async () => {
  await escenarioBase();
  const uid = await altaDe('ana@demo.gri.dev', 'Ana Mesera');

  const r = await cli(['baja', '--como', ADMIN, '--uid', uid, '--si']);
  assert.equal(r.code, 0, r.out);

  const u = await auth.getUser(uid);
  assert.equal(u.disabled, true);
  assert.ok(!u.customClaims?.role, 'los claims tienen que quedar retirados');

  const espejo = (await db.doc(`usuarios/${uid}`).get()).data();
  assert.equal(espejo.activo, false);
  // LA PIEZA QUE HACE POSIBLE LA REVERSIBILIDAD: sin esto, reactivar sería
  // imposible porque los claims ya no existen.
  assert.equal(espejo.role, 'mesero');
  assert.equal(espejo.restauranteId, RID);
  assert.ok(espejo.desactivadoAt);

  // La prueba de que una baja SIRVE PARA ALGO no es la etiqueta `activo:false`
  // sino que esa persona ya no puede entrar (mismo criterio que 11-24).
  assert.equal(
    await intentarLogin('ana@demo.gri.dev', PASSWORD_OK),
    'USER_DISABLED',
    'la persona dada de baja sigue pudiendo iniciar sesión',
  );
});

test('baja pide confirmación: responder que NO aborta sin tocar nada', async () => {
  await escenarioBase();
  const uid = await altaDe('ana@demo.gri.dev', 'Ana Mesera');

  const r = await cli(['baja', '--como', ADMIN, '--uid', uid], { stdin: 'n\n' });
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /Cancelado/);
  // El aviso tiene que decir A QUIÉN afecta: un uid mal copiado se ve aquí.
  assert.match(r.out, /Ana Mesera/);

  const u = await auth.getUser(uid);
  assert.equal(u.disabled, false, 'no se pudo haber deshabilitado');
  assert.deepEqual(u.customClaims, { role: 'mesero', rid: RID });
  const espejo = (await db.doc(`usuarios/${uid}`).get()).data();
  assert.equal(espejo.activo, undefined, 'la ficha no se pudo haber tocado');
});

test('baja confirmada por stdin con "s" sí se aplica', async () => {
  await escenarioBase();
  const uid = await altaDe('ana@demo.gri.dev', 'Ana Mesera');

  const r = await cli(['baja', '--como', ADMIN, '--uid', uid], { stdin: 's\n' });
  assert.equal(r.code, 0, r.out);
  assert.equal((await auth.getUser(uid)).disabled, true);
});

test('baja de un super_admin → rechazada por la matriz (prohibición 1)', async () => {
  const { uidSuper } = await escenarioBase();

  const r = await cli(['baja', '--como', ADMIN, '--uid', uidSuper, '--si']);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /No se puede cambiar el estado de una cuenta de plataforma\./);
  assert.equal((await auth.getUser(uidSuper)).disabled, false);
});

test('baja de uno mismo → rechazada por la matriz (prohibición 2)', async () => {
  const { uidAdmin } = await escenarioBase();

  const r = await cli(['baja', '--como', ADMIN, '--uid', uidAdmin, '--si']);
  assert.equal(r.code, 1, r.out);
  // Mensaje PROPIO: el objetivo NO es super_admin, así que este caso es el único
  // que se pone rojo si se quita la prohibición 2 (ver cabecera de baja-matrix).
  assert.match(r.out, /No puedes cambiar el estado de tu propia cuenta\./);
  assert.equal((await auth.getUser(uidAdmin)).disabled, false);
});

test('baja de personal de otro restaurante siendo admin → rechazada', async () => {
  await escenarioBase();
  await sembrarRestaurante(RID_AJENO);
  const uidAjeno = await sembrarActor({
    email: 'ajeno@otro.gri.dev', claims: { role: 'mesero', rid: RID_AJENO },
  });

  const r = await cli(['baja', '--como', ADMIN, '--uid', uidAjeno, '--si']);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /No puedes cambiar el estado de personal de otro restaurante\./);
  assert.equal((await auth.getUser(uidAjeno)).disabled, false);
});

// ============================================================================
// REACTIVACIÓN
// ============================================================================

test('reactivar restaura disabled:false y los claims LEÍDOS del espejo', async () => {
  await escenarioBase();
  const uid = await altaDe('ana@demo.gri.dev', 'Ana Mesera');
  await cli(['baja', '--como', ADMIN, '--uid', uid, '--si']);
  assert.ok(!(await auth.getUser(uid)).customClaims?.role, 'precondición: sin claims');

  const r = await cli(['reactivar', '--como', ADMIN, '--uid', uid]);
  assert.equal(r.code, 0, r.out);

  const u = await auth.getUser(uid);
  assert.equal(u.disabled, false);
  assert.deepEqual(u.customClaims, { role: 'mesero', rid: RID });

  const espejo = (await db.doc(`usuarios/${uid}`).get()).data();
  assert.equal(espejo.activo, true);
  assert.ok(espejo.reactivadoAt);

  assert.equal(
    await intentarLogin('ana@demo.gri.dev', PASSWORD_OK),
    null,
    'la readmision tiene que devolver el acceso con la contraseña de siempre',
  );
});

test('reactivar con una ficha INCOMPLETA → error accionable, sin dejar nada a medias', async () => {
  await escenarioBase();
  const huerfano = await auth.createUser({ email: 'huerfano@demo.gri.dev', password: PASSWORD_OK });
  await auth.updateUser(huerfano.uid, { disabled: true });
  // Ficha incompleta: conserva el rol (por eso la matriz la deja pasar) pero
  // perdió el restaurante, que es lo que la reactivación necesita para volver a
  // escribir los claims.
  await db.doc(`usuarios/${huerfano.uid}`).set({ role: 'mesero', activo: false });

  // HALLAZGO — el actor tiene que ser la PLATAFORMA, no el admin. Sin
  // `restauranteId` en la ficha y sin claims (se los llevó la baja), el objetivo
  // no tiene rid contra el que comparar, así que a un `admin_restaurante` lo
  // corta ANTES el alcance de tenant de la matriz y este camino queda
  // inalcanzable para él. Escrito con ADMIN, este test estaba verde por el
  // motivo equivocado: fallaba con 'No puedes cambiar el estado de personal de
  // otro restaurante' y nunca llegaba a la rama que dice probar.
  const r = await cli(['reactivar', '--como', SUPER, '--uid', huerfano.uid]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /Vuelve a darlo de alta con el mismo correo para repararla\./);
  assert.equal((await auth.getUser(huerfano.uid)).disabled, true, 'no se pudo haber rehabilitado');
  assert.ok(
    !(await auth.getUser(huerfano.uid)).customClaims?.role,
    'no puede quedar con claims a medias',
  );
});

// ============================================================================
// PROMOVER-SUPER · la vía de recuperación
// ============================================================================

test('promover-super SIN la bandera → aborta sin tocar nada', async () => {
  await escenarioBase();
  const u = await auth.createUser({ email: 'futuro@gri.dev', password: PASSWORD_OK });

  const r = await cli(['promover-super', '--email', 'futuro@gri.dev']);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /Falta la bandera --confirmo-promover-super/);
  assert.ok(!(await auth.getUser(u.uid)).customClaims?.role);
});

test('promover-super con la bandera pero SIN reescribir el correo → aborta', async () => {
  await escenarioBase();
  const u = await auth.createUser({ email: 'futuro@gri.dev', password: PASSWORD_OK });

  const r = await cli(
    ['promover-super', '--email', 'futuro@gri.dev', '--confirmo-promover-super'],
    { stdin: 's\n' }, // un "sí" NO basta: hay que escribir el correo entero
  );
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /El correo no coincide/);
  assert.ok(!(await auth.getUser(u.uid)).customClaims?.role);
});

test('promover-super con bandera + correo reescrito → claims de plataforma y rastro en el espejo', async () => {
  await escenarioBase();
  const u = await auth.createUser({ email: 'futuro@gri.dev', password: PASSWORD_OK });

  const r = await cli(
    ['promover-super', '--email', 'futuro@gri.dev', '--confirmo-promover-super'],
    { stdin: 'futuro@gri.dev\n' },
  );
  assert.equal(r.code, 0, r.out);
  // El aviso de que se está saliendo de la matriz tiene que verse.
  assert.match(r.out, /SE SALTA LA MATRIZ/);

  assert.deepEqual((await auth.getUser(u.uid)).customClaims, { role: 'super_admin', rid: null });

  const espejo = (await db.doc(`usuarios/${u.uid}`).get()).data();
  assert.equal(espejo.role, 'super_admin');
  assert.equal(espejo.restauranteId, null);
  assert.equal(espejo.promovidoPor, 'script:promover-super');
  assert.ok(espejo.promovidoAt);
});
