import 'package:cloud_functions/cloud_functions.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/equipo/equipo_controller.dart';
import 'package:gri_panel_admin/features/equipo/equipo_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_screen.dart';

/// Degradación honesta de `/equipo` cuando las callables NO están desplegadas
/// (11-26, Tarea 1).
///
/// ── POR QUÉ EXISTE ESTE ARCHIVO ───────────────────────────────────────────
/// El usuario decidió NO activar Blaze (`11-CONTEXT.md`, «Blaze — REVERTIDO»),
/// así que `crearUsuarioStaff` y `cambiarEstadoStaff` se quedan en el repo sin
/// desplegar. Llamarlas contra `p-gri-b5b40` devuelve `not-found`, y hasta este
/// plan el controlador lo traducía como **«El restaurante no existe.»** —
/// heredado del caso en que el `rid` destino no existía. Aplicado a una función
/// que nunca se desplegó, ese texto es sencillamente FALSO y manda al operador
/// a investigar el restaurante equivocado.
///
/// Es exactamente el defecto que cerró el plan 11-23 en el escaneo: un
/// `permission-denied` presentado como «revisa el código de la mesa» costó al
/// usuario una sesión de depuración sobre un QR que era correcto. El criterio
/// que se fijó allí —VERDAD + CAUSA + SIGUIENTE PASO— es el que se aplica aquí.
///
/// ── QUÉ SE PRUEBA Y QUÉ NO ────────────────────────────────────────────────
/// Se prueba la TRADUCCIÓN y la UI. NO se prueba que un proyecto sin la función
/// devuelva `not-found` con el mensaje vacío: eso solo se observa desplegando (o
/// no desplegando) de verdad, y aquí se INYECTA. Ver el SUMMARY, sección
/// «verificado vs afirmado».

/// `FirebaseFunctionsException` tiene el constructor `@protected`; una subclase
/// SÍ puede invocarlo (mismo truco que `equipo_provider_test.dart`).
///
/// ⚠️ `message` es `required String` en el plugin: NO existe un
/// `FirebaseFunctionsException` con `message == null` a nivel de tipos. Lo que
/// el controlador llama «sin mensaje de servidor» es la cadena VACÍA (o solo
/// espacios), que es lo que llega cuando el 404 no trae cuerpo útil.
class _ErrorCallable extends FirebaseFunctionsException {
  _ErrorCallable(String code, {super.message = ''}) : super(code: code);
}

const _equipo = <MiembroEquipo>[
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
];

ProviderContainer _container({
  CambiarEstadoCallable? cambiarEstado,
  CrearStaffCallable? crearStaff,
}) {
  final c = ProviderContainer(
    overrides: [
      claimsProvider
          .overrideWith((ref) async => (role: 'admin_restaurante', rid: 'demo')),
      uidSesionProvider.overrideWithValue('u-yo'),
      equipoProvider.overrideWith((ref) async => _equipo),
      if (cambiarEstado != null)
        cambiarEstadoCallableProvider.overrideWithValue(cambiarEstado),
      if (crearStaff != null)
        crearStaffCallableProvider.overrideWithValue(crearStaff),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _montar(WidgetTester tester, ProviderContainer c) async {
  // La tabla tiene 5 columnas y `minWidth: 720` (criterio de `equipo_baja_test`).
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

void main() {
  // =========================================================================
  // 1. La regresión concreta que cierra este plan
  // =========================================================================

  group('LA REGRESIÓN: "El restaurante no existe" ya no se dice por una función'
      ' que no existe', () {
    test('alta — `not-found` SIN mensaje de servidor NO culpa al restaurante',
        () {
      final m = mensajeAltaStaff('not-found');
      expect(m, isNot(contains('El restaurante no existe')));
      expect(m, mensajeGestionPersonalNoDisponible);
    });

    test('baja — `not-found` SIN mensaje de servidor NO culpa al usuario', () {
      final m = mensajeCambioEstadoStaff('not-found');
      expect(m, isNot(contains('Ese usuario ya no existe')));
      expect(m, mensajeGestionPersonalNoDisponible);
    });

    test('un 404 de transporte («NOT FOUND») tampoco culpa al restaurante', () {
      // El plan manda distinguir por «el mensaje que acompaña al error del
      // servidor cuando exista». Si la plataforma rellenara `message` con el
      // marcador crudo del transporte en vez de dejarlo vacío, la regla
      // ingenua volvería a soltar «El restaurante no existe» — verde por el
      // motivo equivocado. Se normaliza y se reconoce como marcador.
      for (final crudo in <String>['NOT FOUND', 'not_found', ' Not Found ']) {
        expect(mensajeAltaStaff('not-found', crudo),
            mensajeGestionPersonalNoDisponible,
            reason: 'marcador de transporte: "$crudo"');
        expect(mensajeCambioEstadoStaff('not-found', crudo),
            mensajeGestionPersonalNoDisponible,
            reason: 'marcador de transporte: "$crudo"');
      }
    });
  });

  // =========================================================================
  // 2. El texto cumple el criterio de 11-23: verdad + causa + siguiente paso
  // =========================================================================

  group('el texto de indisponibilidad', () {
    const m = mensajeGestionPersonalNoDisponible;

    test('nombra el siguiente paso REAL (el script y su documento)', () {
      expect(m, contains('GESTION-PERSONAL.md'));
      expect(m.toLowerCase(), contains('script'));
    });

    test('dice la CAUSA, no un fallo genérico', () {
      expect(m.toLowerCase(), contains('desplegad'));
    });

    test('NO pide reintentar algo que hoy no puede funcionar', () {
      // Mismo criterio que `failed-precondition` en 11-10: reintentar no lo
      // arregla, así que decirlo manda al operador a un bucle.
      final bajo = m.toLowerCase();
      for (final prohibida in <String>[
        'intenta de nuevo',
        'inténtalo',
        'vuelve a intentar',
        'reintenta',
      ]) {
        expect(bajo, isNot(contains(prohibida)), reason: prohibida);
      }
    });

    test('NO culpa al usuario ni suena a avería', () {
      final bajo = m.toLowerCase();
      for (final prohibida in <String>[
        'no tienes permiso',
        'no existe',
        'error',
        'falló',
        'fallo',
      ]) {
        expect(bajo, isNot(contains(prohibida)), reason: prohibida);
      }
    });
  });

  // =========================================================================
  // 3. `unavailable` e `internal` caen en el mismo grupo, SIN filtrar el crudo
  // =========================================================================

  group('unavailable / internal', () {
    for (final code in const <String>['unavailable', 'internal']) {
      test('$code (alta) da el mensaje de indisponibilidad, no un error crudo',
          () {
        final m = mensajeAltaStaff(code, 'stack interno del SDK');
        expect(m, mensajeGestionPersonalNoDisponible);
        expect(m, isNot(contains('stack')));
      });

      test('$code (baja) da el mensaje de indisponibilidad, no un error crudo',
          () {
        final m = mensajeCambioEstadoStaff(code, 'stack trace del SDK');
        expect(m, mensajeGestionPersonalNoDisponible);
        expect(m, isNot(contains('stack')));
      });
    }
  });

  // =========================================================================
  // 4. Las traducciones que YA eran correctas no se han tocado
  // =========================================================================

  group('las traducciones del día del despliegue siguen intactas', () {
    test('alta — los cinco códigos que la callable sí emite', () {
      expect(mensajeAltaStaff('permission-denied'),
          'No tienes permiso para crear ese usuario.');
      expect(mensajeAltaStaff('invalid-argument', 'Te falta una mayúscula.'),
          'Te falta una mayúscula.');
      expect(mensajeAltaStaff('already-exists'), contains('ya está en uso'));
      expect(mensajeAltaStaff('unauthenticated'),
          'Tu sesión expiró. Vuelve a iniciar sesión.');
      expect(mensajeAltaStaff('failed-precondition'),
          contains('no tiene restaurante asignado'));
    });

    test('alta — `not-found` CON mensaje del servidor sigue siendo el rid', () {
      // La callable lanza `not-found` con `El restaurante ${rid} no existe.`
      // (`functions/src/crear-usuario-staff.js:152`). Ese caso vuelve el día
      // del despliegue y su traducción NO cambia. Se sigue mostrando el texto
      // REDACTADO, nunca el crudo del servidor (T-11-10-04).
      final m = mensajeAltaStaff('not-found', 'El restaurante norte no existe.');
      expect(m, 'El restaurante no existe.');
      expect(m, isNot(contains('norte')));
    });

    test('baja — los tres códigos que la callable sí emite', () {
      expect(mensajeCambioEstadoStaff('permission-denied', 'lo que sea'),
          'No tienes permiso para cambiar el estado de ese usuario.');
      expect(mensajeCambioEstadoStaff('failed-precondition', 'repara la ficha'),
          'repara la ficha');
      expect(mensajeCambioEstadoStaff('unauthenticated'),
          'Tu sesión expiró. Vuelve a iniciar sesión.');
    });

    test('baja — `not-found` CON mensaje del servidor sigue siendo el usuario',
        () {
      // `functions/src/cambiar-estado-staff.js:118`.
      expect(mensajeCambioEstadoStaff('not-found', 'Ese usuario ya no existe.'),
          'Ese usuario ya no existe.');
    });

    test('un código de verdad desconocido sigue cayendo al genérico', () {
      // `aborted` NO lo emite ninguna de las dos callables y NO está en el
      // grupo de indisponibilidad: es el caso «no sé qué pasó», y meterlo en un
      // saco concreto reproduciría el bug con otro texto (criterio de 11-23).
      expect(mensajeAltaStaff('aborted', 'stack interno del SDK'),
          'No se pudo crear el usuario. Intenta de nuevo.');
      expect(mensajeCambioEstadoStaff('aborted', 'stack trace del SDK'),
          'No se pudo cambiar el estado del usuario. Intenta de nuevo.');
    });
  });

  // =========================================================================
  // 5. La pantalla: aviso ANTES de pulsar, y el listado intacto
  // =========================================================================

  group('EquipoScreen', () {
    testWidgets('el aviso es visible ANTES de pulsar nada', (tester) async {
      await _montar(tester, _container());

      final aviso = find.byKey(const Key('equipo-aviso-sin-funciones'));
      expect(aviso, findsOneWidget);
      // Es EL MISMO texto que saldría al pulsar: una sola constante, así que
      // no pueden divergir.
      expect(
        find.descendant(
          of: aviso,
          matching: find.text(mensajeGestionPersonalNoDisponible),
        ),
        findsOneWidget,
      );

      // «Visible» de verdad, no solo presente en el árbol: `find.text` lo
      // encontraría igual dentro de un `Offstage` o con altura cero, y el
      // aviso quedaría sin cumplir su única función. Se comprueba la
      // GEOMETRÍA: ocupa espacio, cabe en el viewport y está ENTRE el botón de
      // alta y la tabla — que es «junto a las acciones de escritura».
      final rAviso = tester.getRect(aviso);
      final rBoton = tester.getRect(find.byKey(const Key('equipo-nuevo')));
      final rTabla = tester.getRect(find.byType(DataTable2));
      expect(rAviso.width, greaterThan(0));
      expect(rAviso.height, greaterThan(0));
      expect(rAviso.top, greaterThanOrEqualTo(0));
      expect(rAviso.bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height));
      expect(rAviso.top, greaterThanOrEqualTo(rBoton.top));
      expect(rAviso.bottom, lessThanOrEqualTo(rTabla.top));
    });

    testWidgets('los botones SIGUEN presentes y pulsables', (tester) async {
      // El día del despliegue no debe haber que tocar nada. Ocultarlos
      // obligaría a volver aquí.
      await _montar(tester, _container());

      final nuevo = find.byKey(const Key('equipo-nuevo'));
      expect(nuevo, findsOneWidget);
      expect(tester.widget<ElevatedButton>(nuevo).onPressed, isNotNull);

      final accion = find.byKey(const Key('equipo-accion-u-zoe'));
      expect(accion, findsOneWidget);
      expect(tester.widget<TextButton>(accion).onPressed, isNotNull);
    });

    testWidgets('el listado sigue mostrando nombre, correo, rol y estado',
        (tester) async {
      // El listado es una lectura de Firestore, habilitada al desplegar las
      // reglas el 2026-08-20: este plan NO lo toca y el aviso no puede taparlo.
      await _montar(tester, _container());

      expect(find.text('Zoe Mesera'), findsOneWidget);
      expect(find.text('zoe@demo.com'), findsOneWidget);
      expect(find.text('Mesero'), findsOneWidget);
      expect(find.text('Activo'), findsNWidgets(2));
    });

    testWidgets(
        'pulsar Desactivar con la callable ausente muestra el mensaje honesto',
        (tester) async {
      // Se inyecta la CALLABLE, no la acción: así el mensaje lo produce el
      // controlador REAL, que es el camino de producción. Overridear la acción
      // saltaría justo la traducción que este plan arregla.
      final c = _container(
        cambiarEstado: (_) async => throw _ErrorCallable('not-found'),
      );
      await _montar(tester, c);

      await tester.tap(find.byKey(const Key('equipo-accion-u-zoe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('equipo-baja-confirmar')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBar, mensajeGestionPersonalNoDisponible),
          findsOneWidget);
      // Y NO el texto viejo, que mandaba a investigar otra cosa.
      expect(find.textContaining('Ese usuario ya no existe'), findsNothing);
    });

    testWidgets('el alta con la callable ausente muestra el mismo mensaje',
        (tester) async {
      final accion = _container(
        crearStaff: (_) async => throw _ErrorCallable('not-found'),
      ).read(crearStaffAccionProvider);

      await expectLater(
        () => accion(
          nombre: 'Nadie',
          email: 'nadie@demo.com',
          password: 'Abcdef12',
          rol: 'mesero',
        ),
        throwsA(isA<EquipoException>().having((e) => e.message, 'message',
            mensajeGestionPersonalNoDisponible)),
      );
    });
  });
}
