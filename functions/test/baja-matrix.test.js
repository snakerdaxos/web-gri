// ============================================================================
// GRI — Combinatoria de la matriz de la BAJA de staff (Fase 11, plan 24)
//
// Corre con: cd functions && npm test   (glob `test/*.test.js`; `node --test
// test/` NO funciona en Node 24 — hallazgo de 11-01, reconfirmado en 11-08).
// SIN emuladores, SIN red, en milisegundos: `baja-matrix.js` es lógica PURA.
//
// ---------------------------------------------------------------------------
// LAS DOS PROHIBICIONES NUEVAS (decisión BLOQUEADA, 11-CONTEXT «Baja de
// personal»), cada una marcada en la tabla para que sean localizables en una
// auditoría con un `grep`:
//   // PROHIBICION-1 → nadie puede desactivar a un `super_admin`.
//   // PROHIBICION-2 → nadie puede desactivarse a sí mismo.
//
// ---------------------------------------------------------------------------
// POR QUÉ CADA DENEGACIÓN ASSERTA EL MENSAJE LITERAL, NO SOLO EL CÓDIGO
// ---------------------------------------------------------------------------
// CINCO controles de esta matriz devuelven `permission-denied`. Un caso que
// solo comprobara el código estaría verde aunque lo denegara OTRO control: es
// exactamente el verde por el motivo equivocado que 11-08 cazó en su caso
// ESCALADA HORIZONTAL (asertaba el código y sobrevivía con el arnés roto).
// Aquí es aún más grave, porque la PROHIBICION-2 sobre un objetivo que además
// es `super_admin` la caza la PROHIBICION-1 por el orden de comprobaciones.
// Por eso: (a) toda denegación asserta el texto EXACTO, escrito a mano en este
// archivo —jamás importado del módulo, que lo dejaría verde justo cuando el
// mensaje cambia—, y (b) la PROHIBICION-2 tiene un caso AISLADO cuyo objetivo
// NO es `super_admin`, que es el único que muere si se quita su control.
// ============================================================================

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ROLES_LLAMADORES } from '../src/auth-matrix.js';
import { ROLES_GESTIONABLES, autorizarCambioEstado } from '../src/baja-matrix.js';

// Mensajes esperados. ESCRITOS A MANO a propósito (ver cabecera).
const MSG_LLAMADOR = 'Solo super_admin o admin_restaurante pueden cambiar el estado del personal.';
const MSG_SUPER = 'No se puede cambiar el estado de una cuenta de plataforma.';
const MSG_SELF = 'No puedes cambiar el estado de tu propia cuenta.';
const MSG_TENANT = 'No puedes cambiar el estado de personal de otro restaurante.';
const MSG_NO_STAFF = 'Esta operación es solo para personal del restaurante.';
const MSG_SIN_RID = 'Tu cuenta no tiene restaurante asignado.';

/**
 * Tabla de casos. `esperado`: `{ok: true}` o `{code, msg}`.
 *
 * Las columnas son exactamente las del plan:
 * `[callerRole, callerRid, callerUid, objetivoRole, objetivoRid, objetivoUid]`.
 */
const CASOS = [
  // --- super_admin: sobre staff de cualquier restaurante -------------------
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { ok: true },
  },
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: 'admin_restaurante', objetivoRid: 'otro', objetivoUid: 'u2' },
    esperado: { ok: true },
    nota: 'el super alcanza cualquier tenant, también al admin de un restaurante ajeno',
  },

  // --- admin_restaurante: SOLO su propio rid --------------------------------
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { ok: true },
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'admin_restaurante', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { ok: true },
    nota: 'PERMITIDO por la decisión del usuario: dos socios, y uno puede dar de baja al otro',
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'cocina', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { ok: true },
  },

  // PROHIBICION-1 · nadie desactiva a un super_admin -------------------------
  // PROHIBICION-1
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: 'super_admin', objetivoRid: null, objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_SUPER },
    nota: 'PROHIBICION-1 · ni siquiera otro super_admin puede hacerlo',
  },
  // PROHIBICION-1
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'super_admin', objetivoRid: null, objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_SUPER },
    nota: 'PROHIBICION-1 · un admin no puede apagar la plataforma',
  },

  // PROHIBICION-2 · nadie se desactiva a sí mismo ----------------------------
  // PROHIBICION-2
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u1' },
    esperado: { code: 'permission-denied', msg: MSG_SELF },
    nota: 'PROHIBICION-2 AISLADA · el objetivo NO es super_admin, así que este caso SOLO puede morir por el control de auto-baja',
  },
  // PROHIBICION-2
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'admin_restaurante', objetivoRid: 'demo', objetivoUid: 'u1' },
    esperado: { code: 'permission-denied', msg: MSG_SELF },
    nota: 'PROHIBICION-2 · el escenario real: el único admin se dejaría el restaurante sin administrador',
  },
  // PROHIBICION-1 PROHIBICION-2
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: 'super_admin', objetivoRid: null, objetivoUid: 'u1' },
    esperado: { code: 'permission-denied', msg: MSG_SUPER },
    nota: 'las DOS prohibiciones aplican; gana la 1 por el ORDEN de comprobaciones — este caso NO sirve para probar la 2 (por eso existe el aislado de arriba)',
  },

  // --- Cruce de tenant ------------------------------------------------------
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'otro', objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_TENANT },
  },
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'cliente', objetivoRid: null, objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_TENANT },
    nota: 'un cliente no pertenece a ningún rid: para un admin lo corta el alcance de tenant ANTES que la allow-list de objetivos',
  },

  // --- Llamadores no autorizados -------------------------------------------
  {
    entrada: { callerRole: 'mesero', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'cocina', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_LLAMADOR },
  },
  {
    entrada: { callerRole: 'cocina', callerRid: 'demo', callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_LLAMADOR },
  },
  {
    entrada: { callerRole: 'cliente', callerRid: null, callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_LLAMADOR },
  },
  {
    entrada: { callerRole: undefined, callerRid: null, callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_LLAMADOR },
    nota: 'un cliente auto-registrado no lleva claim `role` (11-04): la ausencia se deniega',
  },

  // --- Llamador mal aprovisionado ------------------------------------------
  {
    entrada: { callerRole: 'admin_restaurante', callerRid: undefined, callerUid: 'u1', objetivoRole: 'mesero', objetivoRid: 'demo', objetivoUid: 'u2' },
    esperado: { code: 'failed-precondition', msg: MSG_SIN_RID },
    nota: 'no es culpa del payload, así que no es invalid-argument',
  },

  // --- El objetivo tiene que ser PERSONAL (hueco del alcance del plan) ------
  // El plan declara «desactivar clientes» fuera de alcance razonando que «un
  // cliente no pertenece a ningún rid». Ese razonamiento solo cierra la puerta
  // para un `admin_restaurante` (a quien lo corta el alcance de tenant): el
  // `super_admin` NO tiene rid contra el que comparar y pasaría. Estos dos
  // casos cubren el hueco.
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: 'cliente', objetivoRid: null, objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_NO_STAFF },
    nota: 'esto es gestión de PERSONAL: un cliente de la app móvil no se toca por esta vía',
  },
  {
    entrada: { callerRole: 'super_admin', callerRid: null, callerUid: 'u1', objetivoRole: undefined, objetivoRid: null, objetivoUid: 'u2' },
    esperado: { code: 'permission-denied', msg: MSG_NO_STAFF },
    nota: 'cuenta sin rol ni en claims ni en el espejo: indistinguible de un cliente auto-registrado',
  },
];

function nombreDe({ callerRole, callerRid, callerUid, objetivoRole, objetivoRid, objetivoUid }) {
  return `${callerRole}(${callerRid})/${callerUid} -> ${objetivoRole}@${objetivoRid}/${objetivoUid}`;
}

function comprobar(caso, decision) {
  if (caso.esperado.ok) {
    assert.equal(decision.ok, true, `debía permitirse; devolvió ${JSON.stringify(decision)}`);
    assert.equal(decision.code, undefined, 'un permitido no trae código');
    assert.equal(decision.msg, undefined, 'un permitido no trae mensaje');
  } else {
    assert.equal(decision.ok, false, `debía denegarse; devolvió ${JSON.stringify(decision)}`);
    assert.equal(decision.code, caso.esperado.code, 'código de denegación');
    // IDENTIDAD del mensaje: sin esto, los cinco controles que comparten
    // `permission-denied` son indistinguibles entre sí (lección de 11-08).
    assert.equal(decision.msg, caso.esperado.msg, 'mensaje de denegación');
  }
}

// La tabla se recorre DOS VECES. `autorizarCambioEstado` no recibe `activo` a
// propósito —la decisión no depende del sentido de la operación—, así que se le
// pasa igualmente como campo extra: si alguien añadiera una rama condicionada a
// `activo`, estos casos la destaparían. Reactivar a un super_admin o a uno mismo
// tampoco está permitido.
for (const activo of [true, false]) {
  describe(`autorizarCambioEstado — tabla de la matriz (activo: ${activo})`, () => {
    for (const caso of CASOS) {
      const sufijo = caso.nota ? ` · ${caso.nota}` : '';
      it(`${nombreDe(caso.entrada)}${sufijo}`, () => {
        comprobar(caso, autorizarCambioEstado({ ...caso.entrada, activo }));
      });
    }
  });
}

describe('la tabla no puede encoger en silencio', () => {
  it('cubre los 19 casos declarados', () => {
    assert.equal(CASOS.length, 19);
  });

  it('la decisión es IDÉNTICA para activo:true y activo:false en los 19 casos', () => {
    for (const caso of CASOS) {
      const conTrue = autorizarCambioEstado({ ...caso.entrada, activo: true });
      const conFalse = autorizarCambioEstado({ ...caso.entrada, activo: false });
      assert.deepEqual(
        conTrue,
        conFalse,
        `la decisión depende del sentido de la operación en ${nombreDe(caso.entrada)}`,
      );
    }
  });

  // OJO: la primera versión de este gate contaba `/\/\/ PROHIBICION-1/g` sobre
  // todo el archivo y salía 5, porque casaba también con la CABECERA y con el
  // separador de sección. Un gate que cuenta menciones no distingue "hay un
  // caso marcado" de "alguien nombró la prohibición en un comentario" — el
  // mismo defecto que 11-13 documentó en su `grep` de RenderFlex. Se cuentan
  // líneas cuyo contenido es EXACTAMENTE la marca, y además se ata la marca al
  // CONTENIDO de la tabla: si alguien borra una fila y deja la marca, o al
  // revés, el conteo cruzado se pone rojo.
  it('las prohibiciones están marcadas en las filas, y las marcas coinciden con los casos', async () => {
    const { readFileSync } = await import('node:fs');
    const fuente = readFileSync(new URL('./baja-matrix.test.js', import.meta.url), 'utf8');
    const marcas = fuente
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => /^\/\/ PROHIBICION-[12]( PROHIBICION-2)?$/.test(l));

    const soloUno = marcas.filter((m) => m === '// PROHIBICION-1').length;
    const soloDos = marcas.filter((m) => m === '// PROHIBICION-2').length;
    const ambas = marcas.filter((m) => m === '// PROHIBICION-1 PROHIBICION-2').length;

    assert.equal(soloUno, 2, 'dos filas marcadas solo con la prohibición 1');
    assert.equal(soloDos, 2, 'dos filas marcadas solo con la prohibición 2');
    assert.equal(ambas, 1, 'una fila donde las dos concurren');

    // Amarre al contenido: las filas marcadas son EXACTAMENTE las que esperan
    // el mensaje de cada prohibición.
    const conMsg = (msg) => CASOS.filter((c) => c.esperado.msg === msg).length;
    assert.equal(conMsg(MSG_SUPER), soloUno + ambas, 'filas que mueren por la prohibición 1');
    assert.equal(conMsg(MSG_SELF), soloDos, 'filas que mueren por la prohibición 2');
  });
});

// ---------------------------------------------------------------------------
// TESTS DE PROPIEDAD — sobreviven a que alguien edite la tabla de arriba
// ---------------------------------------------------------------------------

describe('PROHIBICIÓN 1 (propiedad): nadie puede tocar a un super_admin', () => {
  it('`super_admin` no está en ROLES_GESTIONABLES', () => {
    assert.equal(ROLES_GESTIONABLES.includes('super_admin'), false);
  });

  it('para TODO llamador válido, TODO rid y los DOS sentidos, un objetivo super_admin nunca es ok', () => {
    const ridsLlamador = [undefined, null, 'demo', 'otro'];
    const ridsObjetivo = [undefined, null, 'demo', 'otro'];
    const uids = ['u1', 'u2'];
    let combinaciones = 0;

    for (const callerRole of ROLES_LLAMADORES) {
      for (const callerRid of ridsLlamador) {
        for (const objetivoRid of ridsObjetivo) {
          for (const objetivoUid of uids) {
            for (const activo of [true, false]) {
              const d = autorizarCambioEstado({
                callerRole,
                callerRid,
                callerUid: 'u1',
                objetivoRole: 'super_admin',
                objetivoRid,
                objetivoUid,
                activo,
              });
              assert.equal(
                d.ok,
                false,
                `PROHIBICION-1 rota: ${callerRole}(${callerRid}) sobre super_admin@${objetivoRid}/${objetivoUid} con activo=${activo}`,
              );
              // MEDIDO: sin esta línea el test estaba VERDE POR EL MOTIVO
              // EQUIVOCADO. Al quitar la prohibición 1 del módulo (rotura A),
              // un objetivo `super_admin` seguía denegándose —lo cazaba la
              // allow-list de objetivos del paso 5, porque `super_admin`
              // tampoco está ahí— y esta propiedad no se enteraba. La
              // prohibición 1 va ANTES que todo lo demás salvo el control de
              // llamador, así que el mensaje es SIEMPRE éste; exigirlo es lo
              // que ata la propiedad al control que dice proteger.
              assert.equal(
                d.msg,
                MSG_SUPER,
                `PROHIBICION-1 denegada por OTRO control: ${callerRole}(${callerRid}) sobre super_admin@${objetivoRid}/${objetivoUid}`,
              );
              combinaciones += 1;
            }
          }
        }
      }
    }
    // Sin esto, vaciar ROLES_LLAMADORES dejaría el bucle sin iteraciones y el
    // test pasaría por vacuidad.
    assert.equal(
      combinaciones,
      ROLES_LLAMADORES.length * ridsLlamador.length * ridsObjetivo.length * uids.length * 2,
    );
    assert.ok(combinaciones >= 128, `combinatoria demasiado pequeña: ${combinaciones}`);
  });
});

describe('PROHIBICIÓN 2 (propiedad): nadie puede cambiar su propio estado', () => {
  it('para TODO llamador válido, TODO rol de objetivo y los DOS sentidos, objetivoUid === callerUid nunca es ok', () => {
    const rolesObjetivo = [...ROLES_GESTIONABLES, 'super_admin', 'cliente', undefined];
    const rids = [undefined, null, 'demo', 'otro'];
    let combinaciones = 0;

    for (const callerRole of ROLES_LLAMADORES) {
      for (const callerRid of rids) {
        for (const objetivoRole of rolesObjetivo) {
          for (const objetivoRid of rids) {
            for (const activo of [true, false]) {
              const d = autorizarCambioEstado({
                callerRole,
                callerRid,
                callerUid: 'yo',
                objetivoRole,
                objetivoRid,
                objetivoUid: 'yo',
                activo,
              });
              assert.equal(
                d.ok,
                false,
                `PROHIBICION-2 rota: ${callerRole}(${callerRid}) sobre sí mismo como ${objetivoRole}@${objetivoRid} con activo=${activo}`,
              );
              combinaciones += 1;
            }
          }
        }
      }
    }
    assert.equal(
      combinaciones,
      ROLES_LLAMADORES.length * rids.length * rolesObjetivo.length * rids.length * 2,
    );
    assert.ok(combinaciones >= 256, `combinatoria demasiado pequeña: ${combinaciones}`);
  });

  it('el control de auto-baja es INDEPENDIENTE del de super_admin: con objetivo NO super, la auto-baja sigue denegada con SU mensaje', () => {
    for (const callerRole of ROLES_LLAMADORES) {
      for (const objetivoRole of ROLES_GESTIONABLES) {
        const rid = callerRole === 'super_admin' ? null : 'demo';
        const d = autorizarCambioEstado({
          callerRole,
          callerRid: rid,
          callerUid: 'yo',
          objetivoRole,
          objetivoRid: 'demo',
          objetivoUid: 'yo',
        });
        assert.equal(d.ok, false);
        assert.equal(d.msg, MSG_SELF, `${callerRole} sobre sí mismo como ${objetivoRole}`);
      }
    }
  });
});

describe('PROHIBICIÓN 3 (alcance de tenant, la misma del alta)', () => {
  it('un admin_restaurante nunca alcanza un objetivo de otro rid', () => {
    const propios = ['demo', 'pizza-uno', 'la-esquina'];
    const ajenos = ['otro', 'demo-2', 'pizza-dos', null, undefined];
    let combinaciones = 0;

    for (const callerRid of propios) {
      for (const objetivoRole of ROLES_GESTIONABLES) {
        for (const objetivoRid of ajenos) {
          const d = autorizarCambioEstado({
            callerRole: 'admin_restaurante',
            callerRid,
            callerUid: 'u1',
            objetivoRole,
            objetivoRid,
            objetivoUid: 'u2',
          });
          assert.equal(d.ok, false, `cruce de tenant: admin de ${callerRid} alcanzó ${objetivoRid}`);
          assert.equal(d.msg, MSG_TENANT);
          combinaciones += 1;
        }
      }
    }
    assert.equal(combinaciones, propios.length * ROLES_GESTIONABLES.length * ajenos.length);
  });
});

describe('invariantes del módulo', () => {
  it('ROLES_GESTIONABLES es exactamente el personal de un restaurante', () => {
    assert.deepEqual(ROLES_GESTIONABLES, ['admin_restaurante', 'mesero', 'cocina']);
  });

  it('las constantes de roles de LLAMADOR se COMPARTEN con auth-matrix.js, no se duplican', async () => {
    const { readFileSync } = await import('node:fs');
    const fuente = readFileSync(new URL('../src/baja-matrix.js', import.meta.url), 'utf8');
    assert.ok(
      /import\s*\{[^}]*ROLES_LLAMADORES[^}]*\}\s*from\s*['"]\.\/auth-matrix\.js['"]/.test(fuente),
      'ROLES_LLAMADORES debe importarse de auth-matrix.js (una sola fuente de verdad)',
    );
    assert.equal(
      /const\s+ROLES_LLAMADORES\s*=/.test(fuente),
      false,
      'no se puede redeclarar ROLES_LLAMADORES aquí: divergiría del alta en silencio',
    );
  });

  it('el módulo NO importa nada de Firebase (requisito para correr sin emulador)', async () => {
    const { readFileSync } = await import('node:fs');
    const fuente = readFileSync(new URL('../src/baja-matrix.js', import.meta.url), 'utf8');
    assert.equal(/from\s+['"]firebase/.test(fuente), false, 'baja-matrix.js debe ser lógica pura');
    assert.equal(/require\(['"]firebase/.test(fuente), false);
  });
});
