#!/usr/bin/env node
// ============================================================================
// GRI — Gestión de personal desde la línea de comandos (Fase 11, plan 11-20)
//
// QUÉ ES: la vía de ejecución de `crearUsuarioStaff` y `cambiarEstadoStaff`
// mientras esas Cloud Functions NO estén desplegadas.
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE
// ---------------------------------------------------------------------------
// Decisión REVERTIDA del usuario (11-CONTEXT.md, «Blaze — REVERTIDO»,
// 2026-08-20): no habrá cuenta de pago, así que las callables se quedan sin
// desplegar. Su código y sus 149 pruebas unitarias + 50 e2e se CONSERVAN. Lo
// que faltaba era una forma de ejecutarlas, y es esto: el mismo Admin SDK, con
// la clave de servicio del propietario, corriendo en su máquina.
//
// ---------------------------------------------------------------------------
// ⚠️ LA RESTRICCIÓN DURA: ESTE ARCHIVO NO DECIDE NADA
// ---------------------------------------------------------------------------
// Toda la autorización vive en tres módulos PUROS que ya están probados:
//
//   ../functions/src/auth-matrix.js     → `autorizarAlta`         (quién crea a quién)
//   ../functions/src/baja-matrix.js     → `autorizarCambioEstado` (quién da de baja a quién)
//   ../functions/src/password-policy.js → `validarPassword`       (qué contraseña vale)
//
// PROHIBIDO añadir aquí una comprobación propia de rol, de rid o de contraseña,
// aunque parezca «defensa en profundidad». Si este archivo duplicara la matriz,
// los 149 tests de escalada dejarían de proteger lo que de verdad se ejecuta, y
// la autorización duplicada es exactamente donde aparecen los agujeros con el
// tiempo. Hay un gate que lo hace cumplir leyendo esta fuente:
// `scripts/test/staff-cli/contrato-matrices.test.mjs`. Falla si aparece un
// literal de rol asignable o una regex de contraseña propia.
//
// Solo DOS literales de rol viven aquí, cada uno marcado con `// ROL-LITERAL-OK`
// (mismo patrón que `// AUDIT-STAFF` de 11-03, `// TOKEN-IGNORE` de 11-19 y
// `// POLICY-LOGIN-OK` de 11-22): `super_admin` y `cliente`. Ninguno de los dos
// es asignable por la matriz —`ROLES_ASIGNABLES` los excluye a propósito— así
// que la matriz no puede razonar sobre ellos y el anti-secuestro y la vía de
// recuperación tienen que nombrarlos. Añadir un tercero exige marcarlo, y eso
// deja rastro en el diff.
//
// ---------------------------------------------------------------------------
// ⚠️ ESTO NO ES UNA FRONTERA DE SEGURIDAD (leer antes de confiar en la matriz)
// ---------------------------------------------------------------------------
// En la Cloud Function, la matriz era una frontera REAL: se ejecutaba en el
// servidor contra un llamador que no controlaba nada, y saltársela era
// imposible. Aquí no. Quien tiene la clave de servicio tiene el Admin SDK
// entero: puede abrir un `node` y hacer `setCustomUserClaims(uid, {role: ...})`
// sin pasar por este archivo. La matriz aquí es una barrera contra ERRORES —el
// admin que se equivoca de restaurante, el que se da de baja a sí mismo—, no
// contra un atacante.
// CONSECUENCIA PRÁCTICA: la seguridad del sistema pasa a depender de dónde está
// guardada la clave. Ver `docs/GESTION-PERSONAL.md`, sección «Qué protege esto
// y qué NO».
//
// ---------------------------------------------------------------------------
// LA CLAVE DE SERVICIO SE REFERENCIA POR RUTA, JAMÁS SE LEE
// ---------------------------------------------------------------------------
// Este archivo NUNCA abre `p-gri-b5b40-firebase-adminsdk.json`. Comprueba que
// existe con `existsSync` y le pasa la RUTA al Admin SDK vía
// `GOOGLE_APPLICATION_CREDENTIALS` + `applicationDefault()`. Divergencia
// deliberada respecto a `seed_firebase.mjs`, que sí hace `readFileSync` +
// `cert()`: si el contenido nunca entra en este proceso, no puede acabar en un
// log, en un mensaje de error ni en un volcado de excepción (T-11-20-03).
// El archivo está gitignored por PATRÓN (`.gitignore:36`, `*firebase-adminsdk*.json`).
//
// ---------------------------------------------------------------------------
// USO
// ---------------------------------------------------------------------------
//   node scripts/gestion_staff.mjs                      → esta ayuda
//   node scripts/gestion_staff.mjs listar --como <email>
//   ... ver `imprimirAyuda()` más abajo y docs/GESTION-PERSONAL.md
// ============================================================================

import { randomInt } from 'node:crypto';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

// --- LA ÚNICA AUTORIDAD. No añadir comprobaciones propias junto a estas. -----
import { ROLES_ASIGNABLES, autorizarAlta } from '../functions/src/auth-matrix.js';
import { autorizarCambioEstado } from '../functions/src/baja-matrix.js';
import { validarPassword } from '../functions/src/password-policy.js';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ_REPO = path.resolve(AQUI, '..');

/** Nombre del archivo de clave que el propietario descarga de la Console. */
const CLAVE_POR_DEFECTO = 'p-gri-b5b40-firebase-adminsdk.json';

/**
 * Rol de PLATAFORMA. No es asignable por `autorizarAlta` a propósito
 * (`ROLES_ASIGNABLES` lo excluye: prohibición 1 de 11-08), así que la matriz no
 * puede razonar sobre él y hay que nombrarlo aquí para dos cosas: el
 * anti-secuestro del alta y el comando de recuperación `promover-super`.
 */
const ROL_PLATAFORMA = 'super_admin'; // ROL-LITERAL-OK

/**
 * Rol de COMENSAL de la app móvil. Tampoco es asignable ni gestionable por las
 * matrices; se nombra aquí solo para reconocer una cuenta de cliente y NO
 * secuestrarla (rama (c) del anti-secuestro de 11-08).
 */
const ROL_CLIENTE = 'cliente'; // ROL-LITERAL-OK

// ============================================================================
// Utilidades
// ============================================================================

function textoNoVacio(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

/** El valor de una bandera solo si vino con texto (`--rid` a secas da `true`). */
function texto(v) {
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

/** Primer valor que sea una cadena no vacía. Copia de `cambiar-estado-staff.js`. */
function primerTexto(...valores) {
  for (const v of valores) {
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return undefined;
}

function abortar(mensaje) {
  console.error(`\n[error] ${mensaje}\n`);
  process.exit(1);
}

/**
 * Parser mínimo de argumentos. Deliberadamente sin dependencia de CLI: el repo
 * evita paquetes nuevos y `process.argv` con un `switch` alcanza de sobra.
 * `--clave valor` → string; `--bandera` suelta → true.
 */
function parsearArgs(argv) {
  const flags = {};
  const posicionales = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const nombre = a.slice(2);
      const siguiente = argv[i + 1];
      if (siguiente === undefined || siguiente.startsWith('--')) {
        flags[nombre] = true;
      } else {
        flags[nombre] = siguiente;
        i += 1;
      }
    } else {
      posicionales.push(a);
    }
  }
  return { comando: posicionales[0], flags };
}

/** Pregunta por stdin. Devuelve la respuesta en minúsculas y sin espacios. */
async function preguntar(pregunta) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try {
    const respuesta = await rl.question(pregunta);
    return String(respuesta ?? '').trim();
  } finally {
    rl.close();
  }
}

/**
 * Alfabeto de las contraseñas TEMPORALES generadas. Sin caracteres ambiguos
 * (I, l, 1, O, 0) porque el operador tiene que DICTARLA por teléfono.
 *
 * OJO: esto es GENERACIÓN, no validación. Quien decide si la contraseña vale es
 * `validarPassword` — por eso hay un bucle de rechazo abajo en vez de una
 * construcción «una mayúscula + una minúscula + un número» que reimplementaría
 * la política y quedaría desincronizada el día que la política cambie.
 */
const ALFABETO_TEMPORAL =
  'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

function generarPassword() {
  for (let intento = 0; intento < 200; intento += 1) {
    let candidata = '';
    for (let i = 0; i < 12; i += 1) {
      candidata += ALFABETO_TEMPORAL[randomInt(ALFABETO_TEMPORAL.length)];
    }
    // La POLÍTICA decide. Si algún día exige un símbolo, este bucle deja de
    // encontrar candidatas y falla ruidosamente en vez de generar en silencio
    // contraseñas que el servidor rechazaría.
    if (validarPassword(candidata) === null) return candidata;
  }
  abortar(
    'No se pudo generar una contraseña temporal que cumpla la política. ' +
      'Probablemente la política cambió: pasa una con --password o revisa ' +
      'functions/src/password-policy.js.',
  );
  return '';
}

// ============================================================================
// Arranque del Admin SDK
// ============================================================================

/**
 * DOS MODOS, igual que `seed_firebase.mjs`:
 *
 *  1. EMULADORES — si `FIREBASE_AUTH_EMULATOR_HOST` y `FIRESTORE_EMULATOR_HOST`
 *     están puestos. Tiene PRECEDENCIA sobre la clave a propósito: apuntando a
 *     emuladores no hay ninguna razón para tocar la clave real, y no tocarla es
 *     la mitigación más barata que existe.
 *  2. PROYECTO REAL — `--key <ruta>` > `GOOGLE_APPLICATION_CREDENTIALS` >
 *     `<raíz>/p-gri-b5b40-firebase-adminsdk.json`.
 *
 * Si no hay ni emuladores ni clave: mensaje ACCIONABLE que NOMBRA la ruta
 * esperada y no vuelca nada.
 */
function inicializar(flags) {
  const authEmu = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const fsEmu = process.env.FIRESTORE_EMULATOR_HOST;

  let app;
  if (authEmu && fsEmu) {
    const projectId =
      process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'demo-gri';
    console.log(`[modo] EMULADORES — auth=${authEmu}, firestore=${fsEmu}, proyecto=${projectId}`);
    app = initializeApp({ projectId });
  } else {
    const ruta =
      texto(flags.key) ??
      texto(process.env.GOOGLE_APPLICATION_CREDENTIALS) ??
      path.join(RAIZ_REPO, CLAVE_POR_DEFECTO);

    if (!existsSync(ruta)) {
      abortar(
        `No encuentro la clave de servicio en:\n    ${ruta}\n\n` +
          'CÓMO ARREGLARLO:\n' +
          '  1. Firebase Console → Configuración del proyecto → Cuentas de servicio\n' +
          '     → «Generar nueva clave privada».\n' +
          `  2. Guarda el archivo en la raíz del repo como ${CLAVE_POR_DEFECTO}\n` +
          '     (está gitignored por patrón: NUNCA se commitea).\n' +
          '  3. O pásale la ruta:  --key <ruta>  /  GOOGLE_APPLICATION_CREDENTIALS=<ruta>\n\n' +
          'Guía completa: docs/GESTION-PERSONAL.md',
      );
    }

    // Se le pasa la RUTA al SDK. Este proceso NUNCA lee el contenido: así no
    // puede acabar en un log ni en el volcado de una excepción (T-11-20-03).
    process.env.GOOGLE_APPLICATION_CREDENTIALS = ruta;
    console.log(`[modo] PROYECTO REAL — credencial: ${ruta} (solo la ruta; el contenido no se lee)`);
    app = initializeApp({ credential: applicationDefault() });
  }

  return { auth: getAuth(app), db: getFirestore(app) };
}

// ============================================================================
// Actor: el equivalente de `request.auth` de la callable
// ============================================================================

/**
 * Las callables sacaban el rol del llamador de `request.auth.token`. Aquí no hay
 * token, así que el actor se declara con `--como <email>` y sus claims REALES se
 * leen de Auth: no se acepta un rol por parámetro, porque entonces el operador
 * elegiría su propia autorización y la matriz sería decorativa.
 *
 * Es OBLIGATORIO y sin valor por defecto: sin actor no hay autorización que
 * evaluar, y un script que no evalúa autorización es justo lo que este plan
 * existe para evitar.
 *
 * NOTA: aquí NO se mira QUÉ rol es. Solo que HAYA claims. Quién puede hacer qué
 * lo deciden las matrices, sin excepción.
 */
async function resolverActor(auth, flags) {
  const correo = texto(flags.como);
  if (!textoNoVacio(correo)) {
    abortar(
      'Falta --como <email>.\n' +
        '  Es la cuenta EN NOMBRE DE la que se ejecuta la operación: sus custom\n' +
        '  claims reales son los que evalúa la matriz de autorización.\n' +
        '  Ej.: --como admin@demo.gri.dev',
    );
  }

  let usuario;
  try {
    usuario = await auth.getUserByEmail(correo.trim().toLowerCase());
  } catch (err) {
    if (err?.code === 'auth/user-not-found') {
      abortar(`No existe ninguna cuenta con el correo ${correo}. Revisa --como.`);
    }
    abortar(`No se pudo leer la cuenta ${correo} (${err?.code ?? 'error desconocido'}).`);
  }

  const claims = usuario.customClaims ?? {};
  if (Object.keys(claims).length === 0) {
    abortar(
      `La cuenta ${correo} no tiene custom claims: no es personal de ningún\n` +
        '  restaurante ni de la plataforma, así que no hay autorización que evaluar.',
    );
  }

  return {
    uid: usuario.uid,
    email: usuario.email,
    role: claims.role,
    rid: claims.rid,
  };
}

/**
 * Restaurante sobre el que este actor puede operar, PREGUNTÁNDOSELO A LA MATRIZ.
 *
 * `autorizarAlta` es la única función que sabe derivar el rid efectivo (del
 * claim para un `admin_restaurante`, del parámetro para la plataforma) y
 * rechazar un rid ajeno. Reimplementar aquí ese «si es X usa su rid, si no…»
 * sería precisamente la autorización duplicada que el plan prohíbe, así que se
 * le pregunta con un rol de sonda tomado de la propia allow-list importada.
 *
 * CONSECUENCIA CONOCIDA Y ACEPTADA: una cuenta de plataforma DEBE pasar `--rid`
 * también para `listar`, porque la matriz exige restaurante explícito a quien no
 * tiene uno propio. No hay listado global. Es más estricto que el plan, y la
 * alternativa era escribir aquí una regla de rol propia.
 */
function ridEfectivo(actor, ridPedido) {
  const ROL_SONDA = ROLES_ASIGNABLES[0];
  const decision = autorizarAlta({
    callerRole: actor.role,
    callerRid: actor.rid,
    rolPedido: ROL_SONDA,
    ridPedido,
  });
  if (!decision.ok) abortar(`[${decision.code}] ${decision.msg}`);
  return decision.rid;
}

// ============================================================================
// Comando: listar
// ============================================================================

function alinear(filas, columnas) {
  const anchos = columnas.map((c) =>
    Math.max(c.titulo.length, ...filas.map((f) => String(f[c.clave] ?? '').length)),
  );
  const linea = (celdas) =>
    ' ' + celdas.map((v, i) => String(v ?? '').padEnd(anchos[i])).join('  ');
  const salida = [linea(columnas.map((c) => c.titulo))];
  salida.push(' ' + anchos.map((a) => '─'.repeat(a)).join('  '));
  for (const f of filas) salida.push(linea(columnas.map((c) => f[c.clave])));
  return salida.join('\n');
}

async function comandoListar({ auth, db, flags }) {
  const actor = await resolverActor(auth, flags);
  const rid = ridEfectivo(actor, texto(flags.rid));

  const snap = await db.collection('usuarios').where('restauranteId', '==', rid).get();

  const filas = [];
  for (const doc of snap.docs) {
    const d = doc.data() ?? {};
    // `activo` puede NO existir: la callable de alta no lo escribe (solo la de
    // baja lo pone a false). Ausente = activo, igual que lo interpreta /equipo.
    const activoEspejo = d.activo !== false;
    let estado = activoEspejo ? 'activo' : 'de baja';
    try {
      const u = await auth.getUser(doc.id);
      // Auth y Firestore no son atómicos (ver cabecera de las dos callables):
      // si divergen hay que verlo, no taparlo.
      if (u.disabled === activoEspejo) {
        estado += u.disabled ? ' ⚠ DESINCRONIZADO (Auth: deshabilitado)' : ' ⚠ DESINCRONIZADO (Auth: habilitado)';
      }
    } catch {
      estado += ' ⚠ sin cuenta en Auth';
    }
    filas.push({
      nombre: d.nombre ?? '(sin nombre)',
      email: d.email ?? '(sin correo)',
      rol: d.role ?? '(sin rol)',
      estado,
      uid: doc.id,
    });
  }
  filas.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));

  console.log('');
  console.log(`=== EQUIPO DE ${rid} ===  (visto como ${actor.email})`);
  console.log('');
  if (filas.length === 0) {
    console.log(' No hay nadie dado de alta en este restaurante todavía.');
    console.log(' Da de alta a la primera persona con:');
    console.log(`   node scripts/gestion_staff.mjs crear --como ${actor.email} --email <correo> --nombre "..." --rol ${ROLES_ASIGNABLES[0]}`);
  } else {
    console.log(
      alinear(filas, [
        { clave: 'nombre', titulo: 'NOMBRE' },
        { clave: 'email', titulo: 'CORREO' },
        { clave: 'rol', titulo: 'ROL' },
        { clave: 'estado', titulo: 'ESTADO' },
        { clave: 'uid', titulo: 'UID' },
      ]),
    );
    console.log('');
    console.log(` ${filas.length} persona(s). El UID es lo que piden \`baja\` y \`reactivar\`.`);
  }
  console.log('');
}

// ============================================================================
// Comando: crear
//
// Réplica paso a paso de `functions/src/crear-usuario-staff.js`. Misma
// secuencia, mismos efectos, mismos mensajes. Cualquier divergencia va comentada.
// ============================================================================

async function comandoCrear({ auth, db, flags }) {
  // --- 1. «Sesión» → el actor declarado con --como -------------------------
  const actor = await resolverActor(auth, flags);

  // --- 2. Forma del payload ------------------------------------------------
  const emailBruto = texto(flags.email);
  const nombre = texto(flags.nombre);
  const rol = texto(flags.rol);

  if (!textoNoVacio(emailBruto) || !emailBruto.includes('@')) {
    abortar('El correo no es válido.  (--email <correo>)');
  }

  const passwordPedida = texto(flags.password);
  const generada = passwordPedida === undefined;
  const password = generada ? generarPassword() : passwordPedida;

  // La POLÍTICA DEL SERVIDOR, la misma que aplicaría la callable, y ANTES de
  // tocar Auth: validarla después dejaría la cuenta creada con una contraseña
  // que la política prohíbe (11-22).
  const errorPassword = validarPassword(password);
  if (errorPassword !== null) abortar(errorPassword);

  if (!textoNoVacio(nombre)) abortar('El nombre es obligatorio.  (--nombre "...")');

  // Firebase Auth normaliza el correo; se normaliza también aquí para que el
  // doc espejo y la clave natural del alta coincidan siempre.
  const email = emailBruto.trim().toLowerCase();

  // --- 3. AUTORIZACIÓN · toda la decisión vive en auth-matrix.js -----------
  const decision = autorizarAlta({
    callerRole: actor.role,
    callerRid: actor.rid,
    rolPedido: rol,
    ridPedido: texto(flags.rid),
  });
  if (!decision.ok) abortar(`[${decision.code}] ${decision.msg}`);
  const rid = decision.rid;

  // --- 4. El restaurante destino tiene que existir -------------------------
  const restaurante = await db.doc(`restaurantes/${rid}`).get();
  if (!restaurante.exists) abortar(`El restaurante ${rid} no existe.`);

  // --- 5. Alta idempotente por correo + anti-secuestro de TRES ramas -------
  let uid;
  let creado = false;
  try {
    const user = await auth.createUser({
      email,
      password,
      displayName: nombre.trim(),
      emailVerified: true,
    });
    uid = user.uid;
    creado = true;
  } catch (err) {
    if (err?.code !== 'auth/email-already-exists') {
      abortar(`No se pudo crear el usuario (${err?.code ?? 'error desconocido'}).`);
    }

    const existente = await auth.getUserByEmail(email);
    uid = existente.uid;
    const prev = existente.customClaims ?? {};

    // (a) PLATAFORMA. Degradar a un super_admin sería un apagón total.
    if (prev.role === ROL_PLATAFORMA) abortar('Esa cuenta es de plataforma.');

    // (b) OTRO TENANT. `rid` se compara solo si es cadena: la plataforma lo
    //     lleva a `null` a propósito y eso no es «otro rid».
    if (typeof prev.rid === 'string' && prev.rid !== rid) {
      abortar('Ese correo ya pertenece a otro restaurante.');
    }

    // (c) CUENTA DE CLIENTE. Los claims NO bastan: un cliente auto-registrado
    //     no tiene ninguno (11-04), así que se consulta el doc espejo.
    let esCliente = prev.role === ROL_CLIENTE;
    if (!esCliente) {
      const espejo = await db.doc(`usuarios/${uid}`).get();
      if (espejo.exists) {
        const datos = espejo.data() ?? {};
        esCliente = datos.role === ROL_CLIENTE || datos.restauranteId === null;
      }
    }
    if (esCliente) {
      abortar(
        'Ese correo ya tiene una cuenta de cliente; pide a esa persona que ' +
          'use otro correo para su cuenta de trabajo.',
      );
    }
  }

  // --- 6. Claims · la concesión de privilegio -----------------------------
  await auth.setCustomUserClaims(uid, { role: rol, rid });

  // --- 7. Doc espejo ------------------------------------------------------
  await db.doc(`usuarios/${uid}`).set(
    {
      nombre: nombre.trim(),
      email,
      role: rol,
      restauranteId: rid,
      updatedAt: FieldValue.serverTimestamp(),
      ...(creado ? { createdAt: FieldValue.serverTimestamp() } : {}),
    },
    { merge: true },
  );

  // --- 8. Resumen de qué se hizo ------------------------------------------
  console.log('');
  console.log('=== ALTA DE PERSONAL ===');
  console.log(` actor       : ${actor.email}`);
  console.log(` restaurante : ${rid}`);
  console.log(` persona     : ${nombre.trim()} <${email}>`);
  console.log(` rol         : ${rol}`);
  console.log(` uid         : ${uid}`);
  console.log(
    ` resultado   : ${creado ? 'CREADA' : 'REPARADA (el correo ya existía; claims y ficha reescritos)'}`,
  );
  if (generada) {
    // Se imprime UNA vez, aquí, porque el operador tiene que dictarla. Es el
    // mismo modelo que ya usaba el alta desde el panel (T-11-20-04).
    console.log('');
    console.log(` CONTRASEÑA TEMPORAL: ${password}`);
    console.log(' Dictásela a esa persona y pídele que la cambie desde su perfil.');
  }
  console.log('');
}

// ============================================================================
// Comandos: baja / reactivar
//
// Réplica paso a paso de `functions/src/cambiar-estado-staff.js`, incluido el
// FALLBACK AL DOC ESPEJO —que no es defensa en profundidad sino el camino normal
// de la reactivación: a quien ya está de baja le quitamos los claims en su día.
// ============================================================================

async function resolverObjetivo(auth, flags) {
  const uidPedido = texto(flags.uid);
  const emailPedido = texto(flags['email-objetivo']);

  if (uidPedido) return uidPedido;
  if (!emailPedido) {
    abortar(
      'Falta el objetivo: --uid <uid> (lo muestra `listar`) o --email-objetivo <correo>.',
    );
  }
  try {
    const u = await auth.getUserByEmail(emailPedido.trim().toLowerCase());
    return u.uid;
  } catch (err) {
    if (err?.code === 'auth/user-not-found') {
      abortar(`No existe ninguna cuenta con el correo ${emailPedido}.`);
    }
    return abortar(`No se pudo leer la cuenta ${emailPedido} (${err?.code ?? 'error desconocido'}).`);
  }
}

async function cambiarEstado({ auth, db, flags, activo }) {
  const actor = await resolverActor(auth, flags);
  const uid = await resolverObjetivo(auth, flags);

  // --- 3. El objetivo tiene que existir en Auth ---------------------------
  let objetivo;
  try {
    objetivo = await auth.getUser(uid);
  } catch (err) {
    if (err?.code === 'auth/user-not-found') abortar('Ese usuario ya no existe.');
    return abortar(`No se pudo leer al usuario (${err?.code ?? 'error desconocido'}).`);
  }

  // --- 4. Quién es el objetivo · claims primero, doc espejo después -------
  const espejoRef = db.doc(`usuarios/${uid}`);
  const espejoSnap = await espejoRef.get();
  const espejo = espejoSnap.exists ? (espejoSnap.data() ?? {}) : {};
  const claims = objetivo.customClaims ?? {};

  const objetivoRole = primerTexto(claims.role, espejo.role);
  const objetivoRid = primerTexto(claims.rid, espejo.restauranteId);

  // --- 5. AUTORIZACIÓN · toda la decisión vive en baja-matrix.js ----------
  const decision = autorizarCambioEstado({
    callerRole: actor.role,
    callerRid: actor.rid,
    callerUid: actor.uid,
    objetivoRole,
    objetivoRid,
    objetivoUid: uid,
  });
  if (!decision.ok) abortar(`[${decision.code}] ${decision.msg}`);

  if (activo === false) {
    // --- 6. DESACTIVAR ----------------------------------------------------
    // CONFIRMACIÓN antes de lo destructivo: se muestra A QUIÉN afecta, con
    // nombre, correo, rol y restaurante, para que un uid mal copiado no pase.
    if (flags.si !== true) {
      console.log('');
      console.log('=== VAS A DAR DE BAJA A ===');
      console.log(` nombre      : ${espejo.nombre ?? objetivo.displayName ?? '(sin nombre)'}`);
      console.log(` correo      : ${objetivo.email ?? espejo.email ?? '(sin correo)'}`);
      console.log(` rol         : ${objetivoRole ?? '(desconocido)'}`);
      console.log(` restaurante : ${objetivoRid ?? '(ninguno)'}`);
      console.log(` uid         : ${uid}`);
      console.log('');
      console.log(' No se borra nada: pierde el acceso y se puede reactivar después.');
      const r = await preguntar(' ¿Confirmas la baja? [s/N]: ');
      if (r.toLowerCase() !== 's') {
        console.log('\n Cancelado. No se ha tocado nada.\n');
        return;
      }
    } else {
      console.log('[aviso] --si: baja ejecutada SIN confirmación interactiva.');
    }

    await auth.updateUser(uid, { disabled: true });
    await auth.setCustomUserClaims(uid, null);
    await auth.revokeRefreshTokens(uid);

    // NI UNA MENCIÓN a `role` / `restauranteId` cuando ya están: son lo único
    // que permite reactivar. La excepción es una ficha INCOMPLETA, que se
    // repara con los claims que estamos a punto de borrar.
    const reparacion = {};
    if (typeof espejo.role !== 'string' && objetivoRole) reparacion.role = objetivoRole;
    if (typeof espejo.restauranteId !== 'string' && objetivoRid) {
      reparacion.restauranteId = objetivoRid;
    }

    await espejoRef.set(
      {
        activo: false,
        desactivadoAt: FieldValue.serverTimestamp(),
        desactivadoPor: actor.uid,
        ...reparacion,
      },
      { merge: true },
    );

    console.log('');
    console.log('=== BAJA APLICADA ===');
    console.log(` uid         : ${uid}`);
    console.log(` rol         : ${objetivoRole} @ ${objetivoRid}`);
    console.log(` por         : ${actor.email}`);
    console.log(' cuenta deshabilitada · claims retirados · tokens revocados · ficha activo:false');
    console.log(' Su historial de pedidos queda intacto. Para readmitirla:');
    console.log(`   node scripts/gestion_staff.mjs reactivar --como ${actor.email} --uid ${uid}`);
    console.log('');
  } else {
    // --- 7. REACTIVAR -----------------------------------------------------
    // El rol se lee del ESPEJO, que es donde sobrevivió a la baja.
    const rol = primerTexto(espejo.role);
    const rid = primerTexto(espejo.restauranteId);

    if (!rol || !rid) {
      abortar(
        'No se puede reactivar: falta el rol en su ficha. Vuelve a darlo de ' +
          'alta con el mismo correo para repararla.',
      );
    }

    await auth.updateUser(uid, { disabled: false });
    await auth.setCustomUserClaims(uid, { role: rol, rid });

    await espejoRef.set(
      {
        activo: true,
        reactivadoAt: FieldValue.serverTimestamp(),
        reactivadoPor: actor.uid,
      },
      { merge: true },
    );

    console.log('');
    console.log('=== REACTIVACIÓN APLICADA ===');
    console.log(` uid         : ${uid}`);
    console.log(` rol         : ${rol} @ ${rid}  (restaurado desde su ficha)`);
    console.log(` por         : ${actor.email}`);
    console.log(' Ya puede volver a iniciar sesión con su contraseña de siempre.');
    console.log('');
  }
}

// ============================================================================
// Comando: promover-super  ·  VÍA DE RECUPERACIÓN
// ============================================================================

/**
 * Convierte una cuenta en `super_admin` SALTÁNDOSE la matriz.
 *
 * POR QUÉ VIVE EN ESTE MISMO ARCHIVO Y NO EN OTRO: (a) concentra en un solo
 * sitio el manejo de la clave de servicio, en vez de repartirlo; (b) es la
 * ÚNICA vía de recuperación si el propietario pierde su cuenta de plataforma, y
 * esconderla en otro script la haría inencontrable justo el día que haga falta.
 * `bootstrapPlataforma` (11-07) ya no sirve: es de un solo uso y queda inerte en
 * cuanto existe el primer super_admin.
 *
 * POR QUÉ NO PASA POR `autorizarAlta`: porque esa matriz PROHÍBE asignar
 * `super_admin`, a propósito y de forma absoluta (prohibición 1 de 11-08).
 * Saltársela es literalmente lo que este comando hace. Por eso lleva nombre de
 * comando distinto, bandera explícita y confirmación interactiva: no se puede
 * llegar aquí por accidente ni desde un guion.
 */
async function comandoPromoverSuper({ auth, db, flags }) {
  const correo = texto(flags.email);
  if (!textoNoVacio(correo)) {
    abortar('Falta --email <cuenta a promover>.');
  }

  console.log('');
  console.log('╔══════════════════════════════════════════════════════════════════════╗');
  console.log('║  ⚠  PROMOCIÓN A CUENTA DE PLATAFORMA — SE SALTA LA MATRIZ            ║');
  console.log('╚══════════════════════════════════════════════════════════════════════╝');
  console.log('');
  console.log(' La matriz de autorización PROHÍBE asignar este rol a propósito: ni');
  console.log(' siquiera una cuenta de plataforma puede crear otra. Este comando es la');
  console.log(' vía de recuperación para cuando ya no queda ninguna, y por eso existe');
  console.log(' fuera de la matriz.');
  console.log('');
  console.log(` Cuenta objetivo : ${correo}`);
  console.log(' Efecto          : acceso TOTAL a todos los restaurantes de la plataforma.');
  console.log('');

  if (flags['confirmo-promover-super'] !== true) {
    abortar(
      'Falta la bandera --confirmo-promover-super.\n' +
        '  Es deliberada: este comando no puede ejecutarse por accidente.',
    );
  }

  // Segunda confirmación, interactiva y NO saltable con --si: reescribir el
  // correo obliga a mirar a quién se está promoviendo.
  const respuesta = await preguntar(` Escribe el correo COMPLETO para confirmar: `);
  if (respuesta.toLowerCase() !== correo.trim().toLowerCase()) {
    abortar('El correo no coincide. No se ha tocado nada.');
  }

  let usuario;
  try {
    usuario = await auth.getUserByEmail(correo.trim().toLowerCase());
  } catch (err) {
    if (err?.code === 'auth/user-not-found') {
      abortar(
        `No existe ninguna cuenta con el correo ${correo}. Créala primero desde\n` +
          '  el panel o la app (registro normal) y vuelve a ejecutar este comando.',
      );
    }
    return abortar(`No se pudo leer la cuenta (${err?.code ?? 'error desconocido'}).`);
  }

  await auth.setCustomUserClaims(usuario.uid, { role: ROL_PLATAFORMA, rid: null });

  // Queda constancia de que esto se hizo saltándose la matriz (T-11-20-05).
  await db.doc(`usuarios/${usuario.uid}`).set(
    {
      nombre: usuario.displayName ?? correo,
      email: usuario.email ?? correo.trim().toLowerCase(),
      role: ROL_PLATAFORMA,
      restauranteId: null,
      activo: true,
      promovidoAt: FieldValue.serverTimestamp(),
      promovidoPor: 'script:promover-super',
    },
    { merge: true },
  );

  console.log('');
  console.log('=== PROMOCIÓN APLICADA (SALTÁNDOSE LA MATRIZ) ===');
  console.log(` uid    : ${usuario.uid}`);
  console.log(` correo : ${usuario.email ?? correo}`);
  console.log(` rol    : ${ROL_PLATAFORMA}  ·  registrado como promovidoPor: script:promover-super`);
  console.log('');
  console.log(' Esa persona debe CERRAR SESIÓN y volver a entrar: los custom claims');
  console.log(' viajan dentro del token y el suyo actual todavía no los lleva.');
  console.log('');
}

// ============================================================================
// Ayuda y despacho
// ============================================================================

function imprimirAyuda() {
  const roles = ROLES_ASIGNABLES.join('|');
  console.log(`
GRI — gestión de personal (sin Cloud Functions desplegadas)

Uso:
  node scripts/gestion_staff.mjs <comando> [opciones]

Comandos:
  listar          --como <email> [--rid <slug>]
  crear           --como <email> --email <nuevo> --nombre "..." --rol <${roles}>
                  [--rid <slug>] [--password <...>]
  baja            --como <email> (--uid <uid> | --email-objetivo <correo>) [--si]
  reactivar       --como <email> (--uid <uid> | --email-objetivo <correo>)
  promover-super  --email <cuenta> --confirmo-promover-super

Opciones comunes:
  --como <email>  OBLIGATORIO salvo en promover-super. La cuenta en cuyo nombre
                  se actúa: sus custom claims REALES son los que evalúa la
                  matriz de autorización. No hay valor por defecto.
  --key <ruta>    Clave de servicio. Por defecto: <raíz>/${CLAVE_POR_DEFECTO}
                  (o GOOGLE_APPLICATION_CREDENTIALS). Solo se usa la RUTA.
  --si            Salta la confirmación interactiva de \`baja\` (para guiones).

Ejemplos:
  node scripts/gestion_staff.mjs listar --como admin@demo.gri.dev
  node scripts/gestion_staff.mjs crear --como admin@demo.gri.dev \\
      --email nuevo@demo.gri.dev --nombre "Ana Mesera" --rol ${ROLES_ASIGNABLES[1] ?? roles}

Manual completo: docs/GESTION-PERSONAL.md
`);
}

const COMANDOS = {
  listar: comandoListar,
  crear: comandoCrear,
  baja: (ctx) => cambiarEstado({ ...ctx, activo: false }),
  reactivar: (ctx) => cambiarEstado({ ...ctx, activo: true }),
  'promover-super': comandoPromoverSuper,
};

async function main() {
  const { comando, flags } = parsearArgs(process.argv.slice(2));

  if (flags.ayuda === true || flags.help === true) {
    imprimirAyuda();
    process.exit(0);
  }
  if (comando === undefined) {
    imprimirAyuda();
    process.exit(1);
  }
  if (!Object.hasOwn(COMANDOS, comando)) {
    console.error(`\n[error] Comando desconocido: ${comando}\n`);
    imprimirAyuda();
    process.exit(1);
  }

  const { auth, db } = inicializar(flags);
  await COMANDOS[comando]({ auth, db, flags });
  process.exit(0);
}

main().catch((e) => {
  // Nunca se vuelca el objeto de error entero: puede arrastrar la petición y,
  // con ella, detalles del proyecto. Solo código y mensaje.
  console.error(`\n[error] ${e?.code ? `[${e.code}] ` : ''}${e?.message ?? String(e)}\n`);
  process.exit(1);
});
