import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/equipo/equipo_controller.dart';
import 'package:gri_panel_admin/features/equipo/equipo_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_screen.dart';

/// Baja REVERSIBLE de personal desde `/equipo` (11-24, Tarea 3).
///
/// ── QUÉ SE PRUEBA AQUÍ Y QUÉ NO ───────────────────────────────────────────
/// Aquí NO se prueba ninguna autorización. Las dos prohibiciones nuevas —nadie
/// toca a un `super_admin`, nadie se toca a sí mismo— viven en la callable y
/// están demostradas en `functions/test/baja-matrix.test.js` (combinatoria
/// pura) y en `scripts/test/functions/cambiar-estado-staff.e2e.mjs` (tokens
/// reales), en los dos casos quitando el control y comprobando que caen los
/// casos correctos.
///
/// Lo que se prueba aquí es la UI: que no ofrece acciones que el servidor va a
/// rechazar, que la confirmación existe SOLO en el sentido destructivo, que
/// cancelar no llama a nada y que un doble toque no dispara dos llamadas.
///
/// La acción se INYECTA (`cambiarEstadoAccionProvider`), misma costura que el
/// alta: sin ella estos tests necesitarían una app Firebase inicializada.

const _yo = 'u-yo';

const _equipo = <MiembroEquipo>[
  (
    uid: _yo,
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
    uid: 'u-baja',
    nombre: 'Beto DeBaja',
    email: 'beto@demo.com',
    rol: 'cocina',
    activo: false,
  ),
  (
    uid: 'u-super',
    nombre: 'Sara Super',
    email: 'sara@demo.com',
    rol: 'super_admin',
    activo: true,
  ),
];

/// Doble de la acción: cuenta invocaciones y registra lo recibido.
class _EstadoEspia {
  _EstadoEspia({this.error, this.completer});

  final Object? error;

  /// Si se pasa, la acción queda EN VUELO hasta completarlo.
  final Completer<void>? completer;

  int llamadas = 0;
  final List<({String uid, bool activo})> recibido = [];

  CambiarEstadoAccion get accion => ({
        required String uid,
        required bool activo,
      }) async {
        llamadas++;
        recibido.add((uid: uid, activo: activo));
        if (completer != null) await completer!.future;
        if (error != null) throw error!;
        return (uid: uid, activo: activo, rol: 'mesero', restauranteId: 'demo');
      };
}

int _invalidaciones = 0;

ProviderContainer _container({
  List<MiembroEquipo> equipo = _equipo,
  _EstadoEspia? espia,
  String? uidSesion = _yo,
}) {
  _invalidaciones = 0;
  final c = ProviderContainer(
    overrides: [
      claimsProvider
          .overrideWith((ref) async => (role: 'admin_restaurante', rid: 'demo')),
      uidSesionProvider.overrideWithValue(uidSesion),
      equipoProvider.overrideWith((ref) async {
        _invalidaciones++;
        return equipo;
      }),
      if (espia != null)
        cambiarEstadoAccionProvider.overrideWithValue(espia.accion),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _montar(WidgetTester tester, ProviderContainer c) async {
  // La tabla tiene 5 columnas y `minWidth: 720`: con el viewport por defecto
  // de 800x600 la columna de acción queda fuera y `tap` no acierta.
  tester.view.physicalSize = const Size(1400, 900);
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

Finder _accion(String uid) => find.byKey(Key('equipo-accion-$uid'));

void main() {
  group('EquipoScreen — marca visual y qué acción ofrece cada fila', () {
    testWidgets('un miembro desactivado se marca y su acción pasa a Reactivar',
        (tester) async {
      await _montar(tester, _container());

      // La insignia se pinta en las DOS direcciones: si solo apareciera en el
      // caso raro se leería como un adorno, no como un dato de la fila.
      expect(find.text('Desactivado'), findsOneWidget);
      // Los TRES activos: Yo Mismo, Zoe y Sara. Ocultar la ACCIÓN de una fila
      // (uno mismo, un super_admin) no oculta su ESTADO — la tabla sigue
      // diciendo quién puede entrar, que es el dato que se viene a consultar.
      expect(find.text('Activo'), findsNWidgets(3));

      expect(
        tester.widget<Text>(
          find.descendant(of: _accion('u-baja'), matching: find.byType(Text)),
        ).data,
        'Reactivar',
      );
      expect(
        tester.widget<Text>(
          find.descendant(of: _accion('u-zoe'), matching: find.byType(Text)),
        ).data,
        'Desactivar',
      );
    });

    testWidgets('la fila del propio usuario NO ofrece desactivar',
        (tester) async {
      await _montar(tester, _container());

      expect(_accion(_yo), findsNothing);
      expect(find.byKey(const Key('equipo-accion-propia')), findsOneWidget);
    });

    testWidgets('la fila de un super_admin NO ofrece desactivar',
        (tester) async {
      await _montar(tester, _container());

      expect(_accion('u-super'), findsNothing);
      // Y sigue apareciendo en la lista: ocultar la ACCIÓN no es ocultar a la
      // persona.
      expect(find.text('Sara Super'), findsOneWidget);
    });

    testWidgets(
        'sin uid de sesión conocido NO se pierde ninguna acción legítima',
        (tester) async {
      // Caso degradado: si el uid no se puede leer, la UI ofrece la acción y
      // deja decidir al servidor. Es lo correcto — ocultar es cortesía, no
      // seguridad— y este caso lo fija para que nadie lo "arregle" escondiendo
      // acciones por si acaso.
      await _montar(tester, _container(uidSesion: null));

      expect(_accion('u-zoe'), findsOneWidget);
      expect(_accion(_yo), findsOneWidget);
    });
  });

  group('EquipoScreen — confirmación', () {
    testWidgets('desactivar PIDE confirmación nombrando a la persona',
        (tester) async {
      final espia = _EstadoEspia();
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-zoe'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('equipo-confirmar-baja')), findsOneWidget);
      // NOMBRA a la persona: con varias filas parecidas, un texto genérico no
      // deja comprobar que se pulsó la fila correcta.
      expect(find.text('¿Desactivar a Zoe Mesera?'), findsOneWidget);
      // Y dice que es reversible, que es la decisión bloqueada del usuario.
      expect(
        find.textContaining('puedes reactivarlo cuando quieras'),
        findsOneWidget,
      );
      expect(espia.llamadas, 0, reason: 'todavía no se ha confirmado nada');
    });

    testWidgets('CANCELAR no llama a la callable', (tester) async {
      final espia = _EstadoEspia();
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-zoe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('equipo-baja-cancelar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('equipo-confirmar-baja')), findsNothing);
      expect(espia.llamadas, 0);
    });

    testWidgets('confirmar llama con activo:false y el uid de ESA fila',
        (tester) async {
      final espia = _EstadoEspia();
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-zoe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('equipo-baja-confirmar')));
      await tester.pumpAndSettle();

      expect(espia.llamadas, 1);
      expect(espia.recibido.single.uid, 'u-zoe');
      expect(espia.recibido.single.activo, isFalse);
    });

    testWidgets('REACTIVAR no pide confirmación (no es destructivo)',
        (tester) async {
      final espia = _EstadoEspia();
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-baja'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('equipo-confirmar-baja')), findsNothing);
      expect(espia.llamadas, 1);
      expect(espia.recibido.single.uid, 'u-baja');
      expect(espia.recibido.single.activo, isTrue);
    });
  });

  group('EquipoScreen — resultado de la operación', () {
    testWidgets('tras desactivar avisa de que la sesión abierta caducará',
        (tester) async {
      final espia = _EstadoEspia();
      await _montar(tester, _container(espia: espia));
      final antes = _invalidaciones;

      await tester.tap(_accion('u-zoe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('equipo-baja-confirmar')));
      await tester.pumpAndSettle();

      // El aviso NO es cortesía: un ID token ya emitido vive hasta ~1 h, así
      // que la baja no expulsa al instante una sesión abierta. Que el operador
      // lo sepa es parte de la mitigación del riesgo aceptado T-11-24-04.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('ya no puede entrar'), findsOneWidget);
      expect(find.textContaining('caduque su token'), findsOneWidget);
      expect(_invalidaciones, greaterThan(antes),
          reason: 'la lista se refresca tras la operación');
    });

    testWidgets('tras reactivar avisa de que debe volver a entrar',
        (tester) async {
      final espia = _EstadoEspia();
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-baja'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('volver a iniciar sesión'),
        findsOneWidget,
        reason: 'sin volver a entrar, su token sigue sin los claims',
      );
    });

    testWidgets('un error muestra el mensaje traducido y refresca la lista',
        (tester) async {
      final espia = _EstadoEspia(
        error: const EquipoException('No tienes permiso para cambiar el '
            'estado de ese usuario.'),
      );
      await _montar(tester, _container(espia: espia));
      final antes = _invalidaciones;

      await tester.tap(_accion('u-baja'));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes permiso para cambiar el estado de ese usuario.'),
        findsOneWidget,
      );
      // La operación NO es atómica entre Auth y Firestore: un fallo no
      // garantiza que nada haya cambiado, así que dejar la lista con el estado
      // anterior sería mentir.
      expect(_invalidaciones, greaterThan(antes));
      // Y la pantalla sigue usable, no en un estado bloqueado.
      expect(_accion('u-zoe'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_accion('u-zoe')).onPressed,
        isNotNull,
        reason: 'tras el error los botones vuelven a responder',
      );
    });

    testWidgets('un error inesperado (no EquipoException) no revienta la UI',
        (tester) async {
      final espia = _EstadoEspia(error: StateError('boom'));
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-baja'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo cambiar el estado del usuario.'),
        findsOneWidget,
      );
    });
  });

  group('EquipoScreen — doble toque', () {
    testWidgets('mientras hay una operación en vuelo NINGUNA fila responde',
        (tester) async {
      final completer = Completer<void>();
      final espia = _EstadoEspia(completer: completer);
      await _montar(tester, _container(espia: espia));

      await tester.tap(_accion('u-baja'));
      await tester.pump();

      expect(espia.llamadas, 1);
      // El botón pulsado y TAMBIÉN los de las otras filas: dos bajas
      // simultáneas dejarían la lista mostrando un estado que no es el real.
      expect(tester.widget<TextButton>(_accion('u-baja')).onPressed, isNull);
      expect(tester.widget<TextButton>(_accion('u-zoe')).onPressed, isNull);

      await tester.tap(_accion('u-baja'), warnIfMissed: false);
      await tester.pump();
      expect(espia.llamadas, 1, reason: 'el segundo toque no dispara nada');

      completer.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(_accion('u-zoe')).onPressed, isNotNull);
    });
  });

  // MEDIDO: sin este grupo, meter `'rol': 'mesero'` en el payload NO ponía rojo
  // NADA (rotura AI). El servidor lo ignoraría hoy, pero el contrato es que el
  // cliente no tiene palanca sobre lo que el servidor DERIVA — la misma
  // decisión que hace que el alta no mande `restauranteId` siendo admin.
  group('cambiarEstadoAccion — forma del payload', () {
    Future<Map<String, dynamic>> payloadDe({
      required String uid,
      required bool activo,
    }) async {
      Map<String, dynamic>? visto;
      final c = ProviderContainer(overrides: [
        cambiarEstadoCallableProvider.overrideWithValue((payload) async {
          visto = payload;
          return <String, dynamic>{
            'uid': uid,
            'activo': activo,
            'rol': 'mesero',
            'restauranteId': 'demo',
          };
        }),
      ]);
      addTearDown(c.dispose);
      await c.read(cambiarEstadoAccionProvider)(uid: uid, activo: activo);
      return visto!;
    }

    test('viajan EXACTAMENTE `uid` y `activo`, nada más', () async {
      final payload = await payloadDe(uid: 'u-zoe', activo: false);

      expect(payload.keys.toSet(), {'uid', 'activo'},
          reason: 'ni rol ni restaurante: los DERIVA el servidor del objetivo');
      expect(payload['uid'], 'u-zoe');
      expect(payload['activo'], isFalse);
    });

    test('`activo` viaja como booleano, no como cadena', () async {
      // La callable valida `typeof activo === "boolean"` estricto: mandar
      // "false" sería `invalid-argument`, y con un `!!` en el servidor sería
      // peor todavía (reactivaría a quien se quiso dar de baja).
      final payload = await payloadDe(uid: 'u-zoe', activo: true);
      expect(payload['activo'], isA<bool>());
      expect(payload['activo'], isTrue);
    });
  });

  group('mensajeCambioEstadoStaff — traducción de códigos', () {
    test('permission-denied NO revela cuál de los cinco controles fue', () {
      final m = mensajeCambioEstadoStaff('permission-denied', 'lo que sea');
      expect(m, 'No tienes permiso para cambiar el estado de ese usuario.');
      expect(m.contains('lo que sea'), isFalse);
    });

    test('failed-precondition SÍ muestra el mensaje accionable del servidor',
        () {
      const servidor = 'No se puede reactivar: falta el rol en su ficha. '
          'Vuelve a darlo de alta con el mismo correo para repararla.';
      expect(mensajeCambioEstadoStaff('failed-precondition', servidor),
          servidor);
      // Sin mensaje del servidor cae al genérico, nunca a una cadena vacía.
      expect(mensajeCambioEstadoStaff('failed-precondition', '   ').isNotEmpty,
          isTrue);
    });

    test('not-found y unauthenticated tienen texto propio', () {
      expect(mensajeCambioEstadoStaff('not-found'), 'Ese usuario ya no existe.');
      expect(mensajeCambioEstadoStaff('unauthenticated'),
          'Tu sesión expiró. Vuelve a iniciar sesión.');
    });

    test('un código desconocido cae al genérico, jamás al texto del servidor',
        () {
      final m = mensajeCambioEstadoStaff('internal', 'stack trace del SDK');
      expect(m, 'No se pudo cambiar el estado del usuario. Intenta de nuevo.');
      expect(m.contains('stack'), isFalse);
    });
  });

  // La PRIMERA versión de este grupo era una TAUTOLOGÍA: comparaba
  // `mapa['activo'] as bool? ?? true` contra `isTrue` sobre un mapa literal
  // del propio test, sin llegar nunca a `equipoProvider`. Habría seguido verde
  // con el valor por defecto invertido en el provider. Ahora lee de un
  // Firestore falso, que es el camino real.
  group('equipoProvider — compatibilidad con las fichas anteriores a 11-24',
      () {
    Future<List<MiembroEquipo>> leerEquipo(FakeFirebaseFirestore db) async {
      final c = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider
            .overrideWith((ref) async => (role: 'admin_restaurante', rid: 'demo')),
      ]);
      addTearDown(c.dispose);
      return c.read(equipoProvider.future);
    }

    test('sin campo `activo` la persona se lee como ACTIVA', () async {
      // Si la ausencia se leyera como `false`, todo el equipo dado de alta
      // ANTES de este plan aparecería de baja de golpe y el panel mentiría
      // sobre quién puede entrar.
      final db = FakeFirebaseFirestore();
      await db.doc('usuarios/u-viejo').set({
        'nombre': 'Antiguo',
        'email': 'a@demo.com',
        'role': 'mesero',
        'restauranteId': 'demo',
        // sin `activo`: así es como lo dejó `crearUsuarioStaff` hasta 11-24
      });

      expect((await leerEquipo(db)).single.activo, isTrue);
    });

    test('con `activo: false` la persona se lee como DE BAJA', () async {
      // El par del anterior: sin este, poner `=> true` a pelo en el provider
      // dejaría el primero verde y la pantalla no vería una sola baja.
      final db = FakeFirebaseFirestore();
      await db.doc('usuarios/u-baja').set({
        'nombre': 'De Baja',
        'email': 'b@demo.com',
        'role': 'cocina',
        'restauranteId': 'demo',
        'activo': false,
      });

      expect((await leerEquipo(db)).single.activo, isFalse);
    });
  });
}
