import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/configuracion/configuracion_screen.dart';
import 'package:gri_panel_admin/features/configuracion/restaurante_form_dialog.dart';

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

  // ── 11-05: alta, estado vacío guiado y confirmación de desactivación ─────

  testWidgets(
    '(d) plataforma VACÍA: estado vacío guiado con CTA (no una lista en blanco)',
    (tester) async {
      final db = await buildFakeFirestoreVacio();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Aún no hay restaurantes en la plataforma'),
        findsOneWidget,
      );
      expect(find.text('Crea el primero para empezar a operar'), findsOneWidget);
      expect(find.text('Crear el primer restaurante'), findsOneWidget);
      // Ni un solo Switch: no hay nada que togglear.
      expect(find.byType(Switch), findsNothing);
    },
  );

  testWidgets(
    '(e) el CTA del estado vacío abre el diálogo de alta',
    (tester) async {
      final db = await buildFakeFirestoreVacio();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear el primer restaurante'));
      await tester.pumpAndSettle();

      expect(find.byType(RestauranteFormDialog), findsOneWidget);
    },
  );

  testWidgets(
    '(f) el botón "+ Nuevo restaurante" abre el diálogo también con lista llena',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      expect(find.text('+ Nuevo restaurante'), findsOneWidget);
      await tester.tap(find.text('+ Nuevo restaurante'));
      await tester.pumpAndSettle();

      expect(find.byType(RestauranteFormDialog), findsOneWidget);
    },
  );

  testWidgets(
    '(g) desactivar PIDE confirmación; cancelar no toca Firestore',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      // Switch 0 = GRI Norte (activo, orden alfabético Norte/Sur/Demo).
      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();

      expect(find.text('¿Desactivar GRI Norte?'), findsOneWidget);
      expect(
        find.textContaining('desaparece de la app de clientes'),
        findsOneWidget,
        reason: 'el radio de impacto debe estar explícito en la confirmación',
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      final doc = await db.doc('restaurantes/norte').get();
      expect(doc.data()!['activo'], true, reason: 'cancelar no escribe nada');
      expect(find.textContaining('Restaurante desactivado'), findsNothing);
    },
  );

  testWidgets(
    '(h) confirmar la desactivación escribe activo:false',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();

      final doc = await db.doc('restaurantes/norte').get();
      final data = doc.data()!;
      expect(data['activo'], false);
      // Update quirúrgico: el resto del doc intacto (rules hasOnly(['activo'])).
      expect(data['nombre'], 'GRI Norte');
      expect(
        find.textContaining(
          'Restaurante desactivado — desaparece de la app de clientes',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '(i) ACTIVAR no pide confirmación (solo el sentido destructivo la pide)',
    (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(tester, db);

      await tester.tap(find.text('Restaurantes'));
      await tester.pumpAndSettle();

      // Switch 1 = GRI Sur (inactivo en el seed).
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      // Ningún AlertDialog de confirmación por el camino: el write ya ocurrió.
      expect(find.text('Desactivar'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      final doc = await db.doc('restaurantes/sur').get();
      expect(doc.data()!['activo'], true);
      expect(find.text('Restaurante reactivado'), findsOneWidget);
    },
  );
}
