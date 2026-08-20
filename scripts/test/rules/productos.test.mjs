// ============================================================================
// GRI — Tests de `firestore.rules` para `match /productos/{productoId}`.
//
// ⚠️ ESTO NO ES UN TEST QUE VAYA DE ROJO A VERDE. Ver la cabecera larga de
// `categorias.test.mjs`: las rules ya son correctas; lo que está mal es la
// QUERY del cliente. Aquí el caso es aún más estricto, porque la rama pública
// exige DOS campos (`firestore.rules:121-124`):
//
//     match /productos/{productoId} {
//       allow read: if (resource.data.activo == true
//                       && resource.data.disponible == true)
//                   || menuStaffOf(resource.data.restauranteId);
//
// Consecuencia probada abajo: replicar la regla A MEDIAS (solo `activo`) NO
// basta. Firestore evalúa la consulta, no los documentos: mientras la query no
// acote también `disponible`, podría alcanzar un producto agotado y la
// petición entera se rechaza.
//
// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
// DEBE llevar `where('X', …)`**.
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
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

import { adminDemo, adminOtro, cliente, initEnv, sembrar } from './_contexts.mjs';

const RID = 'demo';

describe('firestore.rules — productos', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('productos');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'productos', 'p-ok'), {
        restauranteId: RID,
        categoriaId: 'c-activa',
        nombre: 'Bandeja paisa',
        precio: 28000,
        activo: true,
        disponible: true,
      });
      await setDoc(doc(db, 'productos', 'p-inactivo'), {
        restauranteId: RID,
        categoriaId: 'c-activa',
        nombre: 'Plato retirado de carta',
        precio: 30000,
        activo: false,
        disponible: true,
      });
      await setDoc(doc(db, 'productos', 'p-agotado'), {
        restauranteId: RID,
        categoriaId: 'c-activa',
        nombre: 'Ajiaco santafereño',
        precio: 25000,
        activo: true,
        disponible: false,
      });
    });
  });

  // --- Cliente autenticado ---------------------------------------------------

  it('CLIENTE: query solo con where("restauranteId") queda DENEGADA', async () => {
    const db = cliente(env);
    // La query que hace hoy restaurantes_provider.dart.
    await assertFails(
      getDocs(query(collection(db, 'productos'), where('restauranteId', '==', RID))),
    );
  });

  it('CLIENTE: query con activo==true pero SIN disponible==true queda DENEGADA (replicación parcial no basta)', async () => {
    const db = cliente(env);
    await assertFails(
      getDocs(
        query(
          collection(db, 'productos'),
          where('restauranteId', '==', RID),
          where('activo', '==', true),
        ),
      ),
    );
  });

  it('CLIENTE: query con activo==true + disponible==true → PERMITIDA y devuelve EXACTAMENTE 1 doc', async () => {
    const db = cliente(env);
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'productos'),
          where('restauranteId', '==', RID),
          where('activo', '==', true),
          where('disponible', '==', true),
        ),
      ),
    );
    assert.equal(snap.size, 1, 'ni el inactivo ni el agotado deben salir');
    assert.equal(snap.docs[0].id, 'p-ok');
  });

  // --- Staff del tenant ------------------------------------------------------

  it('ADMIN del tenant: query sin los filtros de activo/disponible → PERMITIDA (ve inactivos y agotados)', async () => {
    const db = adminDemo(env);
    const snap = await assertSucceeds(
      getDocs(query(collection(db, 'productos'), where('restauranteId', '==', RID))),
    );
    assert.equal(snap.size, 3);
  });

  it('ADMIN del tenant: query SIN NINGÚN filtro (ni restauranteId) queda DENEGADA', async () => {
    // Ninguna de las dos ramas de la regla es demostrable sobre una colección
    // sin acotar: `menuStaffOf(resource.data.restauranteId)` exige que la query
    // fije `restauranteId`. El staff tampoco escapa a "queries are all or
    // nothing".
    const db = adminDemo(env);
    await assertFails(getDocs(query(collection(db, 'productos'))));
  });

  it('ADMIN de OTRO tenant: query sobre "demo" queda DENEGADA', async () => {
    const db = adminOtro(env);
    await assertFails(
      getDocs(query(collection(db, 'productos'), where('restauranteId', '==', RID))),
    );
  });

  // --- Escritura: el cliente jamás toca el menú ------------------------------

  it('CLIENTE: create de un producto queda DENEGADO', async () => {
    const db = cliente(env);
    await assertFails(
      setDoc(doc(db, 'productos', 'p-pirata'), {
        restauranteId: RID,
        categoriaId: 'c-activa',
        nombre: 'Gratis total',
        precio: 0,
        activo: true,
        disponible: true,
      }),
    );
  });

  it('CLIENTE: update de un producto queda DENEGADO', async () => {
    const db = cliente(env);
    await assertFails(updateDoc(doc(db, 'productos', 'p-ok'), { precio: 1 }));
  });

  it('CLIENTE: delete de un producto queda DENEGADO', async () => {
    const db = cliente(env);
    await assertFails(deleteDoc(doc(db, 'productos', 'p-ok')));
  });

  // --- AUDITORÍA 11-27: read de un doc AUSENTE -------------------------------
  //
  // Idéntico a `categorias`: la rama de read desreferencia `resource.data`, así
  // que el doc inexistente se DENIEGA. NO se toca la regla porque nada depende
  // de leer el hueco: los ids son autoId
  // (`collection('productos').add(...)`, menu_provider.dart:163) y el menú se
  // lee siempre por query. Veredicto fijado por escrito.

  it('AUDITORÍA: getDoc de un producto INEXISTENTE queda denegado — sin impacto (autoId + solo queries)', async () => {
    await assertFails(getDoc(doc(adminDemo(env), 'productos', 'prod-que-no-existe')));
  });

  it('AUDITORÍA: una query VACÍA sí funciona — es como el menú lee de verdad', async () => {
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(cliente(env), 'productos'),
          where('restauranteId', '==', 'restaurante-inexistente'),
          where('activo', '==', true),
          where('disponible', '==', true),
        ),
      ),
    );
    assert.equal(snap.size, 0);
  });
});
