#!/usr/bin/env node
// ============================================================================
// GRI — Verificación REAL del shell de carga de las DOS apps web.
//
// Sirve `build/web` de cada app, la abre en Chrome headless por CDP y sondea
// el DOM hasta que el shell `#gri-loading` DESAPARECE. Exit 1 si sigue ahí.
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE (leer antes de tocar nada)
// ---------------------------------------------------------------------------
// El `index.html` de 11-18 pinta un shell de marca a pantalla completa mientras
// `main()` hace `await bootstrap()` (Firebase) antes de `runApp`. Ese shell es
// un overlay `position: fixed; inset: 0` con el z-index máximo: si NO se retira,
// la app queda literalmente INUTILIZABLE — se ve el logo para siempre y ningún
// clic llega a Flutter. Es la amenaza T-11-18-02 del plan.
//
// `flutter build web --release` NO detecta eso: un shell que nunca se retira
// compila igual de bien. `flutter test` tampoco: el `index.html` no entra en la
// suite de widgets. La ÚNICA forma de comprobarlo es ejecutar la app en un
// navegador de verdad, que es lo que hace este script.
//
// Verificado por rotura deliberada (11-18): cambiando el nombre del evento a
// uno que no existe, el shell sigue presente a los 25s y este script sale con 1.
//
// ---------------------------------------------------------------------------
// LIMITACIÓN — LEER ANTES DE CONFIAR
// ---------------------------------------------------------------------------
// * Requiere `flutter build web` PREVIO en las dos apps. Si falta el build,
//   este script FALLA (no lo salta): un gate que se auto-desactiva no es gate.
// * Requiere Chrome instalado. Si no lo encuentra, FALLA.
// * Comprueba que el shell se retira y que Flutter monta su vista. NO comprueba
//   que la app se vea bien ni que la sesión funcione — eso es el smoke manual.
//
// Uso:  cd scripts && npm run verify:shell
// ============================================================================

import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ = path.resolve(AQUI, '..');

const APPS = [
  { app: 'app_cliente', puerto: 5391 },
  { app: 'panel_admin', puerto: 5392 },
];

const PUERTO_CDP = 9393;
const LIMITE_MS = 60000;

const TIPOS = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.css': 'text/css',
  '.ico': 'image/x-icon',
  '.map': 'application/json',
  '.symbols': 'text/plain',
  '.bin': 'application/octet-stream',
};

function chromeExe() {
  const candidatos = [
    process.env.CHROME_EXECUTABLE,
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    process.env.LOCALAPPDATA
      ? path.join(
          process.env.LOCALAPPDATA,
          'Google\\Chrome\\Application\\chrome.exe',
        )
      : null,
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ].filter(Boolean);
  for (const c of candidatos) if (existsSync(c)) return c;
  return null;
}

function servir(dir, puerto) {
  const raiz = path.resolve(dir);
  const srv = http.createServer((req, res) => {
    let p = decodeURIComponent(req.url.split('?')[0]);
    if (p === '/') p = '/index.html';
    const f = path.join(raiz, p);
    if (!f.startsWith(raiz) || !existsSync(f) || statSync(f).isDirectory()) {
      res.writeHead(404);
      res.end('404');
      return;
    }
    res.writeHead(200, {
      'Content-Type': TIPOS[path.extname(f)] ?? 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    res.end(readFileSync(f));
  });
  return new Promise((res) => srv.listen(puerto, '127.0.0.1', () => res(srv)));
}

async function esperarCdp(intentos = 40) {
  for (let i = 0; i < intentos; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PUERTO_CDP}/json/version`);
      if (r.ok) return await r.json();
    } catch {
      /* aún no levanta */
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  return null;
}

/** Abre `url` en una pestaña nueva y sondea hasta que el shell desaparece. */
async function comprobar(url) {
  const destino = await (
    await fetch(
      `http://127.0.0.1:${PUERTO_CDP}/json/new?${encodeURIComponent(url)}`,
      { method: 'PUT' },
    )
  ).json();
  const ws = new WebSocket(destino.webSocketDebuggerUrl);
  let id = 0;
  const pend = new Map();
  await new Promise((r) => ws.addEventListener('open', r));
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pend.has(m.id)) {
      pend.get(m.id)(m);
      pend.delete(m.id);
    }
  });
  const enviar = (method, params = {}) =>
    new Promise((res) => {
      const i = ++id;
      pend.set(i, res);
      ws.send(JSON.stringify({ id: i, method, params }));
    });
  await enviar('Runtime.enable');

  const t0 = Date.now();
  let estado = null;
  while (Date.now() - t0 < LIMITE_MS) {
    const r = await enviar('Runtime.evaluate', {
      expression:
        "JSON.stringify({shell: !!document.getElementById('gri-loading')," +
        " vista: !!document.querySelector('flutter-view, flt-glass-pane')," +
        ' titulo: document.title})',
      returnByValue: true,
    });
    const v = r.result?.result?.value;
    if (v) {
      estado = JSON.parse(v);
      if (!estado.shell && estado.vista) break;
    }
    await new Promise((r) => setTimeout(r, 400));
  }
  ws.close();
  await fetch(
    `http://127.0.0.1:${PUERTO_CDP}/json/close/${destino.id}`,
  ).catch(() => {});
  return { estado, ms: Date.now() - t0 };
}

// ---------------------------------------------------------------------------

const fallos = [];
const servidores = [];
let chrome = null;
let perfil = null;

try {
  // 1. Los builds tienen que existir. Sin build no hay verificación posible y
  //    saltarla en silencio sería el peor de los falsos verdes.
  for (const { app } of APPS) {
    const idx = path.join(RAIZ, app, 'build', 'web', 'index.html');
    if (!existsSync(idx)) {
      console.error(
        `ERROR: falta ${app}/build/web/index.html. Ejecuta antes:\n` +
          `  cd ${app} && flutter build web --release`,
      );
      process.exit(1);
    }
  }

  const exe = chromeExe();
  if (!exe) {
    console.error(
      'ERROR: no encuentro Chrome. Define CHROME_EXECUTABLE con la ruta al binario.',
    );
    process.exit(1);
  }

  for (const { app, puerto } of APPS) {
    servidores.push(await servir(path.join(RAIZ, app, 'build', 'web'), puerto));
  }

  perfil = mkdtempSync(path.join(tmpdir(), 'gri-shell-'));
  chrome = spawn(
    exe,
    [
      '--headless=new',
      '--disable-gpu',
      '--no-first-run',
      '--no-default-browser-check',
      `--remote-debugging-port=${PUERTO_CDP}`,
      `--user-data-dir=${perfil}`,
    ],
    { stdio: 'ignore' },
  );

  const version = await esperarCdp();
  if (!version) {
    console.error('ERROR: Chrome no expuso el puerto de depuración.');
    process.exit(1);
  }
  console.log(`Chrome: ${version.Browser}`);

  for (const { app, puerto } of APPS) {
    const url = `http://127.0.0.1:${puerto}/`;
    const { estado, ms } = await comprobar(url);
    if (estado && estado.shell === false && estado.vista === true) {
      console.log(
        `  OK   ${app} · shell retirado en ${ms}ms · title="${estado.titulo}"`,
      );
    } else {
      console.error(
        `  FALLO ${app} → el shell #gri-loading SIGUE en el DOM tras ${ms}ms ` +
          `(${JSON.stringify(estado)}). La app quedaría inutilizable.`,
      );
      fallos.push(app);
    }
  }
} finally {
  for (const s of servidores) s.close();
  if (chrome) chrome.kill();
  if (perfil) {
    try {
      rmSync(perfil, { recursive: true, force: true });
    } catch {
      /* el perfil temporal puede quedar bloqueado en Windows */
    }
  }
}

if (fallos.length > 0) {
  console.error(`\n${fallos.length} app(s) con el shell de carga atascado.`);
  process.exit(1);
}
console.log('VERIFY SHELL OK · 2 apps · shell de carga retirado en las dos');
process.exit(0);
