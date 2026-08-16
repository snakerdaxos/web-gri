import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/menu/menu_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Tests de la gestión del menú sobre Firestore (MENU-01/02, 10-06):
/// stream vivo categorías+productos, creación de categoría (doc autoId),
/// toggle 'Agotado' → update quirúrgico `disponible: false` SOLO, y badge
/// 'Inactiva' para categoría inactiva.
///
/// Overrides sin red (patrón cola_test): firestoreProvider por fake con
/// seed, claimsProvider por rol/rid.

Widget _screen(FakeFirebaseFirestore db) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: MenuScreen())),
  );
}

/// Pone un flag directo en un doc de productos/categorías (setup).
Future<void> _setFlag(
  FakeFirebaseFirestore db,
  String coleccion,
  String nombre,
  String key,
  Object valor,
) async {
  final snap = await db
      .collection(coleccion)
      .where('nombre', isEqualTo: nombre)
      .get();
  await snap.docs.first.reference.update({key: valor});
}

void main() {
  testWidgets(
    '(a) renderiza categorías; expandida muestra productos con formatCOP y badge Agotado',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _setFlag(db, 'productos', 'Limonada de coco', 'disponible', false);

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(db));
      await tester.pumpAndSettle();

      // Las 2 categorías del seed colapsadas.
      expect(find.text('Platos fuertes'), findsOneWidget);
      expect(find.text('Bebidas'), findsOneWidget);

      // Expandir Platos fuertes → productos + precio int COP formateado.
      await tester.tap(find.text('Platos fuertes'));
      await tester.pumpAndSettle();
      expect(find.text('Bandeja paisa'), findsOneWidget);
      expect(find.text('Ajiaco santafereño'), findsOneWidget);
      expect(find.textContaining('28.000'), findsOneWidget);
      expect(find.textContaining('25.000'), findsOneWidget);
      expect(find.text('Nuevo producto'), findsOneWidget);

      // Expandir Bebidas → la lima agotada con badge (semántica visible).
      await tester.tap(find.text('Bebidas'));
      await tester.pumpAndSettle();
      expect(find.text('Limonada de coco'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Café con leche'), findsOneWidget);
      expect(find.text('Inactivo'), findsNothing);
    },
  );

  testWidgets(
    '(b) Nueva categoría → doc en Firestore + aparece en pantalla (stream vivo)',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nueva categoría'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'Postres');
      await tester.enterText(fields.at(1), '3');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Write: doc autoId con restauranteId del rid activo, nace activa.
      final snap = await db
          .collection('categorias')
          .where('nombre', isEqualTo: 'Postres')
          .get();
      expect(snap.size, 1);
      final data = snap.docs.first.data();
      expect(data['restauranteId'], 'demo');
      expect(data['orden'], 3);
      expect(data['activo'], true);

      // Confirmación + la categoría aparece SIN invalidate manual (stream).
      expect(find.text('Categoría "Postres" creada'), findsOneWidget);
      expect(find.text('Postres'), findsOneWidget);
    },
  );

  testWidgets(
    '(c) toggle Agotado ON → update disponible:false SOLO (nombre/precio intactos)',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Platos fuertes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bandeja paisa'));
      await tester.pumpAndSettle();

      // Switch 'Agotado' (SwitchListTile del dialog — NO el badge).
      final agotadoSwitch = find.widgetWithText(SwitchListTile, 'Agotado');
      expect(agotadoSwitch, findsOneWidget);
      await tester.tap(agotadoSwitch);
      await tester.pump();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Update quirúrgico: disponible false, resto del doc INTACTO.
      final snap = await db
          .collection('productos')
          .where('nombre', isEqualTo: 'Bandeja paisa')
          .get();
      final data = snap.docs.first.data();
      expect(data['disponible'], false);
      expect(data['nombre'], 'Bandeja paisa');
      expect(data['precio'], 28000);
      expect(data['activo'], true);
      expect(find.text('Producto actualizado'), findsOneWidget);
      // Badge visible en la fila tras el refresh del stream.
      expect(find.text('Agotado'), findsOneWidget);
    },
  );

  testWidgets('(d) badge Inactiva visible para la categoría inactiva', (
    tester,
  ) async {
    final db = await buildFakeFirestoreConSeed();
    await _setFlag(db, 'categorias', 'Bebidas', 'activo', false);

    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(db));
    await tester.pumpAndSettle();

    // 'Bebidas' (activo: false) muestra el badge SIN expandir.
    expect(find.text('Inactiva'), findsOneWidget);
    expect(find.text('Platos fuertes'), findsOneWidget);
  });
}
