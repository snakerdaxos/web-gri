import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_list_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';

import 'helpers/firebase_fakes.dart';

/// Regresión de PRIMER ARRANQUE (11-02) — base de datos completamente vacía.
///
/// Por qué existe este archivo: los 91 tests de esta app construyen su
/// Firestore con `buildFakeFirestoreConSeed()`, que SIEMPRE pre-siembra
/// `restaurantes/demo` + mesas + categorías + productos. El escenario de una
/// base recién creada —el que el usuario reportó como roto— era literalmente
/// el único que nunca se había ejercitado (ver `.planning/codebase/TESTING.md`,
/// sección "Is there a test covering the empty-database / first-run
/// bootstrap scenario?" → "No").
///
/// Estos tests son DESCRIPTIVOS del contrato actual, no aspiracionales: si hoy
/// una pantalla queda en blanco, se afirma únicamente que no deja excepción
/// pendiente y se deja un `// TODO(11-09)` apuntando al plan de estados vacíos,
/// que endurecerá la aserción. Arreglar aquí la UI de estados vacíos está
/// PROHIBIDO por el plan (colisionaría con la ola de 11-09).
void main() {
  group('base vacía — providers', () {
    test('restaurantesList devuelve lista vacía y NO lanza', () async {
      final db = await buildFakeFirestoreVacio();
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final lista = await container.read(restaurantesListProvider.future);

      expect(lista, isEmpty);
    });

    test(
        'restauranteDetalle de un id inexistente lanza StateError controlado '
        '(contrato actual del provider)', () async {
      final db = await buildFakeFirestoreVacio();
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(restauranteDetalleProvider('lo-que-sea').future),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Restaurante no encontrado'),
          ),
        ),
      );
    });
  });

  group('base vacía — pantallas', () {
    testWidgets(
        'RestaurantesListScreen renderiza un estado vacío legible sin excepción '
        'pendiente', (tester) async {
      final db = await buildFakeFirestoreVacio();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [firestoreProvider.overrideWithValue(db)],
          child: const MaterialApp(home: RestaurantesListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // El primer arranque NO puede crashear ni dejar un error silencioso.
      expect(tester.takeException(), isNull);
      // Estado vacío ya presente hoy (restaurantes_list_screen.dart:32-40).
      expect(find.text('No hay restaurantes disponibles'), findsOneWidget);
      // Ni spinner colgado ni pantalla de error.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      // TODO(11-09): endurecer a un EmptyState con guía accionable
      // ("aún no hay restaurantes publicados / vuelve pronto"), no solo texto.
    });
  });
}
