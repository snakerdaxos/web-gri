import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/configuracion/configuracion_screen.dart';
import 'package:gri_panel_admin/features/configuracion/restaurantes_admin_provider.dart';
import 'package:gri_panel_admin/features/menu/menu_provider.dart';

import 'helpers/firebase_fakes.dart';

/// Regresión de PRIMER ARRANQUE (11-02) — plataforma completamente vacía.
///
/// Por qué existe este archivo: los 84 tests del panel construyen su Firestore
/// con `buildFakeFirestoreConSeed()`, que SIEMPRE pre-siembra 3 restaurantes +
/// mesas + menú. El escenario del super_admin que entra a una plataforma recién
/// creada —sin un solo restaurante— era el único que nunca se había ejercitado
/// (ver `.planning/codebase/TESTING.md`).
///
/// Estos tests son DESCRIPTIVOS del contrato actual, no aspiracionales: donde
/// hoy la pantalla queda en blanco, se afirma únicamente que no deja excepción
/// pendiente y se deja un `// TODO(11-09)`.
void main() {
  group('base vacía — providers', () {
    test('restaurantesAdmin como super_admin devuelve lista vacía y NO lanza',
        () async {
      final db = await buildFakeFirestoreVacio();
      final container = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith(
          (ref) async => (role: 'super_admin', rid: null),
        ),
      ]);
      addTearDown(container.dispose);

      final lista = await container.read(restaurantesAdminProvider.future);

      expect(lista, isEmpty);
    });

    test('staffMenu con rid nulo emite lista vacía y NO lanza', () async {
      final db = await buildFakeFirestoreVacio();
      // super_admin sin selección → ridActivo == null (restaurante_provider.dart:44-51).
      final container = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith(
          (ref) async => (role: 'super_admin', rid: null),
        ),
      ]);
      addTearDown(container.dispose);
      container.listen(staffMenuProvider, (_, _) {});

      final menu = await container.read(staffMenuProvider.future);

      expect(menu, isEmpty);
    });
  });

  group('base vacía — pantallas', () {
    testWidgets(
        'ConfiguracionScreen (tab Restaurantes) como super_admin renderiza sin '
        'excepción pendiente', (tester) async {
      final db = await buildFakeFirestoreVacio();
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            claimsProvider.overrideWith(
              (ref) async => (role: 'super_admin', rid: null),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ConfiguracionScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // El tab existe para super_admin; el TabBarView es lazy → hay que abrirlo.
      expect(find.text('Restaurantes'), findsOneWidget);
      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Contrato con plataforma vacía: el contador dice 0 y —desde 11-05— el
      // tab GUÍA en vez de dejar una lista en blanco. El TODO(11-09) que había
      // aquí queda resuelto por 11-05 para esta pantalla concreta.
      expect(find.text('0 restaurantes en la plataforma'), findsOneWidget);
      expect(
        find.text('Aún no hay restaurantes en la plataforma'),
        findsOneWidget,
      );
      expect(find.text('Crear el primer restaurante'), findsOneWidget);
    });
  });
}
