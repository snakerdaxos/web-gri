#!/usr/bin/env node
// ============================================================================
// GRI — Gate de BRANDING sobre `app_cliente/web` y `panel_admin/web`.
//
// Falla (exit 1) si CUALQUIERA de las dos apps vuelve a los valores por
// defecto de `flutter create`.
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE (leer antes de tocar nada)
// ---------------------------------------------------------------------------
// Hasta 11-18 las DOS apps servían la plantilla intacta: `<title>gri_cliente`,
// `<meta name="description" content="A new Flutter project.">` y
// `theme_color: #0175C2` — que es el azul de demo de Flutter y ni siquiera es
// el color de marca (#FF4C05). Es el defecto más barato de arreglar y el más
// dañino para la percepción de profesionalidad: se ve en la pestaña del
// navegador, en el favicon y en el instalador de la PWA.
//
// Nada de eso lo detecta `flutter analyze`, `flutter test` ni `flutter build`:
// un `index.html` con la plantilla compila perfectamente. Sin este gate, la
// regresión solo la caza una revisión visual — o sea, no la caza nadie.
//
// ---------------------------------------------------------------------------
// LIMITACIÓN — LEER ANTES DE CONFIAR
// ---------------------------------------------------------------------------
// Esto comprueba TEXTO y CABECERAS de PNG. Verifica que los marcadores de
// plantilla no están, que los colores declarados son los de marca y que los
// iconos existen, son PNG y tienen las dimensiones que el manifest promete.
// **NO puede comprobar que el icono se VEA bien** — eso no es automatizable.
// Un OK aquí significa "no queda ningún valor de plantilla", no "el diseño es
// bueno".
//
// Uso:  cd scripts && npm run audit:branding      (exit 1 si algo falla)
// ============================================================================

import { readFileSync, existsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
// scripts/ → .. = raíz del repo. Se resuelve desde la URL del módulo y NO
// desde el cwd, para que funcione igual desde `scripts/` o desde la raíz.
const RAIZ = path.resolve(AQUI, '..');

/** Color de marca GRI. LOCKED por 11-CONTEXT.md — no se inventa paleta. */
const MARCA = '#ff4c05';

/** Azul de demo de Flutter. Su presencia en cualquier parte es un fallo. */
const AZUL_PLANTILLA = '#0175c2';

/** Texto que `flutter create` deja en description/manifest. */
const LEMA_PLANTILLA = 'a new flutter project';

const APPS = [
  {
    app: 'app_cliente',
    dir: 'app_cliente/web',
    // Nombres de paquete Dart: legítimos en pubspec.yaml, INACEPTABLES como
    // texto de cara al usuario (título de pestaña, nombre de la PWA).
    nombresPaquete: ['gri_cliente'],
    backgroundEsperado: '#f7f7f7', // AppColors.background del cliente
  },
  {
    app: 'panel_admin',
    dir: 'panel_admin/web',
    nombresPaquete: ['gri_panel_admin'],
    backgroundEsperado: '#f5f6f8', // AppColors.background del panel
  },
];

// Los nombres de paquete de AMBAS apps son inaceptables en CUALQUIERA de las
// dos (copiar/pegar entre apps es exactamente cómo reaparecería).
const TODOS_LOS_NOMBRES_PAQUETE = APPS.flatMap((a) => a.nombresPaquete);

const hallazgos = [];

/** Registra un fallo: `archivo → hallazgo`. */
function fallo(archivo, mensaje) {
  hallazgos.push({ archivo, mensaje });
}

/**
 * Lee la cabecera IHDR de un PNG y devuelve {ancho, alto}, o null si el
 * archivo no es un PNG válido. Sirve para detectar un asset truncado, un JPEG
 * renombrado o un icono cambiado de tamaño a espaldas del manifest.
 */
function dimensionesPng(ruta) {
  const b = readFileSync(ruta);
  if (b.length < 24) return null;
  const firma = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  for (let i = 0; i < firma.length; i++) {
    if (b[i] !== firma[i]) return null;
  }
  if (b.toString('latin1', 12, 16) !== 'IHDR') return null;
  return { ancho: b.readUInt32BE(16), alto: b.readUInt32BE(20) };
}

/** Extrae el contenido de un <meta name="X" content="Y"> (primer match). */
function metaContent(html, nombre) {
  const re = new RegExp(
    `<meta\\s+name=["']${nombre}["']\\s+content=["']([^"']*)["']`,
    'i',
  );
  const m = html.match(re);
  return m ? m[1] : null;
}

// ---------------------------------------------------------------------------
// Recorrido
// ---------------------------------------------------------------------------

for (const { app, dir, backgroundEsperado } of APPS) {
  const dirAbs = path.join(RAIZ, dir);
  const indexRel = `${dir}/index.html`;
  const manifestRel = `${dir}/manifest.json`;
  const indexAbs = path.join(dirAbs, 'index.html');
  const manifestAbs = path.join(dirAbs, 'manifest.json');

  // Un archivo ausente es un FALLO, nunca un "nada que revisar": si no, borrar
  // el index.html pondría el gate en verde.
  if (!existsSync(indexAbs)) {
    fallo(indexRel, 'no existe');
    continue;
  }
  if (!existsSync(manifestAbs)) {
    fallo(manifestRel, 'no existe');
    continue;
  }

  // ---- index.html --------------------------------------------------------
  const html = readFileSync(indexAbs, 'utf8');
  const htmlBajo = html.toLowerCase();

  if (htmlBajo.includes(LEMA_PLANTILLA)) {
    fallo(indexRel, 'contiene el lema de plantilla "A new Flutter project"');
  }
  if (htmlBajo.includes(AZUL_PLANTILLA)) {
    fallo(indexRel, `contiene el azul de demo de Flutter ${AZUL_PLANTILLA}`);
  }

  const tituloM = html.match(/<title>([\s\S]*?)<\/title>/i);
  if (!tituloM) {
    fallo(indexRel, 'no tiene <title>');
  } else {
    const titulo = tituloM[1].trim();
    for (const paquete of TODOS_LOS_NOMBRES_PAQUETE) {
      if (titulo.toLowerCase().includes(paquete)) {
        fallo(
          indexRel,
          `<title> es el nombre del paquete Dart ("${titulo}"), no un nombre de producto`,
        );
      }
    }
    if (!titulo.toUpperCase().includes('GRI')) {
      fallo(indexRel, `<title> no menciona la marca GRI ("${titulo}")`);
    }
  }

  const appleTitle = metaContent(html, 'apple-mobile-web-app-title');
  if (appleTitle === null) {
    fallo(indexRel, 'falta <meta name="apple-mobile-web-app-title">');
  } else {
    for (const paquete of TODOS_LOS_NOMBRES_PAQUETE) {
      if (appleTitle.toLowerCase().includes(paquete)) {
        fallo(
          indexRel,
          `apple-mobile-web-app-title es el nombre del paquete Dart ("${appleTitle}")`,
        );
      }
    }
  }

  const themeMeta = metaContent(html, 'theme-color');
  if (themeMeta === null) {
    fallo(indexRel, 'falta <meta name="theme-color">');
  } else if (themeMeta.trim().toLowerCase() !== MARCA) {
    fallo(
      indexRel,
      `<meta name="theme-color"> es "${themeMeta}" y debe ser ${MARCA.toUpperCase()}`,
    );
  }

  // ---- manifest.json -----------------------------------------------------
  const manifestTexto = readFileSync(manifestAbs, 'utf8');
  if (manifestTexto.toLowerCase().includes(LEMA_PLANTILLA)) {
    fallo(manifestRel, 'contiene el lema de plantilla "A new Flutter project"');
  }
  if (manifestTexto.toLowerCase().includes(AZUL_PLANTILLA)) {
    fallo(manifestRel, `contiene el azul de demo de Flutter ${AZUL_PLANTILLA}`);
  }

  let manifest;
  try {
    manifest = JSON.parse(manifestTexto);
  } catch (e) {
    fallo(manifestRel, `no es JSON válido: ${e.message}`);
    continue;
  }

  for (const campo of ['name', 'short_name']) {
    const valor = manifest[campo];
    if (typeof valor !== 'string' || valor.trim() === '') {
      fallo(manifestRel, `"${campo}" vacío o ausente`);
      continue;
    }
    for (const paquete of TODOS_LOS_NOMBRES_PAQUETE) {
      if (valor.toLowerCase().includes(paquete)) {
        fallo(
          manifestRel,
          `"${campo}" es el nombre del paquete Dart ("${valor}"), no un nombre de producto`,
        );
      }
    }
    if (!valor.toUpperCase().includes('GRI')) {
      fallo(manifestRel, `"${campo}" no menciona la marca GRI ("${valor}")`);
    }
  }

  const desc = manifest.description;
  if (typeof desc !== 'string' || desc.trim().length < 20) {
    fallo(manifestRel, '"description" ausente o demasiado corta para ser real');
  }

  const theme = String(manifest.theme_color ?? '').trim().toLowerCase();
  if (theme !== MARCA) {
    fallo(
      manifestRel,
      `"theme_color" es "${manifest.theme_color}" y debe ser ${MARCA.toUpperCase()}`,
    );
  }

  const bg = String(manifest.background_color ?? '').trim().toLowerCase();
  if (bg !== backgroundEsperado) {
    // Los dos fondos difieren A PROPÓSITO entre apps (vienen de dos mockups
    // distintos, documentado en los dos core/theme.dart). Igualarlos sería un
    // "arreglo" equivocado.
    fallo(
      manifestRel,
      `"background_color" es "${manifest.background_color}" y debe ser ` +
        `${backgroundEsperado.toUpperCase()} (AppColors.background de ${app})`,
    );
  }

  // ---- iconos declarados -------------------------------------------------
  const iconos = Array.isArray(manifest.icons) ? manifest.icons : [];
  if (iconos.length !== 4) {
    fallo(
      manifestRel,
      `declara ${iconos.length} iconos y se esperan 4 (192, 512 y sus dos maskable)`,
    );
  }
  for (const icono of iconos) {
    const src = String(icono?.src ?? '');
    if (src === '') {
      fallo(manifestRel, 'un icono no declara "src"');
      continue;
    }
    const iconoRel = `${dir}/${src}`;
    const iconoAbs = path.join(dirAbs, src);
    if (!existsSync(iconoAbs)) {
      fallo(iconoRel, 'declarado en manifest.json pero NO existe en disco');
      continue;
    }
    if (statSync(iconoAbs).size === 0) {
      fallo(iconoRel, 'existe pero está VACÍO (0 bytes)');
      continue;
    }
    const dim = dimensionesPng(iconoAbs);
    if (dim === null) {
      fallo(iconoRel, 'no es un PNG válido (cabecera IHDR ilegible)');
      continue;
    }
    const esperado = String(icono.sizes ?? '');
    const m = esperado.match(/^(\d+)x(\d+)$/);
    if (m && (dim.ancho !== Number(m[1]) || dim.alto !== Number(m[2]))) {
      fallo(
        iconoRel,
        `mide ${dim.ancho}x${dim.alto} pero el manifest declara "${esperado}"`,
      );
    }
  }

  // ---- favicon -----------------------------------------------------------
  const faviconRel = `${dir}/favicon.png`;
  const faviconAbs = path.join(dirAbs, 'favicon.png');
  if (!existsSync(faviconAbs)) {
    fallo(faviconRel, 'no existe');
  } else if (statSync(faviconAbs).size === 0) {
    fallo(faviconRel, 'existe pero está VACÍO (0 bytes)');
  } else if (dimensionesPng(faviconAbs) === null) {
    fallo(faviconRel, 'no es un PNG válido (cabecera IHDR ilegible)');
  }
}

// ---------------------------------------------------------------------------
// Informe
// ---------------------------------------------------------------------------

const archivosRevisados = APPS.length * 2;

if (hallazgos.length > 0) {
  console.error('');
  console.error('AUDIT BRANDING — FALLOS');
  console.error('═'.repeat(72));
  for (const h of hallazgos) {
    console.error(`  ${h.archivo} → ${h.mensaje}`);
  }
  console.error('═'.repeat(72));
  console.error(
    `${hallazgos.length} fallo(s) de branding. Regenerar los assets con ` +
      '`cd app_cliente && dart run tool/gen_branding.dart` y revisar los ' +
      'index.html / manifest.json.',
  );
  console.error('');
  process.exit(1);
}

console.log(
  `AUDIT BRANDING OK · ${APPS.length} apps · ${archivosRevisados} archivos ` +
    'revisados · 0 rastros de plantilla · iconos presentes y con las ' +
    'dimensiones declaradas',
);
