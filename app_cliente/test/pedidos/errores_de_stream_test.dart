// ============================================================================
// GRI — UN STREAM QUE FALLA NO ES UN STREAM QUE CARGA (plan 11-33).
//
// ── EL INCIDENTE ───────────────────────────────────────────────────────────
// El usuario, con un build anterior al arreglo de `usuarioId` (11-28), abrió
// «ver pedido» y la pantalla se quedó GIRANDO. Para siempre. No dijo qué
// pasaba ni ofreció nada que hacer.
//
// La causa NO era que faltara una rama `error:` en la pantalla — la tenía
// desde 11-09. Era que el error nunca LLEGABA a la pantalla:
//
//     final sesion = ref.watch(sesionActualProvider).value;   // <— descarta el error
//     if (sesion == null || uid == null) {
//       yield* const Stream<List<Pedido>>.empty();            // <— cierra sin emitir
//       return;
//     }
//
// `.value` sobre un `AsyncError` devuelve `null`, así que un listener DENEGADO
// de `sesiones` es indistinguible de «este usuario no tiene mesa abierta». Y
// un `async*` que hace `yield*` de un stream vacío y retorna **cierra sin
// emitir nunca**: Riverpod deja ese provider en `AsyncLoading` de por vida.
// Resultado: `pedidosAsync.when(loading: spinner)` para siempre.
//
// Es la CUARTA vez en el proyecto que un fallo se disfraza de otra cosa (el
// escáner culpaba al QR, el panel decía «el restaurante no existe», el
// asistente de reservas decía «ese horario acaba de ser reservado»). El
// barrido de 11-29 revisó los 36 `catch` de las dos apps y no podía ver éste:
// **un Stream que falla no pasa por ningún `catch`**.
//
// ── QUÉ AFIRMA ESTE ARCHIVO ────────────────────────────────────────────────
// 1. Que ante un fallo del stream la pantalla NO muestra un indicador de
//    progreso (el síntoma exacto que reportó el usuario).
// 2. Que muestra el texto del clasificador de 11-23 — el que una persona
//    puede leer y actuar en consecuencia—, no un «Error al cargar» mudo.
// 3. Que ofrece reintentar.
//
// Las aserciones son sobre la CADENA que leería un humano, no sobre la
// presencia de un widget: `findsOneWidget` de un `ErrorBox` pasaría en verde
// con el texto equivocado dentro.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_error_mapper.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

import '../helpers/firebase_fakes.dart';

/// El `permission-denied` REAL del incidente: la query de `pedidos` sin
/// `where('usuarioId')` frente a la regla que lo exige.
FirebaseException _denegado() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: "Property usuarioId is undefined on object. for 'list'",
    );

FirebaseException _sinRed() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Could not reach Cloud Firestore backend.',
    );

/// Monta la pantalla con el provider de pedidos REAL (no sobreescrito): lo que
/// se prueba es justamente cómo `pedidosSession` reacciona al estado de
/// `sesionActual`, que es donde vivía el bug.
Future<void> _montar(
  WidgetTester tester, {
  required Stream<SesionMesa?> sesion,
}) async {
  final db = await buildFakeFirestoreConSeed();
  final auth = mockAuth();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(auth),
      sesionActualProvider.overrideWith((ref) => sesion),
    ],
    child: const MaterialApp(home: PedidoEstadoScreen()),
  ));
  // NO se usa `pumpAndSettle`: si la regresión vuelve, el spinner anima para
  // siempre y `pumpAndSettle` agotaría su timeout de 10 minutos en vez de
  // fallar con un diff legible. Tres bombeos bastan para que el error del
  // stream atraviese el provider y se pinte.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Todo el texto visible del árbol, concatenado. Se afirma contra esto y no
/// contra `find.text(...)` exacto para que el caso no dependa de dónde se
/// pinte el mensaje (SnackBar, Column, ErrorBox…), solo de que se LEA.
String _textoEnPantalla(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

void main() {
  group('pedidos: el listener denegado NO se disfraza de «cargando»', () {
    testWidgets(
        'sesión DENEGADA: no hay spinner y se lee el mensaje de la cuenta',
        (tester) async {
      await _montar(tester,
          sesion: Stream<SesionMesa?>.error(_denegado()));

      // EL SÍNTOMA QUE REPORTÓ EL USUARIO. Si esto pasa, la pantalla gira.
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'un fallo del stream no puede renderizarse como carga');

      final texto = _textoEnPantalla(tester);
      // El mensaje EXACTO del clasificador de 11-23 para un permission-denied
      // al leer los pedidos. Literal a propósito: comparar contra
      // `mensajeDe(...)` sería comparar la pantalla consigo misma.
      expect(
        texto,
        contains('Tu cuenta no puede ver los pedidos de esta mesa'),
        reason: 'debe señalar la CUENTA, que es la causa real',
      );
      // La regla de oro de 11-23: un permission-denied jamás culpa a la red.
      expect(texto, isNot(contains('Revisa tu conexión')));
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sesión sin red: se lee el mensaje de conexión, no el de cuenta',
        (tester) async {
      await _montar(tester, sesion: Stream<SesionMesa?>.error(_sinRed()));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final texto = _textoEnPantalla(tester);
      expect(texto, contains('No pudimos conectar con el servidor'));
      // NO CONFUSIÓN: las dos causas producen dos textos distintos. Sin esta
      // pareja, un clasificador que devolviera siempre lo mismo pasaría.
      expect(texto, isNot(contains('Tu cuenta no puede')));
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin mesa abierta: tampoco gira — lo dice y ofrece escanear',
        (tester) async {
      // `sesiones where usuarioId == uid` sin resultados emite `null`. Antes
      // esto también acababa en `Stream.empty()` → spinner eterno, y la ruta
      // /mesa/pedidos no tiene guard de sesión (app.dart), así que se alcanza
      // desde el producto.
      await _montar(tester, sesion: Stream<SesionMesa?>.value(null));

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'sin sesión hay que DECIRLO, no girar');
      expect(_textoEnPantalla(tester),
          contains('No tienes ninguna mesa abierta'));
    });

    testWidgets('el fallo del stream de pedidos también se explica',
        (tester) async {
      // Aquí la sesión va bien y lo que falla es el propio listener de
      // `pedidos`: la rama `error:` de la pantalla, que decía «Error al
      // cargar tus pedidos» sin distinguir causa alguna.
      final db = await buildFakeFirestoreConSeed();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseAuthProvider.overrideWithValue(mockAuth()),
          sesionActualProvider.overrideWith((ref) => Stream.value(SesionMesa(
                id: 'GRI-MESA-demo-001',
                restauranteId: 'demo',
                mesaId: 'GRI-MESA-demo-001',
                usuarioId: 'test-uid',
                estado: 'activa',
                cuentaSolicitada: false,
                inicioAt: DateTime(2026, 8, 20, 20),
                restauranteNombre: 'Restaurante Demo GRI',
                mesaNumero: 1,
              ))),
          pedidosSessionProvider
              .overrideWith((ref) => Stream.error(_denegado())),
        ],
        child: const MaterialApp(home: PedidoEstadoScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final texto = _textoEnPantalla(tester);
      expect(texto, contains('Tu cuenta no puede ver los pedidos de esta mesa'));
      expect(texto, isNot(contains('Error al cargar tus pedidos')),
          reason: 'el texto mudo que no decía ni la causa ni qué hacer');
    });
  });

  group('el clasificador cubre los contextos de LECTURA', () {
    test('cada contexto de lectura tiene su propio texto por causa', () {
      const lecturas = [
        Contexto.verPedidos,
        Contexto.verMenu,
        Contexto.verReservas,
        Contexto.verRestaurantes,
      ];
      for (final contexto in lecturas) {
        final textos = <String>{};
        for (final causa in CausaFallo.values) {
          final t = mensajeDe(causa, contexto: contexto);
          expect(t, isNotEmpty);
          textos.add(t);
        }
        // permisoDenegado, sinConexion y desconocido tienen que DIFERIR entre
        // sí: si dos causas comparten texto, volvemos al bug de origen.
        expect(
          {
            mensajeDe(CausaFallo.permisoDenegado, contexto: contexto),
            mensajeDe(CausaFallo.sinConexion, contexto: contexto),
            mensajeDe(CausaFallo.desconocido, contexto: contexto),
          }.length,
          3,
          reason: '$contexto aplasta dos causas en el mismo mensaje',
        );
      }
    });

    test('un permiso denegado al LEER nunca culpa a la red ni al usuario', () {
      for (final contexto in [
        Contexto.verPedidos,
        Contexto.verMenu,
        Contexto.verReservas,
        Contexto.verRestaurantes,
      ]) {
        final t = mensajeDe(CausaFallo.permisoDenegado, contexto: contexto);
        expect(t.toLowerCase(), isNot(contains('conexión')));
        expect(t.toLowerCase(), isNot(contains('verifica')));
        expect(t.toLowerCase(), contains('cuenta'));
      }
    });

    test('desconocido no afirma ninguna causa concreta', () {
      for (final contexto in [
        Contexto.verPedidos,
        Contexto.verMenu,
        Contexto.verReservas,
        Contexto.verRestaurantes,
      ]) {
        final t = mensajeDe(CausaFallo.desconocido, contexto: contexto).toLowerCase();
        expect(t, isNot(contains('conexión')));
        expect(t, isNot(contains('cuenta')));
        expect(t, isNot(contains('permiso')));
      }
    });
  });
}
