import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_list_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/shared/empty_state.dart';

import 'helpers/firebase_fakes.dart';

/// Regresión de PRIMER ARRANQUE (11-02) — base de datos completamente vacía.
///
/// Por qué existe este archivo: los 91 tests de esta app construían su
/// Firestore con `buildFakeFirestoreConSeed()`, que SIEMPRE pre-siembra
/// `restaurantes/demo` + mesas + categorías + productos. El escenario de una
/// base recién creada —el que el usuario reportó como roto— era literalmente
/// el único que nunca se había ejercitado (ver `.planning/codebase/TESTING.md`,
/// sección "Is there a test covering the empty-database / first-run
/// bootstrap scenario?" → "No").
///
/// 11-09 ENDURECIÓ este archivo. En 11-02 la aserción de pantalla era
/// DESCRIPTIVA del contrato de entonces ("no deja excepción pendiente" + el
/// texto gris suelto) y llevaba un `// TODO(11-09)` apuntando aquí. Ese TODO
/// queda resuelto: la lista vacía ya no es un `Text` mudo sino un [EmptyState]
/// con titular, guía y una acción, y el test lo AFIRMA. La cobertura sube; no
/// se relajó ninguna aserción previa (`No hay restaurantes disponibles`,
/// ausencia de spinner y ausencia de `Reintentar` siguen exigiéndose igual).
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
        'RestaurantesListScreen renderiza un estado vacío GUIADO sin excepción '
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

      // ── Aserciones de 11-02, intactas ────────────────────────────────────
      expect(find.text('No hay restaurantes disponibles'), findsOneWidget);
      // Ni spinner colgado ni pantalla de error.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // `Reintentar` es el botón de la rama de ERROR (_ErrorView). Que no
      // aparezca aquí distingue "no hay datos" de "no pude leerlos", y sigue
      // siendo cierto porque la acción del estado vacío se llama distinto.
      expect(find.text('Reintentar'), findsNothing);

      // ── Endurecimiento de 11-09: el TODO resuelto ────────────────────────
      expect(find.byType(EmptyState), findsOneWidget);
      expect(
        find.text(
          'Aún no hay restaurantes publicados en GRI. '
          'Vuelve a intentarlo en un momento.',
        ),
        findsOneWidget,
        reason: 'el estado vacío debe explicar POR QUÉ está vacío, no solo '
            'constatar que lo está',
      );
      expect(find.widgetWithText(ElevatedButton, 'Actualizar'), findsOneWidget);
    });

    testWidgets(
        'la acción del estado vacío re-consulta y NO rompe la pantalla',
        (tester) async {
      final db = await buildFakeFirestoreVacio();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [firestoreProvider.overrideWithValue(db)],
          child: const MaterialApp(home: RestaurantesListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Actualizar'));
      await tester.pumpAndSettle();

      // Sigue vacía (la base lo está) pero la pantalla sobrevive al invalidate.
      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No hay restaurantes disponibles'), findsOneWidget);
    });
  });
}
