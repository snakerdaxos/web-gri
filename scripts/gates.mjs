#!/usr/bin/env node
// ============================================================================
// GRI — Ejecutor único de los gates automatizados (Fase 11, plan 11-15)
//
// QUÉ RESUELVE: la red de seguridad de la fase está repartida en seis suites y
// tres auditorías estáticas, cada una con su comando, su directorio y su
// formato de salida. Nadie las corre todas, y las que no se corren son
// exactamente las que se rompen. Este script las corre TODAS en una pasada.
//
// USO (desde scripts/):   npm run gates
//      o desde cualquier sitio:   node scripts/gates.mjs
//
// CONTRATO:
//   · Ejecuta los 9 gates SIEMPRE, aunque uno falle. El objetivo es dar el
//     panorama completo en una sola corrida, no un fallo cada vez.
//   · Sale con código 1 si CUALQUIER gate falla, y con 0 solo si todos pasan.
//   · Un gate de tests falla también cuando el número de tests BAJA respecto a
//     su baseline, aunque el comando devuelva 0: una prueba borrada es una
//     regresión silenciosa y ningún runner la reporta como error.
//   · `flutter analyze` exige literalmente 0 issues.
//
// LO QUE ESTE SCRIPT NO CUBRE (deliberado, documentado en docs/SMOKE-E2E-v2.md):
//   · `npm run verify:shell` exige `flutter build web --release` previo en las
//     DOS apps (minutos) y Chrome instalado. Queda fuera de la pasada rápida;
//     se corre a mano antes de un despliegue web.
//   · Nada de aquí prueba los ÍNDICES COMPUESTOS contra un proyecto real: el
//     emulador no los valida (decisión 11-03) y `audit:indexes` es estático.
//     Para eso está `node scripts/probar_consultas_reales.mjs` (11-28), que
//     lanza las consultas reales por REST contra `p-gri-b5b40` y distingue
//     «falta el índice» de «las reglas deniegan». No entra aquí a propósito:
//     toca la red y consume lecturas de pago.
//   · Nada de aquí prueba el ingreso con Google: el emulador de Auth no
//     implementa el flujo real (plan 11-17 / checkpoint 11-20).
// ============================================================================

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ = path.resolve(AQUI, '..');
const ES_WIN = process.platform === 'win32';

// ---------------------------------------------------------------------------
// BASELINES — número de tests medido al cerrar el plan 11-22 (ver STATE.md,
// sección "Test Baselines"). Estos números pueden SUBIR; si BAJAN, el gate
// falla. Quien retire un test a conciencia debe bajar el número AQUÍ, en el
// mismo commit, para que quede el rastro de que fue una decisión.
// ---------------------------------------------------------------------------
const BASELINES = {
  app_cliente: 500, // flutter test (11-34: 489 -> 500, +11: 8 de test/pedidos/reabrir_cuenta_test.dart, 2 de test/perfil/cerrar_sesion_test.dart y +1 neto en test/reservas (varios casos INVERTIDOS al quitar la escritura del estado de la mesa; ninguno borrado). 11-33: 466 -> 489, +23 del barrido de errores de stream: 11 en test/pedidos/errores_de_stream_test.dart, 8 en test/shared/errores_de_stream_pantallas_test.dart y 4 en test/pedidos/cuenta_320_test.dart. Delta MEDIDO corriendo solo los archivos nuevos. 11-30: 371 -> 408, la carta del menú: fotos, tarjetas y rejilla; 11-31: 408 -> 439, +31 del margen de 4 h para reservar HOY; 11-32: 439 -> 466, +27 de LA CUENTA del comensal: 14 del cálculo con cifras literales y 13 de la pantalla. Delta MEDIDO corriendo solo los dos archivos nuevos, no restando totales del árbol)
  panel_admin: 528, // flutter test (11-34: 474 -> 528, +54: 19 de test/dashboard/ventana_reserva_test.dart, 9 de test/dashboard/mapa_derivado_test.dart, 6 de test/core/reloj_test.dart, 3 de test/core/reloj_cableado_test.dart, 3 de test/shared/cerrar_sesion_test.dart, 4 de la carrera de entregar cuenta, 6 de hoy-vs-proximas en reservas y 4 de los contadores derivados. 11-33: 460 -> 474, +14 del barrido de errores de stream: 10 en test/cocina/errores_de_stream_test.dart, 2 en test/shared/errores_que_mienten_test.dart y 2 en test/cocina/recibo_cobro_test.dart. 11-29: 445 -> 446, 'Marcar ocupada' con la mesa disponible; 11-32: 446 -> 460, +14 de LA CUENTA DE LA MESA del mesero: 1 de ancla del formato, 6 del cálculo, 3 de la consulta y 4 de la pantalla)
  functions_unit: 149, // functions/: node --test test/*.test.js
  rules: 306, // scripts/: @firebase/rules-unit-testing contra el emulador (11-34: 290 -> 306, +16: 8 de «update — reabrir la cuenta», 4 del super_admin operando mesas, 2 en sesiones y 2 en reservas; 11-27: 221 -> 260, +39 casos de LECTURA DE DOCS AUSENTES; 11-28: 260 -> 282, +22 de QUERY vs RULES; 11-29: 282 -> 285, +3 de la FORMA de la tx de reserva futura; 11-31: 285 -> 290, +5 del MARGEN de 4 h server-side)
  functions_e2e: 50, // scripts/: callables contra emuladores auth+functions+firestore
};

// ---------------------------------------------------------------------------
// Resolución de `flutter`. En Windows el ejecutable real es flutter.bat y
// spawn de un .bat exige shell (Node ≥18.20 lo rechaza si no) — por eso todo
// se lanza a través de cmd.exe /c (mismo criterio que run_emulators.mjs).
// ---------------------------------------------------------------------------
function resolverFlutter() {
  const candidatos = ES_WIN ? ['flutter.bat', 'flutter.exe'] : ['flutter'];
  for (const dir of (process.env.PATH || '').split(path.delimiter)) {
    if (!dir) continue;
    for (const nombre of candidatos) {
      const p = path.join(dir, nombre);
      if (existsSync(p)) return p;
    }
  }
  return null;
}

const FLUTTER = resolverFlutter();

function ejecutar(cmd, args, cwd) {
  const inicio = Date.now();
  let bin = cmd;
  let argv = args;
  if (ES_WIN) {
    bin = process.env.ComSpec || 'cmd.exe';
    argv = ['/d', '/s', '/c', cmd, ...args];
  }
  const r = spawnSync(bin, argv, {
    cwd,
    encoding: 'utf8',
    maxBuffer: 128 * 1024 * 1024,
    env: process.env,
    windowsVerbatimArguments: false,
  });
  const salida = `${r.stdout || ''}${r.stderr || ''}`;
  return {
    code: r.status === null ? 1 : r.status,
    salida,
    error: r.error ? String(r.error.message) : null,
    ms: Date.now() - inicio,
  };
}

// --- Analizadores de salida ------------------------------------------------

// `flutter test` imprime "00:03 +345: All tests passed!". El contador es
// acumulativo, así que el válido es el MAYOR de todos los que aparecen.
function contarFlutterTest(salida) {
  let max = null;
  for (const m of salida.matchAll(/\+(\d+)/g)) {
    const n = Number(m[1]);
    if (max === null || n > max) max = n;
  }
  return max;
}

// `node --test` con el reporter spec cierra con "ℹ pass 149" / "ℹ fail 0";
// con el reporter tap, con "# pass 149" / "# fail 0". Se aceptan los dos.
function contarNodeTest(salida) {
  let pass = null;
  let fail = null;
  for (const m of salida.matchAll(/^[ℹ#]\s*pass\s+(\d+)\s*$/gm)) pass = Number(m[1]);
  for (const m of salida.matchAll(/^[ℹ#]\s*fail\s+(\d+)\s*$/gm)) fail = Number(m[1]);
  return { pass, fail };
}

// `flutter analyze` dice "No issues found!" o "N issues found."
function contarIssues(salida) {
  if (/No issues found/i.test(salida)) return 0;
  const m = salida.match(/(\d+)\s+issues?\s+found/i);
  if (m) return Number(m[1]);
  return null;
}

// --- Definición de los gates ----------------------------------------------

const GATES = [
  {
    nombre: 'app_cliente: flutter test',
    tipo: 'flutter-test',
    cwd: path.join(RAIZ, 'app_cliente'),
    args: ['test'],
    baseline: BASELINES.app_cliente,
  },
  {
    nombre: 'app_cliente: flutter analyze',
    tipo: 'flutter-analyze',
    cwd: path.join(RAIZ, 'app_cliente'),
    args: ['analyze'],
  },
  {
    nombre: 'panel_admin: flutter test',
    tipo: 'flutter-test',
    cwd: path.join(RAIZ, 'panel_admin'),
    args: ['test'],
    baseline: BASELINES.panel_admin,
  },
  {
    nombre: 'panel_admin: flutter analyze',
    tipo: 'flutter-analyze',
    cwd: path.join(RAIZ, 'panel_admin'),
    args: ['analyze'],
  },
  {
    // OJO: estos NO corren dentro de `scripts: npm run test:functions`. Ese
    // script hace glob de scripts/test/functions/*.test.mjs (0 coincidencias)
    // y *.e2e.mjs; los unitarios viven en functions/test/*.test.js y sin este
    // gate se quedaban FUERA de la red de seguridad.
    nombre: 'functions: npm test (unitarios)',
    tipo: 'node-test',
    cwd: path.join(RAIZ, 'functions'),
    cmd: 'npm',
    args: ['test'],
    baseline: BASELINES.functions_unit,
  },
  {
    nombre: 'scripts: npm run test:rules',
    tipo: 'node-test',
    cwd: path.join(RAIZ, 'scripts'),
    cmd: 'npm',
    args: ['run', 'test:rules'],
    baseline: BASELINES.rules,
  },
  {
    nombre: 'scripts: npm run test:functions (e2e)',
    tipo: 'node-test',
    cwd: path.join(RAIZ, 'scripts'),
    cmd: 'npm',
    args: ['run', 'test:functions'],
    baseline: BASELINES.functions_e2e,
  },
  {
    nombre: 'scripts: npm run audit:indexes',
    tipo: 'exit',
    cwd: path.join(RAIZ, 'scripts'),
    cmd: 'npm',
    args: ['run', 'audit:indexes'],
  },
  {
    nombre: 'scripts: npm run audit:branding',
    tipo: 'exit',
    cwd: path.join(RAIZ, 'scripts'),
    cmd: 'npm',
    args: ['run', 'audit:branding'],
  },
];

// --- Ejecución -------------------------------------------------------------

const SOLO = process.argv.slice(2).filter((a) => !a.startsWith('-'));

console.log('');
console.log('═'.repeat(78));
console.log(' GRI — GATES AUTOMATIZADOS (Fase 11)');
console.log('═'.repeat(78));
console.log(` raíz: ${RAIZ}`);
console.log(` flutter: ${FLUTTER || '(NO ENCONTRADO EN EL PATH)'}`);
console.log('');

const resultados = [];

for (const gate of GATES) {
  if (SOLO.length && !SOLO.some((s) => gate.nombre.includes(s))) continue;

  const esFlutter = gate.tipo.startsWith('flutter');
  if (esFlutter && !FLUTTER) {
    console.log(`▶ ${gate.nombre} … OMITIDO (flutter no está en el PATH)`);
    resultados.push({
      nombre: gate.nombre,
      ok: false,
      tests: '—',
      detalle: 'flutter no está en el PATH',
      ms: 0,
      salida: '',
    });
    continue;
  }

  process.stdout.write(`▶ ${gate.nombre} … `);
  const cmd = esFlutter ? FLUTTER : gate.cmd;
  const r = ejecutar(cmd, gate.args, gate.cwd);

  let ok = r.code === 0 && !r.error;
  let tests = '—';
  let detalle = r.error ? r.error : `exit ${r.code}`;

  if (gate.tipo === 'flutter-test') {
    const n = contarFlutterTest(r.salida);
    tests = n === null ? '?' : String(n);
    if (n === null) {
      ok = false;
      detalle = 'no se pudo leer el contador de tests de la salida';
    } else if (ok && n < gate.baseline) {
      ok = false;
      detalle = `REGRESIÓN: ${n} tests < baseline ${gate.baseline}`;
    } else if (ok) {
      detalle = n > gate.baseline ? `${n} (baseline ${gate.baseline}, +${n - gate.baseline})` : `${n} = baseline`;
    }
  } else if (gate.tipo === 'node-test') {
    const { pass, fail } = contarNodeTest(r.salida);
    tests = pass === null ? '?' : String(pass);
    if (pass === null) {
      ok = false;
      detalle = 'no se pudo leer "pass N" de la salida';
    } else if (fail && fail > 0) {
      ok = false;
      detalle = `${fail} test(s) en rojo`;
    } else if (ok && pass < gate.baseline) {
      ok = false;
      detalle = `REGRESIÓN: ${pass} tests < baseline ${gate.baseline}`;
    } else if (ok) {
      detalle = pass > gate.baseline ? `${pass} (baseline ${gate.baseline}, +${pass - gate.baseline})` : `${pass} = baseline`;
    }
  } else if (gate.tipo === 'flutter-analyze') {
    const issues = contarIssues(r.salida);
    tests = issues === null ? '?' : `${issues} issues`;
    if (issues === null) {
      ok = false;
      detalle = 'no se pudo leer el número de issues de la salida';
    } else if (issues !== 0) {
      ok = false;
      detalle = `${issues} issue(s) — se exigen 0`;
    } else {
      ok = true; // "No issues found!" es la única forma de pasar
      detalle = '0 issues';
    }
  } else if (gate.tipo === 'exit' && ok) {
    detalle = 'exit 0';
  }

  console.log(`${ok ? 'OK' : 'FALLO'}  (${(r.ms / 1000).toFixed(1)}s)`);
  resultados.push({ nombre: gate.nombre, ok, tests, detalle, ms: r.ms, salida: r.salida });
}

// --- Salida de los que fallaron -------------------------------------------

const fallidos = resultados.filter((r) => !r.ok);

for (const f of fallidos) {
  if (!f.salida) continue;
  const lineas = f.salida.split(/\r?\n/);
  const cola = lineas.slice(-40);
  console.log('');
  console.log('─'.repeat(78));
  console.log(` SALIDA DE: ${f.nombre}  (últimas ${cola.length} líneas)`);
  console.log('─'.repeat(78));
  console.log(cola.join('\n'));
}

// --- Tabla resumen ---------------------------------------------------------

const anchoNombre = Math.max(...resultados.map((r) => r.nombre.length), 6);
const anchoTests = Math.max(...resultados.map((r) => String(r.tests).length), 5);

console.log('');
console.log('═'.repeat(78));
console.log(' RESUMEN');
console.log('═'.repeat(78));
console.log(
  ` ${'GATE'.padEnd(anchoNombre)}  ${'RES.'.padEnd(5)}  ${'TESTS'.padEnd(anchoTests)}  DETALLE`,
);
console.log(
  ` ${'─'.repeat(anchoNombre)}  ${'─'.repeat(5)}  ${'─'.repeat(anchoTests)}  ${'─'.repeat(20)}`,
);
for (const r of resultados) {
  console.log(
    ` ${r.nombre.padEnd(anchoNombre)}  ${(r.ok ? 'OK' : 'FALLO').padEnd(5)}  ` +
      `${String(r.tests).padEnd(anchoTests)}  ${r.detalle}`,
  );
}
console.log('');

const totalMs = resultados.reduce((a, r) => a + r.ms, 0);
console.log(
  ` ${resultados.length} gates · ${resultados.length - fallidos.length} OK · ` +
    `${fallidos.length} fallo(s) · ${(totalMs / 1000 / 60).toFixed(1)} min`,
);
console.log('');
console.log(' Recordatorio: estos gates NO validan los índices compuestos contra el proyecto');
console.log(' real (el emulador no los evalúa) ni el ingreso con Google. Tras desplegar');
console.log(' índices o reglas: node scripts/probar_consultas_reales.mjs — ver');
console.log(' docs/SMOKE-E2E-v2.md §4.1.');
console.log('');

process.exit(fallidos.length > 0 ? 1 : 0);
