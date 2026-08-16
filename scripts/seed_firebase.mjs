#!/usr/bin/env node
// ============================================================================
// seed_firebase.mjs — Seed idempotente del restaurante demo GRI (Phase 10).
//
// Port 1:1 de backend/app/services/seed_service.py (paridad de contenido):
// restaurante demo + 6 usuarios (Auth + claims {role, rid} + doc espejo) +
// 8 mesas con doc ID determinista (QR) + 4 categorías + 16 productos int COP.
//
// DOS MODOS (se detectan solos):
//   1. EMULADORES (sin credenciales) — setear ANTES de correr:
//        FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
//        FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
//      (firebase emulators:exec ya los inyecta para el comando hijo)
//   2. PROYECTO REAL — GOOGLE_APPLICATION_CREDENTIALS=./scripts/serviceAccountKey.json
//      (Firebase Console → Project Settings → Service Accounts → Generate new
//       private key; el archivo está GITIGNORED — NUNCA commitearlo)
//
// Idempotencia por natural key ANTES de cada write (doble corrida = mismo
// estado, sin duplicados):
//   usuario     → email (createUser catch auth/email-already-exists →
//                 getUserByEmail; claims y espejo con set/merge SIEMPRE)
//   mesa        → doc ID GRI-MESA-{rid}-{num:03d} (set merge)
//   categoría   → (restauranteId, nombre)
//   producto    → (restauranteId, categoriaId, nombre)
//   restaurante → doc ID 'demo' (set merge)
//
// Custom claims: SOLO este script (Admin SDK) puede escribirlos — ningún
// cliente puede modificar sus propios claims. Correr el seed ANTES del
// primer login de cada usuario ⇒ el token ya nace con claims (sin el pitfall
// de propagación de hasta 1h; ver docs/FIREBASE_SETUP.md §4).
// ============================================================================

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// --- Constantes (paridad exacta con seed_service.py) ------------------------

const PROJECT_ID = 'p-gri-b5b40';
const RID = 'demo'; // doc ID del restaurante demo
const DEMO_PASSWORD = 'Demo!1234';

// 6 usuarios: super_admin global + staff demo + 2 clientes cross-tenant.
const USERS = [
  { email: 'admin@gri.dev', nombre: 'Super Admin', role: 'super_admin', rid: null },
  { email: 'admin@demo.gri.dev', nombre: 'Admin Demo', role: 'admin_restaurante', rid: RID },
  { email: 'mesero@demo.gri.dev', nombre: 'Mesero Demo', role: 'mesero', rid: RID },
  { email: 'cocina@demo.gri.dev', nombre: 'Cocina Demo', role: 'cocina', rid: RID },
  { email: 'carlos@demo.gri.dev', nombre: 'Carlos Cliente', role: 'cliente', rid: null },
  { email: 'maria@demo.gri.dev', nombre: 'María Cliente', role: 'cliente', rid: null },
];

// Capacidades de las 8 mesas (índice 0 → mesa #1 ... índice 7 → mesa #8).
const MESA_CAPACIDADES = [2, 2, 4, 4, 4, 6, 6, 8];

// Categorías: [nombre, orden].
const CATEGORIAS = [
  ['Entradas', 1],
  ['Platos Fuertes', 2],
  ['Bebidas', 3],
  ['Postres', 4],
];

// Productos: [categoría, nombre, descripción, precio COP int].
const PRODUCTOS = [
  // Entradas (4)
  ['Entradas', 'Patacón con Hogao', 'Patacón crujiente con hogao casero', 12000],
  ['Entradas', 'Empanadas x3', 'Tres empanadas de carne con ají', 9500],
  ['Entradas', 'Arepa Rellena', 'Arepa rellena de queso y carne', 11000],
  ['Entradas', 'Sopita del Día', 'Sopa tradicional de la casa', 14000],
  // Platos Fuertes (5)
  ['Platos Fuertes', 'Bandeja Paisa', 'Bandeja paisa tradicional completa', 32000],
  ['Platos Fuertes', 'Ajiaco Santafereño', 'Ajiaco bogotano con tres papas y guascas', 28000],
  ['Platos Fuertes', 'Lechona Tolimense', 'Lechona tolimense con insulso y arepa', 30000],
  ['Platos Fuertes', 'Trout Moqueta', 'Trucha con moqueta de frijoles', 34000],
  ['Platos Fuertes', 'Sancocho', 'Sancocho trifásico de la casa', 26000],
  // Bebidas (4)
  ['Bebidas', 'Limonada de Coco', 'Limonada de coco helada', 9000],
  ['Bebidas', 'Jugo Natural', 'Jugo natural de fruta de la temporada', 8000],
  ['Bebidas', 'Gaseosa', 'Gaseosa 350ml', 5500],
  ['Bebidas', 'Cerveza Artesanal', 'Cerveza artesanal nacional', 12000],
  // Postres (3)
  ['Postres', 'Tres Leches', 'Postre de tres leches', 9500],
  ['Postres', 'Flan de Coco', 'Flan de coco con arequipe', 8500],
  ['Postres', 'Café con Leche', 'Café con leche colombiano', 4500],
];

// --- Bootstrap: modo emuladores vs proyecto real ----------------------------

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const AUTH_EMU = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FS_EMU = process.env.FIRESTORE_EMULATOR_HOST;

let app;
if (credPath) {
  console.log(`[modo] PROYECTO REAL (${PROJECT_ID}) — credential: ${credPath}`);
  const serviceAccount = JSON.parse(readFileSync(credPath, 'utf8'));
  app = initializeApp({
    credential: cert(serviceAccount),
    projectId: serviceAccount.project_id || PROJECT_ID,
  });
} else {
  if (!AUTH_EMU || !FS_EMU) {
    console.error(
      '[error] Sin GOOGLE_APPLICATION_CREDENTIALS se requiere modo EMULADORES:\n' +
        '  setea FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 y\n' +
        '  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 (o corre dentro de\n' +
        '  firebase emulators:exec). Guía completa: docs/FIREBASE_SETUP.md'
    );
    process.exit(1);
  }
  console.log(
    `[modo] EMULADORES — auth=${AUTH_EMU}, firestore=${FS_EMU} (sin credenciales)`
  );
  app = initializeApp({ projectId: PROJECT_ID });
}

const auth = getAuth(app);
const db = getFirestore(app);

const stats = {
  restaurante: { creado: 0, actualizado: 0 },
  usuarios: { creados: 0, existentes: 0 },
  mesas: { creadas: 0, actualizadas: 0 },
  categorias: { creadas: 0, existentes: 0 },
  productos: { creados: 0, existentes: 0 },
};

// --- Seed --------------------------------------------------------------------

async function seedRestaurante() {
  const ref = db.doc(`restaurantes/${RID}`);
  const existed = (await ref.get()).exists;
  await ref.set(
    {
      nombre: 'Restaurante Demo GRI',
      descripcion: 'Restaurante de demostración de la plataforma GRI.',
      tipoCocina: 'Colombiana',
      direccion: 'Cra. 7 #63-44, Bogotá',
      activo: true,
      califProm: 0,
      califCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  if (existed) stats.restaurante.actualizado += 1;
  else stats.restaurante.creado += 1;
  console.log(
    `[restaurante] ${RID} → ${existed ? 'actualizado (merge)' : 'creado'}`
  );
}

async function seedUsuarios() {
  for (const u of USERS) {
    // Natural key: email.
    let user;
    let creado = false;
    try {
      user = await auth.createUser({
        email: u.email,
        password: DEMO_PASSWORD,
        displayName: u.nombre,
        emailVerified: true,
      });
      creado = true;
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        user = await auth.getUserByEmail(u.email);
      } else {
        throw e;
      }
    }
    // Claims y doc espejo: set/merge SIEMPRE (refrescan en cada corrida).
    await auth.setCustomUserClaims(user.uid, { role: u.role, rid: u.rid });
    await db.doc(`usuarios/${user.uid}`).set(
      {
        nombre: u.nombre,
        email: u.email,
        role: u.role,
        restauranteId: u.rid,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    if (creado) stats.usuarios.creados += 1;
    else stats.usuarios.existentes += 1;
    console.log(
      `[usuarios] ${u.email} → ${creado ? 'creado' : 'existente'} (claims {role:${u.role}, rid:${u.rid ?? 'null'}} + espejo refrescados)`
    );
  }
}

async function seedMesas() {
  for (let i = 1; i <= MESA_CAPACIDADES.length; i++) {
    // Doc ID determinista = código QR de la mesa. Con RID='demo' produce
    // GRI-MESA-demo-001 .. GRI-MESA-demo-008.
    const docId = `GRI-MESA-${RID}-${String(i).padStart(3, '0')}`;
    const ref = db.doc(`mesas/${docId}`);
    const existed = (await ref.get()).exists;
    await ref.set(
      {
        restauranteId: RID,
        numero: i,
        capacidad: MESA_CAPACIDADES[i - 1],
        estado: 'disponible',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    if (existed) stats.mesas.actualizadas += 1;
    else stats.mesas.creadas += 1;
    console.log(
      `[mesas] ${docId} → ${existed ? 'actualizada (merge)' : 'creada'}`
    );
  }
}

async function seedCategorias() {
  const refs = new Map();
  for (const [nombre, orden] of CATEGORIAS) {
    // Natural key: (restauranteId, nombre).
    const snap = await db
      .collection('categorias')
      .where('restauranteId', '==', RID)
      .where('nombre', '==', nombre)
      .limit(1)
      .get();
    let ref;
    if (snap.empty) {
      ref = db.collection('categorias').doc();
      await ref.set({
        restauranteId: RID,
        nombre,
        orden,
        activo: true,
      });
      stats.categorias.creadas += 1;
      console.log(`[categorias] ${nombre} → creada`);
    } else {
      ref = snap.docs[0].ref;
      stats.categorias.existentes += 1;
      console.log(`[categorias] ${nombre} → existente`);
    }
    refs.set(nombre, ref);
  }
  return refs;
}

async function seedProductos(catRefs) {
  for (const [catNombre, nombre, descripcion, precio] of PRODUCTOS) {
    const categoriaRef = catRefs.get(catNombre);
    // Natural key: (restauranteId, categoriaId, nombre).
    const snap = await db
      .collection('productos')
      .where('restauranteId', '==', RID)
      .where('categoriaId', '==', categoriaRef.id)
      .where('nombre', '==', nombre)
      .limit(1)
      .get();
    if (snap.empty) {
      await db.collection('productos').doc().set({
        restauranteId: RID,
        categoriaId: categoriaRef.id,
        nombre,
        descripcion,
        precio, // int COP
        imagenUrl: null,
        disponible: true,
        activo: true,
      });
      stats.productos.creados += 1;
      console.log(`[productos] ${nombre} → creado ($${precio})`);
    } else {
      stats.productos.existentes += 1;
      console.log(`[productos] ${nombre} → existente`);
    }
  }
}

async function main() {
  console.log(`— Seed GRI · restaurante demo "${RID}" —`);
  await seedRestaurante();
  await seedUsuarios();
  await seedMesas();
  const catRefs = await seedCategorias();
  await seedProductos(catRefs);

  console.log('\n=== RESUMEN SEED ===');
  console.log(
    `restaurante: 1 (creado ${stats.restaurante.creado} / actualizado ${stats.restaurante.actualizado})`
  );
  console.log(
    `usuarios:    ${USERS.length} (creados ${stats.usuarios.creados} / existentes ${stats.usuarios.existentes}) — password ${DEMO_PASSWORD}`
  );
  console.log(
    `mesas:       ${MESA_CAPACIDADES.length} (creadas ${stats.mesas.creadas} / actualizadas ${stats.mesas.actualizadas})`
  );
  console.log(
    `categorias:  ${CATEGORIAS.length} (creadas ${stats.categorias.creadas} / existentes ${stats.categorias.existentes})`
  );
  console.log(
    `productos:   ${PRODUCTOS.length} (creados ${stats.productos.creados} / existentes ${stats.productos.existentes})`
  );
  console.log(
    '\nIdempotente: volver a correr NO duplica nada (usuarios por email, ' +
      'categorías por (rid,nombre), productos por (rid,categoria,nombre), ' +
      'mesas/restaurante por doc ID).'
  );
}

main().catch((e) => {
  console.error('[error] Seed falló:', e);
  process.exit(1);
});
