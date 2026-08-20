#!/usr/bin/env node
// ============================================================================
// GRI — Prueba de las consultas de las apps CONTRA UN PROYECTO FIRESTORE REAL.
//
// ---------------------------------------------------------------------------
// POR QUÉ EXISTE (esto es lo importante del archivo)
// ---------------------------------------------------------------------------
// Es la ÚNICA comprobación del repositorio que distingue «falta un índice» de
// «las reglas deniegan». Ninguna suite local puede sustituirla:
//
//   · el EMULADOR de Firestore **no valida índices compuestos** — ejecuta
//     cualquier consulta válida, tenga índice o no, y en el sentido que sea;
//   · `fake_cloud_firestore` (los tests de Flutter) **no tiene motor de
//     reglas** — nunca deniega nada.
//
// Las TRES veces que un bug de esta clase llegó a producción en GRI (11-03
// menú, 11-27 documentos ausentes, 11-28 pedidos) lo detectó una persona
// usando la app, no un test. Esta herramienta convierte esa detección en algo
// repetible en un minuto: firma un custom token para el uid y el rol que se le
// digan, lo canjea por un idToken y lanza por REST las consultas REALES de las
// apps, informando de OK / PERMISSION_DENIED / FAILED_PRECONDITION por cada
// una.
//
// El inventario de consultas NO está cableado aquí: sale de
// `inventario_queries.mjs`, el mismo que usa `audit_indexes.mjs`. Una consulta
// nueva en el Dart aparece sola en las dos herramientas.
//
// ---------------------------------------------------------------------------
// CUÁNDO CORRERLO
// ---------------------------------------------------------------------------
//   · después de CADA `firebase deploy --only firestore:indexes`
//   · después de CADA `firebase deploy --only firestore:rules`
//   · al investigar un «no carga» que solo se ve en el proyecto real
//
// ⚠️ CONSUME LECTURAS REALES del proyecto (se pide `limit 1` por consulta, así
//    que el gasto es mínimo, pero no es cero). NO forma parte de `npm run
//    gates` y no debe formar parte: los gates no tocan la red.
//
// ⚠️ SEGURIDAD. La clave de servicio se pasa POR RUTA y este script no la lee
//    ni la imprime: se la entrega a `firebase-admin`, que es quien la abre.
//    Tampoco se imprimen el custom token ni el idToken. No pegues la salida en
//    ningún sitio público sin revisarla igualmente.
//
// ---------------------------------------------------------------------------
// USO
// ---------------------------------------------------------------------------
//   node scripts/probar_consultas_reales.mjs \
//     --proyecto p-gri-b5b40 \
//     --clave    /ruta/a/la/clave-adminsdk.json      (o GOOGLE_APPLICATION_CREDENTIALS)
//     --api-key  <Web API key del proyecto>          (o FIREBASE_WEB_API_KEY)
//     --uid      d7c4xzmrbYcgiaGW0mCnqrdMril2 \
//     --rol      cliente                             (omitir = claims reales del uid)
//     --rid      demo
//
//   Opciones:
//     --rol <r>          fuerza claims en el token: cliente | super_admin |
//                        admin_restaurante | mesero | cocina. `cliente` = SIN
//                        claim `role` (así lo modela GRI).
//     --rid <id>         restaurante del token y valor por defecto de
//                        `where('restauranteId')`.
//     --mesa <codigo>    valor por defecto de `sesionId` / `mesaId`.
//     --valor campo=v    valor concreto para un campo. Prefijos: `ts:` ISO-8601,
//                        `int:`, `bool:`. Repetible.
//     --solo <texto>     filtra las consultas por archivo/colección.
//     --simular          NO toca la red: imprime la consulta REST que enviaría.
//                        Sirve para revisar la herramienta sin credenciales.
//     --emulador h:p     lanza las consultas contra el EMULADOR de Firestore
//                        (p.ej. `--emulador localhost:8080`) con el token
//                        `owner`. Sirve para comprobar que la herramienta
//                        construye consultas BIEN FORMADAS, y para nada más:
//                        el emulador no valida índices y `owner` se salta las
//                        reglas, así que ahí todo sale OK por construcción.
//
// ---------------------------------------------------------------------------
// CÓMO LEER EL RESULTADO
// ---------------------------------------------------------------------------
//   OK                  la consulta corre: hay índice Y las reglas la permiten.
//   FAILED_PRECONDITION falta el índice compuesto, o está declarado con el
//                       SENTIDO contrario. **Siempre es un error**, sea cual
//                       sea el rol → el script sale con código 1.
//   PERMISSION_DENIED   las reglas no la permiten PARA ESTE ROL. Hay que leerlo
//                       con la cabeza: es lo ESPERADO si corres las consultas
//                       del panel con un uid de cliente. Solo es un fallo si el
//                       rol es el que usa esa pantalla en la app.
//   SIN VALOR           el script no supo con qué valor lanzar un `where`
//                       (era una variable en el Dart y no se pasó `--valor`).
//
// ⚠️ CORRE SIEMPRE AL MENOS DOS VECES: una con un uid de CLIENTE y otra con el
//    de super_admin. El mismo fallo se ve distinto según el rol — con
//    `super_admin` la rama `isSuper()` de las reglas se demuestra sola y las
//    consultas pasan aunque estén mal formadas para un cliente. Ese detalle es
//    justo lo que hizo confuso el diagnóstico del P0 de 11-28.
// ============================================================================

import {
  OP_REST,
  firma,
  inventario,
  ubicacion,
} from './inventario_queries.mjs';

// ---------------------------------------------------------------------------
// Argumentos
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const o = { valores: {} };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const sig = () => argv[(i += 1)];
    if (a === '--proyecto') o.proyecto = sig();
    else if (a === '--clave') o.clave = sig();
    else if (a === '--api-key') o.apiKey = sig();
    else if (a === '--uid') o.uid = sig();
    else if (a === '--rol') o.rol = sig();
    else if (a === '--rid') o.rid = sig();
    else if (a === '--mesa') o.mesa = sig();
    else if (a === '--solo') o.solo = sig();
    else if (a === '--simular') o.simular = true;
    else if (a === '--emulador') o.emulador = sig();
    else if (a === '--valor') {
      const par = sig() ?? '';
      const j = par.indexOf('=');
      if (j < 0) {
        console.error(`--valor mal formado: "${par}" (se espera campo=valor)`);
        process.exit(2);
      }
      o.valores[par.slice(0, j)] = par.slice(j + 1);
    } else if (a === '--ayuda' || a === '-h' || a === '--help') o.ayuda = true;
    else {
      console.error(`Argumento desconocido: ${a}`);
      process.exit(2);
    }
  }
  return o;
}

const opts = parseArgs(process.argv.slice(2));

if (opts.ayuda) {
  console.log(
    'Ver la cabecera de scripts/probar_consultas_reales.mjs — está documentado entero ahí.',
  );
  process.exit(0);
}

opts.clave ??= process.env.GOOGLE_APPLICATION_CREDENTIALS;
opts.apiKey ??= process.env.FIREBASE_WEB_API_KEY;

if (!opts.simular && !opts.emulador) {
  const faltan = ['proyecto', 'uid', 'clave', 'apiKey'].filter((k) => !opts[k]);
  if (faltan.length) {
    console.error('');
    console.error(`Faltan argumentos obligatorios: ${faltan.join(', ')}`);
    console.error('Con --simular no hace falta ninguno (no toca la red).');
    console.error('Documentación completa en la cabecera del archivo.');
    console.error('');
    process.exit(2);
  }
}

// ---------------------------------------------------------------------------
// Valores de los `where`
// ---------------------------------------------------------------------------

/** Campos que en GRI son marcas de tiempo (para tipar bien el valor REST). */
const CAMPOS_TIMESTAMP = new Set([
  'createdAt',
  'updatedAt',
  'fecha',
  'inicioAt',
  'cuentaPedidaAt',
]);

const HOY = new Date();
const HACE_30 = new Date(HOY.getTime() - 30 * 864e5);
const EN_30 = new Date(HOY.getTime() + 30 * 864e5);

/** Convierte un valor de JS al `Value` de la API REST de Firestore. */
function aValueRest(v, campo) {
  if (v === null) return { nullValue: null };
  if (Array.isArray(v)) {
    return { arrayValue: { values: v.map((x) => aValueRest(x, campo)) } };
  }
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { integerValue: String(v) };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (CAMPOS_TIMESTAMP.has(campo)) return { timestampValue: new Date(v).toISOString() };
  return { stringValue: String(v) };
}

/** Interpreta un `--valor campo=...` con sus prefijos de tipo. */
function interpretar(bruto) {
  if (bruto.startsWith('ts:')) return new Date(bruto.slice(3));
  if (bruto.startsWith('int:')) return Number(bruto.slice(4));
  if (bruto.startsWith('bool:')) return bruto.slice(5) === 'true';
  return bruto;
}

/**
 * Resuelve con qué valor lanzar un `where`. Orden de preferencia:
 *   1. el literal que está escrito en el Dart (p.ej. `activo == true`);
 *   2. un `--valor campo=...` de la línea de órdenes;
 *   3. los valores por defecto derivados de --uid / --rid / --mesa;
 *   4. para rangos de fechas, una ventana de ±30 días según el operador.
 * Si nada aplica, devuelve `undefined` y la consulta se reporta SIN VALOR: es
 * preferible declararlo a inventarse un valor y dar un veredicto falso.
 */
function valorDe(filtro) {
  if (filtro.literal !== null && filtro.literal !== undefined) return filtro.literal;
  if (filtro.campo in opts.valores) return interpretar(opts.valores[filtro.campo]);
  if (filtro.campo === 'usuarioId') return opts.uid;
  if (filtro.campo === 'restauranteId') return opts.rid;
  if (filtro.campo === 'sesionId' || filtro.campo === 'mesaId') return opts.mesa;
  if (CAMPOS_TIMESTAMP.has(filtro.campo) && !filtro.igualdad) {
    return /Greater/.test(filtro.op) ? HACE_30 : EN_30;
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Construcción de la consulta REST
// ---------------------------------------------------------------------------

/** @returns {{structuredQuery: object} | {faltan: string[]}} */
function aStructuredQuery(q) {
  const faltan = [];
  const filtros = [];
  for (const f of q.filtros) {
    const v = valorDe(f);
    if (v === undefined) {
      faltan.push(f.campo);
      continue;
    }
    if (f.op === 'isNull') {
      filtros.push({ unaryFilter: { field: { fieldPath: f.campo }, op: 'IS_NULL' } });
    } else {
      filtros.push({
        fieldFilter: {
          field: { fieldPath: f.campo },
          op: OP_REST[f.op],
          value: aValueRest(v, f.campo),
        },
      });
    }
  }
  if (faltan.length) return { faltan };

  const sq = { from: [{ collectionId: q.coleccion }], limit: 1 };
  if (filtros.length === 1) sq.where = filtros[0];
  else if (filtros.length > 1) sq.where = { compositeFilter: { op: 'AND', filters: filtros } };
  if (q.orden.length) {
    sq.orderBy = q.orden.map((o) => ({
      field: { fieldPath: o.campo },
      direction: o.desc ? 'DESCENDING' : 'ASCENDING',
    }));
  }
  return { structuredQuery: sq };
}

// ---------------------------------------------------------------------------
// Autenticación: custom token → idToken
// ---------------------------------------------------------------------------

/**
 * Claims que se inyectan en el custom token. GRI modela el rol `cliente` como
 * la AUSENCIA del claim `role` (ver firestore.rules → isCliente()), y el
 * `super_admin` NO lleva `rid` (scripts/seed_firebase.mjs). Reproducirlo aquí
 * mal daría veredictos falsos.
 */
function claimsDe(rol, rid) {
  if (!rol || rol === 'cliente') return undefined;
  if (rol === 'super_admin') return { role: 'super_admin' };
  if (!rid) {
    console.error(`El rol "${rol}" exige --rid (su tenant).`);
    process.exit(2);
  }
  return { role: rol, rid };
}

async function obtenerIdToken() {
  // Import dinámico: con --simular no hace falta firebase-admin ni la clave.
  const { cert, initializeApp } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');

  // La clave se entrega POR RUTA a firebase-admin. Este script nunca la lee.
  const app = initializeApp({ credential: cert(opts.clave), projectId: opts.proyecto });
  const custom = await getAuth(app).createCustomToken(opts.uid, claimsDe(opts.rol, opts.rid));

  const r = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${opts.apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: custom, returnSecureToken: true }),
    },
  );
  const j = await r.json();
  if (!r.ok || !j.idToken) {
    // Se imprime el mensaje de error de Identity Toolkit, nunca el token.
    throw new Error(`No se pudo canjear el custom token: ${j?.error?.message ?? r.status}`);
  }
  return j.idToken;
}

// ---------------------------------------------------------------------------
// Ejecución
// ---------------------------------------------------------------------------

async function correr(idToken, cuerpo) {
  const base = opts.emulador
    ? `http://${opts.emulador}/v1/projects/${opts.proyecto ?? 'demo-gri'}`
    : `https://firestore.googleapis.com/v1/projects/${opts.proyecto}`;
  const url = `${base}/databases/(default)/documents:runQuery`;
  let r;
  try {
    r = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify(cuerpo),
    });
  } catch (e) {
    // Un fallo de red (host caído, sin salida a internet) no debe tumbar la
    // pasada entera: se reporta como una fila más y las demás siguen.
    return { error: { status: 'RED', message: e.message } };
  }
  const j = await r.json().catch((e) => ({ error: { status: 'RESPUESTA_NO_JSON', message: e.message } }));
  if (!r.ok) {
    const err = Array.isArray(j) ? j[0]?.error : j?.error;
    return { error: err ?? { status: `HTTP_${r.status}`, message: JSON.stringify(j) } };
  }
  const docs = (Array.isArray(j) ? j : []).filter((x) => x.document).length;
  return { docs };
}

const queries = inventario().filter(
  (q) =>
    q.reconocida &&
    !q.ignorar &&
    (!opts.solo || ubicacion(q).includes(opts.solo) || q.coleccion.includes(opts.solo)),
);

const anchoUbi = Math.max(...queries.map((q) => ubicacion(q).length), 12);
const anchoFirma = Math.max(...queries.map((q) => firma(q).length), 20);

console.log('');
console.log('═'.repeat(anchoUbi + anchoFirma + 30));
console.log(' GRI — CONSULTAS REALES CONTRA FIRESTORE');
console.log('═'.repeat(anchoUbi + anchoFirma + 30));
console.log(` proyecto : ${opts.proyecto ?? '(simulación)'}`);
console.log(` uid      : ${opts.uid ?? '(simulación)'}`);
console.log(` rol      : ${opts.rol ?? '(los claims reales del uid)'}`);
console.log(` rid      : ${opts.rid ?? '(sin valor por defecto)'}`);
console.log(` consultas: ${queries.length}`);
console.log('');

let idToken = null;
if (opts.emulador) {
  // Token especial del emulador: se salta las reglas. Ver la advertencia de
  // `--emulador` en la cabecera — esto NO prueba autorización ni índices.
  idToken = 'owner';
} else if (!opts.simular) {
  try {
    idToken = await obtenerIdToken();
  } catch (e) {
    console.error(` No se pudo autenticar: ${e.message}`);
    process.exit(2);
  }
}

const resultados = [];
for (const q of queries) {
  const construida = aStructuredQuery(q);
  if (construida.faltan) {
    resultados.push({ q, estado: 'SIN VALOR', detalle: `sin valor para ${construida.faltan.join(', ')} — usar --valor` });
    continue;
  }
  if (opts.simular) {
    resultados.push({
      q,
      estado: 'SIMULADA',
      detalle: JSON.stringify(construida.structuredQuery),
    });
    continue;
  }
  const r = await correr(idToken, construida);
  if (r.error) {
    resultados.push({
      q,
      estado: r.error.status ?? 'ERROR',
      detalle: (r.error.message ?? '').split('\n')[0],
    });
  } else {
    resultados.push({ q, estado: 'OK', detalle: `${r.docs} doc(s) (limit 1)` });
  }
}

for (const r of resultados) {
  console.log(
    ` ${ubicacion(r.q).padEnd(anchoUbi)}  ${firma(r.q).padEnd(anchoFirma)}  ` +
      `${r.estado.padEnd(19)} ${r.detalle}`,
  );
}

const cuenta = (e) => resultados.filter((r) => r.estado === e).length;
const indices = cuenta('FAILED_PRECONDITION');
const denegadas = cuenta('PERMISSION_DENIED');

console.log('');
console.log('─'.repeat(anchoUbi + anchoFirma + 30));
console.log(
  ` ${resultados.length} consultas · ${cuenta('OK')} OK · ${indices} sin índice usable · ` +
    `${denegadas} denegadas · ${cuenta('SIN VALOR')} sin valor`,
);
if (indices > 0) {
  console.log('');
  console.log(' FAILED_PRECONDITION = falta el índice compuesto O está declarado con el');
  console.log(' sentido (ASC/DESC) contrario al que la consulta necesita. Arreglar en');
  console.log(' firestore.indexes.json, volver a desplegar índices y repetir esta prueba.');
}
if (denegadas > 0) {
  console.log('');
  console.log(' PERMISSION_DENIED hay que leerlo CON EL ROL en la mano: es lo esperado si');
  console.log(' se prueban las consultas del panel con un uid de cliente. Solo es un fallo');
  console.log(' si la pantalla que hace esa consulta la usa este rol.');
}
console.log('');

// Qué se considera fallo, y por qué:
//   · FAILED_PRECONDITION → SIEMPRE: el índice falta o está al revés, y eso no
//     depende del rol con el que se corriera.
//   · cualquier estado inesperado (RED, HTTP_xxx, ERROR…) → SÍ: la
//     comprobación NO se hizo, y un exit 0 haría creer lo contrario a quien
//     encadene esto tras un despliegue.
//   · PERMISSION_DENIED → NO por sí solo: puede ser lo correcto para el rol con
//     el que se corrió (ver «CÓMO LEER EL RESULTADO» en la cabecera). Se
//     reporta y lo juzga la persona.
//   · SIN VALOR → NO: es una limitación del script, no del proyecto. Se
//     resuelve pasando `--valor campo=…`.
const ESPERADOS = new Set(['OK', 'PERMISSION_DENIED', 'SIN VALOR', 'SIMULADA']);
const inesperados = resultados.filter((r) => !ESPERADOS.has(r.estado));
if (inesperados.length > 0) {
  console.log(' Estados inesperados (la comprobación NO llegó a hacerse):');
  for (const r of inesperados) console.log(`   · ${ubicacion(r.q)} → ${r.estado}: ${r.detalle}`);
  console.log('');
}
process.exit(indices > 0 || inesperados.length > 0 ? 1 : 0);
