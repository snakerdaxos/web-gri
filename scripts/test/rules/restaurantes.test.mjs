// ============================================================================
// GRI — Tests de `firestore.rules` para `match /restaurantes/{restId}` y para
// el DEFAULT DENY de las colecciones sin `match`.
//
//   read           : true  (descubrimiento público — la app lista sin login)
//   create, delete : isSuper()
//   update         : super  → hasOnly(['activo'])                (toggle PLAT-05)
//                    cliente→ hasOnly(['califProm','califCount'])
//                             + califProm is number + califCount is int
//
// ⚠️ GAP ESTRUCTURAL ACEPTADO EN v1 (T-11-04-04, documentado en las propias
// rules): un cliente puede escribir `califProm`/`califCount` sin que exista una
// calificación real detrás, porque sin backend no hay forma de validar el
// agregado dentro de la transacción. La validación fuerte necesita Cloud
// Functions y está DIFERIDA por decisión del usuario.
//
// Lo que hacen los tests de abajo NO es cerrar ese hueco: es FIJAR SU TAMAÑO
// EXACTO. Un cliente puede tocar esas dos claves y NADA más — ni `activo`, ni
// `nombre`, ni tipos distintos de los declarados. Si mañana alguien relaja el
// `hasOnly`, el agujero pasaría de "el número de estrellas es poco fiable" a
// "cualquiera reactiva o renombra un restaurante", y estos tests lo impiden.
//
// El bloque final cubre el default deny de Firestore sobre `plataforma/`, el
// documento centinela del bootstrap (plan 11-07).
//
// ⚠️ `initEnv('restaurantes')`: namespace propio obligatorio (_contexts.mjs).
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  adminDemo,
  anon,
  cliente,
  cocina,
  initEnv,
  mesero,
  sembrar,
  superAdmin,
} from './_contexts.mjs';

const RID = 'demo';

describe('firestore.rules — restaurantes', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('restaurantes');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'restaurantes', RID), {
        nombre: 'Restaurante Demo',
        direccion: 'Calle 1 #2-3',
        activo: true,
        califProm: 4.2,
        califCount: 10,
      });
    });
  });

  // --- read: público ---------------------------------------------------------

  describe('read — público por diseño (allow read: if true)', () => {
    it('un ANÓNIMO puede leer la ficha de un restaurante (descubrimiento sin login)', async () => {
      await assertSucceeds(getDoc(doc(anon(env), 'restaurantes', RID)));
    });

    it('un CLIENTE también, obviamente', async () => {
      await assertSucceeds(getDoc(doc(cliente(env), 'restaurantes', RID)));
    });
  });

  // --- create / delete: solo super_admin -------------------------------------

  describe('create y delete — potestad exclusiva del super_admin', () => {
    it('el SUPER_ADMIN puede crear un restaurante (es el alta de la plataforma)', async () => {
      await assertSucceeds(
        setDoc(doc(superAdmin(env), 'restaurantes', 'nuevo-rest'), {
          nombre: 'Restaurante Nuevo',
          activo: true,
          califProm: 0,
          califCount: 0,
        }),
      );
    });

    it('un ADMIN_RESTAURANTE NO puede crear restaurantes — ESCALADA horizontal', async () => {
      // Si pudiera, un admin se fabricaría restaurantes ajenos a la plataforma.
      await assertFails(
        setDoc(doc(adminDemo(env), 'restaurantes', 'rest-pirata'), {
          nombre: 'Mi Cadena',
          activo: true,
          califProm: 0,
          califCount: 0,
        }),
      );
    });

    it('un CLIENTE NO puede crear restaurantes', async () => {
      await assertFails(
        setDoc(doc(cliente(env), 'restaurantes', 'rest-cliente'), {
          nombre: 'Mi Bar',
          activo: true,
          califProm: 0,
          califCount: 0,
        }),
      );
    });

    it('un ANÓNIMO tampoco', async () => {
      await assertFails(
        setDoc(doc(anon(env), 'restaurantes', 'rest-anon'), { nombre: 'X', activo: true }),
      );
    });

    it('el SUPER_ADMIN puede borrar un restaurante', async () => {
      await assertSucceeds(deleteDoc(doc(superAdmin(env), 'restaurantes', RID)));
    });

    it('el ADMIN del propio restaurante NO puede borrarlo', async () => {
      await assertFails(deleteDoc(doc(adminDemo(env), 'restaurantes', RID)));
    });

    it('un CLIENTE no puede borrar un restaurante', async () => {
      await assertFails(deleteDoc(doc(cliente(env), 'restaurantes', RID)));
    });
  });

  // --- update rama SUPER: solo el toggle de activo ---------------------------

  describe('update por super_admin — SOLO el toggle de activo', () => {
    it('el SUPER_ADMIN puede desactivar un restaurante', async () => {
      await assertSucceeds(updateDoc(doc(superAdmin(env), 'restaurantes', RID), { activo: false }));
    });

    it('el SUPER_ADMIN NO puede renombrarlo desde el panel', async () => {
      // La ficha la edita su propio admin por otra vía; el super solo tiene la
      // palanca de activación (paridad PLAT-05).
      await assertFails(
        updateDoc(doc(superAdmin(env), 'restaurantes', RID), { nombre: 'Renombrado' }),
      );
    });

    it('el SUPER_ADMIN NO puede colar el nombre junto al toggle', async () => {
      await assertFails(
        updateDoc(doc(superAdmin(env), 'restaurantes', RID), {
          activo: false,
          nombre: 'Renombrado',
        }),
      );
    });

    it('el ADMIN del restaurante NO puede reactivarse a sí mismo', async () => {
      // Ninguna de las dos ramas del update le aplica: no es super y su claim
      // `role` lo excluye de isCliente().
      await assertFails(updateDoc(doc(adminDemo(env), 'restaurantes', RID), { activo: false }));
    });

    it('ni el MESERO ni la COCINA pueden tocar el flag activo', async () => {
      await assertFails(updateDoc(doc(mesero(env), 'restaurantes', RID), { activo: false }));
      await assertFails(updateDoc(doc(cocina(env), 'restaurantes', RID), { activo: false }));
    });
  });

  // --- update rama CLIENTE: el agregado de calificaciones --------------------

  describe('update por cliente — SOLO el agregado califProm/califCount (gap v1 acotado)', () => {
    it('un CLIENTE puede actualizar califProm y califCount con los tipos correctos', async () => {
      // PERMITIDO a propósito: es la segunda escritura de la transacción de
      // calificar. Sin backend no hay forma de exigir que venga acompañada de
      // una calificación real — ver la cabecera de este archivo.
      await assertSucceeds(
        updateDoc(doc(cliente(env), 'restaurantes', RID), { califProm: 4.5, califCount: 11 }),
      );
    });

    it('un CLIENTE NO puede tocar el flag activo — ESCALADA (reactivar un local cerrado)', async () => {
      await assertFails(updateDoc(doc(cliente(env), 'restaurantes', RID), { activo: false }));
    });

    it('un CLIENTE NO puede renombrar el restaurante', async () => {
      await assertFails(
        updateDoc(doc(cliente(env), 'restaurantes', RID), { nombre: 'Comida Horrible S.A.' }),
      );
    });

    it('un CLIENTE NO puede colar "activo" junto al agregado legítimo', async () => {
      // El intento realista: aprovechar la única escritura permitida como
      // vehículo para una clave prohibida. `hasOnly` lo corta.
      await assertFails(
        updateDoc(doc(cliente(env), 'restaurantes', RID), {
          califProm: 4.5,
          califCount: 11,
          activo: false,
        }),
      );
    });

    it('califCount NO entero: DENEGADO (la regla exige `is int`)', async () => {
      await assertFails(
        updateDoc(doc(cliente(env), 'restaurantes', RID), { califProm: 4.5, califCount: 11.5 }),
      );
    });

    it('califProm como string: DENEGADO (la regla exige `is number`)', async () => {
      await assertFails(
        updateDoc(doc(cliente(env), 'restaurantes', RID), { califProm: '5', califCount: 11 }),
      );
    });

    it('un ANÓNIMO no puede tocar el agregado: isCliente() exige signedIn()', async () => {
      await assertFails(
        updateDoc(doc(anon(env), 'restaurantes', RID), { califProm: 5, califCount: 99 }),
      );
    });
  });

  // --- colecciones NO declaradas: default deny -------------------------------

  describe('colecciones no declaradas — default deny', () => {
    // `plataforma/bootstrap` es el documento CENTINELA del plan 11-07: el que
    // marca que el primer super_admin ya existe y que la Cloud Function de
    // bootstrap queda inerte para siempre. SOLO debe tocarlo el Admin SDK
    // desde la función, que se salta las rules por completo.
    //
    // Hoy ese `match` NO EXISTE: estos tests pasan por el default deny de
    // Firestore ("si ninguna regla lo permite, está prohibido"). Se escriben
    // ANTES de que exista a propósito — cuando 11-07 añada el match explícito,
    // deben seguir en verde. Si alguno se pusiera en rojo, la regla nueva
    // habría abierto el centinela al SDK cliente, que es exactamente el fallo
    // que convertiría el bootstrap en una puerta de escalada.
    const CENTINELA = ['plataforma', 'bootstrap'];

    it('un ANÓNIMO no puede leer plataforma/bootstrap', async () => {
      await assertFails(getDoc(doc(anon(env), ...CENTINELA)));
    });

    it('un CLIENTE no puede leer plataforma/bootstrap', async () => {
      await assertFails(getDoc(doc(cliente(env), ...CENTINELA)));
    });

    it('un ADMIN_RESTAURANTE no puede leer plataforma/bootstrap', async () => {
      await assertFails(getDoc(doc(adminDemo(env), ...CENTINELA)));
    });

    it('// ESCALADA — ni el SUPER_ADMIN puede leer plataforma/bootstrap', async () => {
      await assertFails(getDoc(doc(superAdmin(env), ...CENTINELA)));
    });

    it('// ESCALADA — ni el SUPER_ADMIN puede ESCRIBIR plataforma/bootstrap', async () => {
      // El caso crítico: si el centinela fuera escribible desde el SDK
      // cliente, se podría borrar o alterar para volver a disparar el
      // bootstrap y crear un segundo super_admin.
      await assertFails(
        setDoc(doc(superAdmin(env), ...CENTINELA), { creado: true, uid: 'uid-super' }),
      );
    });

    it('un CLIENTE no puede escribir plataforma/bootstrap', async () => {
      await assertFails(setDoc(doc(cliente(env), ...CENTINELA), { creado: false }));
    });

    it('un ANÓNIMO no puede escribir plataforma/bootstrap', async () => {
      await assertFails(setDoc(doc(anon(env), ...CENTINELA), { creado: false }));
    });

    it('tampoco se puede escribir en una colección inventada cualquiera', async () => {
      // Generaliza el default deny más allá del centinela: nada fuera de los
      // 9 `match` declarados es escribible desde el SDK cliente.
      await assertFails(
        setDoc(doc(superAdmin(env), 'coleccion-inventada', 'doc'), { cualquier: 'cosa' }),
      );
    });
  });
});
