import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/restaurante.dart';
import 'slug.dart';

part 'restaurantes_admin_provider.g.dart';

/// Lista COMPLETA de restaurantes — activos E inactivos — para el tab
/// 'Restaurantes' del super_admin (PLAT-05): `get()` de TODOS los docs de
/// `restaurantes` (super lee todo por rules — un `where activo == true`
/// escondería los inactivos y no se podrían re-activar).
///
/// Defense in depth (patrón restaurantesListProvider): si un staff lo
/// llega a leer, lanza claro — las rules igualmente le denegarían.
/// El toggle de la UI refresca invalidando aquí.
@riverpod
Future<List<Restaurante>> restaurantesAdmin(Ref ref) async {
  // Watches ANTES del primer await (lección 07-03).
  final db = ref.watch(firestoreProvider);
  final claims = await ref.watch(claimsProvider.future);

  if (claims.role != 'super_admin') {
    throw StateError('restaurantesAdmin es solo para super_admin');
  }

  final snap = await db.collection('restaurantes').get();
  final lista = [for (final doc in snap.docs) Restaurante.fromDoc(doc)]
    ..sort((a, b) => a.nombre.compareTo(b.nombre));
  return lista;
}

/// Error de negocio del alta de restaurante, con un mensaje YA redactado para
/// mostrárselo al operador (patrón [MesaDuplicadaException] de mesas_crud).
class RestauranteException implements Exception {
  const RestauranteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Crea `restaurantes/{slug}` — el alta de un restaurante en la plataforma
/// (BOOT-02). Solo el `super_admin` la ejecuta: `allow create: if isSuper()`
/// en `firestore.rules:88`. El gate de la UI es UX; la autorización real es
/// la regla, probada en `scripts/test/rules/restaurantes.test.mjs`.
///
/// Dos validaciones ANTES de escribir, y el orden importa:
///
/// 1. **`slugEsValido`** — el doc ID es el `rid`, del que deriva el doc ID de
///    cada mesa (`GRI-MESA-{rid}-{NNN}`) y por tanto el contenido del QR
///    impreso. Un rid con tildes o mayúsculas deja las mesas
///    PERMANENTEMENTE inescaneables (ver `slug.dart`). No hay vuelta atrás:
///    el doc ID no se puede renombrar.
///
/// 2. **Existencia previa** — Firestore evalúa un `.set()` sobre un doc que YA
///    existe como un **update**, y la regla del super solo permite cambiar
///    `activo` (`hasOnly(['activo'])`). Sin este check, dar de alta un
///    identificador repetido no daría "ese identificador ya está en uso" sino
///    un `permission-denied` incomprensible — y peor: si algún día la regla se
///    relajara, pisaría en silencio el restaurante de otro. La lectura de
///    `restaurantes` es pública, así que el check cuesta un `get()`.
///
/// Nota de concurrencia: entre el `get()` y el `set()` cabe una carrera
/// teórica (dos super_admin creando el mismo slug a la vez). No se usa
/// transacción porque las rules la rechazarían por el mismo motivo del punto 2
/// —el segundo escritor haría un update no permitido— y el resultado sería el
/// mismo: uno de los dos falla. La carrera no puede corromper datos, solo
/// producir un mensaje de error menos bonito.
Future<void> crearRestaurante(
  FirebaseFirestore db, {
  required String slug,
  required String nombre,
  required String descripcion,
  required String tipoCocina,
  required String direccion,
}) async {
  if (!slugEsValido(slug)) {
    throw RestauranteException(
      'El identificador "$slug" no es válido: usa solo minúsculas, números y '
      'guiones (máximo 40 caracteres).',
    );
  }

  final ref = db.doc('restaurantes/$slug');
  final existente = await ref.get();
  if (existente.exists) {
    throw RestauranteException(
      'Ya existe un restaurante con el identificador "$slug".',
    );
  }

  await ref.set(<String, dynamic>{
    'nombre': nombre,
    'descripcion': descripcion,
    'tipoCocina': tipoCocina,
    'direccion': direccion,
    'activo': true,
    'califProm': 0.0,
    'califCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Toggle de `activo` — update que toca SOLO esa key (rules del super:
/// `diff hasOnly(['activo'])` — ni nombre ni calificaciones tocables
/// desde el panel; threat model 10-06).
Future<void> toggleRestauranteActivo(
  FirebaseFirestore db, {
  required String slug,
  required bool valor,
}) {
  return db.doc('restaurantes/$slug').update(<String, dynamic>{
    'activo': valor,
  });
}
