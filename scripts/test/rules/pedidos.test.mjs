// ============================================================================
// GRI — Tests de `firestore.rules` para `match /pedidos/{pedidoId}`.
//
// Este archivo cubre DOS de los tres vectores de escalada de la fase:
//
//   1. ANTI-SPOOFING de sesión (create). La regla gasta 2 access-calls para
//      comprobar que el `sesionId` del pedido pertenece a QUIEN LO ENVÍA y que
//      esa sesión sigue ACTIVA. Sin eso, cualquier cliente autenticado podría
//      cargar comida a la cuenta de la mesa de al lado con solo conocer su
//      mesaId — que está impreso en el QR, a la vista de todos.
//
//   2. MATRIZ ROL × TRANSICIÓN (update). Port de la matriz de la Fase 6:
//        enviado        → aceptado|rechazado : admin | cocina | super  (mesero NO)
//        aceptado       → en_preparacion     : admin | cocina | super  (mesero NO)
//        en_preparacion → servido            : CUALQUIER cocinaStaffOf (mesero SÍ)
//      El mesero puede servir, no puede aceptar ni mandar a preparar. Esa
//      distinción SOLO existe aquí: si se cae, ningún test de Flutter lo nota
//      (`fake_cloud_firestore` no tiene motor de rules).
//
// `soloEstado()` acota todo update a `estado` + `updatedAt`: sin él, el avance
// de cocina sería una puerta abierta para reescribir `total` o `items`.
//
// ⚠️ `initEnv('pedidos')`: namespace propio obligatorio (ver _contexts.mjs).
// ============================================================================

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

import {
  adminDemo,
  adminOtro,
  anon,
  cliente,
  cocina,
  initEnv,
  mesero,
  sembrar,
  superAdmin,
} from './_contexts.mjs';

const RID = 'demo';
const OTRO = 'otro';

const DUENO = 'uid-cliente';
const INTRUSO = 'uid-cliente-intruso';

const M_MIA = 'GRI-MESA-demo-002'; // sesión ACTIVA del dueño
const M_AJENA = 'GRI-MESA-demo-007'; // sesión ACTIVA del intruso
const M_CERRADA = 'GRI-MESA-demo-005'; // sesión CERRADA del dueño

const P_ENVIADO = 'ped-enviado';
const P_ACEPTADO = 'ped-aceptado';
const P_PREPARACION = 'ped-en-preparacion';

const AHORA = new Date('2026-08-19T12:00:00Z');
const LUEGO = new Date('2026-08-19T13:00:00Z');

const ITEM = { productoId: 'p-ok', nombre: 'Bandeja paisa', precio: 25000, cantidad: 1 };

/** Payload válido de create; los tests lo mutan campo a campo. */
function pedidoValido(overrides = {}) {
  return {
    sesionId: M_MIA,
    mesaId: M_MIA, // la regla exige sesionId == mesaId (1 sesión por mesa)
    restauranteId: RID,
    usuarioId: DUENO,
    estado: 'enviado',
    items: [ITEM],
    total: 25000,
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — pedidos', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('pedidos');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      const mesa = { restauranteId: RID, capacidad: 4, estado: 'ocupada', updatedAt: AHORA };
      await setDoc(doc(db, 'mesas', M_MIA), { ...mesa, numero: 2 });
      await setDoc(doc(db, 'mesas', M_AJENA), { ...mesa, numero: 7 });
      await setDoc(doc(db, 'mesas', M_CERRADA), { ...mesa, numero: 5 });

      const sesion = { restauranteId: RID, cuentaSolicitada: false, createdAt: AHORA };
      await setDoc(doc(db, 'sesiones', M_MIA), {
        ...sesion,
        mesaId: M_MIA,
        usuarioId: DUENO,
        estado: 'activa',
      });
      await setDoc(doc(db, 'sesiones', M_AJENA), {
        ...sesion,
        mesaId: M_AJENA,
        usuarioId: INTRUSO,
        estado: 'activa',
      });
      await setDoc(doc(db, 'sesiones', M_CERRADA), {
        ...sesion,
        mesaId: M_CERRADA,
        usuarioId: DUENO,
        estado: 'cerrada',
      });

      // Un pedido por estado de la cola: la matriz se prueba sin encadenar
      // tests entre sí.
      const base = {
        sesionId: M_MIA,
        mesaId: M_MIA,
        restauranteId: RID,
        usuarioId: DUENO,
        items: [ITEM],
        total: 25000,
        createdAt: AHORA,
      };
      await setDoc(doc(db, 'pedidos', P_ENVIADO), { ...base, estado: 'enviado' });
      await setDoc(doc(db, 'pedidos', P_ACEPTADO), { ...base, estado: 'aceptado' });
      await setDoc(doc(db, 'pedidos', P_PREPARACION), { ...base, estado: 'en_preparacion' });
    });
  });

  // --- read ------------------------------------------------------------------

  describe('read — dueño, staff del tenant o super', () => {
    it('el DUEÑO puede leer su pedido', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, DUENO), 'pedidos', P_ENVIADO)));
    });

    it('OTRO cliente NO puede leer el pedido ajeno', async () => {
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'pedidos', P_ENVIADO)));
    });

    it('COCINA del tenant puede leer el pedido (es su cola de trabajo)', async () => {
      await assertSucceeds(getDoc(doc(cocina(env), 'pedidos', P_ENVIADO)));
    });

    it('el ADMIN de OTRO tenant NO puede leerlo — ESCALADA cross-tenant', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'pedidos', P_ENVIADO)));
    });

    it('el SUPER_ADMIN puede leer cualquier pedido', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'pedidos', P_ENVIADO)));
    });
  });

  // --- read de un pedido AUSENTE ---------------------------------------------
  //
  // MISMO MODO DE FALLO que sesiones y reservas (11-27). Una rama de `read` que
  // desreferencia `resource.data` DENIEGA los documentos inexistentes:
  // `resource` es null, la expresión revienta, sale `permission-denied` en vez
  // de "no encontrado".
  //
  // En `pedidos` no había todavía un check-then-create que lo hiciera caer el
  // día 1 —los ids son autoId, no deterministas— pero SÍ hay código que ya
  // depende de poder leer el hueco y que hoy es INALCANZABLE:
  // `_calificar()` (app_cliente/lib/features/pagos/calificacion_sheet.dart:59)
  // hace `tx.get(pedidos/{pedidoId})` y tiene una rama
  // `if (!pedidoSnap.exists) throw 'Pedido no encontrado'` que NUNCA puede
  // ejecutarse: el `tx.get` muere antes con permission-denied y el usuario ve
  // el mensaje genérico. Lo mismo le pasa al seguimiento por doc de un pedido
  // recién creado.
  //
  // Se arregla junto con las otras dos porque es el MISMO defecto, y dejarlo
  // sería dejar la tercera cabeza del bug esperando a que alguien escriba el
  // primer `db.doc('pedidos/$id').snapshots()`.

  describe('read de un pedido AUSENTE — distinguir "no existe" de "no puedes"', () => {
    it('el CLIENTE puede leer un pedidoId inexistente', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-que-no-existe')));
    });

    it('COCINA del tenant también lee el hueco ausente', async () => {
      await assertSucceeds(getDoc(doc(cocina(env), 'pedidos', 'ped-que-no-existe')));
    });

    it('LO QUE ESTO CONCEDE: el admin de OTRO tenant ve el hueco ausente', async () => {
      // Es el grado más bajo de filtración de las tres colecciones: los ids de
      // pedido son autoId de 20 caracteres aleatorios, así que "existe o no
      // existe" no es enumerable ni permite descubrir nada.
      await assertSucceeds(getDoc(doc(adminOtro(env), 'pedidos', 'ped-que-no-existe')));
    });

    it('el ANÓNIMO sigue DENEGADO sobre el pedido ausente: signedIn() manda', async () => {
      await assertFails(getDoc(doc(anon(env), 'pedidos', 'ped-que-no-existe')));
    });

    it('en cuanto el pedido EXISTE, OTRO cliente vuelve a estar DENEGADO', async () => {
      await assertFails(getDoc(doc(cliente(env, INTRUSO), 'pedidos', P_ENVIADO)));
    });

    it('en cuanto el pedido EXISTE, el admin de OTRO tenant vuelve a estar DENEGADO', async () => {
      await assertFails(getDoc(doc(adminOtro(env), 'pedidos', P_ENVIADO)));
    });
  });

  // --- create ----------------------------------------------------------------

  describe('create — el cliente pide desde SU sesión activa', () => {
    it('CLIENTE con sesión propia y activa: el pedido se crea', async () => {
      await assertSucceeds(setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-nuevo'), pedidoValido()));
    });

    it('CLIENTE usando el sesionId de OTRA persona: DENEGADO — ESCALADA (anti-spoofing)', async () => {
      // El mesaId viaja impreso en el QR de la mesa: es información pública.
      // Lo único que impide cargar comida a la cuenta de la mesa de al lado es
      // este get() sobre `sesiones/{sesionId}.usuarioId`.
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-pirata'),
          pedidoValido({ sesionId: M_AJENA, mesaId: M_AJENA }),
        ),
      );
    });

    it('CLIENTE sobre su propia sesión ya CERRADA: DENEGADO (la mesa terminó)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-tarde'),
          pedidoValido({ sesionId: M_CERRADA, mesaId: M_CERRADA }),
        ),
      );
    });

    it('CLIENTE con sesionId != mesaId: DENEGADO (la sesión y la mesa divergirían)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-divergente'),
          pedidoValido({ mesaId: M_AJENA }),
        ),
      );
    });

    it('CLIENTE declarando el usuarioId de otro: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-suplantado'),
          pedidoValido({ usuarioId: INTRUSO }),
        ),
      );
    });

    it('pedido con items vacío: DENEGADO (mínimo 1)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-vacio'), pedidoValido({ items: [] })),
      );
    });

    it('pedido con 51 items: DENEGADO (máximo 50 — tope anti-abuso)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-51'),
          pedidoValido({ items: Array.from({ length: 51 }, () => ({ ...ITEM })) }),
        ),
      );
    });

    it('pedido con exactamente 50 items: PERMITIDO (el borde superior es inclusivo)', async () => {
      await assertSucceeds(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-50'),
          pedidoValido({ items: Array.from({ length: 50 }, () => ({ ...ITEM })) }),
        ),
      );
    });

    it('pedido con total NO entero: DENEGADO (la regla exige `total is int`)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-decimal'), pedidoValido({ total: 25000.5 })),
      );
    });

    it('pedido con total negativo: DENEGADO', async () => {
      await assertFails(
        setDoc(doc(cliente(env, DUENO), 'pedidos', 'ped-negativo'), pedidoValido({ total: -1 })),
      );
    });

    it('pedido con restauranteId distinto al de la mesa: DENEGADO — ESCALADA cross-tenant', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-otro-rid'),
          pedidoValido({ restauranteId: OTRO }),
        ),
      );
    });

    it('pedido que nace ya "aceptado": DENEGADO (solo se crea en enviado)', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, DUENO), 'pedidos', 'ped-autoaceptado'),
          pedidoValido({ estado: 'aceptado' }),
        ),
      );
    });

    it('COCINA no puede crear un pedido: la regla de create es isCliente()', async () => {
      await assertFails(setDoc(doc(cocina(env), 'pedidos', 'ped-staff'), pedidoValido()));
    });
  });

  // --- update: matriz rol × transición ---------------------------------------

  describe('update — matriz rol × transición de la cola de cocina', () => {
    it('COCINA: enviado→aceptado (es quien decide si entra a la cola)', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: enviado→rechazado', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'rechazado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('ADMIN del tenant: enviado→aceptado', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDemo(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('SUPER_ADMIN: enviado→aceptado (isSuper() esquiva el chequeo de rid)', async () => {
      await assertSucceeds(
        updateDoc(doc(superAdmin(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: enviado→aceptado DENEGADO — ESCALADA (aceptar no es su rol)', async () => {
      // ESTE es el caso que hoy solo vive en la regla. El mesero pasa
      // `cocinaStaffOf`, así que lo único que lo detiene es el
      // `role() in ['admin_restaurante','cocina']` de la primera rama.
      await assertFails(
        updateDoc(doc(mesero(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: enviado→rechazado DENEGADO — ESCALADA (rechazar tampoco)', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'pedidos', P_ENVIADO), {
          estado: 'rechazado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: aceptado→en_preparacion', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_ACEPTADO), {
          estado: 'en_preparacion',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: aceptado→en_preparacion DENEGADO — ESCALADA', async () => {
      await assertFails(
        updateDoc(doc(mesero(env), 'pedidos', P_ACEPTADO), {
          estado: 'en_preparacion',
          updatedAt: LUEGO,
        }),
      );
    });

    it('MESERO: en_preparacion→servido PERMITIDO (servir SÍ es su trabajo)', async () => {
      // Única transición sin restricción de rol dentro de cocinaStaffOf: es
      // exactamente la razón por la que el mesero está en ese helper.
      await assertSucceeds(
        updateDoc(doc(mesero(env), 'pedidos', P_PREPARACION), {
          estado: 'servido',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: en_preparacion→servido también permitido', async () => {
      await assertSucceeds(
        updateDoc(doc(cocina(env), 'pedidos', P_PREPARACION), {
          estado: 'servido',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: enviado→servido DENEGADO (salto ilegal: nunca se preparó)', async () => {
      await assertFails(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'servido',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA: enviado→en_preparacion DENEGADO (salta el paso de aceptación)', async () => {
      await assertFails(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'en_preparacion',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA de OTRO tenant: ninguna transición sobre un pedido de "demo" — ESCALADA cross-tenant', async () => {
      await assertFails(
        updateDoc(doc(adminOtro(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('el CLIENTE dueño no puede auto-aceptar su pedido', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, DUENO), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          updatedAt: LUEGO,
        }),
      );
    });

    it('COCINA no puede reescribir el total al cambiar el estado (soloEstado)', async () => {
      // Sin `soloEstado()` el avance de cocina sería una puerta para editar el
      // importe de un pedido ya enviado por el cliente.
      await assertFails(
        updateDoc(doc(cocina(env), 'pedidos', P_ENVIADO), {
          estado: 'aceptado',
          total: 1,
          updatedAt: LUEGO,
        }),
      );
    });
  });

  // --- QUERY vs RULES (11-28) ------------------------------------------------
  //
  // EL P0 QUE ARREGLA ESTE BLOQUE. Un cliente envió su primer pedido contra el
  // proyecto real: apareció un instante y la pantalla se quedó en blanco. En la
  // consola, un 400 en el canal `Listen` de Firestore. La causa NO era el
  // pedido: era el LISTENER que lo mostraba.
  //
  //   pedidos.where('sesionId', isEqualTo: mesaId).orderBy('createdAt')
  //
  // Firestore evalúa las rules contra la CONSULTA, no contra los documentos
  // devueltos. La rama que ampara al cliente es
  // `resource.data.usuarioId == request.auth.uid`, y una query que no restringe
  // `usuarioId` no la puede demostrar: el emulador lo dice con todas las letras
  // — «Property usuarioId is undefined on object. for 'list'». Se deniega el
  // listener ENTERO; la caché local pintaba el pedido recién escrito y el
  // rechazo del servidor la vaciaba acto seguido. De ahí el "aparece y
  // desaparece".
  //
  // TERCERA VEZ que este modo de fallo llega a producción en el proyecto
  // (11-03 categorias/productos, 11-27 docs ausentes, 11-28 pedidos). Ninguna
  // de las tres la vio un test: `fake_cloud_firestore` no tiene motor de rules
  // y los tests de rules probaban `getDoc`, no `getDocs`. Por eso este bloque
  // usa LAS QUERIES LITERALES de las apps, no versiones simplificadas.
  //
  // Contrapartida estática: `scripts/audit_indexes.mjs` (AUDIT 2/4, entrada
  // `pedidos` de PARIDAD_RULES_QUERY) falla si alguien quita el `where`.
  describe('QUERY vs RULES — las consultas LITERALES de las apps (11-28)', () => {
    // El pedido del INTRUSO en la MISMA mesa: `sesiones/{mesaId}` se reutiliza
    // (`abrirSesion()` hace `tx.set()` sobre el mismo doc id cuando la anterior
    // está cerrada), así que dos comensales distintos comparten `sesionId` a lo
    // largo del día. Sin `where('usuarioId')` el segundo vería los pedidos del
    // primero: además de denegada, la query era INCORRECTA.
    async function pedidoDeOtroEnLaMismaMesa() {
      await sembrar(env, async (db) => {
        await setDoc(doc(db, 'pedidos', 'ped-de-otro-comensal'), {
          sesionId: M_MIA,
          mesaId: M_MIA,
          restauranteId: RID,
          usuarioId: INTRUSO,
          estado: 'servido',
          items: [ITEM],
          total: 25000,
          createdAt: LUEGO,
        });
      });
    }

    it('CLIENTE: la query del cliente SIN where("usuarioId") queda DENEGADA — el P0 de 11-28', async () => {
      // Literalmente app_cliente/lib/features/pedidos/pedidos_provider.dart
      // ANTES del arreglo.
      const db = cliente(env, DUENO);
      await assertFails(
        getDocs(
          query(collection(db, 'pedidos'), where('sesionId', '==', M_MIA), orderBy('createdAt')),
        ),
      );
    });

    it('CLIENTE: la misma query CON where("usuarioId") queda PERMITIDA', async () => {
      const db = cliente(env, DUENO);
      await assertSucceeds(
        getDocs(
          query(
            collection(db, 'pedidos'),
            where('sesionId', '==', M_MIA),
            where('usuarioId', '==', DUENO),
            orderBy('createdAt'),
          ),
        ),
      );
    });

    it('CLIENTE: el where("usuarioId") no es cosmético — excluye los pedidos del comensal anterior en la MISMA mesa', async () => {
      await pedidoDeOtroEnLaMismaMesa();
      const db = cliente(env, DUENO);
      const snap = await getDocs(
        query(
          collection(db, 'pedidos'),
          where('sesionId', '==', M_MIA),
          where('usuarioId', '==', DUENO),
          orderBy('createdAt'),
        ),
      );
      assert.equal(snap.size, 3, 'los 3 pedidos del dueño y ninguno del intruso');
      assert.ok(
        snap.docs.every((d) => d.data().usuarioId === DUENO),
        'ningún pedido ajeno se cuela en la pantalla del cliente',
      );
    });

    it('CLIENTE: query de pedidos SIN ningún filtro queda DENEGADA', async () => {
      await assertFails(getDocs(collection(cliente(env, DUENO), 'pedidos')));
    });

    it('CLIENTE: pedir where("usuarioId") de OTRO uid queda DENEGADO — la rama demostrada tiene que ser la SUYA', async () => {
      const db = cliente(env, DUENO);
      await assertFails(
        getDocs(query(collection(db, 'pedidos'), where('usuarioId', '==', INTRUSO))),
      );
    });

    it('CLIENTE: where("restauranteId") NO le sirve — esa rama es la del staff, y él no lo es', async () => {
      // Demostrar una rama que el llamador no cumple no habilita nada: la query
      // acota `restauranteId`, pero `staffOf(...)` es falso para un cliente.
      const db = cliente(env, DUENO);
      await assertFails(
        getDocs(query(collection(db, 'pedidos'), where('restauranteId', '==', RID))),
      );
    });

    it('ANÓNIMO: cualquier query de pedidos queda DENEGADA', async () => {
      await assertFails(
        getDocs(query(collection(anon(env), 'pedidos'), where('usuarioId', '==', DUENO))),
      );
    });

    it('COCINA: la cola de cocina LITERAL (restauranteId + estado IN + orderBy createdAt) queda PERMITIDA', async () => {
      // panel_admin/lib/features/cocina/pedidos_staff_provider.dart
      const db = cocina(env);
      const snap = await getDocs(
        query(
          collection(db, 'pedidos'),
          where('restauranteId', '==', RID),
          where('estado', 'in', ['enviado', 'aceptado', 'en_preparacion']),
          orderBy('createdAt'),
        ),
      );
      assert.equal(snap.size, 3, 'los 3 pedidos vivos de la mesa');
    });

    it('COCINA de OTRO tenant: la misma cola sobre "demo" queda DENEGADA', async () => {
      const db = adminOtro(env);
      await assertFails(
        getDocs(
          query(
            collection(db, 'pedidos'),
            where('restauranteId', '==', RID),
            where('estado', 'in', ['enviado', 'aceptado', 'en_preparacion']),
            orderBy('createdAt'),
          ),
        ),
      );
    });

    it('SUPER: la cola de cocina queda PERMITIDA (isSuper() es demostrable sin mirar documentos)', async () => {
      // OJO al escribir tests de este tipo: con `super_admin` la rama isSuper()
      // se demuestra sola y CUALQUIER query pasa. Un test de query-vs-rules
      // hecho con super da verde SIEMPRE y no prueba nada del cliente. Ese
      // detalle fue justo lo que hizo confuso el diagnóstico del P0.
      const db = superAdmin(env);
      await assertSucceeds(
        getDocs(
          query(
            collection(db, 'pedidos'),
            where('restauranteId', '==', RID),
            where('estado', 'in', ['enviado', 'aceptado', 'en_preparacion']),
            orderBy('createdAt'),
          ),
        ),
      );
    });

    it('ADMIN del tenant: pedidos where("restauranteId") queda PERMITIDA (tabla de clientes del panel)', async () => {
      // panel_admin/lib/features/clientes/clientes_provider.dart
      const db = adminDemo(env);
      await assertSucceeds(
        getDocs(query(collection(db, 'pedidos'), where('restauranteId', '==', RID))),
      );
    });

    it('ADMIN de OTRO tenant: pedidos where("restauranteId" == "demo") queda DENEGADA — aislamiento', async () => {
      const db = adminOtro(env);
      await assertFails(
        getDocs(query(collection(db, 'pedidos'), where('restauranteId', '==', RID))),
      );
    });
  });

  // --- delete ----------------------------------------------------------------

  describe('delete — prohibido siempre (allow delete: if false)', () => {
    it('el CLIENTE dueño no puede borrar su pedido', async () => {
      await assertFails(deleteDoc(doc(cliente(env, DUENO), 'pedidos', P_ENVIADO)));
    });

    it('el ADMIN del tenant no puede borrarlo', async () => {
      await assertFails(deleteDoc(doc(adminDemo(env), 'pedidos', P_ENVIADO)));
    });

    it('ni el SUPER_ADMIN: el pedido es rastro contable', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'pedidos', P_ENVIADO)));
    });
  });
});
