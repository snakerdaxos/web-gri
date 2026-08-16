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
}
