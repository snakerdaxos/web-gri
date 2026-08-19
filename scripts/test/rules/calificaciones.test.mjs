// ============================================================================
// GRI — Tests de `firestore.rules` para `match /calificaciones/{pedidoId}`.
//
// Doc ID = pedidoId → una calificación por pedido, 1:1, garantizada por el
// propio identificador. Es la regla con MÁS access-calls del sistema
// (2 docs / 4 gets) porque valida una CADENA:
//
//   calificacion → pedidos/{pedidoId}          (¿es tuyo? ¿está servido?)
//                → sesiones/{pedido.sesionId}  (¿la mesa ya cerró?)
//
// El get() anidado (`sesiones/$(get(pedidos/...).data.sesionId)`) es lo que
// hace que sembrar mal el fixture produzca falsos verdes: por eso el arrange
// vive en `sembrarCadenaCalificable()`, que siembra SIEMPRE los dos eslabones.
//
//   read           : true (público — la nota sale en el descubrimiento)
//   create         : isCliente + pedido propio + servido + sesión cerrada
//                    + pedidoId == docId + usuarioId propio
//                    + rid == rid del pedido + estrellas int 1..5
//   update, delete : false (la calificación es INMUTABLE)
//
// ⚠️ `initEnv('calificaciones')`: namespace propio obligatorio (_contexts.mjs).
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  adminDemo,
  anon,
  cliente,
  initEnv,
  sembrar,
  superAdmin,
} from './_contexts.mjs';

const RID = 'demo';
const OTRO = 'otro';

const DUENO = 'uid-cliente';
const INTRUSO = 'uid-cliente-intruso';

const AHORA = new Date('2026-08-19T12:00:00Z');

// Un pedido por combinación de la cadena. El doc ID de la calificación ES el
// del pedido, así que cada caso necesita su propio pedido.
const P_CALIFICABLE = 'ped-servido-cerrada'; // propio + servido + sesión cerrada
const P_NO_SERVIDO = 'ped-en-preparacion'; // propio + NO servido
const P_SESION_ABIERTA = 'ped-servido-activa'; // propio + servido + sesión ACTIVA
const P_AJENO = 'ped-de-otro'; // servido + sesión cerrada, pero de otro
const P_YA_CALIFICADO = 'ped-ya-calificado'; // con calificación existente

/**
 * Siembra los DOS eslabones que la regla recorre con su get() anidado.
 * Sin la sesión, la regla no falla por "sesión no cerrada" sino por doc
 * inexistente — el test pasaría por la razón equivocada.
 *
 * @param {import('firebase/firestore').Firestore} db  db con rules DESACTIVADAS
 * @param {{pedidoId: string, sesionId: string, usuarioId?: string,
 *          estadoPedido?: string, estadoSesion?: string, restauranteId?: string}} opts
 */
async function sembrarCadenaCalificable(db, opts) {
  const {
    pedidoId,
    sesionId,
    usuarioId = DUENO,
    estadoPedido = 'servido',
    estadoSesion = 'cerrada',
    restauranteId = RID,
  } = opts;

  await setDoc(doc(db, 'sesiones', sesionId), {
    mesaId: sesionId,
    restauranteId,
    usuarioId,
    estado: estadoSesion,
    cuentaSolicitada: true,
    createdAt: AHORA,
  });
  await setDoc(doc(db, 'pedidos', pedidoId), {
    sesionId,
    mesaId: sesionId,
    restauranteId,
    usuarioId,
    estado: estadoPedido,
    items: [{ productoId: 'p-ok', nombre: 'Bandeja paisa', precio: 25000, cantidad: 1 }],
    total: 25000,
    createdAt: AHORA,
  });
}

/** Payload válido de create; los tests lo mutan campo a campo. */
function calificacionValida(pedidoId, overrides = {}) {
  return {
    pedidoId,
    restauranteId: RID,
    usuarioId: DUENO,
    estrellas: 5,
    comentario: 'Todo excelente',
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — calificaciones', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('calificaciones');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await sembrarCadenaCalificable(db, {
        pedidoId: P_CALIFICABLE,
        sesionId: 'GRI-MESA-demo-002',
      });
      await sembrarCadenaCalificable(db, {
        pedidoId: P_NO_SERVIDO,
        sesionId: 'GRI-MESA-demo-003',
        estadoPedido: 'en_preparacion',
        estadoSesion: 'activa',
      });
      await sembrarCadenaCalificable(db, {
        pedidoId: P_SESION_ABIERTA,
        sesionId: 'GRI-MESA-demo-004',
        estadoSesion: 'activa',
      });
      await sembrarCadenaCalificable(db, {
        pedidoId: P_AJENO,
        sesionId: 'GRI-MESA-demo-006',
        usuarioId: INTRUSO,
      });
      await sembrarCadenaCalificable(db, {
        pedidoId: P_YA_CALIFICADO,
        sesionId: 'GRI-MESA-demo-008',
      });
      await setDoc(doc(db, 'calificaciones', P_YA_CALIFICADO), {
        pedidoId: P_YA_CALIFICADO,
        restauranteId: RID,
        usuarioId: DUENO,
        estrellas: 4,
        comentario: 'Bien',
        createdAt: AHORA,
      });
    });
  });

  // --- read: público ---------------------------------------------------------

  describe('read — público por diseño (alimenta el descubrimiento)', () => {
    it('un ANÓNIMO puede leer una calificación', async () => {
      await assertSucceeds(getDoc(doc(anon(env), 'calificaciones', P_YA_CALIFICADO)));
    });

    it('un CLIENTE puede leer la calificación de otra persona', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, INTRUSO), 'calificaciones', P_YA_CALIFICADO)));
    });
  });

  // --- create: la cadena completa --------------------------------------------

  describe('create — solo el cliente, sobre su pedido servido y con la mesa cerrada', () => {
    it('CLIENTE con pedido propio SERVIDO y sesión CERRADA: 5 estrellas aceptadas', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE),
        ),
      );
    });

    it('1 estrella también se acepta (el borde inferior es inclusivo)', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { estrellas: 1 }),
        ),
      );
    });

    it('pedido NO servido: DENEGADO (no se califica lo que no se ha comido)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_NO_SERVIDO),
          calificacionValida(P_NO_SERVIDO),
        ),
      );
    });

    it('sesión aún ACTIVA: DENEGADO (la mesa no ha terminado)', async () => {
      // Es el get() ANIDADO el que lo detecta: pedido → sesionId → estado.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_SESION_ABIERTA),
          calificacionValida(P_SESION_ABIERTA),
        ),
      );
    });

    it('pedido de OTRA persona: DENEGADO (calificar en nombre ajeno)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'calificaciones', P_AJENO), calificacionValida(P_AJENO)),
      );
    });

    it('estrellas 0: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { estrellas: 0 }),
        ),
      );
    });

    it('estrellas 6: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { estrellas: 6 }),
        ),
      );
    });

    it('estrellas 4.5 (no entera): DENEGADO — `estrellas is int` corta el decimal', async () => {
      // Sin este chequeo, un 4.5 desviaría el agregado califProm del
      // restaurante, que se calcula sobre enteros.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { estrellas: 4.5 }),
        ),
      );
    });

    it('restauranteId distinto al del pedido: DENEGADO — ESCALADA cross-tenant', async () => {
      // Sin esta comprobación se podría inflar (o hundir) la nota de otro
      // restaurante calificando un pedido propio.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { restauranteId: OTRO }),
        ),
      );
    });

    it('campo pedidoId distinto del doc ID: DENEGADO (rompería el 1:1)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { pedidoId: P_AJENO }),
        ),
      );
    });

    it('usuarioId de otra persona: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { usuarioId: INTRUSO }),
        ),
      );
    });

    it('un ANÓNIMO no puede calificar: isCliente() exige signedIn()', async () => {
      await assertFails(
        setDoc(doc(anon(env), 'calificaciones', P_CALIFICABLE), calificacionValida(P_CALIFICABLE)),
      );
    });

    it('el ADMIN del restaurante no puede auto-calificarse: la regla es isCliente()', async () => {
      await assertFails(
        setDoc(
          doc(adminDemo(env), 'calificaciones', P_CALIFICABLE),
          calificacionValida(P_CALIFICABLE, { usuarioId: 'uid-admin-demo' }),
        ),
      );
    });
  });

  // --- update / delete: inmutable --------------------------------------------

  describe('update y delete — la calificación es inmutable (allow: if false)', () => {
    it('el AUTOR no puede cambiar sus estrellas después de publicarlas', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'calificaciones', P_YA_CALIFICADO), { estrellas: 1 }),
      );
    });

    it('el AUTOR no puede borrar su calificación', async () => {
      await assertFails(deleteDoc(doc(cliente(env, DUENO), 'calificaciones', P_YA_CALIFICADO)));
    });

    it('el ADMIN del restaurante no puede borrar una mala reseña', async () => {
      // Es la garantía de que la nota pública no la edita el calificado.
      await assertFails(deleteDoc(doc(adminDemo(env), 'calificaciones', P_YA_CALIFICADO)));
    });

    it('el ADMIN del restaurante tampoco puede editarla', async () => {
      await assertFails(
        updateDoc(doc(adminDemo(env), 'calificaciones', P_YA_CALIFICADO), { estrellas: 5 }),
      );
    });

    it('ni el SUPER_ADMIN puede borrarla desde el cliente (solo el Admin SDK)', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'calificaciones', P_YA_CALIFICADO)));
    });

    it('sobrescribir con set() una calificación existente queda denegado (set = update)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'calificaciones', P_YA_CALIFICADO),
          calificacionValida(P_YA_CALIFICADO, { estrellas: 1 }),
        ),
      );
    });
  });
});
