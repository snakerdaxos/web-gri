// ============================================================================
// GRI — Cloud Functions · punto de entrada del codebase `default`
//
// Runtime: Node 22 (ver `engines.node` en package.json). El Node local de esta
// máquina es 24, que NO es runtime soportado por Cloud Functions: el emulador
// avisará del desajuste pero funciona. Ceñirse a APIs disponibles en Node 22.
//
// ---------------------------------------------------------------------------
// REGLA DE INICIALIZACIÓN — leer antes de añadir un archivo en src/
// ---------------------------------------------------------------------------
// `initializeApp()` se llama UNA SOLA VEZ, aquí, en el módulo raíz.
// Cada archivo de `src/` obtiene sus handles con `getAuth()` / `getFirestore()`
// de `firebase-admin/auth` y `firebase-admin/firestore`, y **NUNCA** vuelve a
// llamar `initializeApp()` (una segunda llamada lanza `app/duplicate-app`).
//
// Sin argumentos, el Admin SDK toma las credenciales por defecto del entorno:
//   - en Cloud Functions, la service account del proyecto;
//   - en emuladores, las variables FIRESTORE_EMULATOR_HOST /
//     FIREBASE_AUTH_EMULATOR_HOST que inyecta firebase-tools.
// Por eso jamás hace falta un archivo de clave privada en este codebase.
//
// ---------------------------------------------------------------------------
// ÍNDICE DE FUNCIONES EXPORTADAS (orden previsto)
// ---------------------------------------------------------------------------
//   bootstrapPlataforma  → plan 11-07. Callable. Crea el PRIMER super_admin y
//                          solo si no existe ninguno; después queda inerte.
//                          Config: BOOTSTRAP_EMAIL / BOOTSTRAP_SECRET.
//   crearUsuarioStaff    → plan 11-08. Callable. Alta de staff con custom
//                          claims {role, rid}. super_admin → cualquier rid;
//                          admin_restaurante → solo su propio rid. Nadie puede
//                          asignar super_admin.
//
// En ESTE plan (11-01) el codebase queda deliberadamente SIN exports: es el
// andamiaje para que el emulador de Functions arranque.
// ============================================================================

import { initializeApp } from 'firebase-admin/app';

initializeApp();

// export { bootstrapPlataforma } from './src/bootstrap.js';   // plan 11-07
// export { crearUsuarioStaff } from './src/staff.js';         // plan 11-08
