#!/usr/bin/env node
// ============================================================================
// GRI — Audit ESTÁTICO de queries Firestore.
//
// Hace DOS comprobaciones sobre el mismo parseo de las cadenas de query del
// código Dart de `app_cliente/lib` y `panel_admin/lib`:
//
//   1. ÍNDICES      · toda query que necesite un índice compuesto tiene su
//                     índice declarado en `firestore.indexes.json`.
//   2. PARIDAD      · toda query no exenta replica en sus `where` los campos
//      rules↔query   que la rama pública de `firestore.rules` exige por doc.
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE (leer antes de tocar nada)
// ---------------------------------------------------------------------------
// * El emulador de Firestore **NO valida índices compuestos**: "The Firestore
//   emulator does not track composite indexes and will instead execute any
//   valid query". Ninguna suite local puede detectar un índice que falta, así
//   que este audit es la ÚNICA mitigación automatizable del bug que dejó el
//   menú del panel en `FAILED_PRECONDITION` en cada carga (Fase 11).
// * Firestore evalúa las security rules contra la CONSULTA, no contra los
//   documentos devueltos. Si una query pierde un `where` que la regla exige,
//   se deniega ENTERA. Los tests de rules (`scripts/test/rules/`) prueban la
//   forma de la query en JavaScript, y los tests de app usan
//   `fake_cloud_firestore`, que no tiene motor de rules: sin este check,
//   borrar un `where('disponible', …)` del Dart no lo detecta NINGÚN gate.
//   Eso es, literalmente, el bug que originó la Fase 11.
//
// ---------------------------------------------------------------------------
// LIMITACIÓN — LEER ANTES DE CONFIAR
// ---------------------------------------------------------------------------
// Esto es un análisis HEURÍSTICO SOBRE TEXTO. Reconoce cadenas
// `.collection('X').where(...).orderBy(...).get()/.snapshots()` escritas de
// forma literal. NO entiende queries construidas dinámicamente, ni `Query`
// guardadas en variables y filtradas después, ni `collectionGroup`.
// **NO sustituye a desplegar los índices y probar contra el proyecto real**
// (`firebase deploy --only firestore:indexes`, paso del runbook de la fase).
// Un OK aquí significa "no se detecta nada mal", no "está probado".
//
// Uso:  cd scripts && npm run audit:indexes      (exit 1 si algo falta)
// ============================================================================

import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
// scripts/ → .. = raíz del repo. Se resuelve desde la URL del módulo y NO
// desde el cwd, para que funcione igual desde `scripts/` o desde la raíz.
const RAIZ = path.resolve(AQUI, '..');

const APPS = ['app_cliente', 'panel_admin'];

// ============================================================================
// TABLA DE PARIDAD rules ↔ query
// ============================================================================
// ⚠️ ACTUALIZAR ESTA TABLA EN EL MISMO COMMIT EN QUE SE TOQUE LA RAMA PÚBLICA
//    DE `firestore.rules`. Si divergen, este audit deja de proteger nada.
//
// Cada entrada dice: "toda query sobre esta colección debe filtrar por estos
// campos con igualdad, salvo exención DECLARADA con `// AUDIT-STAFF: motivo`".
// La exención silenciosa cuenta como fallo — por diseño.
const PARIDAD_RULES_QUERY = {
  categorias: {
    campos: ['activo'],
    origen: "firestore.rules match /categorias — rama pública `resource.data.activo == true`",
  },
  productos: {
    campos: ['activo', 'disponible'],
    origen:
      "firestore.rules match /productos — rama pública `activo == true && disponible == true`",
  },
  usuarios: {
    campos: ['restauranteId'],
    origen:
      'firestore.rules match /usuarios — rama del admin del tenant (AMPLIADA en el plan 11-10)',
  },
};

// Operadores de `where` que Firestore trata como IGUALDAD a efectos de índice.
const OPS_IGUALDAD = new Set([
  'isEqualTo',
  'isNull',
  'whereIn',
  'arrayContains',
  'arrayContainsAny',
]);
// Operadores de RANGO / desigualdad.
const OPS_RANGO = new Set([
  'isGreaterThan',
  'isGreaterThanOrEqualTo',
  'isLessThan',
  'isLessThanOrEqualTo',
  'isNotEqualTo',
  'whereNotIn',
]);

// ---------------------------------------------------------------------------
// Utilidades de fichero
// ---------------------------------------------------------------------------

function dartFiles(dir, acc = []) {
  for (const nombre of readdirSync(dir)) {
    const p = path.join(dir, nombre);
    if (statSync(p).isDirectory()) {
      dartFiles(p, acc);
    } else if (nombre.endsWith('.dart') && !nombre.endsWith('.g.dart')) {
      acc.push(p);
    }
  }
  return acc;
}

/**
 * Sustituye el contenido de comentarios y literales de string por espacios,
 * CONSERVANDO la longitud y los saltos de línea. Así los offsets siguen
 * mapeando a la línea original y el parser no tropieza con un comentario
 * intercalado entre dos eslabones de la cadena (dart format los mete).
 * Los literales de string SÍ se conservan: el parser necesita leer
 * `'restauranteId'`. Solo se neutralizan los comentarios.
 */
function cegarComentarios(src) {
  const out = src.split('');
  let i = 0;
  let enString = null; // comilla activa
  while (i < src.length) {
    const c = src[i];
    const d = src[i + 1];
    if (enString) {
      if (c === '\\') {
        i += 2;
        continue;
      }
      if (c === enString) enString = null;
      i += 1;
      continue;
    }
    if (c === "'" || c === '"') {
      enString = c;
      i += 1;
      continue;
    }
    if (c === '/' && d === '/') {
      while (i < src.length && src[i] !== '\n') {
        out[i] = ' ';
        i += 1;
      }
      continue;
    }
    if (c === '/' && d === '*') {
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) {
        if (src[i] !== '\n') out[i] = ' ';
        i += 1;
      }
      out[i] = ' ';
      out[i + 1] = ' ';
      i += 2;
      continue;
    }
    i += 1;
  }
  return out.join('');
}

const lineaDe = (src, offset) => src.slice(0, offset).split('\n').length;

/** Texto completo de la línea que contiene `offset`, en el fuente ORIGINAL. */
function textoLinea(src, offset) {
  const ini = src.lastIndexOf('\n', offset - 1) + 1;
  let fin = src.indexOf('\n', offset);
  if (fin === -1) fin = src.length;
  return src.slice(ini, fin);
}

/**
 * Desde `pos` (justo tras un `)` de la cadena), lee el siguiente eslabón
 * `.metodo(args)` con escaneo de paréntesis balanceados que respeta strings.
 * @returns {{metodo: string, args: string, fin: number} | null}
 */
function siguienteEslabon(src, pos) {
  const m = /^\s*\.([A-Za-z_]\w*)\(/.exec(src.slice(pos));
  if (!m) return null;
  let i = pos + m[0].length;
  let prof = 1;
  let enString = null;
  while (i < src.length && prof > 0) {
    const c = src[i];
    if (enString) {
      if (c === '\\') i += 1;
      else if (c === enString) enString = null;
    } else if (c === "'" || c === '"') {
      enString = c;
    } else if (c === '(') {
      prof += 1;
    } else if (c === ')') {
      prof -= 1;
    }
    i += 1;
  }
  return {
    metodo: m[1],
    args: src.slice(pos + m[0].length, i - 1),
    fin: i,
  };
}

// ---------------------------------------------------------------------------
// Parseo de las cadenas de query
// ---------------------------------------------------------------------------

/**
 * @returns {Array<{app:string, archivo:string, linea:number, coleccion:string,
 *   igualdades:string[], rangos:string[], orden:Array<{campo:string,desc:boolean}>,
 *   terminal:string, ignorar:string|null, staff:string|null}>}
 */
function parsearQueries(app, archivo) {
  const original = readFileSync(archivo, 'utf8');
  const src = cegarComentarios(original);
  const queries = [];
  const re = /\.collection\(\s*'([^']+)'\s*\)/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const coleccion = m[1];
    const offset = m.index;
    let pos = m.index + m[0].length;

    const igualdades = [];
    const rangos = [];
    const orden = [];
    let terminal = null;
    let reconocida = true;

    for (;;) {
      const esl = siguienteEslabon(src, pos);
      if (!esl) break;
      pos = esl.fin;
      if (esl.metodo === 'where') {
        const campo = /^\s*'([^']+)'\s*,/.exec(esl.args);
        const op = /,\s*([A-Za-z]\w*)\s*:/.exec(esl.args);
        if (!campo || !op) {
          reconocida = false;
          break;
        }
        if (OPS_IGUALDAD.has(op[1])) igualdades.push(campo[1]);
        else if (OPS_RANGO.has(op[1])) rangos.push(campo[1]);
        else reconocida = false;
      } else if (esl.metodo === 'orderBy') {
        const campo = /^\s*'([^']+)'/.exec(esl.args);
        if (!campo) {
          reconocida = false;
          break;
        }
        orden.push({ campo: campo[1], desc: /descending\s*:\s*true/.test(esl.args) });
      } else if (esl.metodo === 'limit' || esl.metodo === 'limitToLast') {
        // No afecta al índice.
      } else if (esl.metodo === 'get' || esl.metodo === 'snapshots' || esl.metodo === 'count') {
        terminal = esl.metodo;
        break;
      } else {
        // `.doc(...)`, `.add(...)`, `.withConverter(...)`: no es una query
        // de colección — se descarta el candidato entero.
        terminal = null;
        reconocida = false;
        break;
      }
    }

    // Sin terminal no hay query (p.ej. `.collection('x').doc(id).set(...)`).
    if (!terminal) continue;

    const linea = lineaDe(original, offset);
    // Marcadores declarativos: en la línea de la colección o en la anterior.
    const contexto =
      textoLinea(original, offset) +
      '\n' +
      (linea > 1
        ? textoLinea(original, original.lastIndexOf('\n', offset - 1) - 1 >= 0
            ? original.lastIndexOf('\n', offset - 1) - 1
            : 0)
        : '');
    const ign = /\/\/\s*AUDIT-IGNORE:\s*(.+)$/m.exec(contexto);
    const stf = /\/\/\s*AUDIT-STAFF:\s*(.+)$/m.exec(contexto);

    queries.push({
      app,
      archivo: path.relative(RAIZ, archivo).replace(/\\/g, '/'),
      linea,
      coleccion,
      igualdades,
      rangos,
      orden,
      terminal,
      reconocida,
      ignorar: ign ? ign[1].trim() : null,
      staff: stf ? stf[1].trim() : null,
    });
  }
  return queries;
}

const firma = (q) => {
  const partes = [q.coleccion];
  for (const c of q.igualdades) partes.push(`${c}==`);
  for (const c of q.rangos) partes.push(`${c}<>`);
  for (const o of q.orden) partes.push(`orderBy(${o.campo}${o.desc ? ' desc' : ''})`);
  return partes.join(' ');
};

// ---------------------------------------------------------------------------
// Clasificación e índices
// ---------------------------------------------------------------------------

/**
 * ¿Necesita índice compuesto?
 *
 * NO lo necesita si son solo filtros de igualdad sin `orderBy`: Firestore los
 * resuelve combinando índices automáticos de campo único.
 * SÍ lo necesita si hay `orderBy` por un campo que no está entre las
 * igualdades, o si hay un rango combinado con igualdades u `orderBy`.
 *
 * Matiz respecto a la formulación corta ("cualquier rango lo necesita"): un
 * rango SOLO, sin igualdades ni orderBy, se resuelve con el índice automático
 * de campo único. Marcarlo como FALTA sería un falso positivo que bloquearía
 * el gate sin motivo. Hoy ninguna query del repo cae en ese caso.
 */
function necesitaCompuesto(q) {
  const eq = new Set(q.igualdades);
  const ordenExterno = q.orden.some((o) => !eq.has(o.campo));
  if (ordenExterno) return true;
  if (q.rangos.length > 0 && (eq.size > 0 || q.orden.length > 0)) return true;
  if (new Set(q.rangos).size > 1) return true;
  return false;
}

/** Parte ordenada exigida al índice: el `orderBy`, o el rango si no hay orderBy. */
function parteOrdenada(q) {
  if (q.orden.length > 0) return q.orden.map((o) => ({ campo: o.campo, desc: o.desc }));
  return [...new Set(q.rangos)].map((campo) => ({ campo, desc: null })); // dirección indiferente
}

function indiceCompatible(q, indices) {
  const eq = [...new Set(q.igualdades)];
  const ord = parteOrdenada(q);
  return indices.some((idx) => {
    if (idx.collectionGroup !== q.coleccion) return false;
    if ((idx.queryScope ?? 'COLLECTION') !== 'COLLECTION') return false;
    const campos = idx.fields ?? [];
    if (campos.length < eq.length + ord.length) return false;
    // Prefijo de igualdades: mismo conjunto, orden irrelevante.
    const prefijo = campos.slice(0, eq.length).map((f) => f.fieldPath);
    if ([...prefijo].sort().join(',') !== [...eq].sort().join(',')) return false;
    // Parte ordenada: misma secuencia de campos.
    const resto = campos.slice(eq.length, eq.length + ord.length);
    if (!resto.every((f, i) => f.fieldPath === ord[i].campo)) return false;
    // Dirección: un índice se recorre en los DOS sentidos, así que valen las
    // direcciones idénticas o TODAS invertidas. `null` = indiferente (rango).
    const iguales = resto.every(
      (f, i) => ord[i].desc === null || (f.order === 'DESCENDING') === ord[i].desc,
    );
    const invertidas = resto.every(
      (f, i) => ord[i].desc === null || (f.order === 'DESCENDING') !== ord[i].desc,
    );
    return iguales || invertidas;
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const indices = JSON.parse(
  readFileSync(path.join(RAIZ, 'firestore.indexes.json'), 'utf8'),
).indexes;

const queries = [];
for (const app of APPS) {
  const dir = path.join(RAIZ, app, 'lib');
  for (const archivo of dartFiles(dir)) queries.push(...parsearQueries(app, archivo));
}
queries.sort((a, b) => a.archivo.localeCompare(b.archivo) || a.linea - b.linea);

const anchoUbi = Math.max(...queries.map((q) => `${q.archivo}:${q.linea}`.length), 12);
const anchoFirma = Math.max(...queries.map((q) => firma(q).length), 20);

let fallos = 0;

console.log('');
console.log('═'.repeat(anchoUbi + anchoFirma + 22));
console.log(' AUDIT 1/2 — ÍNDICES COMPUESTOS  (query Dart ↔ firestore.indexes.json)');
console.log('═'.repeat(anchoUbi + anchoFirma + 22));
console.log(
  ` ${'archivo:línea'.padEnd(anchoUbi)}  ${'firma'.padEnd(anchoFirma)}  veredicto`,
);
console.log('─'.repeat(anchoUbi + anchoFirma + 22));

for (const q of queries) {
  const ubi = `${q.archivo}:${q.linea}`.padEnd(anchoUbi);
  const f = firma(q).padEnd(anchoFirma);
  let veredicto;
  if (q.ignorar) {
    veredicto = `IGNORADA (AUDIT-IGNORE: ${q.ignorar})`;
  } else if (!q.reconocida) {
    veredicto = 'NO PARSEABLE — declarar `// AUDIT-IGNORE: motivo` o simplificar la query';
    fallos += 1;
  } else if (!necesitaCompuesto(q)) {
    veredicto = 'n/a (índices automáticos de campo único)';
  } else if (indiceCompatible(q, indices)) {
    veredicto = 'OK';
  } else {
    veredicto = 'FALTA ÍNDICE COMPUESTO';
    fallos += 1;
  }
  console.log(` ${ubi}  ${f}  ${veredicto}`);
}

console.log('');
console.log('═'.repeat(anchoUbi + anchoFirma + 22));
console.log(' AUDIT 2/2 — PARIDAD rules ↔ query  (filtros que la regla exige por doc)');
console.log('═'.repeat(anchoUbi + anchoFirma + 22));
for (const [col, def] of Object.entries(PARIDAD_RULES_QUERY)) {
  console.log(` · ${col.padEnd(12)} exige where(${def.campos.join(', ')})   — ${def.origen}`);
}
console.log('─'.repeat(anchoUbi + anchoFirma + 22));

let revisadas = 0;
for (const q of queries) {
  const def = PARIDAD_RULES_QUERY[q.coleccion];
  if (!def || q.ignorar) continue;
  revisadas += 1;
  const ubi = `${q.archivo}:${q.linea}`.padEnd(anchoUbi);
  const faltan = def.campos.filter((c) => !q.igualdades.includes(c));
  if (faltan.length === 0) {
    console.log(` ${ubi}  ${firma(q).padEnd(anchoFirma)}  OK`);
  } else if (q.staff) {
    console.log(
      ` ${ubi}  ${firma(q).padEnd(anchoFirma)}  EXENTA (AUDIT-STAFF: ${q.staff})`,
    );
  } else {
    console.log(
      ` ${ubi}  ${firma(q).padEnd(anchoFirma)}  ` +
        `FALTA ${faltan.map((c) => `where('${c}')`).join(' + ')}`,
    );
    fallos += 1;
  }
}
if (revisadas === 0) console.log(' (ninguna query alcanza la tabla de paridad)');

console.log('');
console.log('─'.repeat(anchoUbi + anchoFirma + 22));
console.log(
  ` ${queries.length} queries analizadas · ${revisadas} sujetas a paridad · ${fallos} fallo(s)`,
);
console.log(
  ' Recordatorio: análisis estático. El emulador NO valida índices compuestos —',
);
console.log(
  ' un OK aquí NO sustituye a `firebase deploy --only firestore:indexes` y probar en real.',
);
console.log('');

process.exit(fallos > 0 ? 1 : 0);
