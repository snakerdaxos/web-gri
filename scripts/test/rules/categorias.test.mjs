// ============================================================================
// GRI — Tests de `firestore.rules` para `match /categorias/{categoriaId}`.
//
// ⚠️ ESTO NO ES UN TEST QUE VAYA DE ROJO A VERDE.
//
// Las rules de `categorias` ya son correctas. Lo que está mal —y lo que esta
// suite DEMUESTRA con aserciones ejecutables— es la QUERY de la app cliente
// (`app_cliente/lib/features/restaurantes/restaurantes_provider.dart`), que
// consulta `categorias` filtrando `restauranteId` y descarta las inactivas
// CLIENT-SIDE, después de traerlas.
//
// Firestore evalúa las security rules contra la CONSULTA, nunca contra los
// documentos devueltos (doc. oficial: "security rules are not filters —
// queries are all or nothing" · "If a query could potentially return documents
// that the client does not have permission to read, the entire request fails"
// · "Even if the user authored every story in the database, the query is
// rejected"). Por eso el menú del cliente está denegado DESDE EL DÍA UNO,
// incluso contra el seed prístino donde todo está activo: NO es un edge case
// de "hay una categoría inactiva", es incondicional.
//
// `firestore.rules:104-108` ya lo advertía por escrito:
//
//     // OJO (rules por-doc en queries): la query pública DEBE filtrar
//     // activo == true o un solo doc inactivo deniega toda la query.
//     match /categorias/{categoriaId} {
//       allow read: if resource.data.activo == true
//                   || menuStaffOf(resource.data.restauranteId);
//
// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
// DEBE llevar `where('X', …)`**.
//
// Organización: un archivo por colección (por `match` de las rules), no por
// rol — tocar `match /categorias` dice exactamente qué archivo revisar.
// ============================================================================

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDocs,
  orderBy,
  query,
  setDoc,
  where,
} from 'firebase/firestore';

import { adminDemo, adminOtro, anon, cliente, initEnv, sembrar } from './_contexts.mjs';

const RID = 'demo';
const OTRO = 'otro';

describe('firestore.rules — categorias', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('categorias');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    // Sembrado con las rules DESACTIVADAS (equivalente al Admin SDK): el
    // arrange nunca debe pasar por la capa que estamos probando.
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'categorias', 'c-activa'), {
        restauranteId: RID,
        nombre: 'Platos fuertes',
        orden: 1,
        activo: true,
      });
      await setDoc(doc(db, 'categorias', 'c-inactiva'), {
        restauranteId: RID,
        nombre: 'Temporada navideña',
        orden: 2,
        activo: false,
      });
    });
  });

  // --- Cliente autenticado (sin claims: la ausencia de `role` ES cliente) ---

  it('CLIENTE: query SIN where("activo") queda DENEGADA — el bug de 11-03', async () => {
    const db = cliente(env);
    // Esta es, literalmente, la query que hace hoy restaurantes_provider.dart.
    await assertFails(
      getDocs(query(collection(db, 'categorias'), where('restauranteId', '==', RID))),
    );
  });

  it('CLIENTE: query CON where("activo", "==", true) queda PERMITIDA', async () => {
    const db = cliente(env);
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'categorias'),
          where('restauranteId', '==', RID),
          where('activo', '==', true),
        ),
      ),
    );
  });

  it('CLIENTE: la query filtrada devuelve EXACTAMENTE 1 doc (el filtro no es cosmético)', async () => {
    const db = cliente(env);
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'categorias'),
          where('restauranteId', '==', RID),
          where('activo', '==', true),
        ),
      ),
    );
    assert.equal(snap.size, 1, 'la categoría inactiva NO debe salir');
    assert.equal(snap.docs[0].id, 'c-activa');
  });

  // --- Staff del tenant ------------------------------------------------------

  it('ADMIN del tenant: where("restauranteId") + orderBy("orden") sin filtro de activo → PERMITIDA', async () => {
    const db = adminDemo(env);
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'categorias'),
          where('restauranteId', '==', RID),
          orderBy('orden'),
        ),
      ),
    );
    // El staff ve las inactivas: es la query del panel (menu_provider.dart).
    assert.equal(snap.size, 2);
    assert.deepEqual(
      snap.docs.map((d) => d.id),
      ['c-activa', 'c-inactiva'],
      'orderBy("orden") respetado',
    );
  });

  it('ADMIN de OTRO tenant: la misma query sobre "demo" queda DENEGADA', async () => {
    const db = adminOtro(env, `uid-admin-${OTRO}`);
    await assertFails(
      getDocs(
        query(
          collection(db, 'categorias'),
          where('restauranteId', '==', RID),
          orderBy('orden'),
        ),
      ),
    );
  });

  // --- Anónimo ---------------------------------------------------------------

  it('ANÓNIMO: query CON where("activo", "==", true) queda PERMITIDA', async () => {
    // VEREDICTO FIJADO POR EL PLAN 11-03, no "el que se observe".
    // La regla es `resource.data.activo == true || menuStaffOf(...)` y la
    // PRIMERA rama no exige sesión — `signedIn()` solo cortocircuita dentro
    // del helper de la segunda rama. El descubrimiento de restaurantes y su
    // menú es público por diseño (`restaurantes` es `allow read: if true`).
    // Si este test falla, el bug está en la regla o en el test, NO en esta
    // expectativa: PROHIBIDO reescribir la aserción para que coincida con lo
    // observado.
    const db = anon(env);
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'categorias'),
          where('restauranteId', '==', RID),
          where('activo', '==', true),
        ),
      ),
    );
    assert.equal(snap.size, 1);
  });

  it('ANÓNIMO: query SIN filtro de activo queda DENEGADA', async () => {
    const db = anon(env);
    await assertFails(
      getDocs(query(collection(db, 'categorias'), where('restauranteId', '==', RID))),
    );
  });
});
