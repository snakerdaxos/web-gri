import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/configuracion/configuracion_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Tests del tab 'Restaurantes' de /configuracion sobre Firestore (PLAT-05,
/// 10-06): super_admin ve la lista COMPLETA (activos E inactivos — get() de
/// todos para poder re-activar), el toggle persiste SOLO la key `activo`
/// (rules hasOnly(['activo'])) y el tab AUSENTE para staff.

Widget _screen(
  FakeFirebaseFirestore db, {
  String role = 'super_admin',
  String? rid,
}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith((ref) async => (role: role, rid: rid)),
    ],
    child: const MaterialApp(home: Scaffold(body: ConfiguracionScreen())),
  );
}

Future<void> _pump(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  String role = 'super_admin',
  String? rid,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_screen(db, role: role, rid: rid));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '(a) super_admin: tab Restaurantes con los 3 del seed (sur inactivo OFF)',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db);

      // TabBar: los 3 tabs existen para super_admin.
      expect(find.text('Menú'), findsOneWidget);
      expect(find.text('Restaurante'), findsOneWidget);
      expect(find.text('Restaurantes'), findsOneWidget);

      // Navegar al tab Restaurantes (TabBarView es lazy).
      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      // Los 3 restaurantes del seed (orden alfabético) con su estado.
      expect(find.textContaining('Restaurante Demo GRI'), findsOneWidget);
      expect(find.textContaining('GRI Norte'), findsOneWidget);
      expect(find.textContaining('GRI Sur'), findsOneWidget);
      expect(find.text('Activo'), findsNWidgets(2));
      expect(find.text('Inactivo'), findsOneWidget);
      // Switch OFF en el inactivo (sur — orden alfabético: Norte, Sur, Demo).
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));
      expect(tester.widget<Switch>(switches.at(0)).value, isTrue); // Norte
      expect(tester.widget<Switch>(switches.at(1)).value, isFalse); // Sur
      expect(tester.widget<Switch>(switches.at(2)).value, isTrue); // Demo
    },
  );

  testWidgets(
    '(b) toggle del inactivo → persiste SOLO activo (resto del doc intacto)',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      // Encender el switch OFF (GRI Sur — 2º por orden alfabético).
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      // Update quirúrgico: activo true, keys de negocio intactas.
      final doc = await db.doc('restaurantes/sur').get();
      final data = doc.data()!;
      expect(data['activo'], true);
      expect(data['nombre'], 'GRI Sur (inactivo)');
      expect(data['tipoCocina'], 'Colombiana');
      expect(data['direccion'], 'Cra. 27 #10-20, Bogotá');

      expect(find.text('Restaurante reactivado'), findsOneWidget);
    },
  );

  testWidgets(
    '(c) staff: tab Restaurantes AUSENTE; ficha del propio tenant carga',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db, role: 'admin_restaurante', rid: 'demo');

      expect(find.text('Restaurantes'), findsNothing);
      expect(find.text('Menú'), findsOneWidget);
      expect(find.text('Restaurante'), findsOneWidget);

      // Tab Restaurante (ficha del stream del doc del tenant).
      await tester.tap(find.text('Restaurante'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Restaurante Demo GRI'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
    },
  );
}
