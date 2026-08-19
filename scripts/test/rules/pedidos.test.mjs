// ============================================================================
// GRI — Tests de `firestore.rules` para `match /pedidos/{pedidoId}`.
//
// Este archivo cubre DOS de los tres vectores de escalada de la fase:
//
//   1. ANTI-SPOOFING de sesión (create). La regla gasta 2 access-calls para
//      comprobar que el `sesionId` del pedido pertenece a QUIEN LO ENVÍA y que
//      esa sesión sigue ACTIVA. Sin eso, cualquier cliente autenticado podría
//      cargar comida a la cuenta de la mesa de al lado con solo conocer su
//      mesaId — que está impreso en el QR, a la vista de todos.
//
//   2. MATRIZ ROL × TRANSICIÓN (update). Port de la matriz de la Fase 6:
//        enviado        → aceptado|rechazado : admin | cocina | super  (mesero NO)
//        aceptado       → en_preparacion     : admin | cocina | super  (mesero NO)
//        en_preparacion → servido            : CUALQUIER cocinaStaffOf (mesero SÍ)
//      El mesero puede servir, no puede aceptar ni mandar a preparar. Esa
//      distinción SOLO existe aquí: si se cae, ningún test de Flutter lo nota
//      (`fake_cloud_firestore` no tiene motor de rules).
//
// `soloEstado()` acota todo update a `estado` + `updatedAt`: sin él, el avance
// de cocina sería una puerta abierta para reescribir `total` o `items`.
//
// ⚠️ `initEnv('pedidos')`: namespace propio obligatorio (ver _contexts.mjs).
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  adminDemo,
  adminOtro,
  cliente,
  cocina,
  initEnv,
  mesero,
  sembrar,
  superAdmin,
} from './_contexts.mjs';

const RID = 'demo';
const OTRO = 'otro';

const DUENO = 'uid-cliente';
const INTRUSO = 'uid-cliente-intruso';

const M_MIA = 'GRI-MESA-demo-002'; // sesión ACTIVA del dueño
const M_AJENA = 'GRI-MESA-demo-007'; // sesión ACTIVA del intruso
const M_CERRADA = 'GRI-MESA-demo-005'; // sesión CERRADA del dueño

const P_ENVIADO = 'ped-enviado';
const P_ACEPTADO = 'ped-aceptado';
const P_PREPARACION = 'ped-en-preparacion';

const AHORA = new Date('2026-08-19T12:00:00Z');
const LUEGO = new Date('2026-08-19T13:00:00Z');

const ITEM = { productoId: 'p-ok', nombre: 'Bandeja paisa', precio: 25000, cantidad: 1 };

/** Payload válido de create; los tests lo mutan campo a campo. */
function pedidoValido(overrides = {}) {
  return {
    sesionId: M_MIA,
    mesaId: M_MIA, // la regla exige sesionId == mesaId (1 sesión por mesa)
    restauranteId: RID,
    usuarioId: DUENO,
    estado: 'enviado',
    items: [ITEM],
    total: 25000,
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — pedidos', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('pedidos');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      const mesa = { restauranteId: RID, capacidad: 4, estado: 'ocupada', updatedAt: AHORA };
      await setDoc(doc(db, 'mesas', M_MIA), { ...mesa, numero: 2 });
      await setDoc(doc(db, 'mesas', M_AJENA), { ...mesa, numero: 7 });
      await setDoc(doc(db, 'mesas', M_CERRADA), { ...mesa, numero: 5 });

      const sesion = { restauranteId: RID, cuentaSolicitada: false, createdAt: AHORA };
      await setDoc(doc(db, 'sesiones', M_MIA), {
        ...sesion,
        mesaId: M_MIA,
        usuarioId: DUENO,
        estado: 'activa',
      });
      await setDoc(doc(db, 'sesiones', M_AJENA), {
        ...sesion,
        mesaId: M_AJENA,
        usuarioId: INTRUSO,
        estado: 'activa',
      });
      await setDoc(doc(db, 'sesiones', M_CERRADA), {
        ...sesion,
        mesaId: M_CERRADA,
        usuarioId: DUENO,
        estado: 'cerrada',
      });

      // Un pedido por estado de la cola: la matriz se prueba sin encadenar
      // tests entre sí.
      const base = {
        sesionId: M_MIA,
        mesaId: M_MIA,
        restauranteId: RID,
        usuarioId: DUENO,
        items: [ITEM],
        total: 25000,
        createdAt: AHORA,
      };
      await setDoc(doc(db, 'pedidos', P_ENVIADO), { ...base, estado: 'enviado' });
      await setDoc(doc(db, 'pedidos', P_ACEPTADO), { ...base, estado: 'aceptado' });
      await setDoc(doc(db, 'pedidos', P_PREPARACION), { ...base, estado: 'en_preparacion' });
    });
  });

  // --- read ------------------------------------------------------------------

  describe('read — dueño, staff del tenant o super', () => {
    it('el DUEÑO puede leer su pedido', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, DUENO), 'pedidos', P_ENVIADO)));
    });

    it('OTRO cliente NO puede leer el pedido ajeno', async () => {
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'pedidos', P_ENVIADO)));
    });

    it('COCINA del tenant puede leer el pedido (es su cola de trabajo)', async () => {
      await assertSucceeds(getDoc(doc(cocina(env), 'pedidos', P_ENVIADO)));
    });

    it('el ADMIN de OTRO tenant NO puede leerlo — ESCALADA cross-tenant', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'pedidos', P_ENVIADO)));
    });

    it('el SUPER_ADMIN puede leer cualquier pedido', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'pedidos', P_ENVIADO)));
    });
  });

  // --- create ----------------------------------------------------------------

  describe('create — el cliente pide desde SU sesión activa', () => {
    it('CLIENTE con sesión propia y activa: el pedido se crea', async () => {
      await assertSucceeds(setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-nuevo'), pedidoValido()));
    });

    it('CLIENTE usando el sesionId de OTRA persona: DENEGADO — ESCALADA (anti-spoofing)', async () => {
      // El mesaId viaja impreso en el QR de la mesa: es información pública.
      // Lo único que impide cargar comida a la cuenta de la mesa de al lado es
      // este get() sobre `sesiones/{sesionId}.usuarioId`.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-pirata'),
          pedidoValido({ sesionId: M_AJENA, mesaId: M_AJENA }),
        ),
      );
    });

    it('CLIENTE sobre su propia sesión ya CERRADA: DENEGADO (la mesa terminó)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-tarde'),
          pedidoValido({ sesionId: M_CERRADA, mesaId: M_CERRADA }),
        ),
      );
    });

    it('CLIENTE con sesionId != mesaId: DENEGADO (la sesión y la mesa divergirían)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-divergente'),
          pedidoValido({ mesaId: M_AJENA }),
        ),
      );
    });

    it('CLIENTE declarando el usuarioId de otro: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-suplantado'),
          pedidoValido({ usuarioId: INTRUSO }),
        ),
      );
    });

    it('pedido con items vacío: DENEGADO (mínimo 1)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-vacio'), pedidoValido({ items: [] })),
      );
    });

    it('pedido con 51 items: DENEGADO (máximo 50 — tope anti-abuso)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-51'),
          pedidoValido({ items: Array.from({ length: 51 }, () => ({ ...ITEM })) }),
        ),
      );
    });

    it('pedido con exactamente 50 items: PERMITIDO (el borde superior es inclusivo)', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-50'),
          pedidoValido({ items: Array.from({ length: 50 }, () => ({ ...ITEM })) }),
        ),
      );
    });

    it('pedido con total NO entero: DENEGADO (la regla exige `total is int`)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-decimal'), pedidoValido({ total: 25000.5 })),
      );
    });

    it('pedido con total negativo: DENEGADO', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-negativo'), pedidoValido({ total: -1 })),
      );
    });

    it('pedido con restauranteId distinto al de la mesa: DENEGADO — ESCALADA cross-tenant', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-otro-rid'),
          pedidoValido({ restauranteId: OTRO }),
        ),
      );
    });

    it('pedido que nace ya "aceptado": DENEGADO (solo se crea en enviado)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-autoaceptado'),
          pedidoValido({ estado: 'aceptado' }),
        ),
      );
    });

    it('COCINA no puede crear un pedido: la regla de create es isCliente()', async () => {
      await assertFails(setDoc(doc(cocina(env), 'pedidos', 'ped-staff'), pedidoValido()));
    });
  });

  // --- update: matriz rol × transición ---------------------------------------

  describe('update — matriz rol × transición de la cola de cocina', () => {
    it('COCINA: enviado→aceptado (es quien decide si entra a la cola)', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: enviado→rechazado', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'rechazado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('ADMIN del tenant: enviado→aceptado', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDemo(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('SUPER_ADMIN: enviado→aceptado (isSuper() esquiva el chequeo de rid)', async () => {
      await assertSucceeds(
        updateDoc(doc(superAdmin(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: enviado→aceptado DENEGADO — ESCALADA (aceptar no es su rol)', async () => {
      // ESTE es el caso que hoy solo vive en la regla. El mesero pasa
      // `cocinaStaffOf`, así que lo único que lo detiene es el
      // `role() in ['admin_restaurante','cocina']` de la primera rama.
      await assertFails(
        updateDoc(doc(mesero(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: enviado→rechazado DENEGADO — ESCALADA (rechazar tampoco)', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'pedidos', P_ENVIADO), {
          estado: 'rechazado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: aceptado→en_preparacion', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_ACEPTADO), {
          estado: 'en_preparacion',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: aceptado→en_preparacion DENEGADO — ESCALADA', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'pedidos', P_ACEPTADO), {
          estado: 'en_preparacion',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: en_preparacion→servido PERMITIDO (servir SÍ es su trabajo)', async () => {
      // Única transición sin restricción de rol dentro de cocinaStaffOf: es
      // exactamente la razón por la que el mesero está en ese helper.
      await assertSucceeds(
        updateDoc(doc(mesero(env), 'pedidos', P_PREPARACION), {
          estado: 'servido',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: en_preparacion→servido también permitido', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_PREPARACION), {
          estado: 'servido',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: enviado→servido DENEGADO (salto ilegal: nunca se preparó)', async () => {
      await assertFails(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'servido',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: enviado→en_preparacion DENEGADO (salta el paso de aceptación)', async () => {
      await assertFails(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'en_preparacion',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA de OTRO tenant: ninguna transición sobre un pedido de "demo" — ESCALADA cross-tenant', async () => {
      await assertFails(
        updateDoc(doc(adminOtro(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el CLIENTE dueño no puede auto-aceptar su pedido', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA no puede reescribir el total al cambiar el estado (soloEstado)', async () => {
      // Sin `soloEstado()` el avance de cocina sería una puerta para editar el
      // importe de un pedido ya enviado por el cliente.
      await assertFails(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          total: 1,
          updatedAt: LUEGO,
        }),
      );
    });
  });

  // --- delete ----------------------------------------------------------------

  describe('delete — prohibido siempre (allow delete: if false)', () => {
    it('el CLIENTE dueño no puede borrar su pedido', async () => {
      await assertFails(deleteDoc(doc(cliente(env, DUENO), 'pedidos', P_ENVIADO)));
    });

    it('el ADMIN del tenant no puede borrarlo', async () => {
      await assertFails(deleteDoc(doc(adminDemo(env), 'pedidos', P_ENVIADO)));
    });

    it('ni el SUPER_ADMIN: el pedido es rastro contable', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'pedidos', P_ENVIADO)));
    });
  });
});
