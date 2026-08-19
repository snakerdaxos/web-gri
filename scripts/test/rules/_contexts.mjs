// ============================================================================
// GRI — Fixture COMPARTIDO de la suite de tests de `firestore.rules`.
//
// Este archivo es un CONTRATO: lo importan los tests de rules de los planes
// 11-03, 11-04 y 11-08. No cambiar firmas sin actualizar a sus consumidores.
//
// ---------------------------------------------------------------------------
// MODELO DE AUTORIZACIÓN (recordatorio — ver cabecera de firestore.rules)
// ---------------------------------------------------------------------------
// La autorización es 100% custom claims `{ role, rid }` que viajan en
// `request.auth.token`. El doc `usuarios/{uid}` es un ESPEJO de perfil y JAMÁS
// autoriza nada.
//
//   role                  rid            quién es
//   ------------------    -----------    -------------------------------------
//   'super_admin'         (SIN rid)      plataforma. Confirmado en
//                                        scripts/seed_firebase.mjs:47
//   'admin_restaurante'   su restaurante gestiona menú, mesas, equipo
//   'mesero'              su restaurante sirve, abre sesiones
//   'cocina'              su restaurante avanza estados de pedido
//   (ninguno)             —              cliente: la ausencia de claim `role`
//                                        ES el rol cliente (isCliente())
//
// ⚠️ NO OBVIO: en `authenticatedContext(uid, tokenOptions)` los custom claims
// van en el **SEGUNDO argumento**. Pasarlos dentro del primero (o anidados en
// una clave `claims`) los deja fuera de `request.auth.token` y los tests pasan
// o fallan por la razón equivocada.
//
// ⚠️ NO OBVIO: las rules se evalúan **por documento**, también dentro de una
// query. Si UN solo doc alcanzado por la query no pasa la regla, falla la
// query ENTERA. Los tests de query deben replicar los filtros de producción.
// ============================================================================

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
// scripts/test/rules/ → ../../../ = raíz del repo. Se resuelve desde la URL del
// módulo y NO desde el cwd: el wrapper corre con cwd en la raíz, pero un test
// lanzado a mano desde otra carpeta debe seguir funcionando.
export const RUTA_RULES = path.resolve(AQUI, '..', '..', '..', 'firestore.rules');

/**
 * Proyecto ficticio y AISLADO para la suite de rules. El prefijo `demo-`
 * garantiza que el SDK jamás intente credenciales reales.
 * Es distinto del `--project demo-gri` con el que arranca el emulador: cada
 * projectId vive en su propio namespace dentro del mismo emulador, así que la
 * suite de rules no pisa datos de la suite de functions.
 */
export const PROJECT_ID = 'demo-gri-rules';

/**
 * Arranca el entorno de test contra el emulador de Firestore ya levantado.
 * @returns {Promise<import('@firebase/rules-unit-testing').RulesTestEnvironment>}
 */
export function initEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RUTA_RULES, 'utf8'),
    },
  });
}

// --- Fábricas de contexto por rol ------------------------------------------
// Todas reciben el `testEnv` y devuelven un `Firestore` del SDK cliente, listo
// para usar con `assertSucceeds` / `assertFails`.

/** Sin autenticar: `request.auth == null`. */
export function anon(env) {
  return env.unauthenticatedContext().firestore();
}

/** Cliente: autenticado SIN claims. La ausencia de `role` ES el rol cliente. */
export function cliente(env, uid = 'uid-cliente') {
  return env.authenticatedContext(uid).firestore();
}

/** Admin del restaurante `demo`. */
export function adminDemo(env, uid = 'uid-admin-demo') {
  return env.authenticatedContext(uid, { role: 'admin_restaurante', rid: 'demo' }).firestore();
}

/** Admin de OTRO restaurante — el contexto para probar aislamiento cross-tenant. */
export function adminOtro(env, uid = 'uid-admin-otro') {
  return env.authenticatedContext(uid, { role: 'admin_restaurante', rid: 'otro' }).firestore();
}

/** Mesero del restaurante `demo`. */
export function mesero(env, uid = 'uid-mesero-demo') {
  return env.authenticatedContext(uid, { role: 'mesero', rid: 'demo' }).firestore();
}

/** Cocina del restaurante `demo`. */
export function cocina(env, uid = 'uid-cocina-demo') {
  return env.authenticatedContext(uid, { role: 'cocina', rid: 'demo' }).firestore();
}

/** Super admin de la plataforma: **sin `rid`** (seed_firebase.mjs:47). */
export function superAdmin(env, uid = 'uid-super') {
  return env.authenticatedContext(uid, { role: 'super_admin' }).firestore();
}

/**
 * Prepara datos SALTÁNDOSE las rules (el equivalente a sembrar con Admin SDK).
 * Usar solo para el arrange, nunca para el assert.
 *
 * @param {import('@firebase/rules-unit-testing').RulesTestEnvironment} env
 * @param {(db: import('firebase/firestore').Firestore) => Promise<void>} fn
 */
export function sembrar(env, fn) {
  return env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}
