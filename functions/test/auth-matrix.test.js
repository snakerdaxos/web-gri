// ============================================================================
// GRI — Combinatoria de la matriz de autorización del alta de staff (11-08)
//
// Corre con: cd functions && node --test test/auth-matrix.test.js
// SIN emuladores, SIN red, en milisegundos. Es posible porque `auth-matrix.js`
// es lógica PURA (cero imports de firebase-admin / firebase-functions).
//
// ---------------------------------------------------------------------------
// POR QUÉ LA MATRIZ SE PRUEBA AQUÍ Y NO SOLO EN EL e2e
// ---------------------------------------------------------------------------
// El e2e (`scripts/test/functions/crear-usuario-staff.e2e.mjs`) prueba con
// tokens REALES que la decisión llega al cliente con el código correcto, pero
// cada caso cuesta cientos de milisegundos y exige tres emuladores. La
// combinatoria COMPLETA de escaladas —incluidas las que nadie escribiría a
// mano— vive aquí. Los dos niveles son necesarios: este demuestra que la
// decisión es correcta para todas las entradas; el e2e demuestra que esa
// decisión es la que de verdad gobierna la función desplegada.
//
// LAS DOS PROHIBICIONES ABSOLUTAS (decisión BLOQUEADA del usuario, 11-CONTEXT):
//   (1) nadie puede asignar `super_admin`;
//   (2) un `admin_restaurante` nunca puede tocar un `rid` distinto al suyo.
// Cada una tiene filas marcadas `// ESCALADA` en la tabla Y un test de
// propiedad que la cubre para TODAS las combinaciones, de forma que la
// prohibición sobreviva a que alguien edite la tabla.
// ============================================================================

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  autorizarAlta,
  ROLES_ASIGNABLES,
  ROLES_LLAMADORES,
  SLUG_RE,
} from '../src/auth-matrix.js';

/**
 * Tabla de casos. Cada fila genera UN test cuyo nombre se deriva del propio
 * caso, para que un fallo identifique la entrada sin leer el archivo.
 *
 * `esperado`: `{ rid }` para permitido, `{ code }` para denegado.
 */
const CASOS = [
  // --- super_admin: cualquier restaurante, los tres roles asignables --------
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'admin_restaurante', ridPedido: 'pizza-uno' },
    esperado: { rid: 'pizza-uno' },
    nota: 'el super da de alta el admin inicial de un restaurante nuevo',
  },
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'mesero', ridPedido: 'pizza-uno' },
    esperado: { rid: 'pizza-uno' },
  },
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'cocina', ridPedido: 'pizza-uno' },
    esperado: { rid: 'pizza-uno' },
  },

  // --- admin_restaurante: SOLO su propio rid --------------------------------
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'mesero', ridPedido: undefined },
    esperado: { rid: 'demo' },
    nota: 'sin restauranteId el rid se toma del claim del llamador',
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'mesero', ridPedido: 'demo' },
    esperado: { rid: 'demo' },
    nota: 'mandar su propio rid explícitamente es redundante pero válido',
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'admin_restaurante', ridPedido: 'demo' },
    esperado: { rid: 'demo' },
    nota: 'PERMITIDO por decisión del usuario: dos socios/gerentes, y el restaurante no queda bloqueado si uno pierde el acceso',
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'cocina', ridPedido: 'demo' },
    esperado: { rid: 'demo' },
  },

  // --- ESCALADA VERTICAL · prohibición absoluta (1) -------------------------
  // ESCALADA
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'super_admin', ridPedido: 'demo' },
    esperado: { code: 'invalid-argument' },
    nota: 'ESCALADA · ni siquiera el super_admin puede crear otro super_admin por esta vía',
  },
  // ESCALADA
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'super_admin', ridPedido: 'demo' },
    esperado: { code: 'invalid-argument' },
    nota: 'ESCALADA · un admin no se promueve a sí mismo creando un super',
  },

  // --- ESCALADA HORIZONTAL · prohibición absoluta (2) -----------------------
  // ESCALADA
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'mesero', ridPedido: 'otro' },
    esperado: { code: 'permission-denied' },
    nota: 'ESCALADA · un admin de demo no pone personal en otro restaurante',
  },
  // ESCALADA
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', rolPedido: 'admin_restaurante', ridPedido: 'otro' },
    esperado: { code: 'permission-denied' },
    nota: 'ESCALADA · el caso más grave: un admin ajeno con control total de otro tenant',
  },

  // --- Llamadores no autorizados -------------------------------------------
  {
    entrada: { callerRole: 'mesero', callerRid: 'demo', rolPedido: 'cocina', ridPedido: 'demo' },
    esperado: { code: 'permission-denied' },
  },
  {
    entrada: { callerRole: 'cocina', callerRid: 'demo', rolPedido: 'mesero', ridPedido: 'demo' },
    esperado: { code: 'permission-denied' },
  },
  {
    entrada: { callerRole: 'cliente', callerRid: null, rolPedido: 'mesero', ridPedido: 'demo' },
    esperado: { code: 'permission-denied' },
  },
  {
    entrada: { callerRole: undefined, callerRid: null, rolPedido: 'mesero', ridPedido: 'demo' },
    esperado: { code: 'permission-denied' },
    nota: 'un cliente auto-registrado NO lleva claim `role` (hallazgo de 11-04): la ausencia de rol se deniega',
  },

  // --- Forma de los argumentos ---------------------------------------------
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'MESERO', ridPedido: 'demo' },
    esperado: { code: 'invalid-argument' },
    nota: 'allow-list ESTRICTA y sensible a mayúsculas: sin normalizar, "MESERO" no es un rol',
  },
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'mesero', ridPedido: 'Demo Café' },
    esperado: { code: 'invalid-argument' },
    nota: 'el rid es un slug: de él derivan los doc ID de mesa y por tanto los QR impresos (11-05)',
  },
  {
    entrada: { callerRole: 'super_admin', callerRid: null, rolPedido: 'mesero', ridPedido: undefined },
    esperado: { code: 'invalid-argument' },
    nota: 'el super NO tiene rid propio del que tirar: debe indicar el restaurante',
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: undefined, rolPedido: 'mesero', ridPedido: undefined },
    esperado: { code: 'failed-precondition' },
    nota: 'estado imposible salvo cuenta mal aprovisionada: NO es culpa del payload, así que no es invalid-argument',
  },
];

function nombreDe({ callerRole, callerRid, rolPedido, ridPedido }) {
  return `${callerRole}(${callerRid}) → ${rolPedido}@${ridPedido}`;
}

describe('autorizarAlta — tabla de la matriz de autorización', () => {
  for (const caso of CASOS) {
    const sufijo = caso.nota ? ` · ${caso.nota}` : '';
    it(`${nombreDe(caso.entrada)}${sufijo}`, () => {
      const d = autorizarAlta(caso.entrada);

      if (caso.esperado.rid !== undefined) {
        assert.equal(d.ok, true, `debía permitirse; devolvió ${JSON.stringify(d)}`);
        assert.equal(d.rid, caso.esperado.rid, 'rid efectivo');
        // Un permitido NO debe traer código ni mensaje de error.
        assert.equal(d.code, undefined);
      } else {
        assert.equal(d.ok, false, `debía denegarse; devolvió ${JSON.stringify(d)}`);
        assert.equal(d.code, caso.esperado.code, 'código de denegación');
        assert.equal(typeof d.msg, 'string');
        assert.ok(d.msg.length > 0, 'toda denegación lleva mensaje para la UI');
        // Una denegación NUNCA puede filtrar un rid efectivo.
        assert.equal(d.rid, undefined, 'una denegación no resuelve rid');
      }
    });
  }

  it('la tabla cubre exactamente los 19 casos declarados en el plan', () => {
    assert.equal(CASOS.length, 19);
  });
});

// ---------------------------------------------------------------------------
// TESTS DE PROPIEDAD — sobreviven a que alguien edite la tabla de arriba
// ---------------------------------------------------------------------------

describe('PROHIBICIÓN 1 (propiedad): nadie puede asignar super_admin', () => {
  it('`super_admin` no está en ROLES_ASIGNABLES', () => {
    assert.equal(ROLES_ASIGNABLES.includes('super_admin'), false);
  });

  it('para TODO llamador legítimo y TODO rid, rolPedido="super_admin" nunca devuelve ok', () => {
    const rids = [undefined, null, '', 'demo', 'otro', 'pizza-uno'];
    const ridsLlamador = [undefined, null, 'demo', 'otro'];
    let combinaciones = 0;

    for (const callerRole of ROLES_LLAMADORES) {
      for (const callerRid of ridsLlamador) {
        for (const ridPedido of rids) {
          const d = autorizarAlta({ callerRole, callerRid, rolPedido: 'super_admin', ridPedido });
          assert.equal(
            d.ok,
            false,
            `ESCALADA VERTICAL: ${callerRole}(${callerRid}) consiguió super_admin@${ridPedido}`,
          );
          combinaciones += 1;
        }
      }
    }
    // Si ROLES_LLAMADORES se quedara vacío, el bucle no probaría nada y el
    // test pasaría por vacuidad. Esto lo impide.
    assert.equal(combinaciones, ROLES_LLAMADORES.length * ridsLlamador.length * rids.length);
    assert.ok(combinaciones >= 48, `combinatoria demasiado pequeña: ${combinaciones}`);
  });
});

describe('PROHIBICIÓN 2 (propiedad): un admin_restaurante nunca toca otro rid', () => {
  it('para TODO rol asignable y TODO rid ajeno, la decisión niega o resuelve al rid propio', () => {
    const propios = ['demo', 'pizza-uno', 'la-esquina'];
    const ajenos = ['otro', 'demo-2', 'pizza-dos', 'LA-ESQUINA'];
    let combinaciones = 0;

    for (const callerRid of propios) {
      for (const rolPedido of ROLES_ASIGNABLES) {
        for (const ridPedido of ajenos) {
          if (ridPedido === callerRid) continue;
          const d = autorizarAlta({
            callerRole: 'admin_restaurante',
            callerRid,
            rolPedido,
            ridPedido,
          });
          assert.equal(
            d.ok,
            false,
            `ESCALADA HORIZONTAL: admin de ${callerRid} pasó con ridPedido=${ridPedido}`,
          );
          // Y, sobre todo: jamás resuelve al rid ajeno.
          assert.notEqual(d.rid, ridPedido);
          combinaciones += 1;
        }
      }
    }
    assert.equal(combinaciones, propios.length * ROLES_ASIGNABLES.length * ajenos.length);
  });

  it('cuando SÍ se permite, el rid efectivo es SIEMPRE el del llamador, nunca el pedido', () => {
    for (const rolPedido of ROLES_ASIGNABLES) {
      for (const ridPedido of [undefined, 'demo']) {
        const d = autorizarAlta({
          callerRole: 'admin_restaurante',
          callerRid: 'demo',
          rolPedido,
          ridPedido,
        });
        assert.equal(d.ok, true);
        assert.equal(d.rid, 'demo');
      }
    }
  });
});

describe('invariantes de las allow-lists y del slug', () => {
  it('los conjuntos son los de la decisión bloqueada del usuario', () => {
    assert.deepEqual(ROLES_ASIGNABLES, ['admin_restaurante', 'mesero', 'cocina']);
    assert.deepEqual(ROLES_LLAMADORES, ['super_admin', 'admin_restaurante']);
  });

  it('SLUG_RE acepta los slugs canónicos de 11-05 y rechaza el resto', () => {
    for (const ok of ['demo', 'pizza-uno', 'la-esquina-33', 'a', 'a1-b2-c3']) {
      assert.ok(SLUG_RE.test(ok), `debía aceptar ${ok}`);
    }
    for (const mal of [
      '',
      '-demo',
      'demo-',
      'demo--uno',
      'Demo',
      'demo café',
      'demo_uno',
      'demo/uno',
      'demo\n',
      'á',
    ]) {
      assert.equal(SLUG_RE.test(mal), false, `debía rechazar ${JSON.stringify(mal)}`);
    }
  });

  it('el módulo NO importa nada de Firebase (requisito para que esto corra sin emulador)', async () => {
    const { readFileSync } = await import('node:fs');
    const fuente = readFileSync(new URL('../src/auth-matrix.js', import.meta.url), 'utf8');
    assert.equal(
      /from\s+['"]firebase/.test(fuente),
      false,
      'auth-matrix.js debe seguir siendo lógica pura',
    );
    assert.equal(/require\(['"]firebase/.test(fuente), false);
  });
});
