#!/usr/bin/env node
// ============================================================================
// GRI — Verificación por MUTACIÓN de la ventana de reserva y del reparto
// hoy/próximas (plan 11-34, panel_admin).
//
// QUÉ RESUELVE: una suite verde no dice qué la sostiene. La única forma de
// saber que un control concreto es el que sostiene un caso es QUITARLO y ver
// ponerse rojo ESE caso y no otro.
//
// USO:  node panel_admin/test_mutaciones_11_34.mjs
//
// CONTRATO: una mutación cuya suite sigue en VERDE es un control que no
// sostiene nada, o un test que no prueba lo que dice. Sale con código 1.
// ============================================================================

import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const ES_WIN = process.platform === 'win32';

const MUTACIONES = [
  {
    nombre: 'M1 — la ventana deja de mirar el borde inferior (>= pasa a >)',
    archivo: 'lib/features/dashboard/bloqueo_reserva.dart',
    de: '  return !ahora.isBefore(desde) && !ahora.isAfter(hasta);',
    a: '  return ahora.isAfter(desde) && !ahora.isAfter(hasta);',
    esperaRojo: '20:30 EXACTAS (−30 min): SÍ bloquea',
    suites: ['test/dashboard/ventana_reserva_test.dart'],
  },
  {
    nombre: 'M2 — la cortesía de +30 min desaparece',
    archivo: 'lib/features/dashboard/bloqueo_reserva.dart',
    de: 'const Duration cortesiaTrasLaReserva = Duration(minutes: 30);',
    a: 'const Duration cortesiaTrasLaReserva = Duration(minutes: 0);',
    esperaRojo: '21:30 EXACTAS (+30 min): SÍ bloquea',
    suites: ['test/dashboard/ventana_reserva_test.dart'],
  },
  {
    nombre: 'M3 — una reserva CANCELADA vuelve a bloquear',
    archivo: 'lib/features/dashboard/bloqueo_reserva.dart',
    de: "const Set<String> estadosDeReservaQueBloquean = {'confirmada', 'pendiente'};",
    a: "const Set<String> estadosDeReservaQueBloquean = {'confirmada', 'pendiente', 'cancelada'};",
    esperaRojo: 'cancelar la reserva libera la mesa en el acto',
    suites: [
      'test/dashboard/ventana_reserva_test.dart',
      'test/dashboard/mapa_derivado_test.dart',
    ],
  },
  {
    nombre: 'M4 — `ocupada` deja de ganar sobre el bloqueo',
    archivo: 'lib/features/dashboard/bloqueo_reserva.dart',
    de: '    case EstadoMesa.ocupada:\n    case EstadoMesa.limpieza:\n      return estadoGuardado;',
    a: '    case EstadoMesa.ocupada:\n    case EstadoMesa.limpieza:\n      return bloqueadaPorReserva ? EstadoMesa.reservada : estadoGuardado;',
    esperaRojo: 'OCUPADA gana sobre el bloqueo',
    suites: ['test/dashboard/ventana_reserva_test.dart'],
  },
  {
    nombre: 'M5 — el mapa vuelve a pintar el campo `estado`',
    archivo: 'lib/features/dashboard/widgets/mapa_de_mesas.dart',
    de: '                estadoVisual: m.estadoVisual,',
    a: '                estadoVisual: m.mesa.estado,',
    esperaRojo: 'a las 21:00 la mesa reservada se pinta AMARILLA',
    suites: ['test/dashboard/mapa_derivado_test.dart'],
  },
  {
    nombre: 'M6 — el aviso de «no pude leer las reservas» se calla',
    archivo: 'lib/features/dashboard/widgets/mapa_de_mesas.dart',
    de: '    final reservasIlegibles = reservasAsync.error != null;',
    a: '    const reservasIlegibles = false;',
    esperaRojo: 'si NO se pueden leer las reservas: el mapa se pinta igual Y se avisa',
    suites: ['test/dashboard/mapa_derivado_test.dart'],
  },
  {
    nombre: 'M7 — los contadores vuelven a contar el campo `estado`',
    archivo: 'lib/features/dashboard/stats_provider.dart',
    de: '    final conteo = contarPorEstadoVisual(componerMapaDeMesas(\n      mesas: mesas,\n      reservasDelDia: reservas,\n      ahora: v.$4,\n    ));',
    a: '    final conteo = contarPorEstadoVisual(componerMapaDeMesas(\n      mesas: mesas,\n      reservasDelDia: const [],\n      ahora: v.$4,\n    ));',
    esperaRojo: '11-34: dentro de la ventana, la MISMA mesa pasa a RESERVADA',
    suites: ['test/dashboard/stats_render_test.dart'],
  },
  {
    nombre: 'M8 — la ventana de «próximas» se abre a 60 días',
    archivo: 'lib/features/reservas/reservas_provider.dart',
    de: 'const int diasDeReservasProximas = 7;',
    a: 'const int diasDeReservasProximas = 60;',
    esperaRojo: '(l) una reserva a 30 días queda FUERA de la ventana de 7',
    suites: ['test/reservas/reservas_screen_test.dart'],
  },
  {
    nombre: 'M9 — «próximas» ofrece las acciones de sala',
    archivo: 'lib/features/reservas/reservas_screen.dart',
    de: '    final viva = conAcciones &&\n        (reserva.estado == \'confirmada\' || reserva.estado == \'pendiente\');',
    a: '    final viva =\n        reserva.estado == \'confirmada\' || reserva.estado == \'pendiente\';',
    esperaRojo: '(m) las acciones de SALA no existen en «Próximas»',
    suites: ['test/reservas/reservas_screen_test.dart'],
  },
  {
    nombre: 'M10 — CONTROL: un comentario cambiado no rompe nada',
    archivo: 'lib/features/dashboard/bloqueo_reserva.dart',
    de: '/// Cuánto ANTES de la hora reservada se bloquea la mesa.',
    a: '/// Cuanto ANTES de la hora reservada se bloquea la mesa (control).',
    esperaRojo: 'NINGUNO — debe quedar en VERDE',
    controlVerde: true,
    suites: [
      'test/dashboard/ventana_reserva_test.dart',
      'test/dashboard/mapa_derivado_test.dart',
    ],
  },
];

function correr(suites) {
  const bin = ES_WIN ? (process.env.ComSpec || 'cmd.exe') : 'flutter';
  const args = ['test', ...suites, '--reporter=compact'];
  const argv = ES_WIN ? ['/d', '/s', '/c', 'flutter', ...args] : args;
  const r = spawnSync(bin, argv, {
    cwd: AQUI,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    env: process.env,
  });
  const salida = `${r.stdout || ''}${r.stderr || ''}`;
  const rojos = [
    ...new Set(
      [...salida.matchAll(/^\s*\d+:\d+ \+\d+ -\d+: (.+?) \[E\]/gm)].map((m) =>
        m[1].trim(),
      ),
    ),
  ];
  return { verde: /All tests passed!/.test(salida), rojos };
}

let problemas = 0;
const originales = new Map();
try {
  console.log('── LÍNEA BASE ──');
  const todas = [...new Set(MUTACIONES.flatMap((m) => m.suites))];
  const base = correr(todas);
  console.log(`   ${base.verde ? 'VERDE' : 'ROJA'}`);
  if (!base.verde) {
    console.error('ABORTADO: la línea base ya está roja.');
    process.exit(1);
  }

  for (const m of MUTACIONES) {
    const ruta = path.join(AQUI, m.archivo);
    if (!originales.has(ruta)) originales.set(ruta, readFileSync(ruta, 'utf8'));
    const original = originales.get(ruta);
    const apariciones = original.split(m.de).length - 1;
    if (apariciones !== 1) {
      console.error(`\n✖ ${m.nombre}: el patrón aparece ${apariciones} veces (se esperaba 1).`);
      problemas++;
      continue;
    }
    writeFileSync(ruta, original.replace(m.de, m.a), 'utf8');
    const r = correr(m.suites);
    const ok = m.controlVerde ? r.verde : !r.verde;
    console.log(`\n${ok ? '✔' : '✖'} ${m.nombre}`);
    console.log(`   esperado rojo: ${m.esperaRojo}`);
    for (const rojo of r.rojos.slice(0, 6)) console.log(`     ✖ ${rojo}`);
    if (r.verde) console.log('     (suite VERDE)');
    if (!ok) problemas++;
    writeFileSync(ruta, original, 'utf8');
  }
} finally {
  for (const [ruta, contenido] of originales) writeFileSync(ruta, contenido, 'utf8');
  console.log('\nFuentes RESTAURADAS.');
}

process.exit(problemas === 0 ? 0 : 1);
