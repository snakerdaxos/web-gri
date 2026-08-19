#!/usr/bin/env node
// ============================================================================
// GRI — Wrapper de `firebase emulators:exec` (Fase 11, plan 01)
//
// PROBLEMA QUE RESUELVE: el emulador de Firestore EXIGE una JVM y en esta
// máquina `java` NO está en el PATH. Sin este wrapper, cada desarrollador
// tendría que exportar JAVA_HOME a mano antes de correr un solo test.
//
// QUÉ HACE:
//   1. Resuelve Java en este orden: JAVA_HOME → PATH → JBR de Android Studio.
//   2. Si el Java resuelto NO viene del PATH, inyecta JAVA_HOME y prependea su
//      bin/ al PATH **del proceso hijo únicamente** (jamás muta la máquina).
//   3. Reenvía los argumentos a `firebase emulators:exec`, con cwd en la RAÍZ
//      del repo para que firebase.json / .firebaserc / firestore.rules /
//      firestore.indexes.json resuelvan.
//   4. Acepta `--set-env CLAVE=VALOR` (cero o más, ANTES del resto) y los
//      inyecta en el entorno del proceso hijo.
//
// USO:
//   node run_emulators.mjs [--set-env K=V ...] <opciones firebase> -- <comando>
//
// EJEMPLO:
//   node run_emulators.mjs --only firestore --project demo-gri -- node --test test/rules/
//
// ⚠️ IMPORTANTE Y NO OBVIO — alcance real de `--set-env`:
//   La inyección de entorno NO llega al emulador de Functions. El emulador
//   carga la configuración de cada función desde `functions/.env` y
//   `functions/.env.{projectId}` AL ARRANCAR, antes de que exista el proceso
//   de test. Escribir un `.env` desde un `before()` llega tarde.
//   → La configuración que consume la función vive en `functions/.env.demo-gri`
//     (versionado). `--set-env` sirve SOLO para que el proceso de test sepa
//     qué valores esperar, sin duplicar constantes en dos sitios.
// ============================================================================

import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ_REPO = path.resolve(AQUI, '..');
const ES_WIN = process.platform === 'win32';

// --- 1. Resolución de Java --------------------------------------------------

// Rutas conocidas del JBR (JetBrains Runtime) que instala Android Studio.
// El primero es el verificado en esta máquina: OpenJDK 21.0.10.
const CANDIDATOS_JAVA_HOME = ES_WIN
  ? [
      'C:\\Program Files\\Android\\Android Studio\\jbr',
      'C:\\Program Files\\Android\\Android Studio Preview\\jbr',
      'C:\\Program Files\\JetBrains\\IntelliJ IDEA\\jbr',
      path.join(process.env.LOCALAPPDATA ?? '', 'Programs', 'Android Studio', 'jbr'),
    ]
  : [
      '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      '/usr/lib/jvm/default-java',
    ];

function javaExeDe(javaHome) {
  return path.join(javaHome, 'bin', ES_WIN ? 'java.exe' : 'java');
}

function javaFunciona(exe) {
  const r = spawnSync(exe, ['-version'], { stdio: 'ignore', windowsHide: true });
  return !r.error && r.status === 0;
}

/**
 * @returns {{home: string|null, exe: string, origen: string}|null}
 *   `home === null` significa "vino del PATH": no hay que tocar el entorno.
 */
function resolverJava() {
  // (a) JAVA_HOME explícito
  const envHome = process.env.JAVA_HOME;
  if (envHome) {
    const exe = javaExeDe(envHome);
    if (existsSync(exe) && javaFunciona(exe)) {
      return { home: envHome, exe, origen: 'JAVA_HOME' };
    }
  }

  // (b) java en el PATH
  if (javaFunciona('java')) {
    return { home: null, exe: 'java', origen: 'PATH' };
  }

  // (c) JBR de Android Studio y compañía
  for (const home of CANDIDATOS_JAVA_HOME) {
    if (!home) continue;
    const exe = javaExeDe(home);
    if (existsSync(exe) && javaFunciona(exe)) {
      return { home, exe, origen: 'JBR de Android Studio' };
    }
  }

  return null;
}

function abortarSinJava() {
  console.error(`
[run_emulators] ERROR: no se encontró una JVM utilizable.

El emulador de Firestore requiere Java (el de Auth y el de Functions NO).
Se buscó, en orden:
  1. $JAVA_HOME/bin/java   (JAVA_HOME=${process.env.JAVA_HOME ?? '<no definido>'})
  2. java en el PATH
  3. Rutas conocidas del JBR de Android Studio:
${CANDIDATOS_JAVA_HOME.filter(Boolean).map((c) => `       - ${c}`).join('\n')}

CÓMO ARREGLARLO (cualquiera de las dos):
  A) Instalar un JDK 21 (Temurin):  https://adoptium.net/temurin/releases/?version=21
  B) Apuntar JAVA_HOME a un JDK ya instalado, p. ej. el de Android Studio:
       PowerShell : $env:JAVA_HOME = 'C:\\Program Files\\Android\\Android Studio\\jbr'
       Git Bash   : export JAVA_HOME='/c/Program Files/Android/Android Studio/jbr'
`.trimStart());
  process.exit(1);
}

// --- 2. Parseo de argumentos ------------------------------------------------

/**
 * Extrae los `--set-env K=V` iniciales del argv y devuelve el resto.
 */
function extraerSetEnv(argv) {
  const extra = {};
  let i = 0;
  while (argv[i] === '--set-env') {
    const par = argv[i + 1];
    if (!par || !par.includes('=')) {
      console.error(`[run_emulators] ERROR: --set-env espera CLAVE=VALOR, recibió: ${par ?? '<nada>'}`);
      process.exit(1);
    }
    const idx = par.indexOf('=');
    extra[par.slice(0, idx)] = par.slice(idx + 1);
    i += 2;
  }
  return { extra, resto: argv.slice(i) };
}

/**
 * `firebase emulators:exec <script>` recibe UN solo string de script. Nuestro
 * argv trae el comando ya tokenizado por el shell del llamador, así que hay que
 * re-citar cada token o el shell interno de firebase-tools (cmd.exe en Windows,
 * sh en POSIX) reinterpretará paréntesis, comillas y comodines.
 */
function citarToken(t) {
  if (/^[A-Za-z0-9_@%+=:,.\/\\-]+$/.test(t)) return t;
  return `"${t.replace(/(["\\])/g, '\\$1')}"`;
}

// --- 3. Resolución del CLI de Firebase --------------------------------------

/**
 * Preferimos ejecutar el entrypoint JS con `process.execPath` en vez del shim
 * `.bin/firebase.cmd`: desde Node 18.20/20.12 spawnear un `.cmd` obliga a
 * `shell: true`, y eso rompe el paso de argumentos con comillas. Ejecutar el
 * .js directamente pasa el argv EXACTO, sin shell de por medio.
 */
function resolverCliFirebase() {
  const entryJs = path.join(AQUI, 'node_modules', 'firebase-tools', 'lib', 'bin', 'firebase.js');
  if (existsSync(entryJs)) {
    return { cmd: process.execPath, prefijo: [entryJs] };
  }
  const shim = path.join(AQUI, 'node_modules', '.bin', ES_WIN ? 'firebase.cmd' : 'firebase');
  if (existsSync(shim)) {
    return { cmd: shim, prefijo: [], shell: ES_WIN };
  }
  console.error(
    '[run_emulators] ERROR: firebase-tools no está instalado en scripts/node_modules.\n' +
      '  Corré:  cd scripts && npm install',
  );
  process.exit(1);
}

// --- main -------------------------------------------------------------------

const { extra, resto } = extraerSetEnv(process.argv.slice(2));

const sep = resto.indexOf('--');
if (sep === -1) {
  console.error(
    '[run_emulators] ERROR: falta el separador `--`.\n' +
      '  Uso: node run_emulators.mjs [--set-env K=V ...] <opciones firebase> -- <comando>\n' +
      '  Ej.: node run_emulators.mjs --only firestore --project demo-gri -- node --test test/rules/',
  );
  process.exit(1);
}

const opcionesFirebase = resto.slice(0, sep);
const tokensComando = resto.slice(sep + 1);
if (tokensComando.length === 0) {
  console.error('[run_emulators] ERROR: no hay comando después de `--`.');
  process.exit(1);
}
const script = tokensComando.map(citarToken).join(' ');

const java = resolverJava();
if (!java) abortarSinJava();

const entorno = { ...process.env, ...extra };
if (java.home !== null) {
  entorno.JAVA_HOME = java.home;
  entorno.PATH = path.join(java.home, 'bin') + path.delimiter + (process.env.PATH ?? '');
  // Windows resuelve la variable case-insensitive, pero Node expone ambas.
  if (entorno.Path !== undefined) entorno.Path = entorno.PATH;
}

const cli = resolverCliFirebase();
const args = [...cli.prefijo, 'emulators:exec', ...opcionesFirebase, script];

console.log(`[run_emulators] Java: ${java.origen}${java.home ? ` (${java.home})` : ''}`);
console.log(`[run_emulators] cwd : ${RAIZ_REPO}`);
console.log(`[run_emulators] exec: firebase ${['emulators:exec', ...opcionesFirebase, script].join(' ')}`);
if (Object.keys(extra).length > 0) {
  console.log(`[run_emulators] env : ${Object.keys(extra).join(', ')} (solo para el proceso hijo)`);
}

const hijo = spawn(cli.cmd, args, {
  cwd: RAIZ_REPO,
  env: entorno,
  stdio: 'inherit',
  shell: cli.shell ?? false,
  windowsHide: true,
});

hijo.on('error', (err) => {
  console.error(`[run_emulators] ERROR al lanzar el CLI de Firebase: ${err.message}`);
  process.exit(1);
});

hijo.on('exit', (code, signal) => {
  if (signal) {
    console.error(`[run_emulators] El CLI terminó por señal ${signal}`);
    process.exit(1);
  }
  process.exit(code ?? 1);
});
