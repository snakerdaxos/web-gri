import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/categoria_staff.dart';
import '../../models/producto_staff.dart';
import '../dashboard/restaurante_provider.dart' show ridActivoProvider;

part 'menu_provider.g.dart';

/// Menú completo del tenant EN VIVO (MENU-01/02): categorías con productos
/// anidados — `categorias where restauranteId == rid orderBy orden` +
/// `productos where restauranteId == rid`, combinados con combineLatest
/// (cada alta/edición/toggle re-emite: los cambios se reflejan en vivo en
/// el panel Y en el discover del cliente, que escucha la misma colección
/// con los filtros públicos de rules).
///
/// El staff ve TODO (inactivos y agotados con sus flags — NUNCA filtrar
/// client-side; la query pública del cliente es otra, con `activo`).
///
/// rid null (super_admin sin restaurante seleccionado) → `[]` (patrón
/// mesasProvider). Watches ANTES del primer await (lección 07-03).
@riverpod
Stream<List<CategoriaStaff>> staffMenu(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield const <CategoriaStaff>[];
    return;
  }

  final cats$ = db
      // El staff lee por la rama menuStaffOf() de la regla, no por la
      // publica: DEBE ver las categorias inactivas para poder reactivarlas.
      // AUDIT-STAFF: lectura de staff, exenta de la paridad rules-query.
      .collection('categorias')
      .where('restauranteId', isEqualTo: rid)
      .orderBy('orden')
      .snapshots();
  final prods$ = db
      // Idem: el staff gestiona inactivos y agotados; filtrar por
      // activo/disponible aqui le ocultaria justo lo que debe editar.
      // AUDIT-STAFF: lectura de staff, exenta de la paridad rules-query.
      .collection('productos')
      .where('restauranteId', isEqualTo: rid)
      .snapshots();

  yield* _combineLatest2(cats$, prods$).map((v) => _anidar(v.$1, v.$2));
}

/// Anida los productos en su categoría (orden de llegada del snapshot).
List<CategoriaStaff> _anidar(
  QuerySnapshot<Map<String, dynamic>> cats,
  QuerySnapshot<Map<String, dynamic>> prods,
) {
  final porCategoria = <String, List<ProductoStaff>>{};
  for (final doc in prods.docs) {
    final p = ProductoStaff.fromDoc(doc);
    porCategoria.putIfAbsent(p.categoriaId, () => []).add(p);
  }
  return [
    for (final doc in cats.docs)
      CategoriaStaff.fromDoc(doc).copyWith(
        productos: porCategoria[doc.id] ?? const <ProductoStaff>[],
      ),
  ];
}

/// combineLatest de 2 streams sin rxdart (patrón _combineLatest3 de
/// stats_provider): emite apenas AMBOS tienen su primer valor y re-emite
/// con los ÚLTIMOS ante cualquier cambio posterior. `sync: true` para que
/// la re-emisión entregue EN el evento del snapshot (un read posterior a
/// la escritura ya ve el valor nuevo).
Stream<(A, B)> _combineLatest2<A, B>(Stream<A> a, Stream<B> b) {
  late StreamController<(A, B)> controller;
  A? ultimoA;
  B? ultimoB;
  var cancelado = false;
  final subs = <StreamSubscription<dynamic>>[];

  void emitir() {
    if (cancelado) return;
    if (ultimoA != null && ultimoB != null) {
      controller.add((ultimoA as A, ultimoB as B));
    }
  }

  controller = StreamController<(A, B)>(
    sync: true,
    onListen: () {
      subs.add(
        a.listen((v) {
          ultimoA = v;
          emitir();
        }, onError: controller.addError),
      );
      subs.add(
        b.listen((v) {
          ultimoB = v;
          emitir();
        }, onError: controller.addError),
      );
    },
    onCancel: () async {
      cancelado = true;
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );
  return controller.stream;
}

// ── CRUD (rules: menuStaffOf — super o admin_restaurante del rid) ──────────

/// Crea una categoría (`doc()` autoId — el menú no requiere determinismo).
Future<void> crearCategoria(
  FirebaseFirestore db, {
  required String rid,
  required String nombre,
  required int orden,
}) {
  return db.collection('categorias').add(<String, dynamic>{
    'restauranteId': rid,
    'nombre': nombre,
    'orden': orden,
    'activo': true,
  });
}

/// Update quirúrgico de la categoría — SOLO los campos que cambian
/// (nombre/orden/activo; restauranteId jamás se toca: rules lo exigen
/// igual en el doc entrante).
Future<void> actualizarCategoria(
  FirebaseFirestore db, {
  required CategoriaStaff categoria,
  String? nombre,
  int? orden,
  bool? activo,
}) {
  final changes = <String, dynamic>{};
  if (nombre != null && nombre != categoria.nombre) changes['nombre'] = nombre;
  if (orden != null && orden != categoria.orden) changes['orden'] = orden;
  if (activo != null && activo != categoria.activo) changes['activo'] = activo;
  if (changes.isEmpty) return Future.value();
  return db.doc('categorias/${categoria.id}').update(changes);
}

/// Crea un producto en la categoría indicada (autoId, defaults true para
/// disponible/activo — el alta nace visible).
Future<void> crearProducto(
  FirebaseFirestore db, {
  required String rid,
  required String categoriaId,
  required String nombre,
  String? descripcion,
  required int precio,
  String? imagenUrl,
}) {
  return db.collection('productos').add(<String, dynamic>{
    'restauranteId': rid,
    'categoriaId': categoriaId,
    'nombre': nombre,
    'descripcion': descripcion ?? '',
    'precio': precio, // int COP — sin floats (research anti-pattern)
    'imagenUrl': imagenUrl ?? '',
    'disponible': true,
    'activo': true,
  });
}

/// Update quirúrgico del producto — SOLO los campos que cambian
/// (nombre/descripcion/precio/imagenUrl/disponible/activo).
Future<void> actualizarProducto(
  FirebaseFirestore db, {
  required ProductoStaff producto,
  String? nombre,
  String? descripcion,
  int? precio,
  String? imagenUrl,
  bool? disponible,
  bool? activo,
}) {
  final changes = <String, dynamic>{};
  if (nombre != null && nombre != producto.nombre) changes['nombre'] = nombre;
  // '' limpia el campo; null-aware omitiría la clave (patrón era REST).
  if (descripcion != null && descripcion != (producto.descripcion ?? '')) {
    changes['descripcion'] = descripcion;
  }
  if (precio != null && precio != producto.precio) changes['precio'] = precio;
  if (imagenUrl != null && imagenUrl != (producto.imagenUrl ?? '')) {
    changes['imagenUrl'] = imagenUrl;
  }
  if (disponible != null && disponible != producto.disponible) {
    changes['disponible'] = disponible;
  }
  if (activo != null && activo != producto.activo) changes['activo'] = activo;
  if (changes.isEmpty) return Future.value();
  return db.doc('productos/${producto.id}').update(changes);
}
