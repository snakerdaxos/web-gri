#!/usr/bin/env node
// ============================================================================
// GRI — Marcar un correo como VERIFICADO en el emulador de Auth (plan 11-15)
//
// POR QUÉ EXISTE
// --------------
// `bootstrapPlataforma` exige `email_verified === true` en el idToken del
// llamador (11-07: el correo del fundador no es un secreto, así que el control
// del buzón es uno de los dos factores). La pantalla `/bootstrap` del panel NO
// envía correo de verificación, y el emulador de Auth tampoco envía correos.
// Resultado: contra emuladores, `/bootstrap` denegaría SIEMPRE y el paso [A]
// del runbook sería inejecutable.
//
// Este script hace, contra el EMULADOR y solo contra el emulador, lo que en el
// proyecto real hace la persona al pulsar el enlace del correo.
//
// USO (con el emulador de Auth arriba):
//   node verificar_email_emulador.mjs fundador@demo.gri.dev --crear 'Demo!1234'
//   node verificar_email_emulador.mjs otro@demo.gri.dev
//
//   --crear <password>  da de alta la cuenta si aún no existe (es lo que hace
//                       falta ANTES de abrir /bootstrap: si la cuenta ya
//                       existe, la pantalla inicia sesión en vez de crearla y
//                       la callable ve el token ya verificado).
//
// SEGURIDAD — este script NO PUEDE tocar producción:
//   · La URL está fijada a 127.0.0.1:9099 (el emulador). No es parametrizable.
//   · El projectId está fijado a `demo-gri`, que no existe como proyecto
//     Firebase (el prefijo `demo-` hace que los SDK rechacen credenciales
//     reales por diseño).
//   · `Authorization: Bearer owner` es la credencial ficticia que SOLO acepta
//     el emulador.
// ============================================================================

const HOST = 'http://127.0.0.1:9099';
const PROJECT = 'demo-gri';
const API = `${HOST}/identitytoolkit.googleapis.com/v1`;
const ADMIN = { 'Content-Type': 'application/json', Authorization: 'Bearer owner' };
const KEY = 'fake-api-key'; // el emulador ignora la API key, pero la exige

const [, , emailArg, ...resto] = process.argv;

if (!emailArg || emailArg.startsWith('-')) {
  console.error(
    'Uso: node verificar_email_emulador.mjs <correo> [--crear <password>]\n' +
      '  Ej.: node verificar_email_emulador.mjs fundador@demo.gri.dev --crear "Demo!1234"',
  );
  process.exit(1);
}
const email = emailArg.trim().toLowerCase();
const iCrear = resto.indexOf('--crear');
const password = iCrear === -1 ? null : resto[iCrear + 1];
if (iCrear !== -1 && !password) {
  console.error('ERROR: --crear necesita la contraseña a continuación.');
  process.exit(1);
}

async function json(url, body, headers = ADMIN) {
  const r = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  const t = await r.text();
  let j = null;
  try {
    j = JSON.parse(t);
  } catch {
    /* respuesta no-JSON: se reporta el texto crudo */
  }
  return { status: r.status, json: j, texto: t };
}

// --- 0. El emulador tiene que estar arriba ---------------------------------
try {
  const ping = await fetch(`${HOST}/`);
  if (!ping.ok && ping.status >= 500) throw new Error(`HTTP ${ping.status}`);
} catch (e) {
  console.error(
    `ERROR: no hay emulador de Auth escuchando en ${HOST}.\n` +
      '  Arráncalo primero (ver docs/SMOKE-E2E-v2.md §1) y vuelve a intentarlo.\n' +
      `  Detalle: ${e.message}`,
  );
  process.exit(1);
}

// --- 1. ¿Existe la cuenta? -------------------------------------------------
let r = await json(`${API}/projects/${PROJECT}/accounts:lookup`, { email: [email] });
let usuario = r.json?.users?.[0] ?? null;

// --- 2. Alta si hace falta -------------------------------------------------
if (!usuario) {
  if (!password) {
    console.error(
      `ERROR: no existe ninguna cuenta con ${email} en el emulador.\n` +
        '  Vuelve a lanzarlo con --crear <password> para darla de alta.',
    );
    process.exit(1);
  }
  const alta = await json(
    `${API}/accounts:signUp?key=${KEY}`,
    { email, password, returnSecureToken: true },
    { 'Content-Type': 'application/json' },
  );
  if (alta.status !== 200) {
    console.error(`ERROR al crear la cuenta (HTTP ${alta.status}): ${alta.texto.slice(0, 300)}`);
    process.exit(1);
  }
  console.log(`  cuenta creada · localId=${alta.json.localId}`);
  r = await json(`${API}/projects/${PROJECT}/accounts:lookup`, { email: [email] });
  usuario = r.json?.users?.[0] ?? null;
}

if (!usuario) {
  console.error('ERROR: la cuenta no aparece tras el alta. Revisa el emulador.');
  process.exit(1);
}

// --- 3. Marcar el correo como verificado -----------------------------------
const upd = await json(`${API}/projects/${PROJECT}/accounts:update`, {
  localId: usuario.localId,
  emailVerified: true,
});
if (upd.status !== 200 || upd.json?.emailVerified !== true) {
  console.error(`ERROR al verificar (HTTP ${upd.status}): ${upd.texto.slice(0, 300)}`);
  process.exit(1);
}

console.log(`OK · ${email} queda con emailVerified=true en el emulador (${PROJECT}).`);
console.log('   El idToken que se acuñe a partir de AHORA lleva email_verified: true.');
console.log('   Si esa persona ya tenía sesión abierta, ciérrala y vuelve a entrar.');
