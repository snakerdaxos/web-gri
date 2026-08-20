// test/a11y/a11y_test.dart — accesibilidad de la APP CLIENTE (11-14).
//
// La auditoría puntuó la accesibilidad del cliente con 1/10: cero `Semantics`
// en 68 archivos, 5 de 6 `IconButton` sin etiqueta y el CTA principal
// ("escanear mesa") por debajo del mínimo táctil de Material. Este archivo
// convierte esos hallazgos en gates.
//
// LO QUE ESTO **NO** PRUEBA. `meetsGuideline` mide GEOMETRÍA y RATIOS de
// contraste sobre el árbol de semántica; no ejecuta TalkBack ni VoiceOver. Que
// un lector de pantalla LEA la pantalla en un orden con sentido —y que las
// etiquetas suenen bien en voz alta— sigue siendo verificación humana.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/gri_icons.dart';
import 'package:gri_cliente/core/theme.dart';
import 'package:gri_cliente/features/pagos/calificacion_sheet.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/restaurantes/home_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';

// ── Montaje de pantallas ──────────────────────────────────────────────────
// Todas montan `griTheme`: es el tema REAL de la app (`app.dart:138`). Un test
// de contraste sobre un `ThemeData()` por defecto mediría otra app.

Widget _home(FakeFirebaseFirestore db) => ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth(displayName: 'Ana')),
      ],
      child: MaterialApp(theme: griTheme, home: const HomeScreen()),
    );

RestauranteDetalle _detalle() => RestauranteDetalle(
      id: 'demo',
      nombre: 'Restaurante Demo GRI',
      tipoCocina: 'Internacional',
      descripcion: null,
      direccion: null,
      categorias: [
        Categoria(
          id: 'c1',
          restauranteId: 'demo',
          nombre: 'Platos',
          orden: 1,
          productos: const [
            Producto(
                id: 'p1',
                restauranteId: 'demo',
                categoriaId: 'c1',
                nombre: 'Pasta',
                descripcion: 'Con salsa de la casa',
                precio: 25000,
                disponible: true),
            Producto(
                id: 'p2',
                restauranteId: 'demo',
                categoriaId: 'c1',
                nombre: 'Pizza',
                precio: 32000,
                disponible: true),
          ],
        ),
      ],
    );

/// `MenuMesaScreen` con una sesión REAL abierta (misma vía que producción).
Future<void> _pumpMenu(WidgetTester tester) async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
      restauranteDetalleProvider('demo').overrideWith((ref) async => _detalle()),
    ],
    child: MaterialApp(theme: griTheme, home: const MenuMesaScreen()),
  ));
  await tester.pumpAndSettle();
}

/// Hoja de calificación abierta (se monta desde un botón, como en la app).
Future<void> _pumpCalificacion(WidgetTester tester) async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
  final id = await crearPedido(
    db,
    uid: 'test-uid',
    mesaCodigo: _mesa,
    items: const [
      PedidoItem(productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 2),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth()),
    ],
    child: MaterialApp(
      theme: griTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CalificacionSheet(pedidoId: id),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// El `IconButton` con [icon] dentro de la fila del producto [nombre].
Finder _btnProducto(String nombre, IconData icon) => find.descendant(
      of: find.ancestor(of: find.text(nombre), matching: find.byType(ListTile)),
      matching: find.byWidgetPredicate(
          (w) => w is IconButton && (w.icon as Icon).icon == icon),
    );

/// El NOMBRE ACCESIBLE de cada nodo de semántica que acepta un tap.
///
/// MEDIDO con sonda (11-14): el `tooltip` de un `IconButton` NO acaba en
/// `SemanticsData.label`, sino en `SemanticsData.tooltip` — un campo aparte
/// que Android expone como `tooltipText` y que VoiceOver lee como pista. Por
/// eso `find.bySemanticsLabel` NO encuentra un botón etiquetado solo con
/// tooltip, y por eso `labeledTapTargetGuideline` acepta EXPLÍCITAMENTE los
/// dos campos (`accessibility.dart:263`). Este helper aplica el mismo
/// criterio que la guía, para que las aserciones de wording y las de la guía
/// hablen de lo mismo.
List<String> _nombresAccesiblesTappables(WidgetTester tester) => [
      for (final n in _nodosTappables(tester))
        n.getSemanticsData().label.isNotEmpty
            ? n.getSemanticsData().label
            : n.getSemanticsData().tooltip,
    ];

/// Todos los nodos de semántica que aceptan un tap, en orden de recorrido.
List<SemanticsNode> _nodosTappables(WidgetTester tester) {
  final nodos = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
    if (node.isMergedIntoParent) return;
    if (!node.getSemanticsData().hasAction(SemanticsAction.tap)) return;
    nodos.add(node);
  }

  walk(tester.binding.renderViews.first.owner!.semanticsOwner!
      .rootSemanticsNode!);
  return nodos;
}

/// El único nodo tappable cuyo nombre accesible es [nombre].
SemanticsNode _nodoTappable(WidgetTester tester, String nombre) {
  final nodos = _nodosTappables(tester).where((n) {
    final d = n.getSemanticsData();
    return (d.label.isNotEmpty ? d.label : d.tooltip) == nombre;
  }).toList();
  expect(nodos, hasLength(1), reason: 'nodo tappable "$nombre"');
  return nodos.single;
}

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // Tarea 1 — etiquetas, tooltips y tamaños táctiles
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('home: el botón de escanear la mesa mide 48x48 (mínimo Android)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_home(db));
    await tester.pumpAndSettle();

    final caja = tester.getSize(find
        .ancestor(
          of: find.byIcon(GriIcons.escanearQr).first,
          matching: find.byType(SizedBox),
        )
        .first);
    expect(caja, const Size(48, 48),
        reason: 'es el CTA principal de la app y medía 45x45');
  });

  testWidgets(
      'home: el botón de QR es un nodo de semántica PROPIO de 48x48',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_home(db));
    await tester.pumpAndSettle();

    // ESTA es la aserción con dientes del tamaño táctil, no la guía. MEDIDO
    // con sonda ANTES del plan: sin el `Semantics(container: true)` del
    // `_QrButton`, la acción de tap se fusionaba con toda la cabecera y el
    // árbol tenía UN nodo de 800x77 etiquetado "GRI / GRI / Escanear QR de la
    // mesa". `androidTapTargetGuideline` medía ese nodo y pasaba con el botón
    // a 45x45 — verde por construcción. Aquí se exige que el nodo del botón
    // exista por separado Y que mida 48.
    final nodo = _nodoTappable(tester, 'Escanear QR de la mesa');
    expect(nodo.rect.size, const Size(48, 48));

    // Y que la cabecera haya dejado de ser un botón gigante: ningún nodo
    // tappable puede llamarse ya arrastrando el logo y el título.
    expect(_nombresAccesiblesTappables(tester),
        isNot(contains(contains('GRI\nGRI'))));
    handle.dispose();
  });

  testWidgets('home cumple androidTapTargetGuideline y labeledTapTarget',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_home(db));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('carrito: los botones mas/menos llevan tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpMenu(tester);
    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pumpAndSettle();

    // El wording, sobre el widget...
    expect(
        tester
            .widget<IconButton>(
                _btnProducto('Pasta', Icons.remove_circle_outline))
            .tooltip,
        'Quitar una unidad');
    expect(
        tester
            .widget<IconButton>(_btnProducto('Pasta', Icons.add_circle_outline))
            .tooltip,
        'Agregar una unidad');

    // ...y que ese wording LLEGA de verdad al árbol de semántica, que es lo
    // que lee el sistema. Un `tooltip` en el widget que no llegase al nodo
    // sería una etiqueta que nadie oye.
    final nombres = _nombresAccesiblesTappables(tester);
    expect(nombres, contains('Quitar una unidad'));
    expect(nombres, contains('Agregar una unidad'));
    handle.dispose();
  });

  testWidgets('menú de la mesa cumple las dos guías táctiles', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpMenu(tester);
    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('calificación: cada estrella expone su etiqueta individual',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCalificacion(tester);
    final nombres = _nombresAccesiblesTappables(tester);

    expect(nombres, contains('Calificar con 1 estrella'),
        reason: '"1 estrellas" no es español; la etiqueta se LEE en voz alta');
    for (var i = 2; i <= 5; i++) {
      expect(nombres, contains('Calificar con $i estrellas'),
          reason: 'sin etiqueta el lector lee "botón" cinco veces seguidas');
    }
    handle.dispose();
  });

  testWidgets('calificación cumple las dos guías táctiles', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCalificacion(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
