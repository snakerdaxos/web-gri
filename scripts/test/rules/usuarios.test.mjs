// ============================================================================
// GRI — Tests de `firestore.rules` para `match /usuarios/{uid}`.
//
// ★ ESTE ES EL ARCHIVO MÁS IMPORTANTE DE LA SUITE EN TÉRMINOS DE SEGURIDAD ★
//
// `usuarios/{uid}` es el punto de ESCALADA VERTICAL del sistema: es el único
// documento que un cliente recién registrado puede escribir sobre sí mismo. Si
// la regla dejara pasar un `role` arbitrario, cualquiera con la app instalada
// se daría de alta como `admin_restaurante` desde la pantalla de registro.
//
// La mitigación vive en `firestore.rules` (match /usuarios/{uid}) y hasta este
// plan NO TENÍA NI UN TEST. Los casos marcados `// ESCALADA` son justamente
// esos: buscarlos por esa etiqueta en una auditoría futura.
//
// ⚠️ CLAVE PARA ENTENDER POR QUÉ ESTO NO ES CATASTRÓFICO HOY: el doc
// `usuarios/{uid}` es un ESPEJO de perfil y NUNCA autoriza. La autorización
// real son los custom claims `{role, rid}` del token, que solo pone el Admin
// SDK. Ninguna regla hace `get()` sobre `usuarios/`. Aun así, un `role`
// falsificado en el espejo desincronizaría la UI (el panel decide qué menú
// pintar leyendo el perfil) y sería el primer peldaño de un ataque real —
// mantener el espejo honesto es defensa en profundidad, no cosmética.
//
//   read   : el propio usuario | super_admin
//   create : el propio uid + role == 'cliente' + restauranteId == null
//   update : el propio uid + hasOnly(['nombre'])
//   delete : false
//
// ⚠️ `initEnv('usuarios')`: namespace propio obligatorio (ver _contexts.mjs).
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

const YO = 'uid-cliente'; // uid por defecto de cliente()
const OTRO_UID = 'uid-cliente-intruso';
const UID_ADMIN = 'uid-admin-demo'; // uid por defecto de adminDemo()
const UID_NUEVO = 'uid-recien-registrado';

const AHORA = new Date('2026-08-19T12:00:00Z');

/** Payload de auto-registro legítimo; los tests lo mutan campo a campo. */
function perfilCliente(overrides = {}) {
  return {
    email: 'cliente@example.com',
    nombre: 'Cliente Nuevo',
    role: 'cliente',
    restauranteId: null,
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — usuarios', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('usuarios');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'usuarios', YO), perfilCliente({ nombre: 'Yo Mismo' }));
      await setDoc(doc(db, 'usuarios', OTRO_UID), perfilCliente({ nombre: 'Otra Persona' }));
      // Perfil de staff: lo escribe el Admin SDK (seed / callable de 11-08),
      // jamás el cliente. Sirve para probar la lectura del equipo.
      await setDoc(doc(db, 'usuarios', UID_ADMIN), {
        email: 'admin@demo.com',
        nombre: 'Admin Demo',
        role: 'admin_restaurante',
        restauranteId: RID,
        createdAt: AHORA,
      });
    });
  });

  // --- create: AUTO-REGISTRO — el vector de escalada vertical ----------------

  describe('create — auto-registro: solo cliente y sin restaurante', () => {
    it('auto-registro legítimo (role cliente, restauranteId null, uid propio): PERMITIDO', async () => {
      await assertSucceeds(
        setDoc(doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO), perfilCliente()),
      );
    });

    it('// ESCALADA — auto-registro declarándose admin_restaurante: DENEGADO', async () => {
      // ESTE es el vector: la pantalla de registro escribe este documento con
      // el SDK del cliente. Sin `request.resource.data.role == 'cliente'` en la
      // regla, cualquiera se da de alta como admin desde el móvil.
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ role: 'admin_restaurante', restauranteId: RID }),
        ),
      );
    });

    it('// ESCALADA — auto-registro declarándose super_admin: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ role: 'super_admin' }),
        ),
      );
    });

    it('// ESCALADA — auto-registro como mesero: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ role: 'mesero', restauranteId: RID }),
        ),
      );
    });

    it('// ESCALADA — role cliente pero restauranteId "demo": DENEGADO (pertenencia falsa)', async () => {
      // Un cliente NO pertenece a un restaurante. Colar un rid en el espejo
      // haría que la UI del panel lo tratara como parte del equipo.
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ restauranteId: RID }),
        ),
      );
    });

    it('// ESCALADA — crear el perfil de OTRO uid: DENEGADO (suplantación)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, UID_NUEVO), 'usuarios', 'uid-de-la-victima'), perfilCliente()),
      );
    });

    it('ANÓNIMO no puede crear ningún perfil: la regla exige signedIn()', async () => {
      await assertFails(setDoc(doc(anon(env), 'usuarios', UID_NUEVO), perfilCliente()));
    });

    it('un ADMIN con claims tampoco escribe su propio espejo de staff desde el cliente', async () => {
      // Consecuencia deliberada: el perfil de staff SOLO lo crea el Admin SDK
      // (seed / callable de 11-08), que se salta las rules. Si esto pasara a
      // estar permitido, el espejo dejaría de ser fiable.
      await assertFails(
        setDoc(
          doc(adminDemo(env), 'usuarios', 'uid-admin-nuevo'),
          perfilCliente({ role: 'admin_restaurante', restauranteId: RID }),
        ),
      );
    });
  });

  // --- update: el role queda CONGELADO ---------------------------------------

  describe('update — solo el nombre; role y restauranteId congelados', () => {
    it('el propio usuario puede cambiar su nombre', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), { nombre: 'Yo Renombrado' }),
      );
    });

    it('// ESCALADA — el propio usuario ascendiéndose a admin_restaurante: DENEGADO', async () => {
      // El segundo vector de auto-ascenso: registrarse limpio y ascender
      // después. `hasOnly(['nombre'])` lo cierra.
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), { role: 'admin_restaurante' }),
      );
    });

    it('// ESCALADA — el propio usuario asignándose un restauranteId: DENEGADO', async () => {
      await assertFails(updateDoc(doc(cliente(env, YO), 'usuarios', YO), { restauranteId: RID }));
    });

    it('// ESCALADA — colar el role junto a un cambio de nombre legítimo: DENEGADO', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), {
          nombre: 'Yo Renombrado',
          role: 'cocina',
        }),
      );
    });

    it('cambiar el email tampoco: la regla permite EXACTAMENTE una clave', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), { email: 'otro@example.com' }),
      );
    });

    it('editar el perfil de OTRA persona: DENEGADO', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', OTRO_UID), { nombre: 'Te renombro' }),
      );
    });

    it('el SUPER_ADMIN tampoco edita perfiles ajenos desde el cliente', async () => {
      // Veredicto fijado: la rama de update NO tiene excepción para isSuper()
      // (la de read sí). Cambiar roles es trabajo del Admin SDK, no del panel.
      await assertFails(
        updateDoc(doc(superAdmin(env), 'usuarios', YO), { nombre: 'Renombrado por super' }),
      );
    });
  });

  // --- read -------------------------------------------------------------------

  describe('read — el propio perfil o el super_admin', () => {
    it('el propio usuario puede leer su perfil', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, YO), 'usuarios', YO)));
    });

    it('un CLIENTE NO puede leer el perfil de otra persona', async () => {
      await assertFails(getDoc(doc(cliente(env, YO), 'usuarios', OTRO_UID)));
    });

    it('el SUPER_ADMIN puede leer el perfil de cualquiera', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'usuarios', YO)));
    });

    it('// AMPLIADO EN 11-10 — el ADMIN del restaurante NO puede leer el perfil de su equipo', async () => {
      // Comportamiento ACTUAL, afirmado a propósito: hoy la regla solo deja
      // leer el propio doc o todo al super_admin, así que la pantalla de
      // gestión de equipo del panel NO PUEDE EXISTIR todavía.
      //
      // El plan 11-10 AMPLIARÁ la regla para que un `admin_restaurante` lea los
      // perfiles de su propio rid. Cuando eso ocurra, este test debe cambiar de
      // veredicto **conscientemente** — no es una regresión, es el cambio que
      // ese plan viene a hacer. La ampliación debe quedar acotada al rid del
      // llamador (decisión del CONTEXT de la fase).
      await assertFails(getDoc(doc(adminDemo(env), 'usuarios', YO)));
    });

    it('ANÓNIMO no puede leer ningún perfil', async () => {
      await assertFails(getDoc(doc(anon(env), 'usuarios', YO)));
    });
  });

  // --- delete -----------------------------------------------------------------

  describe('delete — prohibido siempre (allow delete: if false)', () => {
    it('el propio usuario no puede borrar su perfil', async () => {
      await assertFails(deleteDoc(doc(cliente(env, YO), 'usuarios', YO)));
    });

    it('ni el SUPER_ADMIN: borrar cuentas es trabajo del Admin SDK', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'usuarios', YO)));
    });
  });
});
