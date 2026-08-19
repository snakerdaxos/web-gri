// ============================================================================
// GRI — SMOKE del arnés de tests de `firestore.rules`.
//
// Esto NO es un test de producto: es el GATE del andamiaje. Verifica que la
// cadena entera funciona de punta a punta —
//   run_emulators.mjs resuelve Java → arranca el emulador de Firestore →
//   initializeTestEnvironment carga firestore.rules → los contextos por rol
//   producen un request.auth correcto → assertSucceeds/assertFails discriminan.
//
// Si estos 2 casos están en verde, los tests de rules de los planes 11-03,
// 11-04 y 11-08 tienen dónde apoyarse.
//
// Se apoya en la regla `match /restaurantes/{restId}` (firestore.rules:85-101):
//   allow read: if true;              → lectura pública
//   allow create, delete: if isSuper();
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

import { anon, initEnv, sembrar } from './_contexts.mjs';

const RID = 'demo';

describe('smoke — arnés de tests de firestore.rules', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv();
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'restaurantes', RID), {
        nombre: 'Restaurante Demo',
        activo: true,
        califProm: 0,
        califCount: 0,
      });
    });
  });

  it('un usuario ANÓNIMO puede leer restaurantes/{id} (allow read: if true)', async () => {
    const db = anon(env);
    await assertSucceeds(getDoc(doc(db, 'restaurantes', RID)));
  });

  it('un usuario ANÓNIMO NO puede crear restaurantes/{id} (solo isSuper())', async () => {
    const db = anon(env);
    await assertFails(
      setDoc(doc(db, 'restaurantes', 'intruso'), { nombre: 'Pirata', activo: true }),
    );
  });
});
