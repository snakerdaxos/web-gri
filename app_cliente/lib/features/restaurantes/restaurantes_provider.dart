import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/categoria.dart';
import '../../models/producto.dart';
import '../../models/restaurante.dart';
import '../../models/restaurante_detalle.dart';

part 'restaurantes_provider.g.dart';

/// Lista pública de restaurantes activos — Firestore (MIGRA-01).
///
/// `collection('restaurantes').where('activo', isEqualTo: true)` +
/// [Restaurante.fromDoc]; orden estable por nombre (el slug ya no es un
/// secuencia). SIN capa HTTP propia — el override de `firestoreProvider`
/// en tests corta toda la feature del backend real.
@riverpod
Future<List<Restaurante>> restaurantesList(Ref ref) async {
  final db = ref.watch(firestoreProvider);
  final snap = await db
      .collection('restaurantes')
      .where('activo', isEqualTo: true)
      .get();
  final restaurantes = [for (final d in snap.docs) Restaurante.fromDoc(d)]
    ..sort((a, b) => a.nombre.compareTo(b.nombre));
  return restaurantes;
}

/// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
/// doc `restaurantes/{id}` + categorías + productos del restaurante,
/// agrupados por `categoriaId` (colección plana, research 10).
///
/// ⚠️ POR QUÉ LOS FILTROS SON SERVER-SIDE (11-03 — NO "optimizar" quitándolos):
/// la razón NO es rendimiento, es AUTORIZACIÓN. Firestore evalúa las security
/// rules contra la CONSULTA, nunca contra los documentos devueltos: si la query
/// pudiera alcanzar un solo doc que la regla no permite, se rechaza la petición
/// ENTERA con `permission-denied`. Filtrar client-side después de traer los
/// documentos no sirve de nada, porque nunca llegan.
///
/// Las reglas vigentes son (`firestore.rules`, matches /categorias y
/// /productos):
///
///     categorias → activo == true            || menuStaffOf(restauranteId)
///     productos  → activo == true
///                  && disponible == true     || menuStaffOf(restauranteId)
///
/// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
/// DEBE llevar `where('X', …)`**. De ahí que `productos` lleve DOS filtros:
/// replicar la regla a medias (solo `activo`) también deniega la query.
/// Cobertura: `scripts/test/rules/categorias.test.mjs` y `productos.test.mjs`
/// lo afirman contra el emulador con las rules reales.
///
/// Nota de índices: el `orderBy('orden')` de las categorías se sigue haciendo
/// client-side, y es una decisión deliberada de 11-03 — hacerlo server-side
/// obligaría al índice compuesto `categorias(restauranteId, activo, orden)`.
/// El N de categorías por restaurante es pequeño y evitar un índice extra
/// elimina un punto de fallo más: los índices tardan minutos en construirse y
/// el emulador de Firestore ni siquiera los valida, así que un índice que falte
/// solo se descubre en producción. Los `where` de igualdad de arriba se
/// resuelven con los índices automáticos de campo único: no requieren
/// compuesto.
@riverpod
Future<RestauranteDetalle> restauranteDetalle(Ref ref, String id) async {
  final db = ref.watch(firestoreProvider);

  final rSnap = await db.doc('restaurantes/$id').get();
  if (!rSnap.exists) {
    throw StateError('Restaurante no encontrado');
  }

  final catsSnap = await db
      .collection('categorias')
      .where('restauranteId', isEqualTo: id)
      .where('activo', isEqualTo: true)
      .get();
  final prodsSnap = await db
      .collection('productos')
      .where('restauranteId', isEqualTo: id)
      .where('activo', isEqualTo: true)
      .where('disponible', isEqualTo: true)
      .get();

  // Productos agrupados por categoría. Sin filtrado client-side: los `where`
  // de arriba ya garantizan activo == true && disponible == true, y repetirlo
  // aquí sugeriría —falsamente— que el filtro server-side es opcional.
  final porCategoria = <String, List<Producto>>{};
  for (final p in prodsSnap.docs) {
    final producto = Producto.fromDoc(p);
    porCategoria
        .putIfAbsent(producto.categoriaId, () => <Producto>[])
        .add(producto);
  }

  final categorias = <Categoria>[
    for (final c in catsSnap.docs) Categoria.fromDoc(c),
  ];
  categorias.sort((a, b) => a.orden.compareTo(b.orden));

  return RestauranteDetalle.fromDoc(
    rSnap,
    categorias: [
      for (final c in categorias)
        c.copyWith(productos: porCategoria[c.id] ?? const <Producto>[]),
    ],
  );
}
