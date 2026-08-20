// ============================================================================
// GRI — Tests de `firestore.rules` para `match /sesiones/{sesionId}`.
//
// La sesión es el eje del flujo de mesa: nace cuando el cliente escanea el QR
// y muere cuando el staff la cierra. El doc ID ES el mesaId (UNA sesión por
// mesa), y la regla de create hace 1 access-call sobre `mesas/{sesionId}` para
// comprobar que la mesa está libre y pertenece al mismo restaurante.
//
//   read   : dueño | staffOf(rid) | super
//   create : isCliente + estado 'activa' + usuarioId propio + cuentaSolicitada
//            false + mesaId == docId + mesa en [disponible, reservada] +
//            rid de la mesa == rid de la sesión
//   update : rama DUEÑO — hasOnly(cuentaSolicitada, cuentaPedidaAt) y ==true
//            rama STAFF — staffOf + soloEstado + activa → [cerrada, expirada]
//   delete : false (siempre)
//
// ⚠️ NO OBVIO — `setDoc()` sobre un doc que YA existe se evalúa como UPDATE,
// no como create. Es lo que impide "re-abrir" una sesión cerrada saltándose la
// máquina de estados: hay un test dedicado abajo porque es el tipo de detalle
// que se rompe sin que nadie lo note.
//
// ⚠️ `initEnv('sesiones')`: namespace propio obligatorio (ver _contexts.mjs).
// ============================================================================

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, runTransaction, setDoc, updateDoc } from 'firebase/firestore';

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

const DUENO = 'uid-cliente'; // uid por defecto de cliente()
const INTRUSO = 'uid-cliente-intruso';

const M_LIBRE = 'GRI-MESA-demo-001'; // disponible, sin sesión
const M_OCUPADA = 'GRI-MESA-demo-002'; // ocupada, con sesión ACTIVA
const M_RESERVADA = 'GRI-MESA-demo-003'; // reservada, sin sesión
const M_CERRADA = 'GRI-MESA-demo-005'; // con sesión CERRADA

const AHORA = new Date('2026-08-19T12:00:00Z');
const LUEGO = new Date('2026-08-19T13:00:00Z');

/** Payload válido de create; los tests lo mutan campo a campo. */
function sesionValida(overrides = {}) {
  return {
    mesaId: M_LIBRE,
    restauranteId: RID,
    usuarioId: DUENO,
    estado: 'activa',
    cuentaSolicitada: false,
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — sesiones', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('sesiones');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      const mesa = { restauranteId: RID, capacidad: 4, updatedAt: AHORA };
      await setDoc(doc(db, 'mesas', M_LIBRE), { ...mesa, numero: 1, estado: 'disponible' });
      await setDoc(doc(db, 'mesas', M_OCUPADA), { ...mesa, numero: 2, estado: 'ocupada' });
      await setDoc(doc(db, 'mesas', M_RESERVADA), { ...mesa, numero: 3, estado: 'reservada' });
      await setDoc(doc(db, 'mesas', M_CERRADA), { ...mesa, numero: 5, estado: 'limpieza' });

      // Sesión ACTIVA del cliente por defecto sobre la mesa ocupada.
      await setDoc(doc(db, 'sesiones', M_OCUPADA), {
        mesaId: M_OCUPADA,
        restauranteId: RID,
        usuarioId: DUENO,
        estado: 'activa',
        cuentaSolicitada: false,
        createdAt: AHORA,
      });
      // Sesión ya CERRADA: el estado terminal del que no se debe poder volver.
      await setDoc(doc(db, 'sesiones', M_CERRADA), {
        mesaId: M_CERRADA,
        restauranteId: RID,
        usuarioId: DUENO,
        estado: 'cerrada',
        cuentaSolicitada: true,
        createdAt: AHORA,
      });
    });
  });

  // --- read ------------------------------------------------------------------

  describe('read — dueño, staff del tenant o super', () => {
    it('el DUEÑO puede leer su propia sesión', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, DUENO), 'sesiones', M_OCUPADA)));
    });

    it('OTRO cliente NO puede leer la sesión ajena', async () => {
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'sesiones', M_OCUPADA)));
    });

    it('el MESERO del tenant puede leer la sesión de su restaurante', async () => {
      await assertSucceeds(getDoc(doc(mesero(env), 'sesiones', M_OCUPADA)));
    });

    it('el ADMIN de OTRO tenant NO puede leerla — ESCALADA cross-tenant', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'sesiones', M_OCUPADA)));
    });

    it('el SUPER_ADMIN puede leer cualquier sesión', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'sesiones', M_OCUPADA)));
    });
  });

  // --- read de un doc AUSENTE: el "¿existe?" del check-then-create --------
  //
  // EL BUG QUE ESTA SUITE NO VIO (11-27). Los 29 casos de este archivo siembran
  // el documento ANTES de leerlo. El primer uso real —la mesa que NUNCA se ha
  // abierto— no lo ejercitaba ni uno.
  //
  // En el motor de rules, una rama de `read` que desreferencia `resource.data`
  // sobre un documento QUE NO EXISTE no devuelve "no encontrado": `resource` es
  // null, la expresión revienta y la regla evalúa a DENEGADO. El cliente recibe
  // `permission-denied`.
  //
  // `abrirSesion()` (app_cliente/lib/features/sesion_qr/sesion_provider.dart)
  // hace `tx.get(sesiones/{codigoQR})` para saber si la mesa ya está ocupada
  // ANTES de crear la sesión. La primera vez que alguien abre una mesa ese doc
  // no existe → denegado → NADIE podía abrir NINGUNA mesa. El core value del
  // producto, caído detrás de 221 tests en verde.
  //
  // Estos casos son la vacuna: hablan de la AUSENCIA, no del contenido.

  describe('read de un doc AUSENTE — el check-then-create de abrir mesa', () => {
    it('el CLIENTE puede leer sesiones/{mesaId} cuando la sesión NO EXISTE', async () => {
      // M_LIBRE tiene mesa sembrada pero NINGUNA sesión: es exactamente el
      // estado de toda mesa recién creada. Este es el caso que rompía el QR.
      await assertSucceeds(getDoc(doc(cliente(env, DUENO), 'sesiones', M_LIBRE)));
    });

    it('el CLIENTE puede leer un sesionId inventado (aprender "aquí no hay nada")', async () => {
      await assertSucceeds(
        getDoc(doc(cliente(env, DUENO), 'sesiones', 'GRI-MESA-demo-999')),
      );
    });

    it('el MESERO del tenant también lee el hueco ausente', async () => {
      await assertSucceeds(getDoc(doc(mesero(env), 'sesiones', M_LIBRE)));
    });

    it('LO QUE ESTO CONCEDE: el admin de OTRO tenant ve el hueco ausente', async () => {
      // Declarado, no accidental. `resource == null` no puede distinguir tenants
      // porque NO HAY documento del que sacar el `restauranteId`. Lo único que
      // se filtra es "no hay sesión abierta en la mesa cuyo código va IMPRESO en
      // el QR de la mesa" — ocupación físicamente observable desde la puerta.
      await assertSucceeds(getDoc(doc(adminOtro(env), 'sesiones', M_LIBRE)));
    });

    it('el ANÓNIMO sigue DENEGADO sobre el doc ausente: signedIn() manda', async () => {
      // La puerta que NO se abre. Si el fix se hubiera escrito
      // `resource == null || (signedIn() && ...)` en vez de
      // `signedIn() && (resource == null || ...)`, este caso pasaría a verde y
      // cualquiera sin cuenta podría sondear la ocupación del salón.
      await assertFails(getDoc(doc(anon(env), 'sesiones', M_LIBRE)));
    });

    it('en cuanto la sesión EXISTE, OTRO cliente vuelve a estar DENEGADO', async () => {
      // El contenido sigue protegido igual que antes: la ausencia es lo único
      // que se concede. Mismo doc, mismo intruso, distinto veredicto según
      // exista o no.
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'sesiones', M_OCUPADA)));
    });

    it('en cuanto la sesión EXISTE, el admin de OTRO tenant vuelve a estar DENEGADO', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'sesiones', M_OCUPADA)));
    });
  });

  // --- FLUJO COMPLETO: la transacción REAL de abrirSesion() ------------------
  //
  // Los casos de arriba prueban la lectura y los de abajo la escritura, cada
  // uno por separado. Ninguno prueba lo que hace la APP: leer el hueco y
  // escribir en la MISMA transacción. Un fix que arreglara solo el read
  // dejaría el flujo roto igual y esta suite no lo notaría.
  //
  // Réplica paso a paso de `_abrirSesion()`
  // (app_cliente/lib/features/sesion_qr/sesion_provider.dart:82-125), contra
  // el motor de rules real.

  describe('FLUJO COMPLETO — la transacción de abrir mesa, de principio a fin', () => {
    it('el CLIENTE abre una mesa NUNCA usada: get(mesa) + get(sesión ausente) + set + update', async () => {
      const db = cliente(env, DUENO);
      await assertSucceeds(
        runTransaction(db, async (tx) => {
          const mesaRef = doc(db, 'mesas', M_LIBRE);
          const mesaSnap = await tx.get(mesaRef);
          assert.equal(mesaSnap.exists(), true);

          // EL PASO QUE ESTABA ROTO: la sesión no existe todavía.
          const sesionRef = doc(db, 'sesiones', M_LIBRE);
          const sesionSnap = await tx.get(sesionRef);
          assert.equal(sesionSnap.exists(), false);

          tx.set(sesionRef, {
            restauranteId: mesaSnap.data().restauranteId,
            mesaId: M_LIBRE,
            usuarioId: DUENO,
            estado: 'activa',
            cuentaSolicitada: false,
            inicioAt: AHORA,
          });
          tx.update(mesaRef, { estado: 'ocupada', updatedAt: LUEGO });
        }),
      );
    });

    it('y el INTRUSO que llega después pierde: lee la sesión ACTIVA y no la puede leer', async () => {
      // El otro lado del flujo: en cuanto hay sesión, el hueco deja de existir
      // y vuelve a mandar la regla de propiedad. La app traduce esto a "Mesa
      // ocupada" con su propia lectura; aquí se fija el veredicto de las rules.
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'sesiones', M_OCUPADA)));
    });
  });

  // --- create ----------------------------------------------------------------

  describe('create — abrir sesión sobre una mesa libre', () => {
    it('CLIENTE sobre mesa disponible: abre su sesión', async () => {
      await assertSucceeds(
        setDoc(doc(cliente(env, DUENO), 'sesiones', M_LIBRE), sesionValida()),
      );
    });

    it('CLIENTE sobre mesa reservada: también puede sentarse (llegó a su reserva)', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'sesiones', M_RESERVADA),
          sesionValida({ mesaId: M_RESERVADA }),
        ),
      );
    });

    it('CLIENTE sobre mesa YA OCUPADA: denegado, la mesa tiene dueño', async () => {
      // El doc ID coincide con una sesión existente, así que además se evalúa
      // como update — doblemente denegado. Lo que fija el test es el veredicto.
      await assertFails(
        setDoc(
          doc(cliente(env, INTRUSO), 'sesiones', M_OCUPADA),
          sesionValida({ mesaId: M_OCUPADA, usuarioId: INTRUSO }),
        ),
      );
    });

    it('CLIENTE declarando el usuarioId de OTRO: denegado (suplantación)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'sesiones', M_LIBRE), sesionValida({ usuarioId: INTRUSO })),
      );
    });

    it('CLIENTE con mesaId distinto del doc ID: denegado (la sesión apuntaría a otra mesa)', async () => {
      // Sin esta comprobación, el doc ID (= la mesa cuyo estado se consulta)
      // y el mesaId (= la mesa que verán pedidos y cocina) podrían divergir.
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'sesiones', M_LIBRE), sesionValida({ mesaId: M_RESERVADA })),
      );
    });

    it('CLIENTE con restauranteId distinto al de la mesa: denegado — ESCALADA cross-tenant', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'sesiones', M_LIBRE),
          sesionValida({ restauranteId: OTRO }),
        ),
      );
    });

    it('CLIENTE naciendo la sesión ya "cerrada": denegado, solo se crea en activa', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'sesiones', M_LIBRE), sesionValida({ estado: 'cerrada' })),
      );
    });

    it('CLIENTE naciendo con cuentaSolicitada: true: denegado', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'sesiones', M_LIBRE),
          sesionValida({ cuentaSolicitada: true }),
        ),
      );
    });

    it('MESERO NO puede crear una sesión: la regla de create es isCliente()', async () => {
      // Comportamiento ACTUAL de la regla, fijado a propósito. El comentario de
      // _contexts.mjs describe al mesero como quien "abre sesiones"; la regla
      // vigente no se lo permite y quien la cambie debe hacerlo conscientemente.
      await assertFails(setDoc(doc(mesero(env), 'sesiones', M_LIBRE), sesionValida()));
    });

    it('re-abrir una sesión CERRADA con set() queda denegado (set sobre doc existente = update)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'sesiones', M_CERRADA),
          sesionValida({ mesaId: M_CERRADA }),
        ),
      );
    });
  });

  // --- update rama DUEÑO -----------------------------------------------------

  describe('update — el dueño pide la cuenta', () => {
    it('el DUEÑO puede marcar cuentaSolicitada: true con su timestamp', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env, DUENO), 'sesiones', M_OCUPADA), {
          cuentaSolicitada: true,
          cuentaPedidaAt: LUEGO,
        }),
      );
    });

    it('OTRO cliente NO puede pedir la cuenta de una sesión ajena', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, INTRUSO), 'sesiones', M_OCUPADA), {
          cuentaSolicitada: true,
          cuentaPedidaAt: LUEGO,
        }),
      );
    });

    it('el DUEÑO NO puede DESmarcar la cuenta: la regla exige cuentaSolicitada == true', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'sesiones', M_CERRADA), { cuentaSolicitada: false }),
      );
    });

    it('el DUEÑO NO puede cerrar su propia sesión: cerrar es potestad del staff', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'sesiones', M_OCUPADA), {
          estado: 'cerrada',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el DUEÑO NO puede colar otro campo junto a la solicitud de cuenta', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'sesiones', M_OCUPADA), {
          cuentaSolicitada: true,
          restauranteId: OTRO,
        }),
      );
    });
  });

  // --- update rama STAFF -----------------------------------------------------

  describe('update — el staff cierra o expira la sesión', () => {
    it('el MESERO del tenant puede pasar activa→cerrada', async () => {
      await assertSucceeds(
        updateDoc(doc(mesero(env), 'sesiones', M_OCUPADA), {
          estado: 'cerrada',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el ADMIN del tenant puede pasar activa→expirada', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDemo(env), 'sesiones', M_OCUPADA), {
          estado: 'expirada',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el ADMIN de OTRO tenant NO puede cerrarla — ESCALADA cross-tenant', async () => {
      await assertFails(
        updateDoc(doc(adminOtro(env), 'sesiones', M_OCUPADA), {
          estado: 'cerrada',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el staff NO puede re-abrir una sesión cerrada (cerrada→activa)', async () => {
      // `resource.data.estado == 'activa'` en la regla hace de `cerrada` un
      // estado terminal: sin él, una sesión pagada podría revivir.
      await assertFails(
        updateDoc(doc(mesero(env), 'sesiones', M_CERRADA), {
          estado: 'activa',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el staff NO puede cambiar el dueño de la sesión (viola soloEstado)', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'sesiones', M_OCUPADA), {
          estado: 'cerrada',
          usuarioId: INTRUSO,
          updatedAt: LUEGO,
        }),
      );
    });

    it('el SUPER_ADMIN tampoco cierra sesiones: la rama de staff exige rid propio', async () => {
      // Veredicto fijado: `staffOf()` compara contra `rid()`, y el super_admin
      // NO tiene rid (seed_firebase.mjs:47). Puede LEER todo, no operar mesas.
      await assertFails(
        updateDoc(doc(superAdmin(env), 'sesiones', M_OCUPADA), {
          estado: 'cerrada',
          updatedAt: LUEGO,
        }),
      );
    });
  });

  // --- delete ----------------------------------------------------------------

  describe('delete — prohibido para todo el mundo (allow delete: if false)', () => {
    it('el DUEÑO no puede borrar su sesión', async () => {
      await assertFails(deleteDoc(doc(cliente(env, DUENO), 'sesiones', M_OCUPADA)));
    });

    it('el ADMIN del tenant no puede borrar la sesión', async () => {
      await assertFails(deleteDoc(doc(adminDemo(env), 'sesiones', M_OCUPADA)));
    });

    it('ni siquiera el SUPER_ADMIN puede borrarla: la sesión es rastro contable', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'sesiones', M_OCUPADA)));
    });
  });
});
