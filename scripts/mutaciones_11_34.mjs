#!/usr/bin/env node
// ============================================================================
// GRI — Verificación por MUTACIÓN de los controles nuevos de `firestore.rules`
// (plan 11-34).
//
// QUÉ RESUELVE: un `assertFails` pasa también cuando la regla deniega POR OTRO
// MOTIVO, y un `assertSucceeds` pasa también cuando la regla concede de más.
// La única forma de saber que un control concreto es el que sostiene un caso
// es QUITARLO y ver ponerse rojo ESE caso y no otro.
//
// USO:  node scripts/mutaciones_11_34.mjs
//       (arranca el emulador de Firestore UNA vez y corre las 3 suites
//        tocadas por 11-34 contra cada mutación)
//
// CONTRATO: una mutación cuya suite sigue en VERDE es un control que no
// sostiene nada — o el test que debía cubrirlo no existe. Sale con código 1.
// ============================================================================

import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ = path.resolve(AQUI, '..');
const RULES = path.join(RAIZ, 'firestore.rules');
const ES_WIN = process.platform === 'win32';

const ORIGINAL = readFileSync(RULES, 'utf8');

/**
 * Cada mutación: `de` → `a` sobre firestore.rules, y el caso que DEBE ponerse
 * rojo. `de` tiene que aparecer EXACTAMENTE UNA VEZ (si no, la mutación no es
 * la que creemos y se aborta).
 */
const MUTACIONES = [
  {
    nombre: 'M1 — opStaffOf deja de incluir al super (vuelve a staffOf)',
    de: '      return isSuper() || staffOf(r);',
    a: '      return staffOf(r);',
    esperaRojo: 'los 3 casos de super_admin OPERA de mesas/sesiones/reservas',
  },
  {
    nombre: 'M2 — opStaffOf concede al super SIN restricción de forma',
    de: '      return isSuper() || staffOf(r);',
    a: '      return isSuper() || staffOf(r) || isSuper();',
    esperaRojo: 'NINGUNO — mutación de CONTROL: debe quedar en verde',
    controlVerde: true,
  },
  {
    nombre: 'M3 — el candado del timestamp al reabrir la cuenta',
    de: "                                && request.resource.data.get('cuentaPedidaAt', null) == null)))",
    a: '                                )))',
    esperaRojo: 'CANDADO 1 — no puede apagarla dejando el timestamp viejo',
  },
  {
    nombre: 'M4 — el candado "solo se apaga lo que estaba encendido"',
    de: '                            || (resource.data.cuentaSolicitada == true\n                                && request.resource.data.cuentaSolicitada == false',
    a: '                            || (true\n                                && request.resource.data.cuentaSolicitada == false',
    esperaRojo: 'con la bandera YA en false, un update a false queda denegado',
  },
  {
    nombre: 'M5 — el candado "sesión activa" de la rama del comensal',
    de: "                        && resource.data.estado == 'activa'\n                        && request.resource.data.diff(resource.data).affectedKeys()\n                           .hasOnly(['cuentaSolicitada', 'cuentaPedidaAt'])",
    a: "                        && request.resource.data.diff(resource.data).affectedKeys()\n                           .hasOnly(['cuentaSolicitada', 'cuentaPedidaAt'])",
    esperaRojo: 'CANDADO 3 (sesión cerrada) + el endurecido de encender en cerrada',
  },
  {
    nombre: 'M6 — hasOnly de la rama del comensal (caballo de Troya)',
    de: "                           .hasOnly(['cuentaSolicitada', 'cuentaPedidaAt'])\n                        && (request.resource.data.cuentaSolicitada == true",
    a: "                           .hasAny(['cuentaSolicitada', 'cuentaPedidaAt'])\n                        && (request.resource.data.cuentaSolicitada == true",
    esperaRojo: 'apagarla NO es una vía para cerrar la sesión ni colar otro campo',
  },
];

function correrSuites() {
  const args = [
    'run_emulators.mjs',
    '--only', 'firestore',
    '--project', 'demo-gri',
    '--',
    'node', '--test', '--test-concurrency=1',
    'scripts/test/rules/mesas.test.mjs',
    'scripts/test/rules/sesiones.test.mjs',
    'scripts/test/rules/reservas.test.mjs',
  ];
  const bin = ES_WIN ? (process.env.ComSpec || 'cmd.exe') : 'node';
  const argv = ES_WIN ? ['/d', '/s', '/c', 'node', ...args] : args;
  const r = spawnSync(bin, argv, {
    cwd: AQUI,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    env: process.env,
  });
  const salida = `${r.stdout || ''}${r.stderr || ''}`;
  const fail = /^[ℹ#]\s*fail\s+(\d+)\s*$/m.exec(salida);
  const pass = /^[ℹ#]\s*pass\s+(\d+)\s*$/m.exec(salida);
  const rojos = [...salida.matchAll(/^\s*✖\s+(.+?)\s+\(\d/gm)].map((m) => m[1]);
  return {
    pass: pass ? Number(pass[1]) : null,
    fail: fail ? Number(fail[1]) : null,
    rojos,
  };
}

let problemas = 0;
try {
  console.log('── LÍNEA BASE (rules sin mutar) ──');
  const base = correrSuites();
  console.log(`   pass=${base.pass} fail=${base.fail}`);
  if (base.fail !== 0) {
    console.error('ABORTADO: la línea base ya está roja.');
    process.exit(1);
  }

  for (const m of MUTACIONES) {
    const apariciones = ORIGINAL.split(m.de).length - 1;
    if (apariciones !== 1) {
      console.error(`\n✖ ${m.nombre}: el patrón aparece ${apariciones} veces (se esperaba 1).`);
      problemas++;
      continue;
    }
    writeFileSync(RULES, ORIGINAL.replace(m.de, m.a), 'utf8');
    const r = correrSuites();
    const ok = m.controlVerde ? r.fail === 0 : r.fail > 0;
    console.log(`\n${ok ? '✔' : '✖'} ${m.nombre}`);
    console.log(`   pass=${r.pass} fail=${r.fail}  (esperado rojo: ${m.esperaRojo})`);
    for (const rojo of r.rojos.slice(0, 8)) console.log(`     ✖ ${rojo}`);
    if (!ok) problemas++;
  }
} finally {
  writeFileSync(RULES, ORIGINAL, 'utf8');
  console.log('\nfirestore.rules RESTAURADO.');
}

process.exit(problemas === 0 ? 0 : 1);
