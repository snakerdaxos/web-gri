// ============================================================================
// GRI — Contratos de FUENTE de `cambiarEstadoStaff` (Fase 11, plan 24)
//
// Corre con: cd functions && npm test  (sin emuladores, milisegundos)
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE (no estaba en el plan)
// ---------------------------------------------------------------------------
// Dos motivos, y cada uno bastaría:
//
//  1. T-11-24-07 (fuga del error crudo del Admin SDK) es la misma amenaza que
//     T-11-08-05, y allí se demostró que un gate de `grep` no la ve
//     (`grep -c "e.message"` es ciego a `err.message`). El gemelo de este
//     archivo, `crear-usuario-staff.contrato.test.js`, cubre SOLO su propio
//     archivo: sin este, la callable nueva nace sin ese gate.
//
//  2. T-11-24-05 (perder el rol al desactivar) es la amenaza más específica de
//     este plan y su mitigación es una AUSENCIA: que el `set()` de la baja NO
//     mencione `role` ni `restauranteId` para borrarlos. Una ausencia no la
//     puede probar el e2e —solo comprueba el estado tras UNA secuencia—, pero
//     sí se puede afirmar sobre la fuente. Es la red que se pondrá roja el día
//     que alguien "limpie" esos campos porque le parezcan basura.
//
// Estos tests leen la FUENTE porque `onCall` exige el entorno de Cloud
// Functions. El comportamiento se prueba en
// `scripts/test/functions/cambiar-estado-staff.e2e.mjs` contra emuladores.
// ============================================================================

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';

const RUTA = new URL('../src/cambiar-estado-staff.js', import.meta.url);
const FUENTE = readFileSync(RUTA, 'utf8');

/** Líneas de código, sin comentarios de línea ni líneas vacías. */
const LINEAS_CODIGO = FUENTE.split('\n')
  .map((l, i) => ({ n: i + 1, txt: l }))
  .filter(
    ({ txt }) =>
      txt.trim() !== '' && !txt.trim().startsWith('//') && !txt.trim().startsWith('*'),
  );

/**
 * SOLO CÓDIGO. Toda aserción estructural de este archivo va contra esto, jamás
 * contra `FUENTE`.
 *
 * MEDIDO, no supuesto: la primera versión de este archivo comparaba contra
 * `FUENTE` y DOS casos salieron rojos sin que el código estuviera mal. La
 * cabecera de la callable explica los pasos de la revocación y advierte sobre
 * `!!activo`, así que `indexOf('setCustomUserClaims(uid, null)')` encontraba el
 * COMENTARIO —no la llamada— y el orden salía invertido, y el veto a `!!activo`
 * lo disparaba su propia advertencia. Es el mismo defecto que la fase ya ha
 * documentado ocho veces en gates de `grep`: confundir "alguien lo menciona"
 * con "el código lo hace". Con esto, un comentario no puede ni salvar ni
 * hundir un contrato.
 */
const CODIGO = LINEAS_CODIGO.map(({ txt }) => txt).join('\n');

describe('T-11-24-07 · el error crudo del Admin SDK NUNCA sale hacia el cliente', () => {
  it('ninguna línea de código lee `.message` de un error, con CUALQUIER nombre de variable', () => {
    const sospechosas = LINEAS_CODIGO.filter(
      ({ txt }) =>
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
    assert.match(
      CODIGO,
      /new HttpsError\('internal', 'No se pudo cambiar el estado del usuario\.',/,
    );
  });
});

describe('T-11-24-05 · la baja CONSERVA el rol, que es lo que permite reactivar', () => {
  // El `set()` de la desactivación es el trozo entre `activo === false` y el
  // `else` del reactivar. Se aísla para no mirar el de la reactivación.
  const ramaBaja = CODIGO.slice(
    CODIGO.indexOf('if (activo === false)'),
    CODIGO.indexOf('} else {'),
  );

  it('la rama de baja se localiza (si no, este archivo entero sería decoración)', () => {
    assert.ok(ramaBaja.length > 200, 'no se encontró la rama de desactivación');
    assert.match(ramaBaja, /setCustomUserClaims\(uid, null\)/);
  });

  it('la baja NUNCA borra `role` ni `restauranteId` del espejo', () => {
    for (const campo of ['role', 'restauranteId']) {
      for (const borrado of [
        new RegExp(`${campo}:\\s*null`),
        new RegExp(`${campo}:\\s*FieldValue\\.delete\\(\\)`),
        new RegExp(`${campo}:\\s*''`),
        new RegExp(`${campo}:\\s*undefined`),
      ]) {
        assert.equal(
          borrado.test(ramaBaja),
          false,
          `la baja borra \`${campo}\`: la reactivación quedaría rota para siempre ` +
            '(no hay otra fuente del rol, los claims se acaban de eliminar)',
        );
      }
    }
  });

  it('el espejo se escribe con merge, nunca con un set que reemplace el documento', () => {
    const sets = [...CODIGO.matchAll(/espejoRef\.set\(/g)];
    assert.equal(sets.length, 2, 'un set por rama (baja y reactivación)');
    assert.equal(
      (CODIGO.match(/\{ merge: true \}/g) ?? []).length,
      2,
      'sin merge, el set REEMPLAZA el doc y se lleva por delante nombre, email y el rol',
    );
  });

  it('la reactivación lee el rol del ESPEJO, no de unos claims que ya no existen', () => {
    const ramaAlta = CODIGO.slice(CODIGO.indexOf('} else {'));
    assert.match(ramaAlta, /rol = primerTexto\(espejo\.role\)/);
    assert.match(ramaAlta, /rid = primerTexto\(espejo\.restauranteId\)/);
    assert.match(ramaAlta, /setCustomUserClaims\(uid, \{ role: rol, rid \}\)/);
  });
});

describe('contratos estructurales de la callable', () => {
  it('delega la autorización en autorizarCambioEstado y no la reimplementa', () => {
    assert.match(CODIGO, /import \{ autorizarCambioEstado \} from '\.\/baja-matrix\.js'/);
    assert.match(CODIGO, /autorizarCambioEstado\(\{/);
    assert.equal(
      /ROLES_GESTIONABLES\s*=/.test(CODIGO),
      false,
      'las allow-lists viven SOLO en baja-matrix.js',
    );
  });

  it('la identidad del llamador sale del TOKEN, jamás del payload', () => {
    assert.match(CODIGO, /callerUid: request\.auth\.uid/);
    // `request.data.uid` es el OBJETIVO. Si el callerUid saliera de ahí, la
    // prohibición de auto-baja se burlaría mandando cualquier otra cosa.
    assert.equal(
      /callerUid:\s*(request\.data|uid)\b/.test(CODIGO),
      false,
      'el uid del llamador no puede venir del payload',
    );
    assert.match(CODIGO, /callerRole: request\.auth\.token\?\.role/);
    assert.match(CODIGO, /callerRid: request\.auth\.token\?\.rid/);
  });

  it('los TRES pasos de la revocación están presentes y en ese orden', () => {
    const iDisabled = CODIGO.indexOf('updateUser(uid, { disabled: true })');
    const iClaims = CODIGO.indexOf('setCustomUserClaims(uid, null)');
    const iRevoke = CODIGO.indexOf('revokeRefreshTokens(uid)');
    assert.ok(iDisabled > 0, 'falta disabled: true — la persona seguiría entrando');
    assert.ok(iClaims > iDisabled, 'falta retirar los claims, o va antes de deshabilitar');
    assert.ok(
      iRevoke > iClaims,
      'falta revocar los refresh tokens: sin eso la sesión en curso se renueva sola',
    );
  });

  it('`activo` se valida como booleano ESTRICTO', () => {
    // Con `!!activo`, la cadena "false" de un formulario mal serializado
    // REACTIVARÍA a quien se quiso dar de baja.
    assert.match(CODIGO, /typeof activo !== 'boolean'/);
    assert.equal(/!!\s*activo/.test(CODIGO), false);
  });

  it('nada de borrar cuentas: la decisión bloqueada del usuario es desactivar', () => {
    assert.equal(
      /deleteUser\s*\(/.test(CODIGO),
      false,
      'borrar dejaría pedidos huérfanos y rompería los reportes por mesero',
    );
  });

  it('la región va declarada explícitamente (un desajuste da un 404 opaco)', () => {
    assert.match(CODIGO, /region: 'us-central1'/);
    assert.match(CODIGO, /maxInstances: 5/);
  });
});
