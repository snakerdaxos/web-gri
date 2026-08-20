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
import 'dart:io';
import 'dart:math' as math;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/features/auth/login_screen.dart';
import 'package:gri_cliente/features/auth/register_screen.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/gri_icons.dart';
import 'package:gri_cliente/core/reloj.dart';
import 'package:gri_cliente/core/theme.dart';
import 'package:gri_cliente/features/pagos/calificacion_sheet.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/reservas/mis_reservas_screen.dart';
import 'package:gri_cliente/features/reservas/reserva_wizard_screen.dart';
import 'package:gri_cliente/features/restaurantes/home_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/shared/producto_card.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';

import '../helpers/firebase_fakes.dart';

/// Las 18:00 de HOY — ver el override de `relojProvider` de más abajo.
DateTime _hoyALas18() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, 18);
}

const _mesa = 'GRI-MESA-demo-001';

// ── Montaje de pantallas ──────────────────────────────────────────────────
// Todas montan `griTheme`: es el tema REAL de la app (`app.dart:138`). Un test
// de contraste sobre un `ThemeData()` por defecto mediría otra app.

Widget _home(FakeFirebaseFirestore db) => ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth(displayName: 'Ana')),
      ],
      // Dentro de un `Scaffold`, como en la app: el `AppShell` monta cada
      // branch en el body de un Scaffold. Sin él, el fondo no es
      // `scaffoldBackgroundColor` y el `DefaultTextStyle` no es el de
      // Material — dos cosas que el gate de contraste sí mira.
      child: MaterialApp(
          theme: griTheme, home: const Scaffold(body: HomeScreen())),
    );

/// Login y registro con su `GoRouter`, como en `login_register_test.dart`.
Widget _auth({String inicio = '/login'}) {
  final router = GoRouter(
    initialLocation: inicio,
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(theme: griTheme, routerConfig: router),
  );
}

// ── Contraste WCAG, calculado aquí ────────────────────────────────────────
// El plan pedía NO depender de la estimación de la auditoría. Esto es la
// fórmula de la norma (WCAG 2.1, "relative luminance" + "contrast ratio"),
// no una aproximación.

double _canal(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminancia(Color c) =>
    0.2126 * _canal(c.r) + 0.7152 * _canal(c.g) + 0.0722 * _canal(c.b);

/// Ratio de contraste WCAG entre dos colores opacos (1.0 … 21.0).
double ratioContraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// El color con el que se PINTA de verdad el párrafo cuyo texto es [texto].
Color _colorPintado(WidgetTester tester, String texto) {
  final parrafos = find.byType(RichText).evaluate().where((e) =>
      (e.renderObject! as RenderParagraph).text.toPlainText() == texto);
  expect(parrafos, hasLength(1), reason: 'párrafo "$texto"');
  return (parrafos.single.renderObject! as RenderParagraph).text.style!.color!;
}

/// Todos los TEXTOS pintados en el árbol, con su color y tamaño reales.
///
/// Excluye los `Icon`: un icono de Material también se pinta con un
/// `RenderParagraph` (su glifo vive en la fuente `MaterialIcons`), pero NO es
/// texto — el umbral de 4.5:1 de WCAG 1.4.3 no le aplica, y `GriColors.gray`
/// se queda ahí a propósito.
List<(String, Color, double)> _textosPintados(WidgetTester tester) {
  final out = <(String, Color, double)>[];
  for (final e in find.byType(RichText).evaluate()) {
    final span = (e.renderObject! as RenderParagraph).text;
    final estilo = span.style;
    if (estilo?.color == null) continue;
    if (estilo?.fontFamily == 'MaterialIcons') continue;
    final txt = span.toPlainText().trim();
    if (txt.isEmpty) continue;
    out.add((txt, estilo!.color!, estilo.fontSize ?? 14));
  }
  return out;
}

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
      // 11-30: el ancla era `ListTile`; ahora cada plato es un
      // `ProductoCard` (la carta con foto). Mismo scoping, otro tipo.
      of: find.ancestor(
          of: find.text(nombre), matching: find.byType(ProductoCard)),
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

  testWidgets('home cumple las tres guías (táctil, etiqueta y contraste)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_home(db));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
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

  testWidgets('menú de la mesa cumple las tres guías', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpMenu(tester);
    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
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

  testWidgets('calificación cumple las tres guías', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCalificacion(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  // ══════════════════════════════════════════════════════════════════════
  // Tarea 2 — contraste del texto secundario, sin tocar la paleta
  // ══════════════════════════════════════════════════════════════════════

  test('los dos grises, medidos con la fórmula WCAG (no con la auditoría)',
      () {
    const blanco = Color(0xFFFFFFFF);
    const fondo = GriColors.background; // #F7F7F7, el fondo real de la app

    // El token de MARCA no llega a AA como color de texto. Este número es la
    // razón de que exista el otro token; si alguien "arregla" el contraste
    // cambiando `gray`, este caso se pone rojo por el motivo correcto.
    expect(GriColors.gray, const Color(0xFF777777),
        reason: 'token de MARCA: decisión BLOQUEADA del usuario');
    expect(ratioContraste(GriColors.gray, blanco), closeTo(4.48, 0.01));
    expect(ratioContraste(GriColors.gray, fondo), closeTo(4.18, 0.01),
        reason: 'sobre el fondo REAL de la app es aún peor que sobre blanco');

    // El token accesible sí, y sobre los DOS fondos.
    expect(ratioContraste(GriColors.textoSecundarioAccesible, blanco),
        greaterThanOrEqualTo(4.5));
    expect(ratioContraste(GriColors.textoSecundarioAccesible, fondo),
        greaterThanOrEqualTo(4.5));

    // Un solo valor, dos caminos de acceso (11-11 lo declaró en la extensión).
    expect(GriSemanticColors.gri.textoSecundarioAccesible,
        GriColors.textoSecundarioAccesible);
  });

  testWidgets('el texto secundario del login se PINTA con >= 4.5:1',
      (tester) async {
    await tester.pumpWidget(_auth());
    await tester.pumpAndSettle();

    // Se lee el color REAL del párrafo, no el token: comparar contra el token
    // dejaría el caso verde aunque la pantalla siguiera pintando de #777777.
    final color = _colorPintado(tester, 'Reserva y pide desde tu mesa');
    expect(ratioContraste(color, const Color(0xFFFFFFFF)),
        greaterThanOrEqualTo(4.5),
        reason: 'con #777777 el ratio es 4.48 — la auditoría tenía razón');
  });

  testWidgets('BARRIDO: ningún texto del camino crítico se pinta con #777777',
      (tester) async {
    // El gate de verdad de la Tarea 2. `textContrastGuideline` solo mira lo
    // que hay EN PANTALLA en ese frame; esto recorre los párrafos de las
    // cinco pantallas del camino crítico y exige que ni uno solo conserve el
    // gris de marca como color de TEXTO.
    var vistos = 0;
    var accesibles = 0;

    // Riverpod prohíbe cambiar el NÚMERO de overrides de un `ProviderScope`
    // ya montado, y cada pantalla trae los suyos: entre pantalla y pantalla
    // hay que desmontar el árbol entero.
    Future<void> limpiar() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    Future<void> barrer(String pantalla) async {
      final textos = _textosPintados(tester);
      expect(textos, isNotEmpty, reason: 'el barrido no vio nada en $pantalla');
      for (final (txt, color, size) in textos) {
        vistos++;
        if (color == GriColors.textoSecundarioAccesible) accesibles++;
        expect(color, isNot(GriColors.gray),
            reason: '$pantalla: "$txt" (${size}px) se pinta con el gris de '
                'MARCA (#777777 -> 4.48:1). El texto secundario va con '
                'GriColors.textoSecundarioAccesible');
      }
    }

    await tester.pumpWidget(_auth());
    await tester.pumpAndSettle();
    await barrer('login');

    await limpiar();
    await tester.pumpWidget(_auth(inicio: '/register'));
    await tester.pumpAndSettle();
    await barrer('registro');

    await limpiar();
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_home(db));
    await tester.pumpAndSettle();
    await barrer('home');

    await limpiar();
    await _pumpMenu(tester);
    await barrer('menú de la mesa');

    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Carrito ('));
    await tester.pumpAndSettle();
    await barrer('carrito');

    // CANARIO: si el barrido no viese párrafos, todos los `isNot` de arriba
    // pasarían por vacío. Estos dos números demuestran que miró y que
    // encontró el token nuevo aplicado de verdad.
    // Números MEDIDOS: 53 párrafos recorridos, 11 con el token accesible. El
    // umbral va por debajo del valor real para que añadir un texto a una
    // pantalla no ponga esto rojo, pero vaciar el barrido sí.
    expect(vistos, greaterThanOrEqualTo(50), reason: 'párrafos recorridos');
    expect(accesibles, greaterThanOrEqualTo(10),
        reason: 'párrafos ya pintados con el token accesible');
  });

  testWidgets('login y registro cumplen textContrastGuideline',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_auth());
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.pumpWidget(_auth(inicio: '/register'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  // ══════════════════════════════════════════════════════════════════════
  // Tarea 3 — el resto del camino crítico
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('login y registro cumplen las dos guías táctiles',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_auth());
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.pumpWidget(_auth(inicio: '/register'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('el carrito cumple las dos guías táctiles y la de contraste',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpMenu(tester);
    await tester.tap(_btnProducto('Pasta', Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Carrito ('));
    await tester.pumpAndSettle();

    expect(find.text('Enviar pedido'), findsOneWidget,
        reason: 'canario: sin esto el sheet no está abierto y las guías de '
            'abajo estarían midiendo el menú, no el carrito');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('mis reservas: el FAB tiene etiqueta y la pantalla cumple',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
      ],
      child: MaterialApp(theme: griTheme, home: const MisReservasScreen()),
    ));
    await tester.pumpAndSettle();

    // El FAB NO estaba en la lista de la auditoría (contó `IconButton`, y
    // esto es un `FloatingActionButton`): lo destapó la guía.
    expect(_nombresAccesiblesTappables(tester), contains('Reservar una mesa'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  test('GATE ESTÁTICO: GriColors.gray no aparece en ningún contexto de TEXTO',
      () {
    // POR QUÉ HACE FALTA ADEMÁS DEL BARRIDO. El barrido solo ve las pantallas
    // que monta. MEDIDO con dos roturas: devolver a `GriColors.gray` el texto
    // del 404 o el del escáner deja la suite ENTERA en verde, porque esas dos
    // pantallas no están montadas en ningún caso de este archivo. Este gate
    // lee las 68 fuentes de `lib/`, así que no tiene puntos ciegos por
    // cobertura de montaje.
    //
    // Criterio: de los marcadores conocidos, gana el que esté MÁS CERCA por
    // delante de la aparición. `Icon(... color: GriColors.gray)` clasifica
    // como icono aunque tres líneas antes hubiera un `TextStyle`.
    const marcadoresTexto = <String>[
      'TextStyle(',
      'GriText.',
      'unselectedItemColor:',
      'disabledForegroundColor:',
      'foregroundColor:',
    ];
    const marcadoresNoTexto = <String>[
      'Icon(',
      'backgroundColor:',
      'CircularProgressIndicator(',
      'BorderSide(',
      'Divider(',
    ];

    var apariciones = 0;
    var archivos = 0;
    final infracciones = <String>[];

    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // core/theme.dart es donde vive el token: ahí `GriColors.gray` aparece
      // por definición (y en el fallback `neutroFg` de los chips de estado).
      if (f.path.replaceAll(r'\', '/').endsWith('core/theme.dart')) continue;
      archivos++;

      // Fuera comentarios: el doc de un widget puede nombrar el token.
      final codigo = f
          .readAsStringSync()
          .split('\n')
          .map((l) {
            final i = l.indexOf('//');
            return i == -1 ? l : l.substring(0, i);
          })
          .join('\n');

      var desde = 0;
      while (true) {
        final i = codigo.indexOf('GriColors.gray', desde);
        if (i == -1) break;
        desde = i + 1;
        // `GriColors.grayAlgo` no es `GriColors.gray`.
        final sig = i + 'GriColors.gray'.length;
        if (sig < codigo.length &&
            RegExp(r'[A-Za-z0-9_]').hasMatch(codigo[sig])) {
          continue;
        }
        apariciones++;

        final antes = codigo.substring(0, i);
        var mejor = -1;
        var esTexto = false;
        for (final m in marcadoresTexto) {
          final p = antes.lastIndexOf(m);
          if (p > mejor) {
            mejor = p;
            esTexto = true;
          }
        }
        for (final m in marcadoresNoTexto) {
          final p = antes.lastIndexOf(m);
          if (p > mejor) {
            mejor = p;
            esTexto = false;
          }
        }
        final linea = '\n'.allMatches(antes).length + 1;
        if (mejor == -1) {
          infracciones.add('${f.path}:$linea — contexto DESCONOCIDO: '
              'clasifícalo añadiendo su marcador al gate');
        } else if (esTexto) {
          infracciones.add('${f.path}:$linea — GriColors.gray como color de '
              'TEXTO (4.48:1 < 4.5). Usa GriColors.textoSecundarioAccesible');
        }
      }
    }

    expect(infracciones, isEmpty, reason: infracciones.join('\n'));
    // Autocomprobación de cobertura: si el gate dejara de leer archivos o de
    // encontrar apariciones, `isEmpty` pasaría por vacío.
    //
    // MEDIDO 11-33: 7 apariciones legítimas. Eran 12; el plan 11-33 unificó
    // en `features/shared/fallo_de_stream.dart` las CINCO copias del bloque
    // de error (4 pantallas + el `_ErrorView` de la lista de restaurantes),
    // cada una con su `Icon(..., color: GriColors.gray)`. El umbral baja de
    // 10 a 6 por ese motivo, no porque el gate mire menos: sigue leyendo los
    // mismos archivos y clasificando las mismas apariciones. Si alguien
    // vaciara el barrido, esto seguiría poniéndose rojo.
    expect(archivos, greaterThanOrEqualTo(40), reason: 'archivos leídos');
    expect(apariciones, greaterThanOrEqualTo(6),
        reason: 'apariciones de GriColors.gray clasificadas');
  });

  testWidgets('el wizard de reserva etiqueta sus controles de comensales',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        firestoreProvider.overrideWithValue(db),
        // 11-31: reloj fijo a las 18:00, hora a la que hoy ya no admite
        // reservas (margen de 4 h, turno hasta las 21:00) y el wizard abre
        // en mañana con la rejilla entera — que es lo que este caso
        // necesita para poder tocar las 19:00.
        relojProvider.overrideWithValue(() => _hoyALas18()),
      ],
      child: MaterialApp(
        home: const ReservaWizardScreen(
          restauranteId: 'demo',
          restauranteNombre: 'Restaurante Demo GRI',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Al step de personas: fecha -> hora -> personas.
    await tester.tap(find.text('Elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elige una hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('19:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final nombres = _nombresAccesiblesTappables(tester);
    expect(nombres, contains('Agregar un comensal'));
    expect(nombres, contains('Quitar un comensal'));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
