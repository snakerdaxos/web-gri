import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/restaurantes/restaurante_detalle_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_list_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';

import '../helpers/firebase_fakes.dart';

/// Tests de discover sobre Firestore (MIGRA-01): lista pública (solo
/// activos) + detalle con menú agrupado — TODO vía FakeFirebaseFirestore
/// sembrado (override de firestoreProvider, sin red ni dio).

Widget _wrap(Widget child, FakeFirebaseFirestore db) => ProviderScope(
      overrides: [firestoreProvider.overrideWithValue(db)],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('lista muestra SOLO restaurantes activos (Firestore)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    // Inactivo: NO debe aparecer en la lista pública.
    await db.doc('restaurantes/oculto').set({
      'nombre': 'El Oculto',
      'descripcion': 'Cerrado por vacaciones',
      'tipoCocina': 'Fusión',
      'direccion': 'Calle 0',
      'activo': false,
      'califProm': 0.0,
      'califCount': 0,
    });

    await tester.pumpWidget(_wrap(const RestaurantesListScreen(), db));
    await tester.pumpAndSettle();

    expect(find.text('Restaurante Demo GRI'), findsOneWidget);
    expect(find.text('El Oculto'), findsNothing);
    // califCount 0 en el seed → rating "—" (una por card).
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('rating real del doc: "4.8 (245)" con califCount > 0',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('restaurantes/demo').update({
      'califProm': 4.8,
      'califCount': 245,
    });

    await tester.pumpWidget(_wrap(const RestaurantesListScreen(), db));
    await tester.pumpAndSettle();

    expect(find.text('4.8 (245)'), findsOneWidget);
  });

  testWidgets('detalle agrupa el menú por categoría en orden (Firestore)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();

    // ── Nivel provider: agrupación y orden exactos ─────────────────────
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final detalle = await container.read(restauranteDetalleProvider('demo').future);

    expect(detalle.id, 'demo');
    expect(detalle.categorias.map((c) => c.nombre).toList(),
        ['Platos fuertes', 'Bebidas'], reason: 'orden por `orden` (1→2)');
    expect(detalle.categorias[0].productos, hasLength(2));
    expect(detalle.categorias[1].productos, hasLength(2));
    // Precios int COP end-to-end (formatCOP los formatea en la UI).
    expect(detalle.categorias[0].productos.map((p) => p.precio).toList(),
        containsAll([28000, 25000]));

    // ── Nivel widget: render con la primera categoría expandida ───────
    await tester.pumpWidget(
      _wrap(const RestauranteDetalleScreen(restauranteId: 'demo'), db),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platos fuertes'), findsOneWidget);
    expect(find.text('Bandeja paisa'), findsOneWidget);
    // Precio int COP formateado: "$ 28.000".
    expect(find.textContaining('28.000'), findsOneWidget);

    // Botón al wizard con el id String.
    expect(find.text('Reservar una mesa'), findsOneWidget);
  });

  testWidgets('estado loading muestra spinner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [restaurantesListProvider.overrideWithValue(const AsyncLoading())],
        child: const MaterialApp(home: RestaurantesListScreen()),
      ),
    );
    // Sin pumpAndSettle: AsyncLoading infinito nunca se settle.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('estado error muestra mensaje + Reintentar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantesListProvider
              .overrideWithValue(AsyncError('boom', StackTrace.current)),
        ],
        child: const MaterialApp(home: RestaurantesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  // ══════════════════════════════════════════════════════════════════════
  // 11-03 — Filtrado del menú público (categorías inactivas, productos
  // inactivos y productos AGOTADOS no llegan a la UI).
  //
  // ⚠️ ALCANCE DE ESTE TEST: `fake_cloud_firestore` NO tiene motor de
  // security rules, así que aquí se verifica el FILTRADO, jamás la
  // AUTORIZACIÓN. Que la query lleve los `where` que `firestore.rules`
  // exige lo prueba la suite de emulador `scripts/test/rules/`
  // (categorias.test.mjs / productos.test.mjs). Los dos niveles son
  // necesarios: sin el fake, nadie comprueba qué ve el usuario; sin el
  // emulador, nadie comprueba que la petición no se rechace entera.
  // ══════════════════════════════════════════════════════════════════════

  /// Añade al seed una categoría inactiva, un producto inactivo y un
  /// producto agotado (`disponible: false`) — el escenario que hoy rompe
  /// el menú del cliente.
  Future<String> sembrarMenuSucio(FakeFirebaseFirestore db) async {
    final platos = (await db
            .collection('categorias')
            .where('nombre', isEqualTo: 'Platos fuertes')
            .get())
        .docs
        .first
        .id;

    final inactiva = await db.collection('categorias').add({
      'restauranteId': 'demo',
      'nombre': 'Temporada navideña',
      'orden': 3,
      'activo': false,
    });
    // Producto de la categoría inactiva: no debe llegar por ninguna vía.
    await db.collection('productos').add({
      'restauranteId': 'demo',
      'categoriaId': inactiva.id,
      'nombre': 'Natilla',
      'descripcion': 'Solo en diciembre',
      'precio': 12000,
      'imagenUrl': '',
      'disponible': true,
      'activo': true,
    });
    // Producto retirado de carta.
    await db.collection('productos').add({
      'restauranteId': 'demo',
      'categoriaId': platos,
      'nombre': 'Plato retirado',
      'descripcion': 'Ya no se ofrece',
      'precio': 30000,
      'imagenUrl': '',
      'disponible': true,
      'activo': false,
    });
    // Producto AGOTADO: `activo` sigue en true, `disponible` en false.
    await db.collection('productos').add({
      'restauranteId': 'demo',
      'categoriaId': platos,
      'nombre': 'Sancocho agotado',
      'descripcion': 'Se acabó hoy',
      'precio': 26000,
      'imagenUrl': '',
      'disponible': false,
      'activo': true,
    });
    return platos;
  }

  test('detalle: categoría inactiva, producto inactivo y producto AGOTADO no '
      'llegan al menú del cliente', () async {
    final db = await buildFakeFirestoreConSeed();
    await sembrarMenuSucio(db);

    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final detalle =
        await container.read(restauranteDetalleProvider('demo').future);

    // Solo las 2 categorías activas del seed; la inactiva desaparece.
    expect(detalle.categorias.map((c) => c.nombre).toList(),
        ['Platos fuertes', 'Bebidas'],
        reason: 'la categoría inactiva no debe aparecer, y el orden por '
            '`orden` (1→2) se mantiene client-side');

    final nombres = [
      for (final c in detalle.categorias)
        for (final p in c.productos) p.nombre,
    ];
    expect(nombres, containsAll(['Bandeja paisa', 'Ajiaco santafereño']),
        reason: 'los productos disponibles del seed siguen ahí');
    expect(nombres, isNot(contains('Plato retirado')),
        reason: 'producto inactivo');
    expect(nombres, isNot(contains('Sancocho agotado')),
        reason: 'producto AGOTADO (disponible: false) — cambio de '
            'comportamiento de 11-03: antes el filtrado client-side solo '
            'miraba `activo` y un agotado sí llegaba a la UI');
    expect(nombres, isNot(contains('Natilla')),
        reason: 'producto de una categoría inactiva');
    // El seed tiene 4 productos disponibles y ninguno más debe colarse.
    expect(nombres, hasLength(4));
  });

  test('detalle: el orden de las categorías por `orden` se mantiene aunque '
      'lleguen desordenadas de Firestore', () async {
    final db = await buildFakeFirestoreConSeed();
    // Categoría activa con `orden` 0: debe quedar PRIMERA aunque se haya
    // insertado la última (el sort client-side es la única garantía —
    // decisión explícita de 11-03 para no introducir el índice
    // `categorias(restauranteId, activo, orden)`).
    await db.collection('categorias').add({
      'restauranteId': 'demo',
      'nombre': 'Entradas',
      'orden': 0,
      'activo': true,
    });

    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final detalle =
        await container.read(restauranteDetalleProvider('demo').future);

    expect(detalle.categorias.map((c) => c.nombre).toList(),
        ['Entradas', 'Platos fuertes', 'Bebidas']);
  });
}
