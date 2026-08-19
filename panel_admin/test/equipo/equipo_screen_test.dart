import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_controller.dart';
import 'package:gri_panel_admin/features/equipo/equipo_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_screen.dart';
import 'package:gri_panel_admin/features/equipo/staff_form_dialog.dart';

import '../helpers/firebase_fakes.dart';

/// Pantalla `/equipo` y su formulario de alta (11-10, Tarea 3).
///
/// La acción de alta se INYECTA (`crearStaffAccionProvider`), como en
/// `bootstrap_screen_test.dart`: sin esa costura estos tests necesitarían una
/// app Firebase inicializada y no existirían.
///
/// ⚠️ Aquí no se prueba NINGUNA autorización: el gating del router y del
/// sidebar lo prueba `equipo_gating_test.dart`, y la autorización de verdad
/// vive en la callable (`crear-usuario-staff.e2e.mjs`) y en las rules
/// (`usuarios.test.mjs`). La UI oculta lo que no se puede hacer; no lo impide.

const _equipoDemo = <MiembroEquipo>[
  (
    uid: 'u-ana',
    nombre: 'Ana Admin',
    email: 'ana@demo.com',
    rol: 'admin_restaurante'
  ),
  (uid: 'u-zoe', nombre: 'Zoe Mesera', email: 'zoe@demo.com', rol: 'mesero'),
];

/// Alta de mentira: registra lo recibido y devuelve lo que se le diga.
class _AltaEspia {
  _AltaEspia({this.resultado, this.error, this.completer});

  final ResultadoAlta? resultado;
  final Object? error;

  /// Si se pasa, la acción queda EN VUELO hasta completarlo — así se puede
  /// comprobar que el botón está deshabilitado mientras tanto.
  final Completer<void>? completer;

  int llamadas = 0;
  Map<String, Object?>? ultimo;

  CrearStaffAccion get accion => ({
        required String nombre,
        required String email,
        required String password,
        required String rol,
        String? restauranteId,
      }) async {
        llamadas++;
        ultimo = {
          'nombre': nombre,
          'email': email,
          'password': password,
          'rol': rol,
          'restauranteId': restauranteId,
        };
        if (completer != null) await completer!.future;
        if (error != null) throw error!;
        return resultado ??
            (
              uid: 'u-nuevo',
              creado: true,
              rol: rol,
              restauranteId: restauranteId ?? 'demo'
            );
      };
}

ProviderContainer _container({
  required String role,
  String? rid,
  List<MiembroEquipo> equipo = _equipoDemo,
  Object? errorEquipo,
  _AltaEspia? espia,
  String? seleccion,
  FakeFirebaseFirestore? db,
}) {
  final c = ProviderContainer(
    overrides: [
      // El selector de restaurante del super lee `restaurantesListProvider`,
      // que consulta Firestore de verdad. Se le da el fake con el seed en vez
      // de mockear el provider: así el caso prueba que el selector se llena
      // por el camino REAL y no por un doble que siempre devuelve algo.
      if (db != null) firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith((ref) async => (role: role, rid: rid)),
      equipoProvider.overrideWith((ref) async {
        if (errorEquipo != null) throw errorEquipo;
        return equipo;
      }),
      if (espia != null)
        crearStaffAccionProvider.overrideWithValue(espia.accion),
    ],
  );
  if (seleccion != null) {
    c.read(seleccionRestauranteProvider.notifier).set(seleccion);
  }
  addTearDown(c.dispose);
  return c;
}

Future<void> _montar(WidgetTester tester, ProviderContainer c) async {
  // El formulario tiene 5 campos: con el viewport de 800x600 por defecto el
  // botón cae fuera de la ventana y `tap` no acierta (lección 11-07).
  tester.view.physicalSize = const Size(1100, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: EquipoScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirFormulario(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('equipo-nuevo')));
  await tester.pumpAndSettle();
}

Future<void> _rellenar(
  WidgetTester tester, {
  String nombre = 'Nuevo Mesero',
  String email = 'nuevo@demo.com',
  String password = 'clave1234',
}) async {
  await tester.enterText(find.byKey(const Key('staff-nombre')), nombre);
  await tester.enterText(find.byKey(const Key('staff-email')), email);
  await tester.enterText(find.byKey(const Key('staff-password')), password);
}

void main() {
  group('EquipoScreen — listado', () {
    testWidgets('como admin_restaurante lista nombre, correo y rol',
        (tester) async {
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo'),
      );

      expect(find.text('Ana Admin'), findsOneWidget);
      expect(find.text('ana@demo.com'), findsOneWidget);
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Zoe Mesera'), findsOneWidget);
      expect(find.text('Mesero'), findsOneWidget);
      expect(find.byKey(const Key('equipo-nuevo')), findsOneWidget);
    });

    testWidgets('con el equipo vacío se GUÍA, no se deja una lista en blanco',
        (tester) async {
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo', equipo: const []),
      );

      expect(find.byKey(const Key('equipo-vacio')), findsOneWidget);
      // La guía es obligatoria: constatar el vacío sin explicar qué hacer deja
      // al operador sin saber si la pantalla falló (patrón EmptyState, 11-09).
      expect(find.byKey(const Key('equipo-vacio-guia')), findsOneWidget);
      // Y desde el vacío se puede actuar.
      expect(find.byKey(const Key('equipo-nuevo')), findsOneWidget);
    });

    testWidgets('un error del provider ofrece reintentar', (tester) async {
      await _montar(
        tester,
        _container(
          role: 'mesero',
          rid: 'demo',
          errorEquipo: StateError('solo admin'),
        ),
      );

      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('StaffFormDialog — campos según el rol del que ha iniciado sesión', () {
    testWidgets('admin_restaurante: NO hay selector de restaurante',
        (tester) async {
      await _montar(tester, _container(role: 'admin_restaurante', rid: 'demo'));
      await _abrirFormulario(tester);

      expect(find.byType(StaffFormDialog), findsOneWidget);
      expect(find.byKey(const Key('staff-restaurante')), findsNothing);
    });

    testWidgets('super_admin: SÍ hay selector de restaurante', (tester) async {
      await _montar(
        tester,
        _container(
          role: 'super_admin',
          seleccion: 'demo',
          db: await buildFakeFirestoreConSeed(),
        ),
      );
      await _abrirFormulario(tester);

      expect(find.byKey(const Key('staff-restaurante')), findsOneWidget);
    });

    testWidgets('super_admin NUNCA aparece entre los roles asignables',
        (tester) async {
      // La constante es el espejo de ROLES_ASIGNABLES de auth-matrix.js.
      expect(rolesAsignables, ['admin_restaurante', 'mesero', 'cocina']);
      expect(rolesAsignables, isNot(contains('super_admin')));

      await _montar(
        tester,
        _container(
          role: 'super_admin',
          seleccion: 'demo',
          db: await buildFakeFirestoreConSeed(),
        ),
      );
      await _abrirFormulario(tester);

      await tester.tap(find.byKey(const Key('staff-rol')));
      await tester.pumpAndSettle();

      expect(find.text('Super Admin'), findsNothing);
      expect(find.text('Administrador'), findsWidgets);
      expect(find.text('Cocina'), findsWidgets);
    });

    testWidgets('el copy dice que reintentar con el mismo correo REPARA',
        (tester) async {
      await _montar(tester, _container(role: 'admin_restaurante', rid: 'demo'));
      await _abrirFormulario(tester);

      expect(
        find.textContaining('idempotente'),
        findsOneWidget,
        reason: 'es la mitigación de la no-atomicidad Auth/Firestore (11-08)',
      );
    });
  });

  group('StaffFormDialog — validación', () {
    testWidgets('una contraseña de 7 caracteres NO llega a la callable',
        (tester) async {
      // La función rechaza 7 con invalid-argument y hay un caso e2e que lo
      // fija (11-08): el formulario debe exigir 8 ANTES de gastar una llamada.
      final espia = _AltaEspia();
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo', espia: espia),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester, password: '1234567');
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pumpAndSettle();

      expect(espia.llamadas, 0);
      expect(find.byType(StaffFormDialog), findsOneWidget);
    });

    testWidgets('un correo sin arroba tampoco', (tester) async {
      final espia = _AltaEspia();
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo', espia: espia),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester, email: 'no-es-un-correo');
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pumpAndSettle();

      expect(espia.llamadas, 0);
    });
  });

  group('StaffFormDialog — alta', () {
    testWidgets(
        'admin_restaurante: alta correcta, sin restauranteId en la llamada y '
        'con el aviso de volver a entrar', (tester) async {
      final espia = _AltaEspia();
      await _montar(
        tester,
        _container(
          role: 'admin_restaurante',
          rid: 'demo',
          espia: espia,
          // ⚠️ SELECCIÓN AJENA A PROPÓSITO. Sin ella este caso era un VERDE POR
          // EL MOTIVO EQUIVOCADO: `seleccionRestauranteProvider` valía null,
          // así que `restauranteId` llegaba null aunque se borrara el guard
          // `esSuper ? _restauranteId : null` del diálogo (comprobado: la
          // rotura K no tumbaba ni un caso). Con 'norte' sembrado, quitar el
          // guard hace viajar un rid AJENO — exactamente el intento de escalada
          // horizontal que la callable rechaza — y el caso se pone en rojo.
          seleccion: 'norte',
          db: await buildFakeFirestoreConSeed(),
        ),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester);
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pumpAndSettle();

      expect(espia.llamadas, 1);
      // El rid lo DERIVA la callable del claim del llamador.
      expect(espia.ultimo!['restauranteId'], isNull);
      expect(espia.ultimo!['rol'], 'mesero'); // valor por defecto del desplegable
      // El diálogo se cierra y el aviso de propagación de claims aparece.
      expect(find.byType(StaffFormDialog), findsNothing);
      expect(find.textContaining('vuelva a entrar'), findsOneWidget);
    });

    testWidgets('super_admin: el restauranteId elegido SÍ viaja',
        (tester) async {
      final espia = _AltaEspia();
      await _montar(
        tester,
        _container(
          role: 'super_admin',
          seleccion: 'demo',
          espia: espia,
          db: await buildFakeFirestoreConSeed(),
        ),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester);
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pumpAndSettle();

      expect(espia.llamadas, 1);
      expect(espia.ultimo!['restauranteId'], 'demo');
    });

    testWidgets('un alta que REPARA (creado: false) lo dice, no miente con "creado"',
        (tester) async {
      // La callable es idempotente: repetir el alta con el mismo correo
      // devuelve `creado: false` y REPARA. Si la UI dijera "usuario creado" en
      // ese caso, el operador no sabría que acaba de arreglar algo roto.
      final espia = _AltaEspia(
        resultado: (
          uid: 'u-x',
          creado: false,
          rol: 'mesero',
          restauranteId: 'demo'
        ),
      );
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo', espia: espia),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester);
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ya existía y quedó reparada'), findsOneWidget);
      expect(find.textContaining('vuelva a entrar'), findsOneWidget);
    });

    testWidgets('un alta fallida muestra el mensaje y NO cierra el formulario',
        (tester) async {
      final espia = _AltaEspia(
        error: const EquipoException('No tienes permiso para crear ese usuario.'),
      );
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo', espia: espia),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester);
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pumpAndSettle();

      expect(find.byType(StaffFormDialog), findsOneWidget);
      expect(find.text('No tienes permiso para crear ese usuario.'),
          findsOneWidget);
    });

    testWidgets('doble envío imposible mientras la operación está en vuelo',
        (tester) async {
      final completer = Completer<void>();
      final espia = _AltaEspia(completer: completer);
      await _montar(
        tester,
        _container(role: 'admin_restaurante', rid: 'demo', espia: espia),
      );
      await _abrirFormulario(tester);
      await _rellenar(tester);

      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pump(); // la acción queda en vuelo
      await tester.tap(find.byKey(const Key('staff-guardar')));
      await tester.pump();

      expect(espia.llamadas, 1);

      completer.complete();
      await tester.pumpAndSettle();
      expect(espia.llamadas, 1);
    });
  });
}
