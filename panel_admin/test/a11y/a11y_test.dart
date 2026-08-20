@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/theme.dart';
import 'package:gri_panel_admin/features/auth/login_screen.dart';
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

// -------------------------------------------------------------------------
// Contraste (formula WCAG, calculada aqui y no importada de ningun sitio)
// -------------------------------------------------------------------------

/// Luminancia relativa de un color (WCAG 2.x, 1.4.3).
double _luminancia(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

/// Ratio de contraste WCAG entre dos colores OPACOS.
double ratioContraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  final (alto, bajo) = la > lb ? (la, lb) : (lb, la);
  return (alto + 0.05) / (bajo + 0.05);
}

const blanco = Color(0xFFFFFFFF);

/// Los 4 pares (texto, fondo) de la paleta de mesas.
const paresDeMesa = <String, (Color, Color)>{
  'disponible': (GriColors.mesaDisponibleFg, GriColors.mesaDisponibleBg),
  'ocupada': (GriColors.mesaOcupadaFg, GriColors.mesaOcupadaBg),
  'reservada': (GriColors.mesaReservadaFg, GriColors.mesaReservadaBg),
  'limpieza': (GriColors.mesaLimpiezaFg, GriColors.mesaLimpiezaBg),
};

/// Las 8 rutas del shell.
const rutasDelPanel = <String>[
  '/',
  '/mesas',
  '/cocina',
  '/reservas',
  '/clientes',
  '/reportes',
  '/equipo',
  '/configuracion',
];

/// Monta SOLO el login (vive fuera del ShellRoute).
Future<void> montarLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = await buildFakeFirestoreConSeed();
  final c = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: griTheme, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

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

  // =======================================================================
  // 6. Contraste (Tarea 2)
  // =======================================================================

  group('contraste del texto secundario', () {
    test('el token accesible cumple AA sobre los DOS fondos del panel', () {
      // El panel pinta texto secundario sobre blanco (tarjetas, sheets,
      // dialogos) Y sobre el fondo de pagina #F5F6F8 (cabeceras de pantalla,
      // topbar, estados vacios). Afirmarlo solo sobre blanco dejaria pasar un
      // gris que falla donde de verdad se usa: 11-14 midio que #767676 pasa
      // sobre blanco (4.54) y falla sobre el fondo (4.24).
      expect(ratioContraste(GriColors.textoSecundarioAccesible, blanco),
          greaterThanOrEqualTo(4.5));
      expect(
          ratioContraste(GriColors.textoSecundarioAccesible,
              GriColors.background),
          greaterThanOrEqualTo(4.5));
    });

    test('los numeros exactos, calculados con la formula WCAG', () {
      // Contra el HEX escrito a mano, no contra el token (criterio de 11-12):
      // comparar contra el token dejaria el caso verde justo cuando el token
      // cambia. Aqui se comprueba la FORMULA y los numeros que cita el
      // SUMMARY; de que los tokens sigan valiendo eso se encargan los dos
      // casos de abajo.
      const gris777 = Color(0xFF777777);
      const gris6E = Color(0xFF6E6E6E);
      const fondoPanel = Color(0xFFF5F6F8);
      expect(ratioContraste(gris777, blanco), closeTo(4.478, 0.001));
      expect(ratioContraste(gris777, fondoPanel), closeTo(4.141, 0.001));
      expect(ratioContraste(gris6E, blanco), closeTo(5.099, 0.001));
      expect(ratioContraste(gris6E, fondoPanel), closeTo(4.715, 0.001));
    });

    test('GriColors.gray sigue valiendo EXACTAMENTE #777777 (token de MARCA)',
        () {
      // Guarda del threat model T-11-25-01. El arreglo de contraste NO puede
      // hacerse cambiando la paleta: es una decision BLOQUEADA del usuario.
      expect(GriColors.gray, const Color(0xFF777777));
      // Y sigue SIN cumplir: por eso hay un token aparte.
      expect(ratioContraste(GriColors.gray, blanco), lessThan(4.5));
    });

    test('los dos caminos al token accesible dan el MISMO valor', () {
      expect(GriColors.textoSecundarioAccesible, const Color(0xFF6E6E6E));
      expect(GriSemanticColors.gri.textoSecundarioAccesible,
          GriColors.textoSecundarioAccesible);
    });

    for (final ruta in rutasDelPanel) {
      testWidgets('BARRIDO $ruta: ningun parrafo se pinta con gray',
          (tester) async {
        // Mide el color PINTADO (el `TextStyle` resuelto de cada
        // `RenderParagraph`), no el token declarado: un token puede estar bien
        // y el punto de uso seguir teniendo el hex viejo.
        var parrafos = 0;
        var conTokenAccesible = 0;
        final infracciones = <String>[];

        await montarApp(tester, const Size(1280, 900), ruta: ruta);
        for (final e in find.byType(RichText).evaluate()) {
          final estilo = (e.renderObject! as RenderParagraph).text.style;
          // Un `Icon` de Material tambien es un `RichText` (un glifo de la
          // fuente MaterialIcons). NO es texto y el umbral de WCAG 1.4.3 no le
          // aplica: los 7 iconos grises del panel son legitimos.
          if (estilo?.fontFamily == 'MaterialIcons') continue;
          parrafos++;
          // Contra el HEX literal, no contra el token (criterio de 11-12): si
          // alguien "arreglara" el contraste cambiando el valor de
          // `GriColors.gray`, este caso seguiria diciendo la verdad —lo que se
          // pinta ya no seria #777777— y quien se pondria rojo seria la guarda
          // del token, que es a quien le toca.
          if (estilo?.color == const Color(0xFF777777)) {
            infracciones.add('$ruta: «${_recorte(e)}»');
          }
          if (estilo?.color == const Color(0xFF6E6E6E)) {
            conTokenAccesible++;
          }
        }

        expect(infracciones, isEmpty, reason: infracciones.join('\n'));
        // Canarios de cobertura: sin ellos el caso pasaria en verde si el
        // montaje fallara, o si el filtro de iconos se comiera el arbol.
        // Medidos: la ruta mas pobre pinta 18 parrafos y 2 con el token.
        expect(parrafos, greaterThanOrEqualTo(15),
            reason: 'parrafos de texto vistos en $ruta');
        expect(conTokenAccesible, greaterThanOrEqualTo(2),
            reason: 'parrafos de $ruta pintados con el token accesible');
      });
    }

    test('GATE ESTATICO: GriColors.gray no aparece en contexto de TEXTO', () {
      // POR QUE HACE FALTA ADEMAS DEL BARRIDO (hallazgo 3 de 11-14): el
      // barrido solo ve las pantallas que monta. El panel tiene dialogos,
      // sheets y el 404 que ningun caso monta; devolver ahi el gris no
      // pondria roja la suite. Este gate lee TODAS las fuentes de `lib/`.
      //
      // Criterio: de los marcadores conocidos gana el que este MAS CERCA por
      // delante de la aparicion.
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
        // core/theme.dart es donde vive el token: ahi aparece por definicion.
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
                'clasificalo anadiendo su marcador al gate');
          } else if (esTexto) {
            infracciones.add('${f.path}:$linea — GriColors.gray como color de '
                'TEXTO (4.478:1 sobre blanco, 4.141:1 sobre el fondo del '
                'panel). Usa GriColors.textoSecundarioAccesible');
          }
        }
      }

      expect(infracciones, isEmpty, reason: infracciones.join('\n'));
      // Autocomprobacion de cobertura: sin esto `isEmpty` pasaria por vacio
      // si el gate dejara de leer archivos o de encontrar apariciones.
      expect(archivos, greaterThanOrEqualTo(30), reason: 'archivos leidos');
      expect(apariciones, greaterThanOrEqualTo(3),
          reason: 'apariciones de GriColors.gray clasificadas');
    });
  });

  group('contraste: lo que NO se puede arreglar sin tocar la paleta', () {
    // Estos dos casos NO afirman conformidad: FIJAN una deuda medida para que
    // no se olvide y para que cambiar la paleta la ponga roja y obligue a
    // revisarla. La paleta es una decision BLOQUEADA del usuario.

    test('blanco sobre el naranja de marca: 3.34:1', () {
      expect(ratioContraste(blanco, GriColors.primary), closeTo(3.34, 0.005));
      // Pasa el umbral de TEXTO GRANDE (3.0) y no el de texto normal (4.5):
      // los botones de 16 bold cumplen y los de 14 normal no.
      expect(ratioContraste(blanco, GriColors.primary), greaterThan(3.0));
      expect(ratioContraste(blanco, GriColors.primary), lessThan(4.5));
    });

    test('la paleta de mesas no llega a AA para su etiqueta de estado', () {
      // La auditoria señala los colores de mesa como la unica parte del
      // sistema de diseño bien ejecutada desde el principio, y el plan
      // PROHIBE tocarlos. Medido aqui por primera vez: 3 de los 4 pares no
      // llegan a 4.5, y la etiqueta de estado del tile es de 13px normal.
      //
      // El texto 'Mesa N' (25 bold) SI cumple: su umbral es 3.0.
      final medido = <String, double>{
        for (final e in paresDeMesa.entries)
          e.key: ratioContraste(e.value.$1, e.value.$2),
      };
      expect(medido['disponible'], closeTo(3.983, 0.001));
      expect(medido['ocupada'], closeTo(4.358, 0.001));
      expect(medido['reservada'], closeTo(3.514, 0.001));
      expect(medido['limpieza'], closeTo(4.694, 0.001));

      final bajoAA = medido.entries.where((e) => e.value < 4.5).map((e) => e.key);
      expect(bajoAA, unorderedEquals(['disponible', 'ocupada', 'reservada']),
          reason: 'DEUDA CONOCIDA: si esta lista cambia, la paleta de mesas se '
              'ha movido y hay que revisar la deuda del SUMMARY de 11-25');
      // Los cuatro superan el 3:1 de objetos graficos (WCAG 1.4.11), asi que
      // el punto de color de la leyenda si cumple.
      expect(medido.values.every((r) => r >= 3.0), isTrue);
    });
  });

  group('CENSO de contraste: que queda mal y por que', () {
    // El plan preveia acotar `textContrastGuideline` al camino critico y dejar
    // el resto como deuda. MEDIDO: no hace falta acotar NADA por ruido — tras
    // la Tarea 2 el UNICO fallo que queda en las 8 rutas es blanco sobre el
    // naranja de marca (3.34), que no se puede arreglar sin tocar una decision
    // BLOQUEADA. Y aparece en TODAS las rutas, porque el item ACTIVO del
    // sidebar es precisamente blanco sobre el naranja: por eso la guia no
    // puede pasar en ninguna pantalla de dentro del shell.
    //
    // Este censo es mas fuerte que excluir pantallas: si mañana alguien pinta
    // un texto con un gris que no llega a AA, el ratio que reporte la guia
    // dejara de ser 3.34 y este caso se pondra rojo.
    final ratioFallo = RegExp(r'but found ([0-9.]+)');

    for (final ruta in rutasDelPanel) {
      testWidgets('$ruta: los fallos que quedan son SOLO el 3.34 de la marca',
          (tester) async {
        final handle = tester.ensureSemantics();
        await montarApp(tester, const Size(1280, 900), ruta: ruta);
        final ev = await textContrastGuideline.evaluate(tester);

        final ratios = ratioFallo
            .allMatches(ev.reason ?? '')
            .map((m) => m.group(1)!)
            .toSet();

        expect(ratios, isNot(isEmpty),
            reason: 'canario: si no hay NINGUN fallo, o la guia dejo de mirar '
                'o el item activo del sidebar ya no es blanco sobre naranja; '
                'en los dos casos hay que revisar este censo, no borrarlo');
        expect(ratios, equals({'3.34'}),
            reason: 'ratios de fallo en $ruta: $ratios\n${ev.reason}');
        handle.dispose();
      });
    }
  });

  testWidgets('el login cumple textContrastGuideline', (tester) async {
    // El login vive FUERA del ShellRoute, asi que es la unica pantalla del
    // panel donde esta guia puede pasar: dentro del shell el item ACTIVO del
    // sidebar es blanco sobre el naranja de marca (3.34) en TODAS las rutas.
    final handle = tester.ensureSemantics();
    await montarLogin(tester);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}

/// Los primeros 30 caracteres del texto de un parrafo, para el mensaje de
/// fallo del barrido.
String _recorte(Element e) {
  final t = (e.renderObject! as RenderParagraph).text.toPlainText();
  return t.length <= 30 ? t : '${t.substring(0, 30)}…';
}
