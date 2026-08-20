// ============================================================================
// GRI — Tests de `firestore.rules` para `match /mesas/{mesaId}`.
//
// `firestore.rules` ES la capa de autorización de GRI: no hay backend. Este
// archivo convierte en aserciones ejecutables las CINCO ramas del match de
// mesas, que hasta ahora solo estaban verificadas por lectura humana:
//
//   read   : signedIn()                                        (cualquiera con sesión)
//   create : menuStaffOf(request.resource.data.restauranteId)  (super | admin del rid)
//   delete : menuStaffOf(resource.data.restauranteId)
//   update : rama FICHA  — menuStaffOf + hasOnly(numero,capacidad,updatedAt) + rid congelado
//            rama STAFF  — staffOf + soloEstado() + transMesa(a,b)
//            rama CLIENTE— isCliente + soloEstado() + (disponible→reservada
//                                                     | disponible|reservada→ocupada)
//
// `transMesa` es un port 1:1 de MESA_TRANSITIONS del backend FastAPI archivado
// (backend/app/core/state_machines.py). Los tests de abajo afirman que la
// máquina de estados vive de verdad en las rules y no solo en Dart: si alguien
// borra `transMesa` de la regla, `disponible→limpieza` pasaría a estar
// permitido y estos tests se ponen en rojo.
//
// Convención de doc ID: `GRI-MESA-{rid}-{NNN}`. No es cosmética — el escáner
// del cliente valida `^GRI-MESA-[a-z0-9-]+-\d{3}$`.
//
// ⚠️ `initEnv('mesas')`: namespace propio obligatorio (ver _contexts.mjs).
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  adminDemo,
  adminOtro,
  anon,
  cliente,
  cocina,
  initEnv,
  mesero,
  sembrar,
  superAdmin,
} from './_contexts.mjs';

const RID = 'demo';
const OTRO = 'otro';

// Una mesa por estado de partida: así ningún test depende de que otro haya
// dejado la mesa en un estado concreto (hay clearFirestore() en beforeEach).
const M_DISPONIBLE = 'GRI-MESA-demo-001';
const M_OCUPADA = 'GRI-MESA-demo-002';
const M_RESERVADA = 'GRI-MESA-demo-003';
const M_LIMPIEZA = 'GRI-MESA-demo-004';

const AHORA = new Date('2026-08-19T12:00:00Z');

describe('firestore.rules — mesas', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('mesas');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      const base = { restauranteId: RID, capacidad: 4, updatedAt: AHORA };
      await setDoc(doc(db, 'mesas', M_DISPONIBLE), { ...base, numero: 1, estado: 'disponible' });
      await setDoc(doc(db, 'mesas', M_OCUPADA), { ...base, numero: 2, estado: 'ocupada' });
      await setDoc(doc(db, 'mesas', M_RESERVADA), { ...base, numero: 3, estado: 'reservada' });
      await setDoc(doc(db, 'mesas', M_LIMPIEZA), { ...base, numero: 4, estado: 'limpieza' });
    });
  });

  // --- read: signedIn() ------------------------------------------------------

  describe('read — exige sesión, pero no tenant', () => {
    it('ANÓNIMO no puede leer una mesa: la regla exige signedIn()', async () => {
      await assertFails(getDoc(doc(anon(env), 'mesas', M_DISPONIBLE)));
    });

    it('CLIENTE puede leer la mesa que acaba de escanear', async () => {
      await assertSucceeds(getDoc(doc(cliente(env), 'mesas', M_DISPONIBLE)));
    });

    it('STAFF de OTRO tenant también puede leer: la lectura de mesa no es sensible', async () => {
      // Veredicto deliberado, no descuido: `allow read: if signedIn()` no acota
      // por rid. Queda fijado por escrito para que un endurecimiento futuro sea
      // un cambio consciente y no un efecto colateral silencioso.
      await assertSucceeds(getDoc(doc(adminOtro(env), 'mesas', M_DISPONIBLE)));
    });
  });

  // --- read de una mesa AUSENTE: la razón de que el QR diera un mensaje ------
  //
  // AUDITORÍA 11-27 — `mesas` está LIMPIA del bug de `resource.data` en la rama
  // de read, y NO por casualidad: `allow read: if signedIn()` no toca `resource`
  // en absoluto, así que el doc inexistente se lee sin problema.
  //
  // De eso dependen DOS flujos de producción:
  //   · `abrirSesion()` distingue "esa mesa no existe" de "no puedes": si esta
  //     rama se endureciera a `resource.data.restauranteId == rid()`, el mensaje
  //     de mesa inexistente del escáner volvería a ser un permission-denied.
  //   · `crearMesa()` (panel_admin/lib/features/mesas/mesas_crud.dart:35) es un
  //     check-then-create con doc ID determinista: hace `tx.get` sobre la mesa
  //     que va a crear, que POR DEFINICIÓN no existe.
  //
  // Estos casos son el cortafuegos de ese endurecimiento.

  describe('read de una mesa AUSENTE — de esto vive el check-then-create', () => {
    it('el ADMIN puede leer mesas/{id} inexistente (crearMesa comprueba antes de crear)', async () => {
      await assertSucceeds(getDoc(doc(adminDemo(env), 'mesas', 'GRI-MESA-demo-999')));
    });

    it('el CLIENTE puede leer una mesa inexistente ("ese QR no es de ninguna mesa")', async () => {
      await assertSucceeds(getDoc(doc(cliente(env), 'mesas', 'GRI-MESA-demo-999')));
    });

    it('el ANÓNIMO sigue DENEGADO también sobre la mesa ausente', async () => {
      await assertFails(getDoc(doc(anon(env), 'mesas', 'GRI-MESA-demo-999')));
    });
  });

  // --- create / delete: menuStaffOf ------------------------------------------

  describe('create y delete — solo super o admin del propio restaurante', () => {
    it('ADMIN del tenant puede crear una mesa de su restaurante', async () => {
      await assertSucceeds(
        setDoc(doc(adminDemo(env), 'mesas', 'GRI-MESA-demo-009'), {
          restauranteId: RID,
          numero: 9,
          capacidad: 2,
          estado: 'disponible',
          updatedAt: AHORA,
        }),
      );
    });

    it('SUPER_ADMIN puede crear una mesa de cualquier restaurante (no tiene rid)', async () => {
      await assertSucceeds(
        setDoc(doc(superAdmin(env), 'mesas', 'GRI-MESA-demo-010'), {
          restauranteId: RID,
          numero: 10,
          capacidad: 2,
          estado: 'disponible',
          updatedAt: AHORA,
        }),
      );
    });

    it('MESERO NO puede crear una mesa: crear ficha es menuStaffOf, no staffOf', async () => {
      await assertFails(
        setDoc(doc(mesero(env), 'mesas', 'GRI-MESA-demo-011'), {
          restauranteId: RID,
          numero: 11,
          capacidad: 2,
          estado: 'disponible',
          updatedAt: AHORA,
        }),
      );
    });

    it('ADMIN de OTRO tenant NO puede crear una mesa dentro de "demo" — ESCALADA cross-tenant', async () => {
      await assertFails(
        setDoc(doc(adminOtro(env), 'mesas', 'GRI-MESA-demo-012'), {
          restauranteId: RID,
          numero: 12,
          capacidad: 2,
          estado: 'disponible',
          updatedAt: AHORA,
        }),
      );
    });

    it('ADMIN del tenant puede borrar una mesa suya', async () => {
      await assertSucceeds(deleteDoc(doc(adminDemo(env), 'mesas', M_DISPONIBLE)));
    });

    it('MESERO NO puede borrar una mesa', async () => {
      await assertFails(deleteDoc(doc(mesero(env), 'mesas', M_DISPONIBLE)));
    });

    it('ADMIN de OTRO tenant NO puede borrar una mesa de "demo"', async () => {
      await assertFails(deleteDoc(doc(adminOtro(env), 'mesas', M_DISPONIBLE)));
    });
  });

  // --- update rama FICHA -----------------------------------------------------

  describe('update de ficha — numero y capacidad, sin tocar estado ni tenant', () => {
    it('ADMIN del tenant puede editar numero y capacidad', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDemo(env), 'mesas', M_DISPONIBLE), {
          numero: 42,
          capacidad: 8,
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('ADMIN del tenant NO puede mover la mesa a otro restaurante — ESCALADA cross-tenant', async () => {
      // Doblemente denegado: `restauranteId` no está en el hasOnly de la ficha
      // Y la regla exige explícitamente que el rid quede congelado. Que un
      // admin pudiera reasignar el rid de una mesa sería tomar prestado el
      // inventario de otro restaurante.
      await assertFails(
        updateDoc(doc(adminDemo(env), 'mesas', M_DISPONIBLE), { restauranteId: OTRO }),
      );
    });

    it('MESERO NO puede editar la ficha (solo cambia estados)', async () => {
      await assertFails(updateDoc(doc(mesero(env), 'mesas', M_DISPONIBLE), { capacidad: 8 }));
    });

    it('CLIENTE NO puede editar la capacidad de una mesa', async () => {
      await assertFails(updateDoc(doc(cliente(env), 'mesas', M_DISPONIBLE), { capacidad: 99 }));
    });
  });

  // --- update rama STAFF: máquina de estados ---------------------------------

  describe('cambio de estado por staff — transMesa se aplica en las rules, no solo en Dart', () => {
    it('MESERO del tenant: ocupada→limpieza es una transición válida', async () => {
      await assertSucceeds(
        updateDoc(doc(mesero(env), 'mesas', M_OCUPADA), {
          estado: 'limpieza',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('COCINA del tenant: limpieza→disponible cierra el ciclo de la mesa', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'mesas', M_LIMPIEZA), {
          estado: 'disponible',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('MESERO del tenant: disponible→limpieza NO existe en transMesa y queda denegada', async () => {
      // Si este test se pone en verde, `transMesa` ha desaparecido de la regla
      // y la máquina de estados solo vive en el cliente Dart — es decir, no
      // existe: cualquiera con el SDK podría saltársela.
      await assertFails(
        updateDoc(doc(mesero(env), 'mesas', M_DISPONIBLE), {
          estado: 'limpieza',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('MESERO del tenant: ocupada→disponible (saltarse la limpieza) queda denegada', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'mesas', M_OCUPADA), {
          estado: 'disponible',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('MESERO del tenant: colar "capacidad" junto al estado viola soloEstado() y se deniega', async () => {
      // Vector real: el cambio de estado es la única escritura que el mesero
      // tiene permitida; sin soloEstado() serviría de caballo de Troya para
      // editar la ficha entera.
      await assertFails(
        updateDoc(doc(mesero(env), 'mesas', M_OCUPADA), {
          estado: 'limpieza',
          capacidad: 99,
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('ADMIN de OTRO tenant: ninguna transición sobre una mesa de "demo" — ESCALADA cross-tenant', async () => {
      await assertFails(
        updateDoc(doc(adminOtro(env), 'mesas', M_OCUPADA), {
          estado: 'limpieza',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });
  });

  // --- update rama CLIENTE ---------------------------------------------------

  describe('cambio de estado por cliente — solo sus dos transacciones de producto', () => {
    it('CLIENTE: disponible→ocupada es la tx de abrir sesión tras escanear el QR', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env), 'mesas', M_DISPONIBLE), {
          estado: 'ocupada',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('CLIENTE: disponible→reservada es la tx de reservar', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env), 'mesas', M_DISPONIBLE), {
          estado: 'reservada',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('CLIENTE: reservada→ocupada permite sentarse en la mesa que reservó', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env), 'mesas', M_RESERVADA), {
          estado: 'ocupada',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('CLIENTE: ocupada→limpieza es trabajo de staff y queda denegado', async () => {
      // La transición existe en transMesa, pero la rama de cliente no la
      // incluye: liberar la mesa es una decisión operativa del restaurante.
      await assertFails(
        updateDoc(doc(cliente(env), 'mesas', M_OCUPADA), {
          estado: 'limpieza',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('CLIENTE: limpieza→disponible tampoco: no puede darse la mesa por lista', async () => {
      await assertFails(
        updateDoc(doc(cliente(env), 'mesas', M_LIMPIEZA), {
          estado: 'disponible',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });

    it('ANÓNIMO no puede ocupar una mesa: isCliente() exige signedIn()', async () => {
      await assertFails(
        updateDoc(doc(anon(env), 'mesas', M_DISPONIBLE), {
          estado: 'ocupada',
          updatedAt: new Date('2026-08-19T13:00:00Z'),
        }),
      );
    });
  });
});
