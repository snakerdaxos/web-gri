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
/// Nota de índices: el `orderBy('orden')` de las categorías se hace
/// client-side — el índice compuesto `categorias(restauranteId, orden)` NO
/// existe en 10-01 y el where simple usa índice de campo único (el N por
/// restaurante es chico; comportamiento idéntico).
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
      .get();
  final prodsSnap = await db
      .collection('productos')
      .where('restauranteId', isEqualTo: id)
      .get();

  // Productos agrupados por categoría (solo activos — disponible es
  // estado de stock que la UI deshabilita, activo es visibilidad de menú).
  final porCategoria = <String, List<Producto>>{};
  for (final p in prodsSnap.docs) {
    final producto = Producto.fromDoc(p);
    if (!producto.activo) continue;
    porCategoria
        .putIfAbsent(producto.categoriaId, () => <Producto>[])
        .add(producto);
  }

  final categorias = <Categoria>[
    for (final c in catsSnap.docs) Categoria.fromDoc(c),
  ]..retainWhere((c) => c.activo);
  categorias.sort((a, b) => a.orden.compareTo(b.orden));

  return RestauranteDetalle.fromDoc(
    rSnap,
    categorias: [
      for (final c in categorias)
        c.copyWith(productos: porCategoria[c.id] ?? const <Producto>[]),
    ],
  );
}
