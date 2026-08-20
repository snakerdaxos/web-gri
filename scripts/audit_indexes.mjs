#!/usr/bin/env node
// ============================================================================
// GRI — Audit ESTÁTICO de queries Firestore.
//
// Hace CUATRO comprobaciones sobre el inventario de queries que
// `inventario_queries.mjs` extrae del Dart de `app_cliente/lib` y
// `panel_admin/lib`:
//
//   1. ÍNDICES      · toda query que necesite un índice compuesto tiene su
//                     índice declarado en `firestore.indexes.json`, CON EL
//                     SENTIDO (ASC/DESC) que la query exige.
//   2. PARIDAD      · toda query no exenta replica en sus `where` los campos
//      rules↔query   que alguna rama de `firestore.rules` exige por documento.
//   3. COBERTURA    · ninguna query apunta a una colección sin clasificar, y
//                     ninguna colección de las rules se queda sin clasificar.
//   4. ÍNDICES SIN  · informativo: índices declarados que hoy no sirven a
//      USO            ninguna query (no falla el audit — poda deliberada).
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE (leer antes de tocar nada)
// ---------------------------------------------------------------------------
// * El emulador de Firestore **NO valida índices compuestos**: "The Firestore
//   emulator does not track composite indexes and will instead execute any
//   valid query". Ninguna suite local puede detectar un índice que falta —ni
//   uno declarado al revés—, así que este audit es la ÚNICA mitigación
//   automatizable en los gates.
// * Firestore evalúa las security rules contra la CONSULTA, no contra los
//   documentos devueltos. Si una query pierde un `where` que la regla exige,
//   se deniega ENTERA. Los tests de rules (`scripts/test/rules/`) prueban la
//   forma de la query en JavaScript, y los tests de app usan
//   `fake_cloud_firestore`, que no tiene motor de rules: sin este check,
//   borrar un `where('disponible', …)` del Dart no lo detecta NINGÚN gate.
//
// ---------------------------------------------------------------------------
// HISTORIAL — las tres veces que esta clase de bug llegó a producción
// ---------------------------------------------------------------------------
//   11-03  categorias/productos · query sin `where('activo')` → menú denegado.
//          (Origen de este audit y de la tabla de paridad.)
//   11-27  sesiones/reservas/pedidos · `read` que desreferencia `resource.data`
//          denegaba los documentos AUSENTES. No es query-vs-rule, pero es el
//          mismo patrón: la regla y el uso real divergían y ningún gate lo vio.
//   11-28  pedidos · DOS bugs a la vez:
//            (a) query del cliente sin `where('usuarioId')` → listener
//                denegado, pantalla en blanco tras enviar el pedido;
//            (b) índices de `pedidos` declarados con `createdAt DESCENDING`
//                mientras la cola de cocina ordena ASC y el reporte filtra por
//                rango (orden ASC implícito) → FAILED_PRECONDITION en real.
//          (b) pasó por delante de este audit porque comprobaba la PRESENCIA
//          del índice y no su SENTIDO. Corregido: ahora el sentido es exacto.
//
// ---------------------------------------------------------------------------
// LIMITACIÓN — LEER ANTES DE CONFIAR
// ---------------------------------------------------------------------------
// Análisis HEURÍSTICO sobre texto (ver cabecera de `inventario_queries.mjs`).
// **NO sustituye a probar contra el proyecto real.** Para eso está
// `scripts/probar_consultas_reales.mjs`, que lee ESTE MISMO inventario y lanza
// las consultas por REST contra un proyecto de verdad: es lo único que
// distingue "falta el índice" de "las rules deniegan".
// Un OK aquí significa "no se detecta nada mal", no "está probado".
//
// Uso:  cd scripts && npm run audit:indexes      (exit 1 si algo falta)
// ============================================================================

import {
  PARIDAD_RULES_QUERY,
  SIN_RESTRICCION_LECTURA,
  coleccionesDeRules,
  firma,
  firmaIndice,
  indiceQueSirve,
  indicesDeclarados,
  inventario,
  necesitaCompuesto,
  parteOrdenada,
  ubicacion,
} from './inventario_queries.mjs';

const indices = indicesDeclarados();
const queries = inventario();

const anchoUbi = Math.max(...queries.map((q) => ubicacion(q).length), 12);
const anchoFirma = Math.max(...queries.map((q) => firma(q).length), 20);
const ANCHO = anchoUbi + anchoFirma + 22;
const regla = (c = '─') => c.repeat(ANCHO);

let fallos = 0;

// ---------------------------------------------------------------------------
// 1/4 — ÍNDICES COMPUESTOS
// ---------------------------------------------------------------------------

/** "createdAt ASC" — lo que la query exige de la parte ordenada del índice. */
const exigencia = (q) =>
  parteOrdenada(q)
    .map((o) => `${o.campo} ${o.desc ? 'DESC' : 'ASC'}`)
    .join(', ');

console.log('');
console.log(regla('═'));
console.log(' AUDIT 1/4 — ÍNDICES COMPUESTOS  (query Dart ↔ firestore.indexes.json)');
console.log(regla('═'));
console.log(` ${'archivo:línea'.padEnd(anchoUbi)}  ${'firma'.padEnd(anchoFirma)}  veredicto`);
console.log(regla());

for (const q of queries) {
  const ubi = ubicacion(q).padEnd(anchoUbi);
  const f = firma(q).padEnd(anchoFirma);
  let veredicto;
  if (q.ignorar) {
    veredicto = `IGNORADA (AUDIT-IGNORE: ${q.ignorar})`;
  } else if (!q.reconocida) {
    veredicto = 'NO PARSEABLE — declarar `// AUDIT-IGNORE: motivo` o simplificar la query';
    fallos += 1;
  } else if (!necesitaCompuesto(q)) {
    veredicto = 'n/a (índices automáticos de campo único)';
  } else if (indiceQueSirve(q, indices)) {
    veredicto = `OK (${exigencia(q)})`;
  } else {
    // Distinguir "no hay índice" de "lo hay con el sentido cambiado" no es un
    // lujo: el segundo caso es EXACTAMENTE el bug (b) de 11-28, y leído en la
    // tabla como un simple "FALTA ÍNDICE" invita a declarar un duplicado.
    const mismoOrdenSinSentido = indices.filter(
      (idx) =>
        idx.collectionGroup === q.coleccion &&
        (idx.fields ?? []).length >= q.igualdades.length + parteOrdenada(q).length &&
        [...(idx.fields ?? []).slice(0, q.igualdades.length).map((x) => x.fieldPath)]
          .sort()
          .join(',') === [...new Set(q.igualdades)].sort().join(',') &&
        (idx.fields ?? [])
          .slice(q.igualdades.length, q.igualdades.length + parteOrdenada(q).length)
          .every((x, i) => x.fieldPath === parteOrdenada(q)[i].campo),
    );
    veredicto =
      mismoOrdenSinSentido.length > 0
        ? `ÍNDICE CON EL SENTIDO EQUIVOCADO — la query exige (${exigencia(q)}); ` +
          `declarado: ${firmaIndice(mismoOrdenSinSentido[0])}`
        : `FALTA ÍNDICE COMPUESTO — la query exige (${exigencia(q)})`;
    fallos += 1;
  }
  console.log(` ${ubi}  ${f}  ${veredicto}`);
}

// ---------------------------------------------------------------------------
// 2/4 — PARIDAD rules ↔ query
// ---------------------------------------------------------------------------

console.log('');
console.log(regla('═'));
console.log(' AUDIT 2/4 — PARIDAD rules ↔ query  (filtros que la regla exige por doc)');
console.log(regla('═'));
for (const [col, def] of Object.entries(PARIDAD_RULES_QUERY)) {
  const alts = def.alternativas.map((a) => `where(${a.join(' + ')})`).join('  ó  ');
  console.log(` · ${col.padEnd(13)} exige ${alts}`);
  console.log(`   ${''.padEnd(13)}   — ${def.origen}`);
}
console.log(regla());

let revisadas = 0;
for (const q of queries) {
  const def = PARIDAD_RULES_QUERY[q.coleccion];
  if (!def || q.ignorar) continue;
  revisadas += 1;
  const ubi = ubicacion(q).padEnd(anchoUbi);
  const cumple = def.alternativas.find((alt) => alt.every((c) => q.igualdades.includes(c)));
  if (cumple) {
    console.log(` ${ubi}  ${firma(q).padEnd(anchoFirma)}  OK (${cumple.join(' + ')})`);
  } else if (q.staff) {
    console.log(` ${ubi}  ${firma(q).padEnd(anchoFirma)}  EXENTA (AUDIT-STAFF: ${q.staff})`);
  } else {
    const opciones = def.alternativas
      .map((a) => a.map((c) => `where('${c}')`).join(' + '))
      .join(' ó ');
    console.log(` ${ubi}  ${firma(q).padEnd(anchoFirma)}  FALTA ${opciones}`);
    fallos += 1;
  }
}
if (revisadas === 0) console.log(' (ninguna query alcanza la tabla de paridad)');

// ---------------------------------------------------------------------------
// 3/4 — COBERTURA (nadie se escapa de la tabla)
// ---------------------------------------------------------------------------
// Los tres incidentes de esta clase empezaron igual: una colección cuya regla
// mira el documento y una query que nadie confrontó con ella. Que el audit
// solo revise las colecciones que ALGUIEN se acordó de dar de alta reproduce
// el fallo. Aquí se cierra por los dos lados:
//   a) toda colección consultada desde el Dart está clasificada;
//   b) toda colección con `match` en firestore.rules está clasificada.

console.log('');
console.log(regla('═'));
console.log(' AUDIT 3/4 — COBERTURA  (toda colección clasificada en una de las dos tablas)');
console.log(regla('═'));

const clasificada = (c) => c in PARIDAD_RULES_QUERY || c in SIN_RESTRICCION_LECTURA;

const consultadas = [...new Set(queries.filter((q) => !q.ignorar).map((q) => q.coleccion))].sort();
for (const col of consultadas) {
  if (clasificada(col)) {
    const como =
      col in PARIDAD_RULES_QUERY
        ? 'sujeta a paridad'
        : `sin restricción — ${SIN_RESTRICCION_LECTURA[col]}`;
    console.log(` · consultada  ${col.padEnd(15)} ${como}`);
  } else {
    console.log(
      ` · consultada  ${col.padEnd(15)} SIN CLASIFICAR — añadirla a PARIDAD_RULES_QUERY ` +
        'o a SIN_RESTRICCION_LECTURA en inventario_queries.mjs',
    );
    fallos += 1;
  }
}

for (const col of coleccionesDeRules()) {
  if (clasificada(col)) continue;
  console.log(
    ` · en rules    ${col.padEnd(15)} SIN CLASIFICAR — firestore.rules la gobierna y las ` +
      'tablas de inventario_queries.mjs no la conocen',
  );
  fallos += 1;
}

// ---------------------------------------------------------------------------
// 4/4 — ÍNDICES DECLARADOS SIN QUERY QUE LOS USE  (informativo, no falla)
// ---------------------------------------------------------------------------
// No es un error: puede haber índices para queries futuras o para consultas
// manuales. Se listan porque borrarlos de `firestore.indexes.json` los BORRA
// en producción al desplegar, y esa poda debe ser una decisión consciente.

const usados = new Set();
for (const q of queries) {
  if (q.ignorar || !q.reconocida || !necesitaCompuesto(q)) continue;
  const idx = indiceQueSirve(q, indices);
  if (idx) usados.add(indices.indexOf(idx));
}

console.log('');
console.log(regla('═'));
console.log(' AUDIT 4/4 — ÍNDICES DECLARADOS QUE HOY NO SIRVEN A NINGUNA QUERY (informativo)');
console.log(regla('═'));
const sinUso = indices.map((idx, i) => [idx, i]).filter(([, i]) => !usados.has(i));
if (sinUso.length === 0) {
  console.log(' (ninguno — todos los índices declarados tienen query que los use)');
} else {
  for (const [idx] of sinUso) console.log(` · ${firmaIndice(idx)}`);
  console.log('');
  console.log(' No es un fallo. Si se podan, se borran también en producción al desplegar.');
}

// ---------------------------------------------------------------------------

console.log('');
console.log(regla());
console.log(
  ` ${queries.length} queries analizadas · ${revisadas} sujetas a paridad · ` +
    `${consultadas.length} colecciones consultadas · ${fallos} fallo(s)`,
);
console.log(' Recordatorio: análisis estático. El emulador NO valida índices compuestos —');
console.log(' un OK aquí NO sustituye a `node scripts/probar_consultas_reales.mjs` contra el');
console.log(' proyecto real tras desplegar índices o reglas.');
console.log('');

process.exit(fallos > 0 ? 1 : 0);
