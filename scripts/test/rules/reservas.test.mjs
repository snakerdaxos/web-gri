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

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  orderBy,
  where,
} from 'firebase/firestore';

import {
  adminDemo,
  adminOtro,
  anon,
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

  // --- QUERY vs RULES (11-28) ------------------------------------------------
  //
  // Mismo contrato que en `pedidos` y `sesiones`: la regla mira `usuarioId` o
  // `restauranteId` y la consulta tiene que acotar uno de los dos, o se
  // deniega entera. Consultas LITERALES:
  //
  //   app_cliente/lib/features/reservas/reservas_provider.dart:19
  //     reservas.where('usuarioId').orderBy('fecha', descending: true)
  //   panel_admin/lib/features/reservas/reservas_provider.dart:35
  //     reservas.where('restauranteId').where('fecha' >= ).where('fecha' < )
  //
  // Contrapartida estática: entrada `reservas` de PARIDAD_RULES_QUERY.
  describe('QUERY vs RULES — las consultas LITERALES de las apps (11-28)', () => {
    it('CLIENTE: reservas where("usuarioId") + orderBy("fecha" desc) — PERMITIDA', async () => {
      const db = cliente(env, DUENO);
      await assertSucceeds(
        getDocs(
          query(
            collection(db, 'reservas'),
            where('usuarioId', '==', DUENO),
            orderBy('fecha', 'desc'),
          ),
        ),
      );
    });

    it('CLIENTE: reservas SIN filtro queda DENEGADA', async () => {
      await assertFails(getDocs(collection(cliente(env, DUENO), 'reservas')));
    });

    it('CLIENTE: reservas where("usuarioId") de OTRO uid queda DENEGADA', async () => {
      await assertFails(
        getDocs(query(collection(cliente(env, DUENO), 'reservas'), where('usuarioId', '==', INTRUSO))),
      );
    });

    it('ADMIN del tenant: reservas where("restauranteId") + rango de fecha — PERMITIDA', async () => {
      const db = adminDemo(env);
      await assertSucceeds(
        getDocs(
          query(
            collection(db, 'reservas'),
            where('restauranteId', '==', RID),
            where('fecha', '>=', AHORA),
            where('fecha', '<', FUTURO),
          ),
        ),
      );
    });

    it('ADMIN de OTRO tenant: la misma agenda sobre "demo" queda DENEGADA — aislamiento', async () => {
      const db = adminOtro(env);
      await assertFails(
        getDocs(
          query(
            collection(db, 'reservas'),
            where('restauranteId', '==', RID),
            where('fecha', '>=', AHORA),
            where('fecha', '<', FUTURO),
          ),
        ),
      );
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

  // --- read de un SLOT AUSENTE: "¿está libre esta franja?" ------------------
  //
  // EL BUG QUE ESTA SUITE NO VIO (11-27). Los 27 casos de este archivo siembran
  // la reserva antes de leerla. El caso real —la franja LIBRE, que es la que se
  // quiere reservar— no lo ejercitaba ninguno.
  //
  // Una rama de `read` que desreferencia `resource.data` DENIEGA los documentos
  // que aún no existen: `resource` es null y la expresión revienta. Sale como
  // `permission-denied`, no como "no encontrado".
  //
  // `crearReserva()` (app_cliente/lib/features/reservas/reserva_controller.dart)
  // recorre las mesas candidatas y hace `tx.get(reservas/{mesaId}_{fecha}_{HH})`
  // sobre cada una: **la primera que NO existe es la elegida**. Con el doc
  // ausente denegado, ese `tx.get` moría antes de encontrar nada y NINGÚN
  // cliente podía reservar NINGUNA franja. Leer el hueco no es un accesorio del
  // flujo: ES el flujo.

  describe('read de un SLOT AUSENTE — el check-then-create de reservar', () => {
    it('el CLIENTE puede leer el slot LIBRE (doc inexistente)', async () => {
      // El id sigue la forma real `{mesaId}_{yyyyMMdd}_{HH}` y no está sembrado.
      await assertSucceeds(
        getDoc(doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-001_20300820_19')),
      );
    });

    it('el CLIENTE puede sondear el slot de OTRA mesa candidata (el bucle de asignación)', async () => {
      // La tx prueba mesa por mesa hasta dar con una libre: si el sondeo de la
      // segunda candidata se deniega, la asignación automática no existe.
      await assertSucceeds(
        getDoc(doc(cliente(env, DUENO), 'reservas', 'GRI-MESA-demo-020_20300820_19')),
      );
    });

    it('el MESERO del tenant también lee el slot ausente', async () => {
      await assertSucceeds(
        getDoc(doc(mesero(env), 'reservas', 'GRI-MESA-demo-001_20300820_19')),
      );
    });

    it('LO QUE ESTO CONCEDE: el admin de OTRO tenant ve el slot ausente', async () => {
      // No hay documento, así que no hay `restauranteId` contra el que acotar.
      // Lo que se filtra es "esa franja está libre" — la disponibilidad que
      // cualquier sistema de reservas publica por diseño.
      await assertSucceeds(
        getDoc(doc(adminOtro(env), 'reservas', 'GRI-MESA-demo-001_20300820_19')),
      );
    });

    it('el ANÓNIMO sigue DENEGADO sobre el slot ausente: signedIn() manda', async () => {
      await assertFails(
        getDoc(doc(anon(env), 'reservas', 'GRI-MESA-demo-001_20300820_19')),
      );
    });

    it('en cuanto la reserva EXISTE, OTRO cliente vuelve a estar DENEGADO', async () => {
      // Se concede la ausencia, jamás el contenido: quién reservó, para cuántos
      // y a qué hora sigue siendo privado.
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'reservas', R_FUTURA)));
    });

    it('en cuanto la reserva EXISTE, el admin de OTRO tenant vuelve a estar DENEGADO', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'reservas', R_FUTURA)));
    });
  });

  // --- FLUJO COMPLETO: la transacción REAL de crearReserva() ----------------
  //
  // Réplica paso a paso de `_crearReserva()`
  // (app_cliente/lib/features/reservas/reserva_controller.dart:100-140): la
  // asignación automática de mesa sondea el slot de cada candidata y se queda
  // con la PRIMERA que no existe. Leer y escribir en la misma transacción es
  // lo que hace la app; probarlo por separado no basta.

  describe('FLUJO COMPLETO — la transacción de reservar, de principio a fin', () => {
    it('el CLIENTE reserva una franja LIBRE: get(slot ausente) + set + update de la mesa', async () => {
      const db = cliente(env, DUENO);
      const SLOT = new Date('2030-08-20T19:00:00Z');
      const ID_SLOT = 'GRI-MESA-demo-001_20300820_19';

      await assertSucceeds(
        runTransaction(db, async (tx) => {
          const slotRef = doc(db, 'reservas', ID_SLOT);

          // EL PASO QUE ESTABA ROTO: el slot libre es un doc que no existe.
          const slotSnap = await tx.get(slotRef);
          assert.equal(slotSnap.exists(), false);

          const mesaRef = doc(db, 'mesas', M_NORMAL);
          const mesaSnap = await tx.get(mesaRef);
          assert.equal(mesaSnap.data().estado, 'disponible');

          tx.update(mesaRef, { estado: 'reservada', updatedAt: AHORA });
          tx.set(slotRef, {
            restauranteId: RID,
            mesaId: M_NORMAL,
            mesaNumero: 1,
            usuarioId: DUENO,
            fecha: SLOT,
            fechaStr: '2030-08-20',
            hora: 19,
            numPersonas: 4,
            estado: 'confirmada',
            createdAt: AHORA,
          });
        }),
      );
    });

    it('y el slot ya TOMADO sigue siendo ilegible para otro cliente', async () => {
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'reservas', R_FUTURA)));
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
