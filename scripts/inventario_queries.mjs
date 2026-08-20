// ============================================================================
// GRI — INVENTARIO de las queries Firestore que hacen las apps Flutter.
//
// Extraído de `audit_indexes.mjs` en el plan 11-28 para que haya UNA sola
// fuente de verdad sobre "qué consulta hace la app", consumida por:
//
//   · scripts/audit_indexes.mjs         — comprobación ESTÁTICA (índices +
//                                          paridad rules↔query). Corre en los
//                                          gates, sin red.
//   · scripts/probar_consultas_reales.mjs — comprobación CONTRA EL PROYECTO
//                                          REAL por REST. NO corre en gates.
//
// Que las dos herramientas lean el MISMO inventario es el punto: una query
// nueva en el Dart aparece sola en las dos, sin que nadie tenga que acordarse
// de darla de alta en ningún sitio.
//
// ---------------------------------------------------------------------------
// LIMITACIÓN — LEER ANTES DE CONFIAR
// ---------------------------------------------------------------------------
// Esto es un análisis HEURÍSTICO SOBRE TEXTO. Reconoce cadenas
// `.collection('X').where(...).orderBy(...).get()/.snapshots()` escritas de
// forma literal. NO entiende queries construidas dinámicamente, ni `Query`
// guardadas en variables y filtradas después, ni `collectionGroup`.
// Una cadena que el parser no sepa leer se marca `reconocida: false` y el
// audit la trata como FALLO (hay que declararla `// AUDIT-IGNORE: motivo`),
// para que el punto ciego sea siempre EXPLÍCITO.
// ============================================================================

import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
/** scripts/ → .. = raíz del repo (resuelta desde la URL del módulo, no del cwd). */
export const RAIZ = path.resolve(AQUI, '..');

export const APPS = ['app_cliente', 'panel_admin'];

// ============================================================================
// TABLA 1 — PARIDAD rules ↔ query
// ============================================================================
// ⚠️ ACTUALIZAR EN EL MISMO COMMIT EN QUE SE TOQUE UNA RAMA `allow read` DE
//    `firestore.rules`. Si divergen, el audit deja de proteger nada.
//    `audit_indexes.mjs` comprueba que TODA colección con `match` en las rules
//    esté en esta tabla o en [SIN_RESTRICCION_LECTURA]: añadir una colección
//    nueva a las rules y olvidarse de aquí ROMPE EL GATE a propósito.
//
// Semántica de `alternativas`: lista de conjuntos de campos. La query debe
// replicar con IGUALDAD **todos** los campos de **al menos una** alternativa.
// Es la traducción literal de una regla en forma de disyunción:
//
//     allow read: if resource.data.usuarioId == request.auth.uid   ← alt. 1
//                 || staffOf(resource.data.restauranteId)          ← alt. 2
//
// Firestore evalúa las rules contra la CONSULTA, no contra los documentos
// devueltos: si ninguna rama es demostrable a partir de los `where`, la query
// se deniega ENTERA aunque todos los documentos fueran legibles uno a uno.
export const PARIDAD_RULES_QUERY = {
  categorias: {
    alternativas: [['activo']],
    origen: "firestore.rules /categorias — rama pública `resource.data.activo == true`",
  },
  productos: {
    alternativas: [['activo', 'disponible']],
    origen:
      "firestore.rules /productos — rama pública `activo == true && disponible == true`",
  },
  usuarios: {
    alternativas: [['restauranteId']],
    origen: 'firestore.rules /usuarios — rama del admin del tenant (plan 11-10)',
  },
  // ── Añadidas en 11-28 (el P0 de `pedidos` en producción) ────────────────
  // Las tres comparten la MISMA forma de regla:
  //   signedIn() && (resource == null
  //                  || resource.data.usuarioId == request.auth.uid
  //                  || staffOf(resource.data.restauranteId) || isSuper())
  // `resource == null` e `isSuper()` no dependen de ningún campo, así que no
  // generan alternativa: lo que la query DEBE demostrar es una de las dos
  // ramas que sí miran el documento. Exigir una de las dos es más estricto
  // que la regla (un super_admin podría listar sin filtro), y eso es
  // deliberado: ninguna pantalla del producto lista pedidos/sesiones/reservas
  // de TODOS los restaurantes, y una query así sería un error de tenant
  // aunque las rules la dejaran pasar. Si algún día hace falta, se declara
  // con `// AUDIT-STAFF: motivo`.
  pedidos: {
    alternativas: [['usuarioId'], ['restauranteId']],
    origen: "firestore.rules /pedidos — `usuarioId == uid` | `staffOf(restauranteId)`",
  },
  sesiones: {
    alternativas: [['usuarioId'], ['restauranteId']],
    origen: "firestore.rules /sesiones — `usuarioId == uid` | `staffOf(restauranteId)`",
  },
  reservas: {
    alternativas: [['usuarioId'], ['restauranteId']],
    origen: "firestore.rules /reservas — `usuarioId == uid` | `staffOf(restauranteId)`",
  },
};

// ============================================================================
// TABLA 2 — colecciones cuya regla de LECTURA no mira el documento
// ============================================================================
// Aquí van SOLO las colecciones cuyo `allow read` es demostrable sin ningún
// `where`: no desreferencian `resource.data` en ninguna rama que haga falta
// probar. Para ellas la paridad no aplica y no hace falta filtro alguno.
// El motivo se escribe entero: es lo que revisa quien audite esta tabla.
export const SIN_RESTRICCION_LECTURA = {
  restaurantes: 'allow read: if true — descubrimiento público',
  mesas: 'allow read: if signedIn() — no mira resource.data',
  calificaciones: 'allow read: if true — visibles en discover',
  plataforma: 'allow read: if false — nadie lee; ninguna query de app la toca',
};

// Operadores de `where` que Firestore trata como IGUALDAD a efectos de índice.
export const OPS_IGUALDAD = new Set([
  'isEqualTo',
  'isNull',
  'whereIn',
  'arrayContains',
  'arrayContainsAny',
]);
// Operadores de RANGO / desigualdad.
export const OPS_RANGO = new Set([
  'isGreaterThan',
  'isGreaterThanOrEqualTo',
  'isLessThan',
  'isLessThanOrEqualTo',
  'isNotEqualTo',
  'whereNotIn',
]);

/** Traducción del operador Dart al de la API REST de Firestore. */
export const OP_REST = {
  isEqualTo: 'EQUAL',
  isNull: 'IS_NULL',
  whereIn: 'IN',
  arrayContains: 'ARRAY_CONTAINS',
  arrayContainsAny: 'ARRAY_CONTAINS_ANY',
  isGreaterThan: 'GREATER_THAN',
  isGreaterThanOrEqualTo: 'GREATER_THAN_OR_EQUAL',
  isLessThan: 'LESS_THAN',
  isLessThanOrEqualTo: 'LESS_THAN_OR_EQUAL',
  isNotEqualTo: 'NOT_EQUAL',
  whereNotIn: 'NOT_IN',
};

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
 * Sustituye el contenido de los comentarios por espacios, CONSERVANDO la
 * longitud y los saltos de línea. Así los offsets siguen mapeando a la línea
 * original y el parser no tropieza con un comentario intercalado entre dos
 * eslabones de la cadena (dart format los mete). Los literales de string SÍ
 * se conservan: el parser necesita leer `'restauranteId'`.
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

/**
 * Intenta leer el VALOR literal de un `where`. Devuelve `{literal: v}` si el
 * valor está escrito a mano en el Dart, o `null` si es una expresión (una
 * variable como `rid`, `sesion.mesaId`, `desde`…). Los `null` los resuelve
 * `probar_consultas_reales.mjs` a partir de sus parámetros; el audit estático
 * no los necesita para nada.
 */
function valorLiteral(texto) {
  // El texto llega tal cual desde el argumento: puede traer la coma final del
  // eslabón (`whereIn: const [...],`) y saltos de línea de dart format.
  const t = texto
    .trim()
    .replace(/,\s*$/, '')
    .trim()
    .replace(/^const\s+/, '');
  if (/^'[^']*'$/.test(t)) return { literal: t.slice(1, -1) };
  if (t === 'true') return { literal: true };
  if (t === 'false') return { literal: false };
  if (/^-?\d+$/.test(t)) return { literal: Number(t) };
  const lista = /^\[([\s\S]*)\]$/.exec(t);
  if (lista) {
    const partes = lista[1]
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    if (partes.length > 0 && partes.every((s) => /^'[^']*'$/.test(s))) {
      return { literal: partes.map((s) => s.slice(1, -1)) };
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Parseo de las cadenas de query
// ---------------------------------------------------------------------------

/**
 * @typedef {Object} Filtro
 * @property {string} campo
 * @property {string} op        operador Dart (`isEqualTo`, `whereIn`, …)
 * @property {boolean} igualdad si Firestore lo trata como igualdad
 * @property {*} literal        valor literal si estaba escrito a mano, o null
 *
 * @typedef {Object} QueryDart
 * @property {string} app
 * @property {string} archivo   ruta relativa a la raíz, con `/`
 * @property {number} linea
 * @property {string} coleccion
 * @property {Filtro[]} filtros
 * @property {string[]} igualdades  campos con filtro de igualdad
 * @property {string[]} rangos      campos con filtro de rango
 * @property {Array<{campo:string,desc:boolean}>} orden
 * @property {'get'|'snapshots'|'count'} terminal
 * @property {boolean} reconocida
 * @property {string|null} ignorar  motivo de `// AUDIT-IGNORE:`
 * @property {string|null} staff    motivo de `// AUDIT-STAFF:`
 */

/** @returns {QueryDart[]} */
export function parsearQueries(app, archivo) {
  const original = readFileSync(archivo, 'utf8');
  const src = cegarComentarios(original);
  const queries = [];
  const re = /\.collection\(\s*'([^']+)'\s*\)/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const coleccion = m[1];
    const offset = m.index;
    let pos = m.index + m[0].length;

    const filtros = [];
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
        const esIgualdad = OPS_IGUALDAD.has(op[1]);
        if (!esIgualdad && !OPS_RANGO.has(op[1])) {
          reconocida = false;
          break;
        }
        const crudo = esl.args.slice(esl.args.indexOf(`${op[1]}:`) + op[1].length + 1);
        const lit = valorLiteral(crudo);
        filtros.push({
          campo: campo[1],
          op: op[1],
          igualdad: esIgualdad,
          literal: lit ? lit.literal : null,
        });
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
        ? textoLinea(
            original,
            original.lastIndexOf('\n', offset - 1) - 1 >= 0
              ? original.lastIndexOf('\n', offset - 1) - 1
              : 0,
          )
        : '');
    const ign = /\/\/\s*AUDIT-IGNORE:\s*(.+)$/m.exec(contexto);
    const stf = /\/\/\s*AUDIT-STAFF:\s*(.+)$/m.exec(contexto);

    queries.push({
      app,
      archivo: path.relative(RAIZ, archivo).replace(/\\/g, '/'),
      linea,
      coleccion,
      filtros,
      igualdades: filtros.filter((f) => f.igualdad).map((f) => f.campo),
      rangos: filtros.filter((f) => !f.igualdad).map((f) => f.campo),
      orden,
      terminal,
      reconocida,
      ignorar: ign ? ign[1].trim() : null,
      staff: stf ? stf[1].trim() : null,
    });
  }
  return queries;
}

/** Inventario COMPLETO de las dos apps, ordenado por archivo:línea. */
export function inventario() {
  const queries = [];
  for (const app of APPS) {
    const dir = path.join(RAIZ, app, 'lib');
    for (const archivo of dartFiles(dir)) queries.push(...parsearQueries(app, archivo));
  }
  queries.sort((a, b) => a.archivo.localeCompare(b.archivo) || a.linea - b.linea);
  return queries;
}

/** Firma legible y estable de una query (la que se imprime en las tablas). */
export function firma(q) {
  const partes = [q.coleccion];
  for (const c of q.igualdades) partes.push(`${c}==`);
  for (const c of q.rangos) partes.push(`${c}<>`);
  for (const o of q.orden) partes.push(`orderBy(${o.campo}${o.desc ? ' desc' : ''})`);
  return partes.join(' ');
}

export const ubicacion = (q) => `${q.archivo}:${q.linea}`;

// ---------------------------------------------------------------------------
// Índices
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
 * de campo único. Marcarlo como FALTA sería un falso positivo.
 */
export function necesitaCompuesto(q) {
  const eq = new Set(q.igualdades);
  const ordenExterno = q.orden.some((o) => !eq.has(o.campo));
  if (ordenExterno) return true;
  if (q.rangos.length > 0 && (eq.size > 0 || q.orden.length > 0)) return true;
  if (new Set(q.rangos).size > 1) return true;
  return false;
}

/**
 * Parte ORDENADA que el índice tiene que servir, CON SENTIDO.
 *
 * ── 11-28: por qué el sentido ya no es "indiferente" ────────────────────────
 * Antes esta función devolvía `desc: null` (dirección irrelevante) cuando la
 * query no llevaba `orderBy` explícito, y `indiceCompatible` además aceptaba
 * un índice con TODAS las direcciones invertidas. Las dos concesiones eran
 * falsas y costaron un P0: contra el proyecto REAL p-gri-b5b40,
 *
 *   pedidos restauranteId== estado IN[…] orderBy(createdAt ASC)  → FAILED_PRECONDITION
 *   la MISMA con orderBy(createdAt DESC)                          → OK
 *   pedidos restauranteId== estado== createdAt>=… (sin orderBy)   → FAILED_PRECONDITION
 *
 * con el índice `restauranteId ASC, estado ASC, createdAt DESCENDING`
 * declarado y construido. Es decir: Firestore NO sirve un orden ASCENDENTE
 * desde un índice compuesto declarado DESCENDENTE, aunque los campos que le
 * preceden sean todos de igualdad; y un filtro de RANGO sin `orderBy` impone
 * orden ASCENDENTE implícito sobre el campo del rango, que el índice debe
 * declarar como ASCENDING.
 *
 * El audit estático nunca lo vio porque aceptaba las dos formas. Ahora exige
 * coincidencia EXACTA de sentido. Si algún día se comprueba en real que una
 * combinación invertida sí funciona, el cambio va aquí, con la evidencia.
 */
export function parteOrdenada(q) {
  if (q.orden.length > 0) return q.orden.map((o) => ({ campo: o.campo, desc: o.desc }));
  // Rango sin orderBy → orden ASCENDENTE implícito por el campo del rango.
  return [...new Set(q.rangos)].map((campo) => ({ campo, desc: false }));
}

/** ¿Hay en `indices` alguno que sirva a `q`? (sentido EXACTO — ver arriba) */
export function indiceCompatible(q, indices) {
  return indiceQueSirve(q, indices) !== null;
}

/** Devuelve el índice que sirve a `q`, o null. */
export function indiceQueSirve(q, indices) {
  const eq = [...new Set(q.igualdades)];
  const ord = parteOrdenada(q);
  return (
    indices.find((idx) => {
      if (idx.collectionGroup !== q.coleccion) return false;
      if ((idx.queryScope ?? 'COLLECTION') !== 'COLLECTION') return false;
      const campos = idx.fields ?? [];
      if (campos.length < eq.length + ord.length) return false;
      // Prefijo de igualdades: mismo conjunto, orden irrelevante.
      const prefijo = campos.slice(0, eq.length).map((f) => f.fieldPath);
      if ([...prefijo].sort().join(',') !== [...eq].sort().join(',')) return false;
      // Parte ordenada: misma secuencia de campos Y mismo sentido.
      const resto = campos.slice(eq.length, eq.length + ord.length);
      if (!resto.every((f, i) => f.fieldPath === ord[i].campo)) return false;
      return resto.every((f, i) => (f.order === 'DESCENDING') === ord[i].desc);
    }) ?? null
  );
}

/** Descripción legible de un índice declarado (para los informes). */
export function firmaIndice(idx) {
  return `${idx.collectionGroup}: ${(idx.fields ?? [])
    .map((f) => `${f.fieldPath} ${f.order === 'DESCENDING' ? 'DESC' : 'ASC'}`)
    .join(', ')}`;
}

/** Índices declarados en `firestore.indexes.json`. */
export function indicesDeclarados() {
  return JSON.parse(readFileSync(path.join(RAIZ, 'firestore.indexes.json'), 'utf8')).indexes;
}

/**
 * Colecciones con `match /X/{…}` de primer nivel en `firestore.rules`.
 * Sirve para el chequeo de SINCRONÍA: toda colección que las rules gobiernan
 * tiene que estar clasificada en [PARIDAD_RULES_QUERY] o en
 * [SIN_RESTRICCION_LECTURA]. Añadir una colección a las rules y olvidarse de
 * las tablas de aquí rompe el gate — que es exactamente lo que debe pasar.
 */
export function coleccionesDeRules() {
  const src = readFileSync(path.join(RAIZ, 'firestore.rules'), 'utf8');
  const cols = new Set();
  for (const m of src.matchAll(/match\s+\/([A-Za-z_]\w*)\/\{/g)) cols.add(m[1]);
  // `match /databases/{database}/documents` es el envoltorio, no una colección.
  cols.delete('databases');
  return [...cols].sort();
}
