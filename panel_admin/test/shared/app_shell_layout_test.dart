import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/design_tokens.dart';
import 'package:gri_panel_admin/core/theme.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/shared/app_shell.dart';

import '../helpers/firebase_fakes.dart';

/// Geometría del AppShell del panel (11-21, Tarea 1).
///
/// ── POR QUÉ ESTE ARCHIVO EXISTE ───────────────────────────────────────────
/// El sidebar del panel desbordaba a CUALQUIER ancho de ventana: el `Row` del
/// logo mete un badge de 45px + hueco + un `Column` con 'GRI' (24 bold) y
/// 'Gestión de Restaurante' (11) SIN restricción de ancho, dentro de un
/// `Container` de 250px con padding horizontal de 15 (→ 220px útiles). Lo
/// mismo con el `Text(label)` del ítem de menú.
///
/// Medido antes del arreglo, a 1280x900: **85 px a la derecha** (logo) y
/// **33 px a la derecha** (ítem de menú).
///
/// `bootstrap_router_test.dart` lo descubrió (11-07) y lo TAPÓ con un filtro
/// de `FlutterError.onError` para poder quedarse verde. Ese filtro se retiró
/// en 11-21 y este archivo es lo que ocupa su lugar: en vez de esconder los
/// desbordes, los AFIRMA ausentes a los anchos que importan.
///
/// ── DETALLE DE FONTANERÍA ─────────────────────────────────────────────────
/// Los desbordes de RenderFlex NO son excepciones lanzadas: se reportan por
/// `FlutterError.onError` durante el layout. Se recogen a mano para poder
/// imprimir el desborde EXACTO en píxeles cuando el caso falla. El hook se
/// restaura ANTES de cualquier `expect`: si un `expect` falla con el hook
/// puesto, el harness aborta con "A test overrode FlutterError.onError…" y el
/// motivo real se pierde.
void main() {
  /// Desbordes recogidos durante el último [montar].
  late List<String> desbordes;

  /// Monta la app REAL (GriApp → goRouterProvider real → ShellRoute →
  /// AppShell) con sesión de `admin_restaurante` sobre el Firestore fake.
  /// Un pump del `AppShell` suelto no valdría: el ancho del sidebar y el del
  /// contenido salen del mismo `LayoutBuilder`.
  Future<void> montar(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    desbordes = <String>[];
    // OVERFLOW-DETECTOR: se recogen para AFIRMAR que la lista queda vacía y
    // para poder imprimir los píxeles exactos cuando no lo esté. NO es un
    // filtro; ver test/shared/sin_filtros_overflow_test.dart.
    final onErrorPrevio = FlutterError.onError;
    FlutterError.onError = (details) {
      final txt = details.exceptionAsString();
      if (txt.contains('A RenderFlex overflowed')) {
        desbordes.add(txt.split('\n').first);
        return;
      }
      onErrorPrevio?.call(details);
    };

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

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const GriApp()),
      );
      // Sesión: sin esto el guard manda a /login y el shell no se monta.
      ctrl.add(MockUser(uid: 'u-admin', email: 'admin@demo.gri.dev'));
      // Timeout explícito de 30 s SIMULADOS: el default son 10 minutos, y un
      // shell que no llegue a estabilizarse dejaría el caso colgado sin decir
      // nada durante 10 minutos.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
    } finally {
      FlutterError.onError = onErrorPrevio;
    }
  }

  void sinDesbordes(String donde) {
    expect(
      desbordes,
      isEmpty,
      reason: 'RenderFlex desbordado en $donde:\n  ${desbordes.join("\n  ")}',
    );
  }

  testWidgets('a 800x900 el shell con sesión no desborda', (tester) async {
    await montar(tester, const Size(800, 900));

    expect(find.byType(AppShell), findsOneWidget);
    sinDesbordes('800x900');
  });

  testWidgets(
      'a 1920x1080 el shell con sesión no desborda (el grid de stats está a 4 '
      'columnas)', (tester) async {
    await montar(tester, const Size(1920, 1080));

    expect(find.byType(AppShell), findsOneWidget);
    sinDesbordes('1920x1080');
  });

  testWidgets('a 1280x900 (el ancho donde se midieron los 85px + 33px) no '
      'desborda', (tester) async {
    await montar(tester, const Size(1280, 900));

    expect(find.byType(AppShell), findsOneWidget);
    sinDesbordes('1280x900');
  });

  testWidgets('el sidebar expandido conserva los textos de marca y las 8 '
      'etiquetas del menú', (tester) async {
    await montar(tester, const Size(1280, 900));

    expect(find.text('GRI'), findsOneWidget);
    expect(find.text('Gestión de Restaurante'), findsOneWidget);
    for (final label in const [
      'Dashboard',
      'Mesas',
      'Pedidos',
      'Reservas',
      'Clientes',
      'Reportes',
      'Equipo',
      'Configuración',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'falta el ítem $label');
    }
    sinDesbordes('1280x900 (marca visible)');
  });

  testWidgets(
      'el punto de colapso NO se movió: a 700px el sidebar mide 70 y oculta '
      'las etiquetas', (tester) async {
    await montar(tester, const Size(700, 900));

    // 700 < GriBreakpoints.compact (750) — el token y el código siguen
    // diciendo lo mismo (paridad de 11-11).
    expect(GriBreakpoints.compact, 750);
    expect(find.text('GRI'), findsNothing);
    expect(find.text('Gestión de Restaurante'), findsNothing);
    // 'Dashboard' NO sirve como aserción: es también el título del topbar en
    // la ruta '/'. Se comprueban etiquetas que solo existen en el sidebar.
    for (final label in const ['Mesas', 'Pedidos', 'Reservas', 'Equipo']) {
      expect(find.text(label), findsNothing,
          reason: 'colapsado no debe pintar la etiqueta $label');
    }

    final sidebar = find.byWidgetPredicate(
      (w) => w is Container && w.color == GriColors.sidebar,
    );
    expect(sidebar, findsOneWidget);
    expect(
      tester.getSize(sidebar).width,
      70.0,
      reason: 'el sidebar colapsado debe seguir midiendo 70px',
    );
    sinDesbordes('700x900 (colapsado)');
  });

  testWidgets('el sidebar expandido sigue midiendo 250px', (tester) async {
    await montar(tester, const Size(1280, 900));

    final sidebar = find.byWidgetPredicate(
      (w) => w is Container && w.color == GriColors.sidebar,
    );
    expect(tester.getSize(sidebar).width, 250.0);
  });
}
