@TestOn('vm')
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/equipo/equipo_controller.dart';
import 'package:gri_panel_admin/features/equipo/equipo_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_screen.dart';
import 'package:gri_panel_admin/features/menu/menu_screen.dart';
import 'package:gri_panel_admin/features/mesas/mesa_actions_sheet.dart';
import 'package:gri_panel_admin/models/mesa.dart';

import '../helpers/firebase_fakes.dart';

/// Accesibilidad del panel admin (11-25).
///
/// -- LO QUE ESTA SUITE SI DEMUESTRA Y LO QUE NO ---------------------------
/// `meetsGuideline` mide GEOMETRIA y RATIOS sobre el arbol de semantica. NO
/// ejecuta un lector de pantalla: que TalkBack o NVDA lean el panel en un
/// orden con sentido queda AFIRMADO, no verificado.
///
/// -- POR QUE NO BASTA CON LAS GUIAS ---------------------------------------
/// El plan 11-14 (gemelo de este, en `app_cliente`) MIDIO que
/// `androidTapTargetGuideline` pasa VERDE sobre el bug que decia cazar. Aqui
/// ocurre algo peor y en la otra direccion: las tres guias pasaban verdes
/// sobre un panel cuya barra de navegacion ENTERA era invisible para un lector
/// de pantalla, porque una guia solo puede juzgar los nodos que existen y los
/// del sidebar no existian. Por eso los primeros casos de esta suite afirman
/// PRESENCIA en el arbol, no conformidad de una guia.

// -------------------------------------------------------------------------
// Montaje
// -------------------------------------------------------------------------

/// Monta `GriApp` (router y AppShell REALES) con sesion de
/// `admin_restaurante` y navega a [ruta].
///
/// Pumpear una pantalla suelta NO sirve para lo que mide esta suite: el
/// defecto central de este plan vive en la interaccion entre el shell y el
/// Navigator interno del `ShellRoute`, y desaparece si se monta la pantalla
/// por su cuenta.
Future<ProviderContainer> montarApp(
  WidgetTester tester,
  Size tamano, {
  String ruta = '/',
  String role = 'admin_restaurante',
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ctrl = StreamController<User?>.broadcast();
  final db = await buildFakeFirestoreConSeed();
  // Mesas sembradas EN VARIOS ESTADOS: con el mapa vacio (o con las tres del
  // seed, todas 'disponible') los casos del tile pasarian por construccion.
  for (var i = 4; i <= 8; i++) {
    await db.doc('mesas/GRI-MESA-demo-00$i').set({
      'restauranteId': 'demo',
      'numero': i,
      'capacidad': 4,
      'estado': i.isEven ? 'ocupada' : 'reservada',
    });
  }
  final container = ProviderContainer(overrides: [
    authStateChangesProvider.overrideWith((ref) => ctrl.stream),
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: true)),
    claimsProvider.overrideWith((ref) async => (role: role, rid: 'demo')),
  ]);
  addTearDown(() {
    container.dispose();
    ctrl.close();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GriApp()),
  );
  ctrl.add(MockUser(uid: 'u-admin', email: 'admin@demo.gri.dev'));
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
  if (ruta != '/') {
    container.read(goRouterProvider).go(ruta);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
  }
  return container;
}

// -------------------------------------------------------------------------
// Lectura del arbol de semantica
// -------------------------------------------------------------------------

/// Un nodo del arbol, aplanado a lo que interesa afirmar.
typedef NodoA11y = ({
  int id,
  String label,
  String tooltip,
  bool tap,
  bool boton,
  Size tamano,
});

List<NodoA11y> nodos(WidgetTester tester) {
  final salida = <NodoA11y>[];
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    salida.add((
      id: n.id,
      label: d.label,
      tooltip: d.tooltip,
      tap: d.hasAction(SemanticsAction.tap),
      boton: d.flagsCollection.isButton,
      tamano: n.rect.size,
    ));
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  // El MISMO recorrido que hacen las guías de `flutter_test`
  // (`accessibility.dart`: `for (final RenderView view in
  // tester.binding.renderViews) ... view.owner!.semanticsOwner!`), para que
  // estos casos y `meetsGuideline` hablen exactamente del mismo árbol.
  for (final RenderView view in tester.binding.renderViews) {
    walk(view.owner!.semanticsOwner!.rootSemanticsNode!);
  }
  return salida;
}

/// El nombre accesible de un nodo: `label` o, si esta vacio, `tooltip`.
///
/// Es el MISMO criterio que aplica `labeledTapTargetGuideline`
/// (`accessibility.dart`: `if (data.label.isEmpty && data.tooltip.isEmpty)`).
/// Escribirlo aqui evita el error que 11-14 documento: `find.bySemanticsLabel`
/// solo mira `label`, asi que no ve un nombre puesto con `tooltip`.
String nombreAccesible(NodoA11y n) => n.label.isEmpty ? n.tooltip : n.label;

/// Los 8 items del sidebar, en orden.
const itemsSidebar = <String>[
  'Dashboard',
  'Mesas',
  'Pedidos',
  'Reservas',
  'Clientes',
  'Reportes',
  'Equipo',
  'Configuración',
];

// -------------------------------------------------------------------------
// Equipo (se monta suelto: la tabla necesita el equipo inyectado)
// -------------------------------------------------------------------------

const _equipoSembrado = <MiembroEquipo>[
  (
    uid: 'u-yo',
    nombre: 'Yo Mismo',
    email: 'yo@demo.com',
    rol: 'admin_restaurante',
    activo: true,
  ),
  (
    uid: 'u-zoe',
    nombre: 'Zoe Mesera',
    email: 'zoe@demo.com',
    rol: 'mesero',
    activo: true,
  ),
  (
    uid: 'u-beto',
    nombre: 'Beto DeBaja',
    email: 'beto@demo.com',
    rol: 'cocina',
    activo: false,
  ),
];

/// Abre el bottom sheet de acciones de una mesa (patrón
/// `test/dashboard/mesa_actions_test.dart`).
Future<void> montarSheetDeMesa(
  WidgetTester tester, {
  EstadoMesa estado = EstadoMesa.ocupada,
  bool showEdit = true,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = await buildFakeFirestoreConSeed();
  final mesa = Mesa(
    id: 'GRI-MESA-demo-002',
    restauranteId: 'demo',
    numero: 2,
    capacidad: 4,
    estado: estado,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith(
          (ref) async => (role: 'mesero', rid: 'demo'),
        ),
      ],
      child: Consumer(
        builder: (consumerContext, ref, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (buttonContext) => TextButton(
                  onPressed: () => showMesaActionsSheet(
                    buttonContext,
                    ref,
                    mesa,
                    showEdit: showEdit,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// Monta `/configuracion` con el menú desplegado (categorías + productos).
Future<void> montarMenu(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = await buildFakeFirestoreConSeed();
  final c = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: true)),
    claimsProvider
        .overrideWith((ref) async => (role: 'admin_restaurante', rid: 'demo')),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: MenuScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> montarEquipo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final c = ProviderContainer(overrides: [
    claimsProvider
        .overrideWith((ref) async => (role: 'admin_restaurante', rid: 'demo')),
    uidSesionProvider.overrideWithValue('u-yo'),
    equipoProvider.overrideWith((ref) async => _equipoSembrado),
    cambiarEstadoAccionProvider.overrideWithValue(
      ({required String uid, required bool activo}) async =>
          (uid: uid, activo: activo, rol: 'mesero', restauranteId: 'demo'),
    ),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: EquipoScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // =======================================================================
  // 1. La navegacion EXISTE para un lector de pantalla
  // =======================================================================

  group('la barra de navegacion existe en el arbol de semantica', () {
    testWidgets('expandida (1280): los 8 items tienen nombre accesible',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(1280, 900));

      final nombres = nodos(tester).map(nombreAccesible).toSet();
      final ausentes = itemsSidebar.where((i) => !nombres.contains(i)).toList();

      expect(ausentes, isEmpty,
          reason: 'estos items del sidebar NO existen en el arbol de '
              'semantica: $ausentes');
      handle.dispose();
    });

    testWidgets('expandida (1280): los 7 no activos son pulsables',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(1280, 900));

      final pulsables =
          nodos(tester).where((n) => n.tap).map(nombreAccesible).toSet();
      // 'Dashboard' es la ruta activa: su onTap es null a proposito.
      final navegables = itemsSidebar.where((i) => i != 'Dashboard');

      for (final item in navegables) {
        expect(pulsables, contains(item),
            reason: 'el item «$item» no expone accion de pulsar');
      }
      handle.dispose();
    });

    testWidgets('el topbar existe en el arbol de semantica', (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(1280, 900));

      final nombres = nodos(tester).map(nombreAccesible).toSet();
      expect(nombres, contains('Resumen de tu restaurante'));
      expect(nombres, contains('Restaurante Demo GRI'));
      handle.dispose();
    });
  });

  // =======================================================================
  // 2. Sidebar COLAPSADO (70px) - navegacion solo-icono
  // =======================================================================

  group('sidebar colapsado (700px): navegacion solo-icono', () {
    testWidgets('los 8 items siguen teniendo nombre accesible',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(700, 900));

      final nombres = nodos(tester).map(nombreAccesible).toSet();
      final ausentes = itemsSidebar.where((i) => !nombres.contains(i)).toList();
      expect(ausentes, isEmpty,
          reason: 'colapsado, estos items no se anuncian: $ausentes');
      handle.dispose();
    });

    testWidgets('cada item lleva Tooltip con su nombre (raton)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(700, 900));

      // Colapsado el icono va SOLO: sin tooltip, un usuario de raton no tiene
      // ninguna forma de saber que es cada cosa. Se afirma sobre el arbol de
      // semantica (campo `tooltip`), no sobre el widget: es lo que de verdad
      // llega a la plataforma.
      final conTooltip = nodos(tester)
          .map((n) => n.tooltip)
          .where((t) => t.isNotEmpty)
          .toSet();
      final ausentes =
          itemsSidebar.where((i) => !conTooltip.contains(i)).toList();
      expect(ausentes, isEmpty, reason: 'sin Tooltip colapsado: $ausentes');
      handle.dispose();
    });

    testWidgets('expandida NO pone tooltip (la etiqueta ya se lee)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(1280, 900));

      final conTooltip = nodos(tester)
          .map((n) => n.tooltip)
          .where((t) => t.isNotEmpty)
          .toSet();
      expect(conTooltip.intersection(itemsSidebar.toSet()), isEmpty,
          reason: 'expandido el nombre ya es visible: un tooltip encima solo '
              'duplicaria el anuncio');
      handle.dispose();
    });
  });

  // =======================================================================
  // 3. El mapa de mesas - el control que el staff toca todo el dia
  // =======================================================================

  group('mapa de mesas', () {
    testWidgets('cada tile se anuncia con su numero Y su estado',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(1280, 900));

      final nombres = nodos(tester).map(nombreAccesible).toSet();
      // Sembradas arriba: 1-3 disponibles, pares ocupadas, impares reservadas.
      expect(nombres, contains('Mesa 1, Disponible, 2 personas'));
      expect(nombres, contains('Mesa 4, Ocupada, 4 personas'));
      expect(nombres, contains('Mesa 5, Reservada, 4 personas'));
      handle.dispose();
    });

    testWidgets('el tile se anuncia como BOTON, no como texto suelto',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(1280, 900));

      final tiles = nodos(tester)
          .where((n) => nombreAccesible(n).startsWith('Mesa 4, '))
          .toList();
      expect(tiles, hasLength(1),
          reason: 'la mesa 4 deberia tener UN nodo propio');
      expect(tiles.single.tap, isTrue);
      expect(tiles.single.boton, isTrue,
          reason: 'sin la marca de boton, un lector de pantalla anuncia el '
              'tile como texto y no dice que se pueda activar');
      handle.dispose();
    });
  });

  // =======================================================================
  // 3b. El sheet de acciones de una mesa y el menu
  // =======================================================================

  group('sheet de acciones de mesa', () {
    testWidgets('cada accion se anuncia con su verbo y cumple las dos guias',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarSheetDeMesa(tester);

      final nombres = nodos(tester).map(nombreAccesible).toSet();
      // Desde 'ocupada' la unica transicion valida es limpieza.
      expect(nombres, contains('Marcar en limpieza'));
      expect(nombres, contains('Ver código QR'));
      expect(nombres, contains('Editar mesa'));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('menu (categorias y productos)', () {
    testWidgets('el boton de editar NOMBRA la categoria', (tester) async {
      final handle = tester.ensureSemantics();
      await montarMenu(tester);

      // El seed trae DOS categorias: un tooltip generico 'Editar categoria'
      // repetido no deja saber cual se edita.
      final nombres = nodos(tester).map(nombreAccesible).toSet();
      expect(nombres, contains('Editar la categoría Platos fuertes'));
      expect(nombres, contains('Editar la categoría Bebidas'));
      handle.dispose();
    });

    testWidgets('cumple las dos guias', (tester) async {
      final handle = tester.ensureSemantics();
      await montarMenu(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  // =======================================================================
  // 4. /equipo - las acciones de baja y readmision (11-24)
  // =======================================================================

  group('/equipo', () {
    testWidgets('la accion de cada fila NOMBRA a la persona', (tester) async {
      final handle = tester.ensureSemantics();
      await montarEquipo(tester);

      final nombres = nodos(tester).map(nombreAccesible).toSet();
      // Con varias filas, «Desactivar» repetido no deja saber a quien se
      // desactiva: el nombre visible esta en OTRA celda de la tabla y un
      // lector de pantalla no lo asocia.
      expect(nombres, contains('Desactivar a Zoe Mesera'));
      expect(nombres, contains('Reactivar a Beto DeBaja'));
      handle.dispose();
    });
  });

  // =======================================================================
  // 5. Las guias de Flutter sobre el camino critico
  // =======================================================================

  group('guias del camino critico', () {
    for (final ruta in const <String>['/', '/mesas', '/equipo']) {
      testWidgets('$ruta cumple tap targets Android (48dp) y etiquetado',
          (tester) async {
        final handle = tester.ensureSemantics();
        await montarApp(tester, const Size(1280, 900), ruta: ruta);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('el panel colapsado (700) cumple las dos guias',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarApp(tester, const Size(700, 900));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('/equipo con filas de accion cumple las dos guias',
        (tester) async {
      final handle = tester.ensureSemantics();
      await montarEquipo(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
