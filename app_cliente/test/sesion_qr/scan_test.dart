import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/firebase_error_mapper.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/state_machines.dart';
import 'package:gri_cliente/features/sesion_qr/scan_screen.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';

/// Sesión QR sobre Firestore (Task 1 de 10-04): abrirSesion tx determinista
/// sobre sesiones/{mesaId}, concurrencia doble-apertura (MIGRA-06), y el
/// stream del doc como banner vivo. Todo contra fakes in-memory.

const _mesa = 'GRI-MESA-demo-001';

/// Espera activa hasta que [cond] sea true (los snapshots de los fakes
/// emiten en microtareas — polling breve en vez de tiempos fijos).
Future<void> _hasta(bool Function() cond) async {
  final fin = DateTime.now().add(const Duration(seconds: 5));
  while (!cond()) {
    if (DateTime.now().isAfter(fin)) {
      fail('timeout esperando condición del stream');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  // ── Unidad: la tx de abrirSesion ─────────────────────────────────────────

  test('mesa disponible → sesión activa con dueño y mesa pasa a ocupada',
      () async {
    final db = await buildFakeFirestoreConSeed();

    final sesion = await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    expect(sesion.estado, 'activa');
    expect(sesion.usuarioId, 'uid-a');
    expect(sesion.mesaId, _mesa);
    expect(sesion.mesaNumero, 1, reason: 'numero leído de la mesa en la tx');

    final doc = await db.doc('sesiones/$_mesa').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['estado'], 'activa');
    expect(doc.data()!['usuarioId'], 'uid-a');
    expect(doc.data()!['mesaId'], _mesa, reason: 'mesaId == docId (rules)');
    expect(doc.data()!['cuentaSolicitada'], false);

    final mesa = await db.doc('mesas/$_mesa').get();
    expect(mesa.data()!['estado'], 'ocupada');
  });

  test('CONCURRENCIA (MIGRA-06): dos abrirSesion simultáneos → 1 gana, 1 "Mesa ocupada"',
      () async {
    final db = await buildFakeFirestoreConSeed();

    final resultados = await Future.wait<String>([
      abrirSesion(db, uid: 'uid-a', codigoQR: _mesa)
          .then((_) => 'ok')
          .catchError((_) => 'error'),
      abrirSesion(db, uid: 'uid-b', codigoQR: _mesa)
          .then((_) => 'ok')
          .catchError((_) => 'error'),
    ]);
    // .catchError tapa el mensaje — repetimos por separado para assertearlo.
    final perdedor = abrirSesion(db, uid: 'uid-c', codigoQR: _mesa);

    expect(resultados.where((r) => r == 'ok').length, 1,
        reason: 'exactamente UNA sesión se crea');
    await expectLater(perdedor,
        throwsA(isA<SesionException>().having((e) => e.message, 'message', 'Mesa ocupada')));

    final doc = await db.doc('sesiones/$_mesa').get();
    expect(doc.data()!['estado'], 'activa');
    expect(doc.data()!['usuarioId'], anyOf('uid-a', 'uid-b'));
    final mesa = await db.doc('mesas/$_mesa').get();
    expect(mesa.data()!['estado'], 'ocupada');
  });

  test('mesa en limpieza → TransicionInvalidaException (mensaje controlado en el controller)',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/$_mesa').update({'estado': 'limpieza'});

    await expectLater(
      abrirSesion(db, uid: 'uid-a', codigoQR: _mesa),
      throwsA(isA<TransicionInvalidaException>()),
    );

    // El controller lo traduce a mensaje user-friendly (contrato de la UI).
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'uid-a')),
    ]);
    addTearDown(container.dispose);

    final error = await container
        .read(sesionControllerProvider.notifier)
        .abrir(_mesa)
        .then<Object?>((s) => s, onError: (Object e) => e);
    expect(error, isA<SesionException>());
    expect((error as SesionException).message,
        'La mesa no está disponible en este momento');
  });

  // CAMBIADO EN 11-23: antes este caso afirmaba 'Código de mesa inválido', el
  // MISMO texto que recibía un código con el formato roto. Eran dos causas
  // distintas con un solo mensaje; ahora cada una tiene el suyo.
  test('código BIEN FORMADO pero inexistente (GRI-MESA-demo-999) → mensaje de mesa inexistente',
      () async {
    final db = await buildFakeFirestoreConSeed();

    await expectLater(
      abrirSesion(db, uid: 'uid-a', codigoQR: 'GRI-MESA-demo-999'),
      throwsA(isA<SesionException>().having((e) => e.message, 'message',
          mensajeDe(CausaFallo.noEncontrado, contexto: Contexto.abrirMesa))),
    );

    final sesiones = await db.collection('sesiones').get();
    expect(sesiones.docs, isEmpty, reason: 'sin doc creado');
  });

  test('código con formato ROTO → mensaje de formato, DISTINTO del de mesa inexistente',
      () async {
    final db = await buildFakeFirestoreConSeed();

    // Lo que devuelve el QR de otra app: una URL, no un código de mesa. Por la
    // cámara (`_onDetect`) esto entra SIN pasar por el validator del campo
    // manual, así que la comprobación tiene que vivir en el dominio.
    for (final basura in <String>[
      'https://ejemplo.com/mesa/1',
      'GRI-MESA-001', // le falta el slug del restaurante
      'gri-mesa-demo-001', // minúsculas
      'GRI-MESA-demo-1', // sin los tres dígitos
      '',
    ]) {
      await expectLater(
        abrirSesion(db, uid: 'uid-a', codigoQR: basura),
        throwsA(isA<SesionException>().having(
            (e) => e.message,
            'message',
            mensajeDe(CausaFallo.formatoInvalido,
                contexto: Contexto.abrirMesa))),
        reason: 'código rechazado: $basura',
      );
    }

    expect(
      mensajeDe(CausaFallo.formatoInvalido, contexto: Contexto.abrirMesa),
      isNot(mensajeDe(CausaFallo.noEncontrado, contexto: Contexto.abrirMesa)),
      reason: 'formato roto y mesa inexistente NO son la misma cosa',
    );
  });

  // ── El incidente real: permission-denied y backend inalcanzable ──────────

  test('permission-denied de Firestore → mensaje sobre la CUENTA, no sobre el código',
      () async {
    final db = await buildFakeFirestoreConSeed();
    // Inyección en la lectura de `sesiones/{mesa}` dentro de la tx. En
    // producción la denegación del incidente venía del `create` sobre
    // `sesiones` (la regla exige `isCliente()` y la cuenta era `super_admin`);
    // el fake no puede lanzar desde el `tx.set` sin dejar un future huérfano,
    // así que se inyecta en la lectura de la MISMA colección. Al clasificador
    // le da igual qué llamada lanzó: lo que clasifica es el `code`.
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied'));

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'uid-a')),
    ]);
    addTearDown(container.dispose);

    final error = await container
        .read(sesionControllerProvider.notifier)
        .abrir(_mesa)
        .then<Object?>((s) => s, onError: (Object e) => e);

    expect(error, isA<SesionException>());
    final mensaje = (error as SesionException).message;
    expect(mensaje,
        mensajeDe(CausaFallo.permisoDenegado, contexto: Contexto.abrirMesa));
    // La regresión, afirmada donde nace:
    expect(mensaje.toLowerCase(), isNot(contains('código')));
    expect(mensaje.toLowerCase(), isNot(contains('qr')));
    expect(mensaje.toLowerCase(), isNot(contains('verifica')));
  });

  test('unavailable de Firestore → mensaje sobre la CONEXIÓN', () async {
    final db = await buildFakeFirestoreConSeed();
    whenCalling(Invocation.method(#get, null)).on(db.doc('mesas/$_mesa'))
        .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'uid-a')),
    ]);
    addTearDown(container.dispose);

    final error = await container
        .read(sesionControllerProvider.notifier)
        .abrir(_mesa)
        .then<Object?>((s) => s, onError: (Object e) => e);

    expect(error, isA<SesionException>());
    expect((error as SesionException).message,
        mensajeDe(CausaFallo.sinConexion, contexto: Contexto.abrirMesa));
  });

  test('T-11-23-04: el catch DEJA TRAZA del fallo (ningún error queda mudo)',
      () async {
    // VERDE CAZADA (rotura F): borrar el `debugPrint` entero dejaba la suite
    // en verde. La mitigación del registro de amenazas estaba AFIRMADA, no
    // verificada. `debugPrint` es una variable global reasignable, así que se
    // intercepta de verdad.
    final trazas = <String>[];
    final original = debugPrint;
    debugPrint = (String? mensaje, {int? wrapWidth}) =>
        trazas.add(mensaje ?? '');
    addTearDown(() => debugPrint = original);

    final db = await buildFakeFirestoreConSeed();
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied'));

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'uid-a')),
    ]);
    addTearDown(container.dispose);

    await container
        .read(sesionControllerProvider.notifier)
        .abrir(_mesa)
        .then<Object?>((s) => s, onError: (Object e) => e);

    final todo = trazas.join('\n');
    expect(todo, contains('permission-denied'),
        reason: 'la causa REAL tiene que quedar en el log del desarrollador,'
            ' aunque el usuario vea un texto amable');
    expect(todo, contains('CausaFallo.permisoDenegado'),
        reason: 'y también CÓMO se clasificó, para poder auditar el mapeo');
  });

  test('LAS CINCO CAUSAS dan CINCO mensajes distintos a través del controller',
      () async {
    // No es el test del mapeador (aquel compara la tabla consigo misma): aquí
    // cada mensaje se OBTIENE ejecutando el flujo real con su causa montada.
    Future<String> mensajeDelFlujo(
      Future<dynamic> Function() montar,
      String codigo,
    ) async {
      final db = await montar();
      final container = ProviderContainer(overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth(uid: 'uid-a')),
      ]);
      addTearDown(container.dispose);
      final error = await container
          .read(sesionControllerProvider.notifier)
          .abrir(codigo)
          .then<Object?>((s) => s, onError: (Object e) => e);
      expect(error, isA<SesionException>(), reason: 'código $codigo');
      return (error as SesionException).message;
    }

    final formato = await mensajeDelFlujo(
        buildFakeFirestoreConSeed, 'https://ejemplo.com/mesa/1');
    final inexistente =
        await mensajeDelFlujo(buildFakeFirestoreConSeed, 'GRI-MESA-demo-999');
    final noDisponible = await mensajeDelFlujo(() async {
      final db = await buildFakeFirestoreConSeed();
      await db.doc('mesas/$_mesa').update({'estado': 'limpieza'});
      return db;
    }, _mesa);
    final permiso = await mensajeDelFlujo(() async {
      final db = await buildFakeFirestoreConSeed();
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('sesiones/$_mesa'))
          .thenThrow(FirebaseException(
              plugin: 'cloud_firestore', code: 'permission-denied'));
      return db;
    }, _mesa);
    final red = await mensajeDelFlujo(() async {
      final db = await buildFakeFirestoreConSeed();
      whenCalling(Invocation.method(#get, null)).on(db.doc('mesas/$_mesa'))
          .thenThrow(FirebaseException(
              plugin: 'cloud_firestore', code: 'unavailable'));
      return db;
    }, _mesa);

    final mensajes = <String, String>{
      'formatoInvalido': formato,
      'noEncontrado': inexistente,
      'noDisponible': noDisponible,
      'permisoDenegado': permiso,
      'sinConexion': red,
    };
    final claves = mensajes.keys.toList();
    for (var i = 0; i < claves.length; i++) {
      for (var j = i + 1; j < claves.length; j++) {
        expect(mensajes[claves[i]], isNot(mensajes[claves[j]]),
            reason: '${claves[i]} y ${claves[j]} comparten mensaje');
      }
    }
    // Y ninguno de los dos que NO son culpa del usuario habla del código.
    for (final clave in ['permisoDenegado', 'sinConexion']) {
      final texto = mensajes[clave]!.toLowerCase();
      expect(texto, isNot(contains('código')), reason: clave);
      expect(texto, isNot(contains('qr')), reason: clave);
      expect(texto, isNot(contains('verifica')), reason: clave);
    }
  });

  test('sesión cerrada previa en esa mesa → se permite re-abrir', () async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('sesiones/GRI-MESA-demo-002').set({
      'restauranteId': 'demo',
      'mesaId': 'GRI-MESA-demo-002',
      'usuarioId': 'otro-uid',
      'estado': 'cerrada',
      'cuentaSolicitada': true,
      'inicioAt': DateTime(2026, 8, 1, 12),
    });

    final sesion =
        await abrirSesion(db, uid: 'uid-a', codigoQR: 'GRI-MESA-demo-002');

    expect(sesion.estado, 'activa');
    final doc = await db.doc('sesiones/GRI-MESA-demo-002').get();
    expect(doc.data()!['estado'], 'activa');
    expect(doc.data()!['usuarioId'], 'uid-a');
    expect(doc.data()!['cuentaSolicitada'], false,
        reason: 'el set reemplaza el doc (nueva sesión limpia)');
    final mesa = await db.doc('mesas/GRI-MESA-demo-002').get();
    expect(mesa.data()!['estado'], 'ocupada');
  });

  test('stream sesionProvider refleja cuentaSolicitada=true de otro writer',
      () async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final emisiones = <SesionMesa>[];
    container.listen(
      sesionProvider(_mesa),
      (_, next) => next.whenData((s) => emisiones.add(s)),
    );

    await _hasta(() => emisiones.isNotEmpty);
    expect(emisiones.last.cuentaSolicitada, false);
    expect(emisiones.last.estado, 'activa');
    expect(emisiones.last.restauranteNombre, 'Restaurante Demo GRI',
        reason: 'enriquecido client-side (join)');
    expect(emisiones.last.mesaNumero, 1);

    // Otro writer (staff/mesero flip) — el stream lo refleja solo.
    await db.doc('sesiones/$_mesa').update({'cuentaSolicitada': true});

    await _hasta(() => emisiones.last.cuentaSolicitada);
    expect(emisiones.last.cuentaSolicitada, true);
  });

  // ── Widgets: ScanScreen (input manual de primera clase) ─────────────────

  Widget wrapFake(FakeTestFirestoreBuilder builder) {
    final router = GoRouter(
      initialLocation: '/sesion/scan',
      routes: [
        GoRoute(path: '/sesion/scan', builder: (_, _) => const ScanScreen()),
        GoRoute(
          path: '/mesa',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('MESA_PAGE'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(builder.db),
        firebaseAuthProvider.overrideWithValue(builder.auth ?? mockAuth()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('render inicial: sin cámara, input manual y hint del nuevo formato',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('Escanear con cámara'), findsOneWidget);
    expect(find.text('O escribe el código de la mesa'), findsOneWidget);
    expect(find.text('GRI-MESA-demo-001'), findsOneWidget,
        reason: 'hint con slug de restaurante');
  });

  testWidgets('GRI-MESA-001 (sin slug) queda bloqueado por el validator',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'GRI-MESA-001');
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();

    expect(find.textContaining('formato GRI-MESA-demo-001'), findsOneWidget);
    // Sin navegación.
    expect(find.text('MESA_PAGE'), findsNothing);
  });

  testWidgets('GRI-MESA-demo-001 válido → sesión abierta (Mesa 1) + navegación',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), _mesa);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mesa 1'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsOneWidget);

    final doc = await db.doc('sesiones/$_mesa').get();
    expect(doc.data()!['usuarioId'], 'test-uid');
  });

  testWidgets('mesa ocupada por sesión ajena → SnackBar "Mesa ocupada", sin navegar',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('sesiones/$_mesa').set({
      'restauranteId': 'demo',
      'mesaId': _mesa,
      'usuarioId': 'otro-uid',
      'estado': 'activa',
      'cuentaSolicitada': false,
    });

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), _mesa);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mesa ocupada'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);
    expect(find.text('Abrir mesa'), findsOneWidget, reason: 'permite reintentar');
  });

  testWidgets('mesa en limpieza → mensaje controlado (sin crash ni navegación)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('mesas/$_mesa').update({'estado': 'limpieza'});

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), _mesa);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.text('La mesa no está disponible en este momento'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);
  });

  // ── 11-23: la pantalla ante las causas que NO son culpa del código ───────

  /// Junta el `data` de TODOS los `Text` del árbol. Mismo criterio que el 404
  /// de 11-09: no se mira el widget que uno espera, se mira TODO lo que el
  /// usuario puede leer — incluidos el AppBar, el hint del campo y el
  /// SnackBar.
  String textoVisible(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' ⏐ ');

  Future<void> intentarAbrir(WidgetTester tester, String codigo) async {
    await tester.enterText(find.byType(TextFormField), codigo);
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('permission-denied → la pantalla habla de la CUENTA y NO dice código, QR ni verifica',
      (tester) async {
    // El incidente real, reproducido de punta a punta: cuenta sin permiso para
    // crear sesión (era `super_admin`), QR perfectamente correcto.
    final db = await buildFakeFirestoreConSeed();
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied'));

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();
    await intentarAbrir(tester, _mesa);

    expect(
        find.text(mensajeDe(CausaFallo.permisoDenegado,
            contexto: Contexto.abrirMesa)),
        findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);

    // LA REGRESIÓN. El usuario perdió el tiempo revisando un QR correcto
    // porque la pantalla le habló del código. Ya no puede volver a pasar: se
    // afirma sobre TODO el texto visible, no solo sobre el SnackBar.
    final visible = textoVisible(tester).toLowerCase();
    expect(visible, isNot(contains('verifica')));
    expect(visible, isNot(contains('no pudimos abrir la mesa')));
    expect(visible, contains('cuenta'));
  });

  testWidgets('permission-denied → el botón vuelve y se puede reintentar',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied'));

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();
    await intentarAbrir(tester, _mesa);

    final boton = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Abrir mesa'), matching: find.byType(ElevatedButton)));
    expect(boton.onPressed, isNotNull, reason: 'habilitado para reintentar');

    // Segundo intento: mismo mensaje, sin quedarse colgado.
    await intentarAbrir(tester, _mesa);
    expect(
        find.text(mensajeDe(CausaFallo.permisoDenegado,
            contexto: Contexto.abrirMesa)),
        findsWidgets);
  });

  testWidgets('unavailable → la pantalla habla de la CONEXIÓN', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    whenCalling(Invocation.method(#get, null)).on(db.doc('mesas/$_mesa'))
        .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();
    await intentarAbrir(tester, _mesa);

    expect(
        find.text(
            mensajeDe(CausaFallo.sinConexion, contexto: Contexto.abrirMesa)),
        findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);
    final visible = textoVisible(tester).toLowerCase();
    expect(visible, isNot(contains('verifica')));
  });

  testWidgets('mesa inexistente → la pantalla dice que la mesa no existe, no que el código esté mal',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();
    await intentarAbrir(tester, 'GRI-MESA-demo-999');

    expect(
        find.text(
            mensajeDe(CausaFallo.noEncontrado, contexto: Contexto.abrirMesa)),
        findsOneWidget);
    expect(find.text('Código de mesa inválido'), findsNothing,
        reason: 'el mensaje viejo, que confundía las dos causas, ya no existe');
    expect(find.text('MESA_PAGE'), findsNothing);
  });

  testWidgets('el validator del campo y el dominio comparten la MISMA regla de formato',
      (tester) async {
    // VERDE CAZADA (rotura I): `_codigoRegExp = codigoMesaRegExp` es una
    // afirmación, no una verificación — desandarla y volver a escribir la
    // expresión a mano dejaba la suite ENTERA en verde, porque ningún caso
    // usaba un slug con guion y ese es justo el carácter que se pierde al
    // copiarla mal (`[a-z0-9-]+` -> `[a-z0-9]+`).
    //
    // Aquí el código es BIEN FORMADO (slug `mi-resto`, con guion) pero la mesa
    // no existe: si la pantalla y el dominio comparten la regla, el usuario
    // llega al mensaje de «mesa inexistente». Si divergen, se queda atascado
    // en el error del campo.
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(wrapFake(FakeTestFirestoreBuilder(db: db)));
    await tester.pumpAndSettle();
    await intentarAbrir(tester, 'GRI-MESA-mi-resto-001');

    expect(find.textContaining('El código tiene formato'), findsNothing,
        reason: 'el validator NO debe rechazar un slug con guion');
    expect(
        find.text(
            mensajeDe(CausaFallo.noEncontrado, contexto: Contexto.abrirMesa)),
        findsOneWidget,
        reason: 'llegó al dominio, que es quien sabe que esa mesa no existe');
  });

  testWidgets('un fallo CRUDO que se salta al controller no sale como "Error de conexión"',
      (tester) async {
    // El `catch (e)` de scan_screen es la última red: solo se alcanza si algo
    // lanza FUERA del try de `SesionController.abrir` (hoy el controller ya
    // envuelve todo en SesionException, así que es defensa en profundidad).
    // Se fuerza sustituyendo el controller por uno que lanza el error crudo.
    final db = await buildFakeFirestoreConSeed();
    final router = GoRouter(
      initialLocation: '/sesion/scan',
      routes: [
        GoRoute(path: '/sesion/scan', builder: (_, _) => const ScanScreen()),
        GoRoute(
          path: '/mesa',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('MESA_PAGE'))),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        sesionControllerProvider.overrideWith(ControllerQueLanzaCrudo.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await intentarAbrir(tester, _mesa);

    expect(find.text('Error de conexión. Intenta de nuevo.'), findsNothing,
        reason: 'el mensaje ciego que afirmaba una causa sin saberla');
    expect(
        find.text(mensajeDe(CausaFallo.permisoDenegado,
            contexto: Contexto.abrirMesa)),
        findsOneWidget);
  });
}

/// Controller que lanza el error CRUDO de Firebase sin envolverlo — la única
/// forma de alcanzar el `catch (e)` genérico de `ScanScreen`.
class ControllerQueLanzaCrudo extends SesionController {
  @override
  Future<SesionMesa> abrir(String codigoQr) async {
    throw FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied');
  }
}

/// Envoltorio mínimo para inyectar db+auth al _wrap de los widget tests.
class FakeTestFirestoreBuilder {
  FakeTestFirestoreBuilder({required this.db, this.auth});

  final dynamic db;
  final dynamic auth;
}
