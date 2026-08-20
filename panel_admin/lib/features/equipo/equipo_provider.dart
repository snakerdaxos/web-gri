import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../dashboard/restaurante_provider.dart' show ridActivoProvider;

part 'equipo_provider.g.dart';

/// Una persona del equipo del restaurante, tal y como la pinta `/equipo`.
/// Proyección mínima del doc espejo `usuarios/{uid}` que escribe la callable
/// `crearUsuarioStaff` (11-08): `{nombre, email, role, restauranteId}`.
///
/// `activo` lo escribe `cambiarEstadoStaff` (11-24). NO existe en las fichas
/// creadas antes de ese plan, así que su ausencia se lee como `true`: si se
/// leyera como `false`, todo el equipo ya existente aparecería de baja de
/// golpe y el panel mentiría sobre quién puede entrar.
typedef MiembroEquipo = ({
  String uid,
  String nombre,
  String email,
  String rol,
  bool activo,
});

/// Roles que gestionan personal. Espejo de `ROLES_LLAMADORES` de
/// `functions/src/auth-matrix.js` — SINCRONIZAR si aquella allow-list cambia.
const rolesQueGestionanEquipo = <String>['super_admin', 'admin_restaurante'];

/// El equipo del restaurante activo (BOOT-04).
///
/// ⚠️ EL `where('restauranteId', isEqualTo: rid)` ES OBLIGATORIO, NO UN FILTRO
/// DE CONVENIENCIA. Firestore evalúa las security rules contra la CONSULTA, no
/// contra los documentos devueltos: la rama que autoriza esta lectura es
/// `role() == 'admin_restaurante' && resource.data.restauranteId == rid()`
/// (`firestore.rules`, match /usuarios, AMPLIADO EN 11-10), así que sin
/// replicar el filtro la query se deniega ENTERA — no devuelve "menos
/// documentos", falla con `permission-denied`. Es exactamente el modo de fallo
/// del bug del menú del plan 11-03. Lo vigila además `npm run audit:indexes`
/// (tabla `PARIDAD_RULES_QUERY`, entrada `usuarios`).
///
/// El orden por nombre se hace EN CLIENTE a propósito: un `orderBy('nombre')`
/// junto al `where` de igualdad exigiría un índice compuesto nuevo, y el equipo
/// de un restaurante es una lista corta. Con eso `audit:indexes` sigue en 0
/// fallos.
///
/// `rid` efectivo: staff → su claim; `super_admin` → el restaurante elegido en
/// el selector del topbar. Todo eso ya lo resuelve [ridActivoProvider] (10-06);
/// aquí NO se inventa un mecanismo nuevo. Sin selección (super recién entrado)
/// devuelve `[]` y no lanza — patrón de `clientesProvider`.
///
/// Defense in depth (patrón `restaurantesAdminProvider`): si un `mesero` o
/// `cocina` llegara hasta aquí, lanza claro en vez de disparar una query que
/// las rules van a denegar igualmente. El gate REAL es la regla, no esto.
@riverpod
Future<List<MiembroEquipo>> equipo(Ref ref) async {
  // Riverpod 3: TODOS los `ref.watch` ANTES del primer `await` (lección 07-03).
  // Los dos futuros se piden aquí y se esperan abajo, en orden.
  final db = ref.watch(firestoreProvider);
  final claimsFuturo = ref.watch(claimsProvider.future);
  final ridFuturo = ref.watch(ridActivoProvider.future);

  final claims = await claimsFuturo;
  if (!rolesQueGestionanEquipo.contains(claims.role)) {
    throw StateError(
      'La gestión de equipo es solo para super_admin y admin_restaurante',
    );
  }

  final rid = await ridFuturo;
  if (rid == null) return const <MiembroEquipo>[];

  final snap = await db
      .collection('usuarios')
      .where('restauranteId', isEqualTo: rid)
      .get();

  final miembros = <MiembroEquipo>[
    for (final doc in snap.docs) _miembro(doc),
  ]..sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
  return miembros;
}

MiembroEquipo _miembro(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data();
  return (
    uid: doc.id,
    // El espejo siempre trae `nombre`/`email` (los escribe la callable), pero
    // un doc sembrado a mano podría no traerlos: la pantalla nunca debe
    // reventar por un dato de perfil.
    nombre: (d['nombre'] as String?)?.trim().isNotEmpty == true
        ? (d['nombre'] as String).trim()
        : 'Sin nombre',
    email: d['email'] as String? ?? '',
    rol: d['role'] as String? ?? '',
    // Por defecto ACTIVO: ver la nota de [MiembroEquipo]. Solo un `false`
    // explícito da de baja.
    activo: d['activo'] as bool? ?? true,
  );
}

/// uid de quien ha iniciado sesión, o `null` sin sesión.
///
/// Existe para que la fila del propio usuario no ofrezca la acción de
/// desactivar. Es una COSTURA: `FirebaseAuth.instance` no es instanciable en
/// `flutter test`, así que sin este provider el ocultamiento quedaría afirmado
/// por lectura de código en vez de verificado (misma razón que
/// `crearStaffCallableProvider`, 11-10).
///
/// ⚠️ Esto es UX, NO SEGURIDAD: la decisión real vive en `cambiarEstadoStaff`,
/// que rechaza la auto-baja con su propio mensaje y tiene caso e2e con token
/// real. Ocultar el botón solo evita ofrecer algo que el servidor va a
/// rechazar.
@Riverpod(keepAlive: true)
String? uidSesion(Ref ref) {
  // Rebuild en cada cambio de sesión, igual que `claimsProvider`.
  ref.watch(authStateChangesProvider);
  return ref.watch(firebaseAuthProvider).currentUser?.uid;
}

/// Etiqueta en español del rol, para la tabla y el desplegable.
String etiquetaRol(String rol) => switch (rol) {
      'super_admin' => 'Super Admin',
      'admin_restaurante' => 'Administrador',
      'mesero' => 'Mesero',
      'cocina' => 'Cocina',
      'cliente' => 'Cliente',
      _ => rol,
    };
