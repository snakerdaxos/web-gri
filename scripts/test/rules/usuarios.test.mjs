// ============================================================================
// GRI — Tests de `firestore.rules` para `match /usuarios/{uid}`.
//
// ★ ESTE ES EL ARCHIVO MÁS IMPORTANTE DE LA SUITE EN TÉRMINOS DE SEGURIDAD ★
//
// `usuarios/{uid}` es el punto de ESCALADA VERTICAL del sistema: es el único
// documento que un cliente recién registrado puede escribir sobre sí mismo. Si
// la regla dejara pasar un `role` arbitrario, cualquiera con la app instalada
// se daría de alta como `admin_restaurante` desde la pantalla de registro.
//
// La mitigación vive en `firestore.rules` (match /usuarios/{uid}) y hasta este
// plan NO TENÍA NI UN TEST. Los casos marcados `// ESCALADA` son justamente
// esos: buscarlos por esa etiqueta en una auditoría futura.
//
// ⚠️ CLAVE PARA ENTENDER POR QUÉ ESTO NO ES CATASTRÓFICO HOY: el doc
// `usuarios/{uid}` es un ESPEJO de perfil y NUNCA autoriza. La autorización
// real son los custom claims `{role, rid}` del token, que solo pone el Admin
// SDK. Ninguna regla hace `get()` sobre `usuarios/`. Aun así, un `role`
// falsificado en el espejo desincronizaría la UI (el panel decide qué menú
// pintar leyendo el perfil) y sería el primer peldaño de un ataque real —
// mantener el espejo honesto es defensa en profundidad, no cosmética.
//
//   read   : el propio usuario | super_admin
//            | admin_restaurante cuyo rid == resource.data.restauranteId
//              (AMPLIADO EN 11-10 — pantalla de gestión de equipo del panel)
//   create : el propio uid + role == 'cliente' + restauranteId == null
//   update : el propio uid + hasOnly(['nombre'])
//   delete : false
//
// ⚠️ `initEnv('usuarios')`: namespace propio obligatorio (ver _contexts.mjs).
// ============================================================================

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
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
const RID_OTRO = 'otro';

const YO = 'uid-cliente'; // uid por defecto de cliente()
const OTRO_UID = 'uid-cliente-intruso';
const UID_ADMIN = 'uid-admin-demo'; // uid por defecto de adminDemo()
const UID_MESERO = 'uid-mesero-demo'; // uid por defecto de mesero()
const UID_ADMIN_OTRO = 'uid-admin-otro'; // uid por defecto de adminOtro()
const UID_NUEVO = 'uid-recien-registrado';

const AHORA = new Date('2026-08-19T12:00:00Z');

/** Payload de auto-registro legítimo; los tests lo mutan campo a campo. */
function perfilCliente(overrides = {}) {
  return {
    email: 'cliente@example.com',
    nombre: 'Cliente Nuevo',
    role: 'cliente',
    restauranteId: null,
    createdAt: AHORA,
    ...overrides,
  };
}

describe('firestore.rules — usuarios', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let env;

  before(async () => {
    env = await initEnv('usuarios');
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await sembrar(env, async (db) => {
      await setDoc(doc(db, 'usuarios', YO), perfilCliente({ nombre: 'Yo Mismo' }));
      await setDoc(doc(db, 'usuarios', OTRO_UID), perfilCliente({ nombre: 'Otra Persona' }));
      // Perfil de staff: lo escribe el Admin SDK (seed / callable de 11-08),
      // jamás el cliente. Sirve para probar la lectura del equipo.
      await setDoc(doc(db, 'usuarios', UID_ADMIN), {
        email: 'admin@demo.com',
        nombre: 'Admin Demo',
        role: 'admin_restaurante',
        restauranteId: RID,
        createdAt: AHORA,
      });
      // Segundo miembro del equipo de `demo`: sin él, la query del equipo
      // devolvería un solo doc y no distinguiría "lista el equipo" de
      // "lee su propio perfil".
      await setDoc(doc(db, 'usuarios', UID_MESERO), {
        email: 'mesero@demo.com',
        nombre: 'Mesero Demo',
        role: 'mesero',
        restauranteId: RID,
        createdAt: AHORA,
      });
      // Staff de OTRO tenant: el objetivo del cruce de restaurante.
      await setDoc(doc(db, 'usuarios', UID_ADMIN_OTRO), {
        email: 'admin@otro.com',
        nombre: 'Admin Otro',
        role: 'admin_restaurante',
        restauranteId: RID_OTRO,
        createdAt: AHORA,
      });
    });
  });

  /** La query REAL del panel: `usuarios where restauranteId == <rid>`. */
  function queryEquipo(db, rid) {
    return query(collection(db, 'usuarios'), where('restauranteId', '==', rid));
  }

  // --- create: AUTO-REGISTRO — el vector de escalada vertical ----------------

  describe('create — auto-registro: solo cliente y sin restaurante', () => {
    it('auto-registro legítimo (role cliente, restauranteId null, uid propio): PERMITIDO', async () => {
      await assertSucceeds(
        setDoc(doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO), perfilCliente()),
      );
    });

    it('// ESCALADA — auto-registro declarándose admin_restaurante: DENEGADO', async () => {
      // ESTE es el vector: la pantalla de registro escribe este documento con
      // el SDK del cliente. Sin `request.resource.data.role == 'cliente'` en la
      // regla, cualquiera se da de alta como admin desde el móvil.
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ role: 'admin_restaurante', restauranteId: RID }),
        ),
      );
    });

    it('// ESCALADA — auto-registro declarándose super_admin: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ role: 'super_admin' }),
        ),
      );
    });

    it('// ESCALADA — auto-registro como mesero: DENEGADO', async () => {
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ role: 'mesero', restauranteId: RID }),
        ),
      );
    });

    it('// ESCALADA — role cliente pero restauranteId "demo": DENEGADO (pertenencia falsa)', async () => {
      // Un cliente NO pertenece a un restaurante. Colar un rid en el espejo
      // haría que la UI del panel lo tratara como parte del equipo.
      await assertFails(
        setDoc(
          doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO),
          perfilCliente({ restauranteId: RID }),
        ),
      );
    });

    it('// ESCALADA — crear el perfil de OTRO uid: DENEGADO (suplantación)', async () => {
      await assertFails(
        setDoc(doc(cliente(env, UID_NUEVO), 'usuarios', 'uid-de-la-victima'), perfilCliente()),
      );
    });

    it('ANÓNIMO no puede crear ningún perfil: la regla exige signedIn()', async () => {
      await assertFails(setDoc(doc(anon(env), 'usuarios', UID_NUEVO), perfilCliente()));
    });

    it('un ADMIN con claims tampoco escribe su propio espejo de staff desde el cliente', async () => {
      // Consecuencia deliberada: el perfil de staff SOLO lo crea el Admin SDK
      // (seed / callable de 11-08), que se salta las rules. Si esto pasara a
      // estar permitido, el espejo dejaría de ser fiable.
      await assertFails(
        setDoc(
          doc(adminDemo(env), 'usuarios', 'uid-admin-nuevo'),
          perfilCliente({ role: 'admin_restaurante', restauranteId: RID }),
        ),
      );
    });
  });

  // --- update: el role queda CONGELADO ---------------------------------------

  describe('update — solo el nombre; role y restauranteId congelados', () => {
    it('el propio usuario puede cambiar su nombre', async () => {
      await assertSucceeds(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), { nombre: 'Yo Renombrado' }),
      );
    });

    it('// ESCALADA — el propio usuario ascendiéndose a admin_restaurante: DENEGADO', async () => {
      // El segundo vector de auto-ascenso: registrarse limpio y ascender
      // después. `hasOnly(['nombre'])` lo cierra.
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), { role: 'admin_restaurante' }),
      );
    });

    it('// ESCALADA — el propio usuario asignándose un restauranteId: DENEGADO', async () => {
      await assertFails(updateDoc(doc(cliente(env, YO), 'usuarios', YO), { restauranteId: RID }));
    });

    it('// ESCALADA — colar el role junto a un cambio de nombre legítimo: DENEGADO', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), {
          nombre: 'Yo Renombrado',
          role: 'cocina',
        }),
      );
    });

    it('cambiar el email tampoco: la regla permite EXACTAMENTE una clave', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', YO), { email: 'otro@example.com' }),
      );
    });

    it('editar el perfil de OTRA persona: DENEGADO', async () => {
      await assertFails(
        updateDoc(doc(cliente(env, YO), 'usuarios', OTRO_UID), { nombre: 'Te renombro' }),
      );
    });

    it('el SUPER_ADMIN tampoco edita perfiles ajenos desde el cliente', async () => {
      // Veredicto fijado: la rama de update NO tiene excepción para isSuper()
      // (la de read sí). Cambiar roles es trabajo del Admin SDK, no del panel.
      await assertFails(
        updateDoc(doc(superAdmin(env), 'usuarios', YO), { nombre: 'Renombrado por super' }),
      );
    });
  });

  // --- read -------------------------------------------------------------------

  describe('read — el propio perfil o el super_admin', () => {
    it('el propio usuario puede leer su perfil', async () => {
      await assertSucceeds(getDoc(doc(cliente(env, YO), 'usuarios', YO)));
    });

    it('un CLIENTE NO puede leer el perfil de otra persona', async () => {
      await assertFails(getDoc(doc(cliente(env, YO), 'usuarios', OTRO_UID)));
    });

    it('el SUPER_ADMIN puede leer el perfil de cualquiera', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'usuarios', YO)));
    });

    it('AMPLIADO EN 11-10 — el ADMIN del restaurante SÍ lee el perfil de su equipo', async () => {
      // CAMBIO DE VEREDICTO CONSCIENTE (plan 11-10). Hasta este plan la regla
      // solo dejaba leer el propio doc o todo al super_admin, y por eso la
      // pantalla de gestión de equipo del panel no podía existir. El comentario
      // que 11-04 dejó aquí (`// AMPLIADO EN 11-10`) señalaba exactamente esto.
      //
      // ⚠️ EL CASO ANTERIOR ERA UN VERDE POR EL MOTIVO EQUIVOCADO ESPERANDO
      // A OCURRIR: leía `usuarios/YO`, que es un CLIENTE con
      // `restauranteId: null`. Con la regla ampliada ese `assertFails` SEGUIRÍA
      // PASANDO (null != 'demo') sin haber ejercitado jamás la ampliación, y
      // el nombre del test habría mentido. Por eso el caso positivo lee un doc
      // de STAFF del propio rid, y el negativo del cliente se conserva aparte
      // como aserción de ACOTAMIENTO (ver el bloque de abajo).
      await assertSucceeds(getDoc(doc(adminDemo(env), 'usuarios', UID_MESERO)));
    });

    it('ANÓNIMO no puede leer ningún perfil', async () => {
      await assertFails(getDoc(doc(anon(env), 'usuarios', YO)));
    });
  });

  // --- read de un perfil AUSENTE: el cortocircuito que salva el auto-registro
  //
  // AUDITORÍA 11-27 — la rama de read de `usuarios` SÍ desreferencia
  // `resource.data.restauranteId`, pero está a la DERECHA de dos `||`:
  //
  //   signedIn() && (request.auth.uid == uid || isSuper() || (admin && deref))
  //
  // El motor de rules CORTOCIRCUITA el `||`, así que quien lee su propio doc
  // —o el super_admin— nunca llega a la desreferencia y el doc ausente se lee
  // sin problema. De eso vive el auto-registro: `auth_controller.dart` lee
  // `usuarios/{uid}` ANTES de crearlo (línea 164), y ese doc no existe.
  //
  // Por eso `usuarios` NO se toca en 11-27: no necesita `resource == null`, y
  // añadírselo concedería a cualquier admin_restaurante un oráculo de "existe
  // este uid" que ningún flujo pide. Estos casos fijan el cortocircuito como
  // CONTRATO: si alguien reordena la disyunción y pone la desreferencia
  // primero, se ponen en rojo.

  describe('read de un perfil AUSENTE — el cortocircuito del || (11-27)', () => {
    it('el RECIÉN REGISTRADO puede leer su propio doc antes de que exista', async () => {
      // `request.auth.uid == uid` corta ANTES de tocar resource.data.
      await assertSucceeds(getDoc(doc(cliente(env, UID_NUEVO), 'usuarios', UID_NUEVO)));
    });

    it('el SUPER_ADMIN puede leer un uid inexistente: isSuper() corta antes', async () => {
      await assertSucceeds(getDoc(doc(superAdmin(env), 'usuarios', 'uid-fantasma')));
    });

    it('el ADMIN sigue DENEGADO sobre un uid inexistente — y así se queda', async () => {
      // Veredicto FIJADO, no descuido: la 3ª rama sí desreferencia y por tanto
      // deniega el doc ausente. Ningún flujo lo necesita (el panel lista el
      // equipo con una QUERY, no con gets por uid), y arreglarlo regalaría un
      // oráculo de existencia de cuentas. Se deja como está, por escrito.
      await assertFails(getDoc(doc(adminDemo(env), 'usuarios', 'uid-fantasma')));
    });

    it('OTRO cliente sigue DENEGADO sobre un uid inexistente', async () => {
      await assertFails(getDoc(doc(cliente(env, OTRO_UID), 'usuarios', 'uid-fantasma')));
    });

    it('el ANÓNIMO sigue DENEGADO sobre un uid inexistente', async () => {
      await assertFails(getDoc(doc(anon(env), 'usuarios', 'uid-fantasma')));
    });
  });

  // --- read del EQUIPO: la ampliación del plan 11-10 --------------------------
  //
  // Lo que se concede: `admin_restaurante` lee los docs de `usuarios` cuyo
  // `restauranteId` sea SU rid. Ni un permiso más. Los casos de abajo prueban
  // las DOS direcciones: que la lectura legítima funciona y que cada forma de
  // salirse (sin filtro, otro tenant, otro rol) queda denegada.
  //
  // ⚠️ Firestore evalúa las rules contra la CONSULTA, no contra los documentos
  // devueltos: una query sin el `where('restauranteId', '==', rid)` se deniega
  // ENTERA aunque todos los docs que devolvería fueran legibles. Ese es el modo
  // de fallo del bug del menú (11-03) y por eso el provider del panel replica
  // el filtro (`panel_admin/lib/features/equipo/equipo_provider.dart`).

  describe('read del equipo — acotado al rid del admin llamador (11-10)', () => {
    it('el ADMIN de demo LISTA su equipo con where restauranteId == demo: PERMITIDO', async () => {
      await assertSucceeds(getDocs(queryEquipo(adminDemo(env), RID)));
    });

    it('el ADMIN de demo SIN el where de rid: DENEGADO (la query es all-or-nothing)', async () => {
      await assertFails(getDocs(collection(adminDemo(env), 'usuarios')));
    });

    it('el ADMIN de demo con where restauranteId == "otro": DENEGADO (cruce de tenant)', async () => {
      await assertFails(getDocs(queryEquipo(adminDemo(env), RID_OTRO)));
    });

    it('el ADMIN de demo leyendo el doc suelto de un usuario de "otro": DENEGADO', async () => {
      await assertFails(getDoc(doc(adminDemo(env), 'usuarios', UID_ADMIN_OTRO)));
    });

    it('el ADMIN de OTRO listando el equipo de demo: DENEGADO (la dirección contraria)', async () => {
      await assertFails(getDocs(queryEquipo(adminOtro(env), RID)));
    });

    it('ACOTAMIENTO — el ADMIN de demo NO lee el perfil de un CLIENTE (restauranteId null)', async () => {
      // La ampliación es por `restauranteId == rid()`, no "todo el que pase por
      // el restaurante": los clientes tienen `restauranteId: null` y siguen
      // fuera. La lista de clientes del panel se pliega desde `pedidos`
      // (`clientes_provider.dart`), justamente porque esto está cerrado.
      await assertFails(getDoc(doc(adminDemo(env), 'usuarios', YO)));
    });

    it('el MESERO de demo listando el equipo de demo: DENEGADO (solo admin, no todo el staff)', async () => {
      await assertFails(getDocs(queryEquipo(mesero(env), RID)));
    });

    it('COCINA de demo listando el equipo de demo: DENEGADO', async () => {
      await assertFails(getDocs(queryEquipo(cocina(env), RID)));
    });

    it('el MESERO de demo leyendo el doc suelto de su compañero admin: DENEGADO', async () => {
      await assertFails(getDoc(doc(mesero(env), 'usuarios', UID_ADMIN)));
    });

    it('el MESERO sigue leyendo SU PROPIO perfil (no se rompió la rama de siempre)', async () => {
      await assertSucceeds(getDoc(doc(mesero(env), 'usuarios', UID_MESERO)));
    });

    it('un CLIENTE no puede listar usuarios ni replicando el filtro', async () => {
      await assertFails(getDocs(queryEquipo(cliente(env, YO), RID)));
    });

    it('ANÓNIMO no puede listar usuarios', async () => {
      await assertFails(getDocs(queryEquipo(anon(env), RID)));
    });

    it('el SUPER_ADMIN sigue listando usuarios SIN filtro (rama isSuper intacta)', async () => {
      await assertSucceeds(getDocs(collection(superAdmin(env), 'usuarios')));
    });
  });

  // --- delete -----------------------------------------------------------------

  describe('delete — prohibido siempre (allow delete: if false)', () => {
    it('el propio usuario no puede borrar su perfil', async () => {
      await assertFails(deleteDoc(doc(cliente(env, YO), 'usuarios', YO)));
    });

    it('ni el SUPER_ADMIN: borrar cuentas es trabajo del Admin SDK', async () => {
      await assertFails(deleteDoc(doc(superAdmin(env), 'usuarios', YO)));
    });
  });
});
