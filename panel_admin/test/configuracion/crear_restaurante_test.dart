import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/configuracion/restaurante_form_dialog.dart';
import 'package:gri_panel_admin/features/configuracion/restaurantes_admin_provider.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';

import '../helpers/firebase_fakes.dart';

/// Alta de restaurante (11-05, Tarea 2) — la acción que saca a la plataforma
/// del callejón sin salida de la base vacía.
///
/// Lo que estos tests NO prueban: la AUTORIZACIÓN. `fake_cloud_firestore` no
/// tiene motor de rules (decisión 11-04), así que aquí un `admin_restaurante`
/// también podría escribir `restaurantes/x`. Que solo el super pueda crear lo
/// prueba `scripts/test/rules/restaurantes.test.mjs` contra el emulador.

/// Lee el texto REAL del campo de identificador (el controller), no lo que
/// haya pintado alrededor: el caso del slug vacío hay que afirmarlo sobre el
/// contenido del campo, y `find.text('')` no sirve para eso.
String _textoDelCampo(WidgetTester tester, Key key) {
  return tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;
}

/// Abre el diálogo como lo abre la pantalla real (showDialog sobre una ruta),
/// para que el `Navigator.pop()` del éxito tenga a dónde volver.
Future<void> _abrirDialogo(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: ctx,
                builder: (_) => const RestauranteFormDialog(),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

ProviderContainer _container(FakeFirebaseFirestore db) {
  final c = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    claimsProvider.overrideWith((ref) async => (role: 'super_admin', rid: null)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('crearRestaurante (unidad, base vacía)', () {
    test('escribe restaurantes/{slug} con la forma exacta del contrato',
        () async {
      final db = await buildFakeFirestoreVacio();

      await crearRestaurante(
        db,
        slug: 'pizza-uno',
        nombre: 'Pizza Uno',
        descripcion: 'La mejor pizza del barrio',
        tipoCocina: 'Italiana',
        direccion: 'Calle 1 #2-3, Bogotá',
      );

      final doc = await db.doc('restaurantes/pizza-uno').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['nombre'], 'Pizza Uno');
      expect(data['descripcion'], 'La mejor pizza del barrio');
      expect(data['tipoCocina'], 'Italiana');
      expect(data['direccion'], 'Calle 1 #2-3, Bogotá');
      expect(data['activo'], isTrue);
      expect(data['califProm'], 0.0);
      expect(data['califCount'], 0);
      expect(data['createdAt'], isNotNull);
    });

    test('slug inválido lanza RestauranteException SIN tocar Firestore',
        () async {
      final db = await buildFakeFirestoreVacio();

      await expectLater(
        crearRestaurante(
          db,
          slug: 'Pizzería Uno',
          nombre: 'Pizza Uno',
          descripcion: '',
          tipoCocina: '',
          direccion: '',
        ),
        throwsA(isA<RestauranteException>()),
      );

      final snap = await db.collection('restaurantes').get();
      expect(snap.docs, isEmpty);
    });

    test('slug duplicado lanza con mensaje legible y NO pisa el doc existente',
        () async {
      final db = await buildFakeFirestoreVacio();
      await crearRestaurante(
        db,
        slug: 'demo',
        nombre: 'Original',
        descripcion: 'd',
        tipoCocina: 't',
        direccion: 'dir',
      );

      await expectLater(
        crearRestaurante(
          db,
          slug: 'demo',
          nombre: 'Intruso',
          descripcion: 'x',
          tipoCocina: 'x',
          direccion: 'x',
        ),
        throwsA(
          isA<RestauranteException>().having(
            (e) => e.message,
            'message',
            'Ya existe un restaurante con el identificador "demo".',
          ),
        ),
      );

      // El doc original queda INTACTO (un .set() ciego lo habría pisado).
      final doc = await db.doc('restaurantes/demo').get();
      expect(doc.data()!['nombre'], 'Original');
      final snap = await db.collection('restaurantes').get();
      expect(snap.docs.length, 1);
    });
  });

  group('RestauranteFormDialog', () {
    testWidgets('el slug se deriva del nombre en vivo y se muestra al usuario',
        (tester) async {
      final db = await buildFakeFirestoreVacio();
      await _abrirDialogo(tester, _container(db));

      expect(
        find.text('Identificador (no se puede cambiar después)'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'Pizzería Doña Ana',
      );
      await tester.pump();

      expect(
        _textoDelCampo(tester, const Key('campo-slug')),
        'pizzeria-dona-ana',
      );
    });

    testWidgets(
        'editar el slug a mano lo desacopla del nombre; inválido deshabilita '
        'Guardar y muestra el error inline', (tester) async {
      final db = await buildFakeFirestoreVacio();
      await _abrirDialogo(tester, _container(db));

      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'Pizza Uno',
      );
      await tester.pump();
      expect(_textoDelCampo(tester, const Key('campo-slug')), 'pizza-uno');

      // Edición manual inválida.
      await tester.enterText(find.byKey(const Key('campo-slug')), 'Pizza Uno!');
      await tester.pump();

      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('guardar-restaurante')))
            .onPressed,
        isNull,
        reason: 'con un slug inválido no se puede guardar',
      );
      expect(
        find.text(
          'Solo minúsculas, números y guiones (sin tildes ni espacios)',
        ),
        findsOneWidget,
      );

      // Ya tocado a mano: seguir escribiendo el nombre NO lo sobreescribe.
      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'Pizza Dos',
      );
      await tester.pump();
      expect(_textoDelCampo(tester, const Key('campo-slug')), 'Pizza Uno!');
    });

    testWidgets('un nombre sin letras ni dígitos deja el slug vacío y pide uno',
        (tester) async {
      final db = await buildFakeFirestoreVacio();
      await _abrirDialogo(tester, _container(db));

      await tester.enterText(find.byKey(const Key('campo-nombre')), '★★★');
      await tester.pump();

      expect(_textoDelCampo(tester, const Key('campo-slug')), '');
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('guardar-restaurante')))
            .onPressed,
        isNull,
      );
      expect(
        find.text('Escribe un identificador (el nombre no produce ninguno)'),
        findsOneWidget,
      );
    });

    testWidgets('guardar dos veces seguidas no crea dos documentos',
        (tester) async {
      final db = await buildFakeFirestoreVacio();
      await _abrirDialogo(tester, _container(db));

      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'Pizza Uno',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('guardar-restaurante')));
      await tester.pump();

      // ESTA es la aserción con dientes: el doc-count seguiría en 1 aunque el
      // guard de _saving no existiera, porque el check de existencia rechaza
      // el segundo intento. Lo que hay que probar es que el botón se apaga.
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('guardar-restaurante')))
            .onPressed,
        isNull,
        reason: 'mientras _saving, Guardar debe estar deshabilitado',
      );

      await tester.tap(
        find.byKey(const Key('guardar-restaurante')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final snap = await db.collection('restaurantes').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.id, 'pizza-uno');
    });

    testWidgets(
        'tras el alta, la selección y ridActivo apuntan al restaurante nuevo',
        (tester) async {
      final db = await buildFakeFirestoreVacio();
      final container = _container(db);
      // Punto de partida real: plataforma vacía, el super no tiene selección
      // (app_shell._maybeInitDefaultRid ya corrió con la lista vacía).
      expect(container.read(seleccionRestauranteProvider), isNull);
      expect(await container.read(ridActivoProvider.future), isNull);

      await _abrirDialogo(tester, container);
      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'Pizza Uno',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('guardar-restaurante')));
      await tester.pumpAndSettle();

      expect(container.read(seleccionRestauranteProvider), 'pizza-uno');
      expect(await container.read(ridActivoProvider.future), 'pizza-uno');
      // Y el diálogo se cerró.
      expect(find.byType(RestauranteFormDialog), findsNothing);
    });

    testWidgets('un slug ya usado se rechaza con mensaje legible y sin pisar',
        (tester) async {
      final db = await buildFakeFirestoreVacio();
      await db.doc('restaurantes/pizza-uno').set(<String, dynamic>{
        'nombre': 'El de siempre',
        'activo': true,
        'califProm': 0.0,
        'califCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _abrirDialogo(tester, _container(db));

      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'Pizza Uno',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('guardar-restaurante')));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya existe un restaurante con el identificador "pizza-uno".'),
        findsOneWidget,
      );
      // El diálogo sigue abierto para corregir, y el doc original intacto.
      expect(find.byType(RestauranteFormDialog), findsOneWidget);
      final doc = await db.doc('restaurantes/pizza-uno').get();
      expect(doc.data()!['nombre'], 'El de siempre');
    });
  });
}
