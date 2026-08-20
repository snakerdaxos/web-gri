// ============================================================================
// GRI — EL PANEL TAMPOCO PUEDE MENTIR ANTE UN STREAM ROTO (plan 11-33).
//
// El incidente lo reportó el usuario en el CLIENTE («ver pedido se queda
// cargando»), pero la causa raíz es de la librería y por tanto vale para las
// dos apps: Riverpod 3 reintenta cualquier excepción diez veces con backoff y,
// mientras reintenta, el estado es `AsyncLoading` CON el error dentro
// (`core/async_fallo.dart` lo documenta con las líneas exactas). `when` mira
// `isLoading` primero, así que pinta la rama de carga.
//
// En el panel eso no produce solo un spinner: produce **cifras falsas**, que
// es peor. Este archivo cubre los tres casos donde el fallo se disfrazaba de
// un dato bueno:
//
//   1. LA CUENTA DE LA MESA. El importe se leía con `.value ?? const []`, así
//      que un listener denegado daba lista vacía → `cuentaDeMesa` sumaba 0 →
//      el mesero leía «0 $» y cobraba cero. 11-32 tuvo el cuidado de mostrar
//      un GUION mientras carga, precisamente para que nadie leyera un cero
//      como «esta mesa no debe nada»; la rama de ERROR se saltaba ese cuidado.
//   2. LOS AVISOS DE CUENTA. `.value ?? const []` → «ninguna mesa ha pedido la
//      cuenta». Las mesas que esperan para pagar quedan invisibles.
//   3. EL HISTORIAL DE UN CLIENTE. `error: (e, _) => const _SinPedidos()` →
//      «este cliente no tiene pedidos». Es una afirmación sobre los datos
//      hecha desde un fallo que no los pudo leer.
//
// Las aserciones son sobre la CADENA que leería el mesero. Un `findsOneWidget`
// sobre un widget de error pasaría en verde con el texto equivocado dentro.
// ============================================================================

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/async_fallo.dart';
import 'package:gri_panel_admin/core/firebase_error_mapper.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/cocina/cocina_screen.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';

import '../helpers/firebase_fakes.dart';

FirebaseException _denegado() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

FirebaseException _sinRed() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

const _mesa = 'GRI-MESA-demo-003';

String _texto(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

Future<FakeFirebaseFirestore> _conSesionQuePidioLaCuenta() async {
  final db = await buildFakeFirestoreConSeed();
  await db.doc('mesas/$_mesa').update({'estado': 'ocupada'});
  await db.doc('sesiones/$_mesa').set({
    'restauranteId': 'demo',
    'mesaId': _mesa,
    'usuarioId': 'uid-cli',
    'estado': 'activa',
    'cuentaSolicitada': true,
    'inicioAt': DateTime(2026, 8, 20, 19, 30),
  });
  return db;
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

/// El scope lleva `retry: reintentoGri` porque es lo que lleva `main.dart`
/// en producción. Importa para el caso del importe: con el reintento POR
/// DEFECTO de Riverpod el provider pasa ~38 s en `AsyncLoading`, la fila
/// muestra su guion y el cero falso no llega a verse dentro de un test. Con
/// la política real el error es inmediato y el `.value ?? const []` enseña
/// el cero de verdad — que es lo que ve el mesero.
Widget _cocina(FakeFirebaseFirestore db, List<Override> extra) => ProviderScope(
      retry: reintentoGri,
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith((ref) async => (role: 'mesero', rid: 'demo')),
        ...extra,
      ],
      child: const MaterialApp(home: Scaffold(body: CocinaScreen())),
    );

/// El importe por mesa vive en la HOJA que abre el badge, no en el cuerpo de
/// la pantalla: hay que tocarlo o el caso pasaria en verde sin haber mirado
/// nunca la cifra.
Future<void> _abrirHojaDeCuentas(WidgetTester tester) async {
  final badge = find.textContaining('pidió la cuenta');
  expect(badge, findsOneWidget,
      reason: 'sin el badge no hay hoja que abrir y el caso no probaría nada');
  await tester.tap(badge);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════════════════════
  // 1. DINERO: un listener roto NO puede leerse como «esta mesa debe 0»
  // ══════════════════════════════════════════════════════════════════════
  group('la cuenta de la mesa ante un fallo', () {
    testWidgets('NO muestra un cero: el cero se leería como «no debe nada»',
        (tester) async {
      final db = await _conSesionQuePidioLaCuenta();
      await _pump(
        tester,
        _cocina(db, [
          pedidosServidosMesaProvider(_mesa)
              .overrideWith((ref) => Stream<List<PedidoStaff>>.error(_denegado())),
        ]),
      );

      await _abrirHojaDeCuentas(tester);
      final texto = _texto(tester);
      // `formatCOP(0)` es «0 $» con espacio duro. Que aparezca significa que
      // el mesero está viendo una cifra INVENTADA por un `?? const []`.
      expect(texto, isNot(contains('0\u00A0\$')),
          reason: 'un fallo de lectura no puede renderizarse como importe 0');
      // Y hay que DECIR que la cifra no se pudo calcular.
      expect(texto, contains('Tu cuenta no puede ver la cuenta de la mesa'));
    });

    testWidgets('sin red dice otra cosa: las dos causas no se aplastan',
        (tester) async {
      final db = await _conSesionQuePidioLaCuenta();
      await _pump(
        tester,
        _cocina(db, [
          pedidosServidosMesaProvider(_mesa)
              .overrideWith((ref) => Stream<List<PedidoStaff>>.error(_sinRed())),
        ]),
      );

      await _abrirHojaDeCuentas(tester);
      final texto = _texto(tester);
      expect(texto, isNot(contains('0\u00A0\$')));
      expect(texto, contains('No pudimos conectar con el servidor'));
      expect(texto, isNot(contains('Tu cuenta no puede')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 2. Los avisos de cuenta no pueden desaparecer en silencio
  // ══════════════════════════════════════════════════════════════════════
  testWidgets('un fallo en los avisos de cuenta se ve; no queda en «ninguna»',
      (tester) async {
    final db = await _conSesionQuePidioLaCuenta();
    await _pump(
      tester,
      _cocina(db, [
        avisoCuentaProvider
            .overrideWith((ref) => Stream<List<AvisoCuenta>>.error(_denegado())),
      ]),
    );

    expect(_texto(tester), contains('los avisos de cuenta'),
        reason: 'una mesa esperando para pagar no puede quedar invisible');
  });

  // ══════════════════════════════════════════════════════════════════════
  // 3. La cola de cocina: mensaje con causa, y sin spinner
  // ══════════════════════════════════════════════════════════════════════
  group('la cola de cocina ante un fallo', () {
    testWidgets('permiso denegado: no gira y habla de la cuenta',
        (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(
        tester,
        _cocina(db, [
          pedidosStaffProvider
              .overrideWith((ref) => Stream<List<PedidoStaff>>.error(_denegado())),
        ]),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final texto = _texto(tester);
      expect(texto, contains('Tu cuenta no puede ver los pedidos de la cocina'));
      expect(texto, isNot(contains('Error cargando pedidos')),
          reason: 'el texto mudo que servía igual para cualquier causa');
    });

    testWidgets('sin red: habla de la conexión', (tester) async {
      final db = await buildFakeFirestoreConSeed();
      await _pump(
        tester,
        _cocina(db, [
          pedidosStaffProvider
              .overrideWith((ref) => Stream<List<PedidoStaff>>.error(_sinRed())),
        ]),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_texto(tester), contains('No pudimos conectar con el servidor'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 4. El clasificador del panel y el del cliente NO pueden derivar
  // ══════════════════════════════════════════════════════════════════════
  //
  // Las dos apps tienen su copia (no comparten paquete: convención del repo
  // desde la fase 10). El MISMO vector se prueba en las dos suites; si una
  // copia reclasifica un código, su caso cae. El vector gemelo vive en
  // `app_cliente/test/core/firebase_error_mapper_test.dart`.
  group('paridad de clasificación con app_cliente', () {
    test('el vector compartido de códigos se clasifica igual', () {
      FirebaseException fb(String code) =>
          FirebaseException(plugin: 'cloud_firestore', code: code);

      expect(clasificarFallo(fb('permission-denied')),
          CausaFallo.permisoDenegado);
      expect(clasificarFallo(fb('unauthenticated')), CausaFallo.permisoDenegado);
      expect(clasificarFallo(fb('unavailable')), CausaFallo.sinConexion);
      expect(clasificarFallo(fb('deadline-exceeded')), CausaFallo.sinConexion);
      expect(clasificarFallo(fb('cancelled')), CausaFallo.sinConexion);
      expect(clasificarFallo(fb('internal')), CausaFallo.sinConexion);
      expect(clasificarFallo(fb('not-found')), CausaFallo.noEncontrado);
      // DELIBERADO (decisión de 11-23): ni de red ni de permisos.
      expect(clasificarFallo(fb('aborted')), CausaFallo.desconocido);
      expect(clasificarFallo(fb('failed-precondition')), CausaFallo.desconocido);
      expect(clasificarFallo(StateError('x')), CausaFallo.desconocido);
    });

    test('CRITERIO 1: un permiso denegado nunca culpa a la red', () {
      for (final c in Contexto.values) {
        final t = mensajeDe(CausaFallo.permisoDenegado, contexto: c)
            .toLowerCase();
        expect(t, contains('cuenta'));
        expect(t, isNot(contains('conexión')));
        expect(t, isNot(contains('internet')));
        // T-11-23-01: no nombra la regla ni el rol que haría falta.
        for (final rol in ['mesero', 'cocina', 'admin_restaurante', 'super_admin']) {
          expect(t, isNot(contains(rol)), reason: 'no revela el rol exigido');
        }
      }
    });

    test('CRITERIO 2: desconocido no afirma ninguna causa concreta', () {
      for (final c in Contexto.values) {
        final t = mensajeDe(CausaFallo.desconocido, contexto: c).toLowerCase();
        expect(t, isNot(contains('conexión')));
        expect(t, isNot(contains('permiso')));
        expect(t, isNot(contains('tu cuenta')));
      }
    });

    test('NO CONFUSIÓN: cada causa produce un texto distinto', () {
      for (final c in Contexto.values) {
        final textos =
            CausaFallo.values.map((x) => mensajeDe(x, contexto: c)).toSet();
        expect(textos.length, CausaFallo.values.length,
            reason: '$c aplasta dos causas en el mismo mensaje');
      }
    });
  });

  group('reintentoGri (copia del panel)', () {
    test('idéntico al del cliente: solo la red se reintenta, 3 veces', () {
      expect(reintentoGri(0, _sinRed()), const Duration(milliseconds: 200));
      expect(reintentoGri(2, _sinRed()), const Duration(milliseconds: 800));
      expect(reintentoGri(3, _sinRed()), isNull);
      expect(reintentoGri(0, _denegado()), isNull);
      expect(reintentoGri(0, StateError('bug')), isNull);
    });
  });
}
