// test/core/colores_render_test.dart — los tokens migrados en 11-12 se
// RENDERIZAN de verdad, y valen el hex de siempre.
//
// ── POR QUÉ EXISTE (medido, no supuesto) ───────────────────────────────────
// El plan 11-12 declara en su registro de amenazas (T-11-12-01, «deriva
// visual durante la migración») que la mitigación son «las 175+ pruebas
// existentes como red de seguridad». Se MIDIÓ con 14 roturas deliberadas,
// cambiando el último dígito de cada token nuevo y ejecutando la suite
// entera. Resultado real:
//
//   token                     efecto de romperlo (ANTES de este archivo)
//   ------------------------  -----------------------------------------
//   sidebarItemInactivo       ROJO  (app_shell_layout_test, de 11-21)
//   pedidoEnPreparacion       ROJO  (theme_tokens_test, de 11-11)
//   divider                   verde
//   sidebarSubtitulo          verde
//   badgeCategoriaInactiva    verde
//   advertencia               verde
//   badgeAgotado              verde
//   badgeInactivo             verde
//   imagenPlaceholderBg       verde
//   reporteIconoBg            verde
//   reporteIconoFg            verde
//   griCardDecoration EN LAS PANTALLAS   verde (solo el token está afirmado)
//   floatingActionButtonTheme            verde
//
// Es decir: la red de seguridad que el plan daba por hecha cubría 2 de 11
// tokens. Nueve migraciones quedaban AFIRMADAS, no verificadas — exactamente
// el modo de fallo que esta fase lleva persiguiendo desde 11-05.
//
// ── LA REGLA DE ESTE ARCHIVO ───────────────────────────────────────────────
// Todas las aserciones comparan contra el **hex literal**, JAMÁS contra el
// token. Comparar contra `GriColors.divider` dejaría el caso verde
// precisamente cuando el token cambia de valor, que es lo único que este
// archivo tiene que impedir. (Mismo criterio que 11-19 adoptó para la app
// cliente.)
//
// Lo que estos casos prueban es que el color LLEGA al árbol renderizado con
// ese valor. NO prueban que la pantalla se vea bien: eso no es observable en
// `flutter test` y sigue pendiente de verificación humana.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/theme.dart';
import 'package:gri_panel_admin/features/menu/menu_screen.dart';
import 'package:gri_panel_admin/features/menu/producto_form_dialog.dart';
import 'package:gri_panel_admin/features/mesas/mesa_form_dialog.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/features/mesas/mesas_screen.dart';
import 'package:gri_panel_admin/features/reportes/reportes_screen.dart';
import 'package:gri_panel_admin/features/shared/error_box.dart';

import '../helpers/firebase_fakes.dart';

// ── Hex de referencia, escritos A MANO ──────────────────────────────────────
// Son los valores que estaban en `lib/features/**` ANTES de 11-12. Si alguien
// cambia un token, estos números NO se mueven y el caso se pone rojo.
const int kDivider = 0xFFEEEEEE;
const int kSidebarSubtitulo = 0xFFAAAAAA;
const int kSidebarItemInactivo = 0xFFCCCCCC;
const int kBadgeCategoriaInactiva = 0xFFE65100;
const int kBadgeAgotado = 0xFFFF8F00;
const int kBadgeInactivo = 0xFF9E9E9E;
const int kAdvertencia = 0xFFE65100;
const int kImagenPlaceholderBg = 0xFFEEEEEE;
const int kReporteIconoBg = 0xFFE8F0FE;
const int kReporteIconoFg = 0xFF3478F6;
const int kNaranjaMarca = 0xFFFF4C05;
const int kSombraTarjeta = 0x0D000000;

/// Todos los colores que el árbol renderizado declara, en ARGB de 32 bits.
///
/// Recorre `Container` (por `color` y por `decoration`), `DecoratedBox`,
/// `Icon`, `Text` y `Divider`. Se recogen los DECLARADOS en el árbol, no los
/// píxeles del framebuffer: `flutter test` no compara capturas y este repo no
/// tiene golden tests.
Set<int> _coloresDelArbol(WidgetTester tester) {
  final out = <int>{};
  void deco(Decoration? d) {
    if (d is! BoxDecoration) return;
    if (d.color != null) out.add(d.color!.toARGB32());
    for (final s in d.boxShadow ?? const <BoxShadow>[]) {
      out.add(s.color.toARGB32());
    }
  }

  for (final w in tester.allWidgets) {
    if (w is Container) {
      if (w.color != null) out.add(w.color!.toARGB32());
      deco(w.decoration);
    } else if (w is DecoratedBox) {
      deco(w.decoration);
    } else if (w is Icon) {
      if (w.color != null) out.add(w.color!.toARGB32());
    } else if (w is Text) {
      final c = w.style?.color;
      if (c != null) out.add(c.toARGB32());
    } else if (w is Divider) {
      if (w.color != null) out.add(w.color!.toARGB32());
    }
  }
  return out;
}

/// Monta la app REAL con sesión de `admin_restaurante` (patrón de
/// `app_shell_layout_test.dart`, 11-21): el sidebar y el topbar solo existen
/// dentro del `ShellRoute`.
Future<void> _montarShell(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ctrl = StreamController<User?>.broadcast();
  final db = await buildFakeFirestoreConSeed();
  final container = ProviderContainer(overrides: [
    authStateChangesProvider.overrideWith((ref) => ctrl.stream),
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: true)),
    claimsProvider.overrideWith(
      (ref) async => (role: 'admin_restaurante', rid: 'demo'),
    ),
  ]);
  addTearDown(() {
    container.dispose();
    ctrl.close();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GriApp()),
  );
  ctrl.add(MockUser(uid: 'u-admin', email: 'admin@demo.gri.dev'));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
}

Widget _conProviders(FakeFirebaseFirestore db, Widget hijo, {ThemeData? tema}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ],
    child: MaterialApp(theme: tema, home: hijo),
  );
}

Future<void> _setFlag(
  FakeFirebaseFirestore db,
  String coleccion,
  String nombre,
  String key,
  Object valor,
) async {
  final snap =
      await db.collection(coleccion).where('nombre', isEqualTo: nombre).get();
  await snap.docs.first.reference.update({key: valor});
}

void main() {
  group('chrome del shell — los 3 grises del sidebar/topbar', () {
    testWidgets('el separador del topbar y el subtítulo del sidebar siguen '
        'siendo #EEEEEE y #AAAAAA', (tester) async {
      await _montarShell(tester, const Size(1280, 900));

      final colores = _coloresDelArbol(tester);
      expect(colores, contains(kDivider),
          reason: 'el Divider bajo el topbar ya no pinta #EEEEEE '
              '(GriColors.divider ha cambiado de valor)');
      expect(colores, contains(kSidebarSubtitulo),
          reason: '«Gestión de Restaurante» ya no pinta #AAAAAA');
      expect(colores, contains(kSidebarItemInactivo),
          reason: 'los ítems no activos del menú ya no pintan #CCCCCC');
    });
  });

  group('menú — los 3 badges', () {
    testWidgets('categoría inactiva #E65100, agotado #FF8F00, inactivo #9E9E9E',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      // Un badge por cada rama: categoría con soft-delete, producto agotado
      // y producto con soft-delete. Sin esto no se renderiza ninguno y los
      // tres `contains` quedarían verdes por vacuidad — por eso el caso
      // afirma además que los tres textos ESTÁN.
      await _setFlag(db, 'categorias', 'Bebidas', 'activo', false);
      await _setFlag(db, 'productos', 'Limonada de coco', 'disponible', false);
      await _setFlag(db, 'productos', 'Café con leche', 'activo', false);

      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_conProviders(db, const Scaffold(body: MenuScreen())));
      await tester.pumpAndSettle();

      // Expandir «Bebidas» para que salgan los badges de producto.
      await tester.tap(find.text('Bebidas'));
      await tester.pumpAndSettle();

      expect(find.text('Inactiva'), findsWidgets);
      expect(find.text('Agotado'), findsWidgets);
      expect(find.text('Inactivo'), findsWidgets);

      final colores = _coloresDelArbol(tester);
      expect(colores, contains(kBadgeCategoriaInactiva),
          reason: 'el badge «Inactiva» ya no pinta #E65100');
      expect(colores, contains(kBadgeAgotado),
          reason: 'el badge «Agotado» ya no pinta #FF8F00');
      expect(colores, contains(kBadgeInactivo),
          reason: 'el badge «Inactivo» ya no pinta #9E9E9E');
    });
  });

  group('reportes — el recuadro del icono', () {
    testWidgets('sigue siendo #E8F0FE con el icono en #3478F6',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      // Sin un pedido SERVIDO dentro del rango no hay tarjetas de resumen y
      // los dos `contains` quedarían verdes por vacuidad.
      await db.collection('pedidos').add({
        'restauranteId': 'demo',
        'mesaId': 'GRI-MESA-demo-002',
        'sesionId': 'GRI-MESA-demo-002',
        'usuarioId': 'uid-ana',
        'clienteNombre': 'Ana Torres',
        'estado': 'servido',
        'items': <Map<String, Object>>[
          {'nombre': 'Bandeja paisa', 'cantidad': 2, 'precio': 28000},
        ],
        'total': 56000,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 15, 13)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 15, 13)),
      });

      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester
          .pumpWidget(_conProviders(db, const Scaffold(body: ReportesScreen())));
      await tester.pumpAndSettle();

      final state =
          tester.state<ReportesScreenState>(find.byType(ReportesScreen));
      state.debugSetFechas(DateTime(2026, 8, 10), DateTime(2026, 8, 20));
      await tester.pump();
      await tester.tap(find.text('Consultar'));
      await tester.pumpAndSettle();

      expect(find.text('Total vendido'), findsOneWidget,
          reason: 'no se generó el reporte: el caso miraría un árbol sin '
              'tarjetas y quedaría verde por vacuidad');

      final colores = _coloresDelArbol(tester);
      expect(colores, contains(kReporteIconoBg),
          reason: 'el recuadro del icono de reporte ya no pinta #E8F0FE');
      expect(colores, contains(kReporteIconoFg),
          reason: 'el icono de reporte ya no pinta #3478F6');
    });
  });

  group('la sombra de tarjeta LLEGA a las pantallas', () {
    testWidgets('las tarjetas del dashboard pintan 0x0D000000 / blur 12 / '
        'offset(0,3) / radio 15', (tester) async {
      await _montarShell(tester, const Size(1280, 900));

      // El token está afirmado en theme_tokens_test; lo que aquí se afirma
      // es que la PANTALLA lo usa. Si alguien vuelve a escribir la sombra a
      // mano con otro valor, este caso cae.
      final sombras = <BoxShadow>[];
      final radios = <BorderRadiusGeometry?>[];
      for (final w in tester.allWidgets) {
        Decoration? d;
        if (w is Container) {
          d = w.decoration;
        } else if (w is DecoratedBox) {
          d = w.decoration;
        }
        if (d is BoxDecoration && (d.boxShadow ?? const []).isNotEmpty) {
          sombras.addAll(d.boxShadow!);
          radios.add(d.borderRadius);
        }
      }

      expect(sombras, isNotEmpty,
          reason: 'ninguna tarjeta del dashboard declara sombra: el caso '
              'estaría verde por vacuidad');
      for (final s in sombras) {
        expect(s.color.toARGB32(), kSombraTarjeta);
        expect(s.blurRadius, 12);
        expect(s.offset, const Offset(0, 3));
      }
      for (final r in radios) {
        expect(r, BorderRadius.circular(15));
      }
    });
  });

  group('el FAB de mesas sale del tema', () {
    testWidgets('bajo griTheme pinta el naranja de marca sin declararlo',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();

      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _conProviders(db, const MesasScreen(), tema: griTheme),
      );
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      // El widget NO declara color: lo pone floatingActionButtonTheme.
      expect(fab.backgroundColor, isNull,
          reason: 'el FAB ha vuelto a declarar su color inline');
      expect(griTheme.floatingActionButtonTheme.backgroundColor?.toARGB32(),
          kNaranjaMarca);
      expect(griTheme.floatingActionButtonTheme.foregroundColor,
          const Color(0xFFFFFFFF));

      // …y llega al render: el Material del FAB pinta ese color.
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color?.toARGB32(), kNaranjaMarca);
    });
  });

  group('los dos literales que solo viven en un diálogo', () {
    testWidgets('el aviso de regeneración del QR sigue en #E65100',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_conProviders(
        db,
        const Scaffold(
          body: MesaFormDialog(
            mesa: Mesa(
              id: 'GRI-MESA-demo-002',
              restauranteId: 'demo',
              numero: 2,
              capacidad: 4,
              estado: EstadoMesa.disponible,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // El aviso solo aparece si el número TIPEADO difiere del original.
      await tester.enterText(find.byType(TextFormField).first, '7');
      await tester.pumpAndSettle();
      expect(find.textContaining('regenera el código QR'), findsOneWidget,
          reason: 'sin el aviso en pantalla el caso quedaría verde por '
              'vacuidad');

      expect(_coloresDelArbol(tester), contains(kAdvertencia),
          reason: 'el aviso de regeneración del QR ya no pinta #E65100');
    });

    testWidgets('el placeholder de imagen rota sigue en #EEEEEE',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_conProviders(
        db,
        const Scaffold(body: ProductoFormDialog(categoriaId: 'cat-x')),
      ));
      await tester.pumpAndSettle();

      // En `flutter test` toda petición de red falla, así que escribir una
      // URL dispara el errorBuilder — que es justo el punto de uso.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'URL de imagen (opcional)'),
          'https://example.invalid/x.png');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget,
          reason: 'el errorBuilder no se disparó: el caso quedaría verde por '
              'vacuidad');

      expect(_coloresDelArbol(tester), contains(kImagenPlaceholderBg),
          reason: 'el placeholder de imagen rota ya no pinta #EEEEEE');
    });
  });

  group('ErrorBox — el padding que NO era igual en las tres copias', () {
    testWidgets('en una caja de alto LIBRE, el relleno añade exactamente 64 px',
        (tester) async {
      // Contexto de dashboard y mesas: la ErrorBox va dentro de un Column
      // que se mide por su contenido. Aquí los 32+32 SÍ mueven píxeles.
      Future<double> alto(EdgeInsetsGeometry? p) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  p == null
                      ? ErrorBox(message: 'x', onRetry: () {})
                      : ErrorBox(message: 'x', onRetry: () {}, padding: p),
                ],
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(ErrorBox)).height;
      }

      expect(await alto(null) - await alto(EdgeInsets.zero), 64);
    });

    testWidgets('HALLAZGO: dentro de un Expanded el relleno es un NO-OP '
        '(medido)', (tester) async {
      // La ErrorBox de cocina vive en `Expanded(child: ...when(error: …))`.
      // Con alto FIJO, el `Center` reparte el sobrante a partes iguales, así
      // que un padding simétrico no mueve nada: (H-h)/2 == 32 + (H-64-h)/2.
      //
      // Consecuencia honesta: unificar las tres copias SIN el parámetro
      // `padding` NO habría cambiado un píxel en cocina — al contrario de lo
      // que se podría suponer del hecho de que la copia fuera distinta.
      // `EdgeInsets.zero` se conserva porque reproduce la estructura EXACTA
      // que había y porque el no-op depende de que el contenedor siga
      // teniendo alto fijo, no de la ErrorBox.
      Future<double> topBoton(EdgeInsetsGeometry? p) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: p == null
                      ? ErrorBox(message: 'x', onRetry: () {})
                      : ErrorBox(message: 'x', onRetry: () {}, padding: p),
                ),
              ],
            ),
          ),
        ));
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.text('Reintentar')).dy;
      }

      expect(await topBoton(null), await topBoton(EdgeInsets.zero),
          reason: 'si esto deja de cumplirse, el EdgeInsets.zero de cocina '
              'pasa a ser load-bearing y hay que medirlo de nuevo');
    });

    test('cocina_screen sigue pasando EdgeInsets.zero a la ErrorBox', () {
      // Aserción textual, deliberada: la geometría de la cola de cocina en
      // estado de error no es alcanzable sin un stream que falle, y montar
      // ese fallo con fake_cloud_firestore no es fiable. Se afirma el
      // contrato en el código, y se declara que es una aserción de fuente,
      // no de render.
      final fuente =
          File('lib/features/cocina/cocina_screen.dart').readAsStringSync();
      expect(fuente, contains('ErrorBox(\n                  padding: EdgeInsets.zero,'),
          reason: 'cocina volvería a llevar los 32 px verticales que NUNCA '
              'tuvo: +64 px de alto en la cola de pedidos');
    });
  });
}
