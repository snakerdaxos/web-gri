// ============================================================================
// GRI — Tests de `firestore.rules` para `match /reservas/{reservaId}`.
//
// Doc ID = `{mesaId}_{yyyyMMdd}_{HH}` → 1 reserva por mesa y franja horaria.
// La unicidad del slot la garantiza el doc ID, no una regla: por eso aquí se
// prueba lo que la regla SÍ decide.
//
//   create : isCliente + usuarioId propio + estado 'confirmada'
//            + fecha > request.time            (nada de reservar en el pasado)
//            + numPersonas entre 1 y 20
//            + rid de la mesa == rid de la reserva      (1 access-call)
//            + numPersonas <= capacidad REAL de la mesa (mismo doc: cacheado)
//   update : soloEstado + estado 'cancelada' + (dueño de reserva futura | staff)
//   delete : false
//
// ⚠️ NO OBVIO — `fecha` se compara contra `request.time`, que es un TIMESTAMP.
// Hay que sembrar y enviar `Date`/`Timestamp` reales, nunca un string ISO: un
// string nunca es > timestamp y el test pasaría por la razón equivocada.
//
// ⚠️ La capacidad se re-lee del servidor. Es la mitigación de que el cliente
// mande `numPersonas: 20` sobre una mesa de 2: el número que manda la app no
// se cree, se contrasta.
//
// ⚠️ `initEnv('reservas')`: namespace propio obligatorio (ver _contexts.mjs).
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  adminDemo,
  adminOtro,
  cliente,
  initEnv,
  mesero,
  sembrar,
  superAdmin,
} from './_contexts.mjs';

const RID = 'demo';
const OTRO = 'otro';

const DUENO = 'uid-cliente';
const INTRUSO = 'uid-cliente-intruso';

const M_NORMAL = 'GRI-MESA-demo-001'; // capacidad 4
const M_GRANDE = 'GRI-MESA-demo-020'; // capacidad 30 — aísla el tope duro de 20

// Timestamps REALES (no strings): la regla compara contra request.time.
const FUTURO = new Date('2030-01-15T20:00:00Z');
const PASADO = new Date('2020-01-15T20:00:00Z');
const AHORA = new Date('2026-08-19T12:00:00Z');

const R_FUTURA = 'GRI-MESA-demo-001_20300115_20';
const R_PASADA = 'GRI-MESA-demo-001_20200115_20';

/** Payload válido de create; los tests lo mutan campo a campo. */
function reservaValida(overrides = {}) {
  return {
    mesaId: M_NORMAL,
    restauranteId: RID,
    usuarioId: DUENO,
    estado: 'confirmada',
    fecha: FUTURO,
    numPersonas: 4,
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — reservas', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('reservas');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'mesas', M_NORMAL), {
        restauranteId: RID,
        numero: 1,
        capacidad: 4,
        estado: 'disponible',
        updatedAt: AHORA,
      });
      await setDoc(doc(db, 'mesas', M_GRANDE), {
        restauranteId: RID,
        numero: 20,
        capacidad: 30,
        estado: 'disponible',
        updatedAt: AHORA,
      });

      // Reserva futura del dueño: la que se puede cancelar.
      await setDoc(doc(db, 'reservas', R_FUTURA), {
        mesaId: M_NORMAL,
        restauranteId: RID,
        usuarioId: DUENO,
        estado: 'confirmada',
        fecha: FUTURO,
        numPersonas: 4,
        createdAt: AHORA,
      });
      // Reserva ya pasada: el cliente ya no manda sobre ella (sí el staff).
      await setDoc(doc(db, 'reservas', R_PASADA), {
        mesaId: M_NORMAL,
        restauranteId: RID,
        usuarioId: DUENO,
        estado: 'confirmada',
        fecha: PASADO,
        numPersonas: 4,
        createdAt: AHORA,
      });
    });
  });

  // --- read ------------------------------------------------------------------

  describe('read — dueño, staff del tenant o super', () => {
    it('el DUEÑO puede leer su reserva', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, DUENO), 'reservas', R_FUTURA)));
    });

    it('OTRO cliente NO puede leer la reserva ajena', async () => {
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'reservas', R_FUTURA)));
    });

    it('el MESERO del tenant puede leerla (gestiona la agenda del salón)', async () => {
      await assertSucceeds(getDoc(doc(mesero(env), 'reservas', R_FUTURA)));
    });

    it('el ADMIN de OTRO tenant NO puede leerla — ESCALADA cross-tenant', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'reservas', R_FUTURA)));
    });

    it('el SUPER_ADMIN puede leer cualquier reserva', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'reservas', R_FUTURA)));
    });
  });

  // --- create ----------------------------------------------------------------

  describe('create — reservar un slot futuro que quepa en la mesa', () => {
    it('CLIENTE con fecha futura y 4 personas en una mesa de 4: reserva creada', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300220_21'),
          reservaValida(),
        ),
      );
    });

    it('fecha en el PASADO: DENEGADO (no se reserva hacia atrás)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20200220_21'),
          reservaValida({ fecha: PASADO }),
        ),
      );
    });

    it('numPersonas 5 en una mesa de capacidad 4: DENEGADO (capacidad releída del servidor)', async () => {
      // El cliente podría mandar cualquier número: la regla lo contrasta con la
      // capacidad real de la mesa, no con lo que declare la app.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300221_21'),
          reservaValida({ numPersonas: 5 }),
        ),
      );
    });

    it('numPersonas 0: DENEGADO (mínimo 1)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300222_21'),
          reservaValida({ numPersonas: 0 }),
        ),
      );
    });

    it('numPersonas 21 en una mesa de capacidad 30: DENEGADO por el tope duro de 20', async () => {
      // La mesa daría de sí, pero el tope de grupo es una regla de negocio
      // independiente de la capacidad física.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-020_20300222_21'),
          reservaValida({ mesaId: M_GRANDE, numPersonas: 21 }),
        ),
      );
    });

    it('numPersonas 20 en una mesa de capacidad 30: PERMITIDO (el borde es inclusivo)', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-020_20300223_21'),
          reservaValida({ mesaId: M_GRANDE, numPersonas: 20 }),
        ),
      );
    });

    it('restauranteId distinto al de la mesa: DENEGADO — ESCALADA cross-tenant', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300224_21'),
          reservaValida({ restauranteId: OTRO }),
        ),
      );
    });

    it('usuarioId de otra persona: DENEGADO (reservar a nombre ajeno)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300225_21'),
          reservaValida({ usuarioId: INTRUSO }),
        ),
      );
    });

    it('reserva que nace ya "cancelada": DENEGADO (solo se crea confirmada)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300226_21'),
          reservaValida({ estado: 'cancelada' }),
        ),
      );
    });

    it('el MESERO no puede crear una reserva: la regla de create es isCliente()', async () => {
      // Comportamiento ACTUAL fijado por escrito: hoy no existe la reserva
      // telefónica tomada por el salón. Ampliarlo sería un cambio consciente.
      await assertFails(
        setDoc(doc(mesero(env), 'reservas', 'GRI-MESA-demo-001_20300227_21'), reservaValida()),
      );
    });
  });

  // --- update ----------------------------------------------------------------

  describe('update — cancelar, y solo cancelar', () => {
    it('el DUEÑO puede cancelar su reserva futura', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env, DUENO), 'reservas', R_FUTURA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });

    it('OTRO cliente NO puede cancelar la reserva ajena', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, INTRUSO), 'reservas', R_FUTURA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });

    it('el DUEÑO NO puede cancelar una reserva ya pasada (la regla exige fecha futura)', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'reservas', R_PASADA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });

    it('el MESERO del tenant sí puede marcar cancelada una reserva pasada (no-show)', async () => {
      // La rama de staff no mira la fecha a propósito: el no-show se registra
      // después de la hora.
      await assertSucceeds(
        updateDoc(doc(mesero(env), 'reservas', R_PASADA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });

    it('el ADMIN del tenant también puede cancelarla', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDemo(env), 'reservas', R_FUTURA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });

    it('el ADMIN de OTRO tenant NO puede cancelarla — ESCALADA cross-tenant', async () => {
      await assertFails(
        updateDoc(doc(adminOtro(env), 'reservas', R_FUTURA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });

    it('pasar a un estado que no sea "cancelada": DENEGADO (no hay más transiciones)', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'reservas', R_FUTURA), {
          estado: 'sentada',
          updatedAt: AHORA,
        }),
      );
    });

    it('el DUEÑO no puede mover la fecha ni el número de personas al cancelar', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'reservas', R_FUTURA), {
          estado: 'cancelada',
          numPersonas: 20,
          updatedAt: AHORA,
        }),
      );
    });

    it('el SUPER_ADMIN no cancela reservas: la rama de staff exige rid propio', async () => {
      // Veredicto fijado: `staffOf()` compara contra `rid()` y el super_admin no
      // tiene rid. Lee todo, opera nada.
      await assertFails(
        updateDoc(doc(superAdmin(env), 'reservas', R_FUTURA), {
          estado: 'cancelada',
          updatedAt: AHORA,
        }),
      );
    });
  });

  // --- delete ----------------------------------------------------------------

  describe('delete — prohibido siempre (allow delete: if false)', () => {
    it('el DUEÑO no puede borrar su reserva (se cancela, no se borra)', async () => {
      await assertFails(deleteDoc(doc(cliente(env, DUENO), 'reservas', R_FUTURA)));
    });

    it('el ADMIN del tenant tampoco', async () => {
      await assertFails(deleteDoc(doc(adminDemo(env), 'reservas', R_FUTURA)));
    });

    it('ni el SUPER_ADMIN', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'reservas', R_FUTURA)));
    });
  });
});
