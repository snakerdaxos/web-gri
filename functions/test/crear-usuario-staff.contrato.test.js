// ============================================================================
// GRI — Contratos de FUENTE de `crearUsuarioStaff` (Fase 11, plan 08)
//
// Corre con: cd functions && node --test test/*.test.js  (sin emuladores)
//
// ---------------------------------------------------------------------------
// POR QUÉ ESTE ARCHIVO EXISTE (no estaba en el plan · ver 11-08-SUMMARY)
// ---------------------------------------------------------------------------
// El plan mitigaba T-11-08-05 (fuga del error crudo del Admin SDK) con este
// gate de shell:
//     grep -c "e.message" src/crear-usuario-staff.js | grep -q '^0$'
// Ese gate es CIEGO a la fuga real. En `grep` el punto es un comodín, así que
// el patrón exige la letra `e` justo antes: cubre `e.message`, pero NO
// `err.message` ni `err?.message` — y `err` es precisamente el nombre que usa
// el catch de `bootstrap-plataforma.js`, o sea el nombre que un humano
// escribiría aquí. Comprobado: los tres literales dan 0, 0 y 1.
// Un gate que no puede fallar cuando el control falta es decoración. Este sí
// puede: se verificó rompiéndolo (ver la tabla de roturas del SUMMARY).
//
// Estos tests leen la FUENTE en vez de ejecutar la función porque `onCall`
// exige el entorno de Cloud Functions. El comportamiento se prueba en
// `scripts/test/functions/crear-usuario-staff.e2e.mjs` contra emuladores
// reales; esto es la red de seguridad estática que corre en milisegundos.
// ============================================================================

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';

const RUTA = new URL('../src/crear-usuario-staff.js', import.meta.url);
const FUENTE = readFileSync(RUTA, 'utf8');

/** Líneas de código, sin comentarios de línea ni líneas vacías. */
const LINEAS_CODIGO = FUENTE.split('\n')
  .map((l, i) => ({ n: i + 1, txt: l }))
  .filter(({ txt }) => txt.trim() !== '' && !txt.trim().startsWith('//') && !txt.trim().startsWith('*'));

describe('T-11-08-05 · el error crudo del Admin SDK NUNCA sale hacia el cliente', () => {
  it('ninguna línea de código lee `.message` de un error, con CUALQUIER nombre de variable', () => {
    // Cubre e.message, err.message, err?.message, error["message"], etc.
    const sospechosas = LINEAS_CODIGO.filter(({ txt }) =>
      /(\?\.|\.)\s*message\b/.test(txt) || /\[\s*['"]message['"]\s*\]/.test(txt),
    );
    assert.deepEqual(
      sospechosas.map(({ n, txt }) => `${n}: ${txt.trim()}`),
      [],
      'devolver o registrar el mensaje del SDK filtra estado interno del proyecto',
    );
  });

  it('tampoco se lee `.stack`', () => {
    const sospechosas = LINEAS_CODIGO.filter(({ txt }) => /(\?\.|\.)\s*stack\b/.test(txt));
    assert.deepEqual(sospechosas.map(({ n }) => n), []);
  });

  it('el HttpsError de fallo inesperado es `internal` con mensaje fijo', () => {
    assert.match(FUENTE, /new HttpsError\(\s*'internal',\s*'No se pudo crear el usuario\.',/);
  });
});

describe('contratos estructurales de la callable', () => {
  it('delega la autorización en autorizarAlta y no la reimplementa', () => {
    assert.match(FUENTE, /import \{ autorizarAlta \} from '\.\/auth-matrix\.js'/);
    assert.match(FUENTE, /autorizarAlta\(\{/);
    // Si la función volviera a decidir por su cuenta, la matriz tendría dos
    // fuentes de verdad y la combinatoria de auth-matrix.test.js dejaría de
    // cubrir lo que de verdad corre.
    assert.equal(
      /ROLES_ASIGNABLES\s*=/.test(FUENTE),
      false,
      'las allow-lists viven SOLO en auth-matrix.js',
    );
  });

  it('el rid efectivo sale de la decisión, no del payload', () => {
    assert.match(FUENTE, /const rid = decision\.rid;/);
    // `restauranteId` del payload solo puede aparecer como ENTRADA de la
    // decisión (ridPedido) y en la lectura del propio payload; jamás como el
    // valor que se escribe en los claims.
    assert.match(FUENTE, /setCustomUserClaims\(uid, \{ role: rol, rid \}\)/);
    assert.equal(
      /setCustomUserClaims\([^)]*restauranteId/.test(FUENTE),
      false,
      'escribir el restauranteId del payload en los claims ES la escalada horizontal',
    );
  });

  it('la región va declarada explícitamente (un desajuste da un 404 opaco)', () => {
    assert.match(FUENTE, /region: 'us-central1'/);
    assert.match(FUENTE, /maxInstances: 5/);
  });

  it('las TRES ramas del anti-secuestro están presentes', () => {
    // (a) plataforma
    assert.match(FUENTE, /prev\.role === 'super_admin'/);
    // (b) otro tenant
    assert.match(FUENTE, /prev\.rid !== rid/);
    // (c) cliente — y consultando el doc espejo, porque los claims no bastan
    assert.match(FUENTE, /datos\.role === 'cliente'/);
    assert.match(FUENTE, /db\.doc\(`usuarios\/\$\{uid\}`\)\.get\(\)/);
  });
});

describe('11-22 · la POLÍTICA de contraseñas es del servidor, no solo del panel', () => {
  it('importa la política del módulo compartido y no la reimplementa', () => {
    assert.match(
      FUENTE,
      /import \{[^}]*validarPassword[^}]*\} from '\.\/password-policy\.js';/,
      'la regla tiene que venir de password-policy.js, que es lo que los '
        + 'vectores canónicos mantienen sincronizado con las dos apps',
    );
    assert.ok(
      LINEAS_CODIGO.some(({ txt }) => /validarPassword\(\s*password\s*\)/.test(txt)),
      'la callable no llama a validarPassword con el password recibido',
    );
  });

  it('no queda ni rastro de la regla escrita a mano', () => {
    // `MIN_PASSWORD` era la regla vieja. Si vuelve, es que alguien duplicó el
    // umbral aquí y las tres implementaciones ya pueden divergir.
    const sospechosas = LINEAS_CODIGO.filter(({ txt }) =>
      /MIN_PASSWORD/.test(txt)
      || /password(\?\.)?\.length\s*[<>]=?/.test(txt)
      || /\[A-Z\]|\[a-z\]/.test(txt),
    );
    assert.deepEqual(sospechosas.map(({ n, txt }) => `${n}: ${txt.trim()}`), []);
  });

  it('la validación va ANTES de tocar Auth (si no, deja cuentas prohibidas)', () => {
    // Sin este orden, un rechazo posterior a `createUser` dejaría al usuario
    // creado con una contraseña que la política prohíbe. El e2e lo comprueba
    // por comportamiento; esto lo fija en la FUENTE, que es donde se rompe.
    const idx = (re) => LINEAS_CODIGO.findIndex(({ txt }) => re.test(txt));
    const iValidacion = idx(/validarPassword\(\s*password\s*\)/);
    const iCreate = idx(/auth\.createUser\(/);
    assert.ok(iValidacion >= 0, 'no encuentro la llamada a validarPassword');
    assert.ok(iCreate >= 0, 'no encuentro createUser');
    assert.ok(
      iValidacion < iCreate,
      `validarPassword (línea ${LINEAS_CODIGO[iValidacion]?.n}) tiene que ir `
        + `ANTES de createUser (línea ${LINEAS_CODIGO[iCreate]?.n})`,
    );
  });

  it('el rechazo es invalid-argument con el mensaje CONCRETO de la política', () => {
    // `invalid-argument` = "lo que me mandaste no tiene sentido". Un
    // `permission-denied` aquí mentiría: el problema no es quién llama.
    assert.match(
      FUENTE,
      /new HttpsError\(\s*'invalid-argument',\s*errorPassword\s*\)/,
      'el mensaje que viaja tiene que ser el de la política, no uno genérico',
    );
  });
});
