// ============================================================================
// GRI — Gate de CONTRATO del CLI de personal (Fase 11, plan 11-20)
//
// QUÉ HACE CUMPLIR: la restricción dura del plan. `scripts/gestion_staff.mjs`
// **no decide la autorización**: la delega en las tres piezas puras que ya están
// probadas. Si alguien reimplementa esa lógica dentro del script —aunque sea
// «solo un if de defensa en profundidad»— este archivo se pone rojo.
//
// POR QUÉ IMPORTA: la matriz de alta y la de baja acumulan 149 pruebas
// unitarias con la combinatoria COMPLETA de escalada de privilegios. Esas
// pruebas protegen `functions/src/*-matrix.js`. En el momento en que el script
// tenga su propia copia de la decisión, seguirán verdes... protegiendo código
// que ya no es el que se ejecuta. La autorización duplicada es exactamente
// donde aparecen los agujeros con el tiempo.
//
// ---------------------------------------------------------------------------
// SE MIRA EL CÓDIGO, NO LOS COMENTARIOS — y no es un detalle
// ---------------------------------------------------------------------------
// Un `grep -q "baja-matrix" gestion_staff.mjs` PASA sobre un archivo que no
// importa nada: lo satisface la línea de la cabecera que menciona el módulo.
// MEDIDO en vivo durante este plan (el <verify> de la Tarea 2 del plan pasó
// sobre la versión del script que aún no tenía `baja`). Por eso aquí se
// eliminan comentarios de bloque y de línea ANTES de buscar, y los marcadores
// —que sí viven en comentarios— se buscan aparte, sobre la línea original.
//
// ESTE ARCHIVO NO NECESITA EMULADORES y corre en milisegundos:
//   cd scripts && node --test test/staff-cli/contrato-matrices.test.mjs
// ============================================================================

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ_REPO = path.resolve(AQUI, '..', '..', '..');

const RUTA_CLI = path.join(RAIZ_REPO, 'scripts', 'gestion_staff.mjs');
const MODULOS_PUROS = [
  path.join(RAIZ_REPO, 'functions', 'src', 'auth-matrix.js'),
  path.join(RAIZ_REPO, 'functions', 'src', 'baja-matrix.js'),
  path.join(RAIZ_REPO, 'functions', 'src', 'password-policy.js'),
];

function leer(ruta) {
  return readFileSync(ruta, 'utf8');
}

/**
 * Separa cada línea en su parte de CÓDIGO y la línea ORIGINAL (con comentario).
 *
 * Los comentarios de bloque se blanquean primero conservando los saltos de
 * línea, para que la numeración siga cuadrando con el archivo real. Después, de
 * cada línea se corta lo que va a partir del primer `//`.
 */
function lineasDeCodigo(fuente) {
  const sinBloques = fuente.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '));
  const originales = fuente.split('\n');
  return sinBloques.split('\n').map((linea, i) => {
    const corte = linea.indexOf('//');
    return {
      n: i + 1,
      codigo: corte === -1 ? linea : linea.slice(0, corte),
      original: originales[i] ?? '',
    };
  });
}

/** Todo el código del archivo, ya sin comentarios, como un solo texto. */
function soloCodigo(fuente) {
  return lineasDeCodigo(fuente)
    .map((l) => l.codigo)
    .join('\n');
}

// ============================================================================
// 1. El script IMPORTA las tres piezas (y de los archivos correctos)
// ============================================================================

const IMPORTS_EXIGIDOS = [
  { simbolo: 'autorizarAlta', modulo: '../functions/src/auth-matrix.js' },
  { simbolo: 'autorizarCambioEstado', modulo: '../functions/src/baja-matrix.js' },
  { simbolo: 'validarPassword', modulo: '../functions/src/password-policy.js' },
];

for (const { simbolo, modulo } of IMPORTS_EXIGIDOS) {
  test(`gestion_staff.mjs importa ${simbolo} de ${modulo}`, () => {
    const codigo = soloCodigo(leer(RUTA_CLI));
    const re = new RegExp(
      `import\\s*\\{[^}]*\\b${simbolo}\\b[^}]*\\}\\s*from\\s*['"]${modulo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}['"]`,
    );
    assert.ok(
      re.test(codigo),
      `Falta el import REAL (no un comentario) de ${simbolo} desde ${modulo}.\n` +
        'La autorización del CLI tiene que ser la misma que la de la callable, o los\n' +
        '149 tests de escalada dejan de proteger lo que se ejecuta.',
    );
  });

  test(`gestion_staff.mjs LLAMA a ${simbolo}, no solo lo importa`, () => {
    const codigo = soloCodigo(leer(RUTA_CLI));
    // Un import sin uso es indistinguible de no tenerlo: el linter lo quitaría y
    // nadie lo notaría. Se exige al menos una invocación.
    const llamadas = codigo.match(new RegExp(`\\b${simbolo}\\s*\\(`, 'g')) ?? [];
    assert.ok(
      llamadas.length >= 1,
      `${simbolo} se importa pero no se invoca en ninguna parte del código.`,
    );
  });
}

// ============================================================================
// 2. El script NO tiene literales de rol asignable
// ============================================================================
//
// Los tres roles que la matriz SÍ sabe asignar no deben aparecer nunca en el
// código del CLI: si aparecen, es que alguien está comparando roles aquí. Los
// necesarios para la ayuda salen de `ROLES_ASIGNABLES`, que se importa.

const ROLES_ASIGNABLES_LITERAL = ['admin_restaurante', 'mesero', 'cocina'];

test('gestion_staff.mjs NO contiene literales de rol asignable en el código', () => {
  const lineas = lineasDeCodigo(leer(RUTA_CLI));
  const hallazgos = [];
  for (const l of lineas) {
    for (const rol of ROLES_ASIGNABLES_LITERAL) {
      if (l.codigo.includes(rol)) hallazgos.push(`${l.n}: ${l.codigo.trim()}`);
    }
  }
  assert.deepEqual(
    hallazgos,
    [],
    'Hay literales de rol asignable en el código del CLI. Eso significa que el\n' +
      'script está razonando sobre roles por su cuenta, en vez de preguntárselo a\n' +
      '`autorizarAlta` / `autorizarCambioEstado`:\n  ' +
      hallazgos.join('\n  '),
  );
});

// ============================================================================
// 3. Los DOS literales que sí hacen falta están DECLARADOS
// ============================================================================
//
// `super_admin` y `cliente` no son asignables ni gestionables por las matrices
// (`ROLES_ASIGNABLES` y `ROLES_GESTIONABLES` los excluyen a propósito), así que
// la matriz no puede razonar sobre ellos: el anti-secuestro del alta y la vía de
// recuperación tienen que nombrarlos. Se aceptan, pero DECLARADOS con
// `// ROL-LITERAL-OK` — mismo patrón que `// AUDIT-STAFF` (11-03),
// `// TOKEN-IGNORE` (11-19) y `// POLICY-LOGIN-OK` (11-22). Una exención
// silenciosa cuenta como fallo.

const MARCADOR = '// ROL-LITERAL-OK';
const ROLES_NO_ASIGNABLES = ['super_admin', 'cliente'];

test('los literales de rol no asignables están declarados con // ROL-LITERAL-OK', () => {
  const lineas = lineasDeCodigo(leer(RUTA_CLI));
  const sinDeclarar = [];
  let declarados = 0;
  for (const l of lineas) {
    const tiene = ROLES_NO_ASIGNABLES.some((r) => l.codigo.includes(`'${r}'`));
    if (!tiene) continue;
    if (l.original.includes(MARCADOR)) declarados += 1;
    else sinDeclarar.push(`${l.n}: ${l.codigo.trim()}`);
  }
  assert.deepEqual(
    sinDeclarar,
    [],
    `Literal de rol sin declarar. Añade ${MARCADOR} en esa línea y explica por qué\n` +
      'la matriz no puede decidirlo:\n  ' + sinDeclarar.join('\n  '),
  );
  assert.ok(
    declarados >= 1,
    'No hay ningún literal declarado: si desaparecieron, este gate se quedó sin nada\n' +
      'que vigilar y hay que revisar si el anti-secuestro sigue en pie.',
  );
});

// ============================================================================
// 4. El script NO tiene una política de contraseñas propia
// ============================================================================
//
// La política vive en `password-policy.js` y sus vectores canónicos en
// `scripts/password_policy_vectors.json` (11-22). Una segunda implementación
// aquí divergiría en silencio: el CLI aceptaría contraseñas que el panel
// rechaza, o al revés.

const HUELLAS_DE_POLITICA = [
  { patron: /\\p\{L[ul]\}/, que: 'categoría Unicode de mayúscula/minúscula (\\p{Lu} / \\p{Ll})' },
  { patron: /\[A-Z\]/, que: 'clase de caracteres [A-Z]' },
  { patron: /\[a-z\]/, que: 'clase de caracteres [a-z]' },
  { patron: /\[0-9\]/, que: 'clase de caracteres [0-9]' },
  { patron: /\\d/, que: 'clase de dígito \\d' },
  { patron: /\bRegExp\b/, que: 'construcción de una RegExp' },
  { patron: /\.length\s*[<>=!]=*\s*(?:[6-9]|[1-9]\d+)\b/, que: 'comparación de longitud contra un mínimo' },
  { patron: /\b(?:MIN_PASSWORD|LONGITUD_MINIMA|minPassword|minLength)\b/, que: 'constante de longitud mínima propia' },
];

test('gestion_staff.mjs NO contiene una política de contraseñas propia', () => {
  const lineas = lineasDeCodigo(leer(RUTA_CLI));
  const hallazgos = [];
  for (const l of lineas) {
    for (const h of HUELLAS_DE_POLITICA) {
      if (h.patron.test(l.codigo)) hallazgos.push(`${l.n} (${h.que}): ${l.codigo.trim()}`);
    }
  }
  assert.deepEqual(
    hallazgos,
    [],
    'Huellas de una política de contraseñas propia en el CLI. La única fuente es\n' +
      '`validarPassword` de functions/src/password-policy.js:\n  ' + hallazgos.join('\n  '),
  );
});

// ============================================================================
// 5. Los tres módulos importados siguen siendo PUROS
// ============================================================================
//
// ES LA PREMISA DE LA QUE DEPENDE TODO ESTE PLAN. `scripts/` es otro paquete:
// puede importar `functions/src/*.js` porque esos archivos no arrastran
// `firebase-admin` ni `firebase-functions`. El día que alguien ensucie
// cualquiera de los tres, el CLI dejaría de arrancar —o peor, arrancaría con
// una segunda instancia del SDK—. Este test lo detecta antes que el runtime.

for (const ruta of MODULOS_PUROS) {
  const nombre = path.basename(ruta);
  test(`${nombre} sigue siendo PURO (sin imports de firebase)`, () => {
    const codigo = soloCodigo(leer(ruta));
    const sucios = [];
    for (const paquete of ['firebase-admin', 'firebase-functions', 'firebase/']) {
      if (codigo.includes(paquete)) sucios.push(paquete);
    }
    assert.deepEqual(
      sucios,
      [],
      `${nombre} importa ${sucios.join(', ')}. Eso rompe DOS cosas a la vez: la\n` +
        'combinatoria completa de escalada deja de poder ejecutarse sin emuladores, y\n' +
        '`scripts/gestion_staff.mjs` deja de poder importarlo.',
    );
  });
}

// ============================================================================
// 6. El detector de comentarios funciona (control del propio gate)
// ============================================================================
//
// Sin esto, un fallo en `lineasDeCodigo` dejaría los cuatro tests de arriba
// verdes por el motivo equivocado: si blanqueara TODO, no encontraría nunca un
// hallazgo y no fallaría jamás.

test('lineasDeCodigo separa código de comentarios (control del gate)', () => {
  const muestra = [
    "const a = 'mesero'; // comentario",
    "// const b = 'cocina';",
    '/* const c = ',
    "   \'admin_restaurante\'; */",
    "const d = 'super_admin'; // ROL-LITERAL-OK",
  ].join('\n');
  const lineas = lineasDeCodigo(muestra);

  assert.equal(lineas.length, 5, 'se pierde la numeración de líneas');
  assert.ok(lineas[0].codigo.includes('mesero'), 'no ve un literal en código real');
  assert.ok(!lineas[1].codigo.includes('cocina'), 'no ignora un comentario de línea');
  assert.ok(!lineas[3].codigo.includes('admin_restaurante'), 'no ignora un comentario de bloque');
  assert.ok(lineas[4].codigo.includes('super_admin'), 'no ve el literal declarado');
  assert.ok(lineas[4].original.includes(MARCADOR), 'pierde el marcador, que vive en el comentario');
});
