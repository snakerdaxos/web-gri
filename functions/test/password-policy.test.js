// ============================================================================
// GRI — La politica de contrasenas del SERVIDOR frente a los vectores CANONICOS
// (Fase 11, plan 11-22).
//
// Corre con: cd functions && npm test   (sin emuladores)
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARCHIVO NO TIENE NI UN CASO ESCRITO A MANO
// ---------------------------------------------------------------------------
// La regla la fijo el usuario (11-CONTEXT.md, LOCKED) y hay TRES runtimes que
// tienen que aplicarla igual: las dos apps Flutter y esta funcion. Tres
// implementaciones son tres oportunidades de divergir en silencio, asi que las
// tres leen el MISMO archivo, `scripts/password_policy_vectors.json`. Anadir un
// vector alli ejercita los tres sin tocar ningun test.
//
// Que la politica viva TAMBIEN aqui no es redundancia: si solo estuviera en el
// cliente, bastaria con invocar `crearUsuarioStaff` directamente para saltarsela
// (T-11-22-01). El comportamiento extremo a extremo se prueba en
// `scripts/test/functions/crear-usuario-staff.e2e.mjs` contra emuladores reales;
// esto es la red de seguridad pura, que corre en milisegundos.
// ============================================================================

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';

import { faltantes, validarPassword } from '../src/password-policy.js';

const RUTA_VECTORES = new URL(
  '../../scripts/password_policy_vectors.json',
  import.meta.url,
);
const { vectores } = JSON.parse(readFileSync(RUTA_VECTORES, 'utf8'));

/**
 * Trozo de mensaje que DEBE aparecer cuando falta cada cosa y que NO debe
 * aparecer cuando no falta. Escrito a mano a proposito: comparar contra la
 * propia implementacion dejaria el caso verde justo cuando esta cambia.
 */
const HUELLA = {
  longitud: '8 caracteres',
  mayuscula: 'mayúscula',
  minuscula: 'minúscula',
  numero: 'número',
};

const ORDEN = ['longitud', 'mayuscula', 'minuscula', 'numero'];

/** Etiqueta legible: la cadena vacia y la muy larga no se imprimen tal cual. */
function etiqueta(p) {
  if (p === '') return '(vacía)';
  if (p.length > 20) return `${p.slice(0, 12)}…(${p.length} car.)`;
  return p;
}

describe('vectores canonicos · carga y bordes obligatorios', () => {
  it('el JSON canonico se lee y trae los bordes que pidio el usuario', () => {
    assert.ok(vectores.length >= 12, 'muy pocos vectores');
    const passwords = new Set(vectores.map((v) => v.password));
    for (const obligatorio of [
      'Abcdefg1', // exactamente 8, valida
      'Abcdef1', // 7, valida por composicion pero corta
      'abcdefg1', // sin mayuscula
      'ABCDEFG1', // sin minuscula
      'Abcdefgh', // sin numero
      'ABCDEFGH', // solo mayusculas
      '12345678', // solo digitos: el caso que hoy pasa
      '', // vacia
      'Abc def1', // con espacios
      'Ábcdefg1', // acento
      'añoNuev0', // enye
    ]) {
      assert.ok(
        passwords.has(obligatorio),
        `falta el borde «${etiqueta(obligatorio)}» en el JSON canonico`,
      );
    }
    assert.ok(
      [...passwords].some((p) => p.length >= 100),
      'falta el vector "muy larga" (no hay longitud maxima)',
    );
  });
});

describe('faltantes() coincide con los vectores canonicos', () => {
  for (const v of vectores) {
    it(`«${etiqueta(v.password)}» → [${v.faltan.join(', ')}]`, () => {
      assert.deepEqual(faltantes(v.password), v.faltan, v.nota);
    });
  }
});

describe('validarPassword() coincide con los vectores canonicos', () => {
  for (const v of vectores) {
    it(`«${etiqueta(v.password)}» → ${v.valida ? 'valida' : 'invalida'}`, () => {
      const msg = validarPassword(v.password);
      assert.equal(msg === null, v.valida, `mensaje real: ${msg}`);
      if (v.valida) return;

      // El mensaje NOMBRA lo que falta y NO nombra lo que no falta: es la
      // diferencia entre "te falta una mayuscula" y "contrasena invalida".
      for (const [clave, trozo] of Object.entries(HUELLA)) {
        assert.equal(
          msg.includes(trozo),
          v.faltan.includes(clave),
          `«${msg}» respecto a ${clave}`,
        );
      }
    });
  }
});

describe('contrato del orden y de la redaccion', () => {
  it('el orden es SIEMPRE longitud, mayuscula, minuscula, numero', () => {
    for (const v of vectores) {
      const indices = faltantes(v.password).map((k) => ORDEN.indexOf(k));
      assert.ok(
        indices.every((i) => i >= 0),
        `clave desconocida para «${etiqueta(v.password)}»`,
      );
      assert.deepEqual(
        indices,
        [...indices].sort((a, b) => a - b),
        `orden roto para «${etiqueta(v.password)}»`,
      );
    }
  });

  it('la redaccion concuerda en singular y plural', () => {
    // Escritos a mano: son EXACTAMENTE los mismos que fijan los dos tests
    // Dart. Si las tres implementaciones divergen en la redaccion, el panel
    // mostraria un texto distinto segun venga del formulario o del servidor.
    const esperados = {
      Abcdefg1: null,
      abcdefg1: 'Te falta una mayúscula.',
      ABCDEFG1: 'Te falta una minúscula.',
      Abcdefgh: 'Te falta un número.',
      ABCDEFGH: 'Te faltan una minúscula y un número.',
      12345678: 'Te faltan una mayúscula y una minúscula.',
      Abcdef1: 'Debe tener al menos 8 caracteres.',
      Abcdefg: 'Debe tener al menos 8 caracteres y te falta un número.',
      '': 'Debe tener al menos 8 caracteres y te faltan una mayúscula, una minúscula y un número.',
    };
    for (const [password, esperado] of Object.entries(esperados)) {
      assert.equal(validarPassword(password), esperado, `para «${password}»`);
    }
  });

  it('ningun mensaje es el generico que el usuario prohibio', () => {
    for (const v of vectores) {
      const msg = validarPassword(v.password);
      if (msg === null) continue;
      assert.ok(!msg.toLowerCase().includes('inválida'), msg);
      assert.ok(
        Object.values(HUELLA).some((t) => msg.includes(t)),
        `el mensaje «${msg}» no dice QUE falta`,
      );
    }
  });

  it('una entrada que no es cadena se trata como vacia, no revienta', () => {
    // La callable recibe el payload de un cliente que puede mentir en el tipo.
    for (const basura of [undefined, null, 12345678, {}, []]) {
      assert.deepEqual(faltantes(basura), ORDEN);
      assert.equal(typeof validarPassword(basura), 'string');
    }
  });
});
