// test/pedidos/errores_honestos_test.dart — el resto del flujo de mesa deja de
// mentir sobre la causa de sus fallos (11-23, Tarea 3).
//
// ── POR QUÉ ────────────────────────────────────────────────────────────────
// El bug que el usuario sufrió en el escáner («Verifica el código» ante un
// permiso denegado) NO era un caso aislado: el mismo patrón estaba repetido
// tres veces más en el camino crítico, y las tres decían «Error de conexión»
// —o su primo— ante CUALQUIER excepción:
//
//   · menu_mesa_screen.dart      → enviar el pedido
//   · pedido_estado_screen.dart  → pedir la cuenta
//   · calificacion_sheet.dart    → calificar
//
// Un `permission-denied` por esos tres caminos le decía al usuario que
// revisara su internet. Aquí se afirma que ya no.
//
// ── CÓMO SE INYECTAN LOS FALLOS ────────────────────────────────────────────
// Con `mock_exceptions` sobre el fake de Firestore, SIEMPRE después de montar
// la pantalla: durante el montaje se leen los mismos documentos y una
// inyección temprana rompería el arranque en vez de la mutación. El documento
// elegido en cada caso es uno que SOLO toca la mutación bajo prueba.
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_error_mapper.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pagos/calificacion_sheet.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/pedidos/pedido_estado_screen.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/categoria.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/producto.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';

const _mesa = 'GRI-MESA-demo-001';
const _items = [
  PedidoItem(productoId: 'p1', nombre: 'Pasta', precio: 25000, cantidad: 2),
];

/// El texto ciego que este plan retira del camino crítico.
const _mensajeCiego = 'Error de conexión. Intenta de nuevo.';

/// El texto ciego del sheet de calificación.
const _mensajeCiegoCalificacion =
    'No pudimos enviar tu calificación. Intenta de nuevo.';

RestauranteDetalle _detalle() => RestauranteDetalle(
      id: 'demo',
      nombre: 'Restaurante Demo GRI',
      tipoCocina: 'Internacional',
      descripcion: null,
      direccion: null,
      categorias: [
        Categoria(id: 'c1', restauranteId: 'demo', nombre: 'Platos', orden: 1,
            productos: [
          const Producto(
              id: 'p1',
              restauranteId: 'demo',
              categoriaId: 'c1',
              nombre: 'Pasta',
              descripcion: 'Con salsa de la casa',
              precio: 25000,
              disponible: true),
        ]),
      ],
    );

FirebaseException _fb(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

/// Intercepta `debugPrint` para poder afirmar que los `catch` dejan traza.
///
/// EXISTE POR UNA VERDE CAZADA (rotura D): borrar el `debugPrint` entero de
/// `menu_mesa_screen.dart` dejaba la suite ENTERA en verde. La mitigación
/// T-11-23-04 («ningún catch queda mudo») estaba AFIRMADA, no verificada —
/// exactamente el mismo agujero que apareció en `sesion_provider.dart`.
///
/// OJO: la restauración va DENTRO del cuerpo del caso, no en un `addTearDown`.
/// `testWidgets` comprueba que las variables de depuración de `foundation`
/// estén sin tocar (`debugAssertAllFoundationVarsUnset`) ANTES de ejecutar los
/// tearDown, así que restaurar allí llega tarde y el caso falla con «The value
/// of a foundation debug variable was changed by the test».
class _Trazas {
  _Trazas() : _original = debugPrint {
    debugPrint =
        (String? mensaje, {int? wrapWidth}) => _lineas.add(mensaje ?? '');
  }

  final DebugPrintCallback _original;
  final List<String> _lineas = [];

  /// Restaura `debugPrint` y afirma que la traza lleva la causa REAL y CÓMO se
  /// clasificó. El usuario ve un texto amable; quien depura necesita el código
  /// de Firebase.
  void esperar(String code, CausaFallo causa) {
    debugPrint = _original;
    final todo = _lineas.join('\n');
    expect(todo, contains(code),
        reason: 'el catch tiene que dejar la causa real en el log');
    expect(todo, contains('$causa'),
        reason: 'y también cómo se clasificó, para poder auditar el mapeo');
  }
}

/// Junta el `data` de TODOS los `Text` del árbol: se afirma sobre lo que el
/// usuario PUEDE LEER, no sobre el widget que uno espera encontrar.
String _textoVisible(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' ⏐ ');

void main() {
  // ══ 1. Enviar el pedido (menu_mesa_screen) ════════════════════════════

  Future<dynamic> pumpMenu(WidgetTester tester) async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
        restauranteDetalleProvider('demo')
            .overrideWith((ref) async => _detalle()),
      ],
      child: const MaterialApp(home: MenuMesaScreen()),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> armarYEnviar(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pump();
    // El boton de enviar vive DENTRO del sheet del carrito, no en el menu.
    await tester.tap(find.textContaining('Carrito (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar pedido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('PEDIDO con permission-denied → habla del PERMISO, no de la conexión',
      (tester) async {
    final db = await pumpMenu(tester);
    final trazas = _Trazas();
    // `sesiones/{mesa}` solo se lee por `.get()` dentro de la tx de
    // crearPedido: los streams de la pantalla usan `.snapshots()`.
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(_fb('permission-denied'));

    await armarYEnviar(tester);

    trazas.esperar('permission-denied', CausaFallo.permisoDenegado);

    expect(
        find.text(mensajeDe(CausaFallo.permisoDenegado,
            contexto: Contexto.crearPedido)),
        findsOneWidget);
    expect(find.text(_mensajeCiego), findsNothing,
        reason: 'un permiso denegado NO es un problema de conexión');
    expect(_textoVisible(tester).toLowerCase(), contains('cuenta'));
  });

  testWidgets('PEDIDO con unavailable → habla de la CONEXIÓN', (tester) async {
    final db = await pumpMenu(tester);
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(_fb('unavailable'));

    await armarYEnviar(tester);

    expect(
        find.text(
            mensajeDe(CausaFallo.sinConexion, contexto: Contexto.crearPedido)),
        findsOneWidget);
    expect(find.text(_mensajeCiego), findsNothing);
  });

  testWidgets('PEDIDO: el mensaje de dominio (carrito vacío) NO cambia',
      (tester) async {
    // Regla del plan: lo que ya decía la verdad se queda como estaba.
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    await expectLater(
      crearPedido(db, uid: 'test-uid', mesaCodigo: _mesa, items: const []),
      throwsA(isA<PedidoException>()
          .having((e) => e.message, 'message', 'Tu carrito está vacío')),
    );
  });

  // ══ 2. Pedir la cuenta (pedido_estado_screen) ═════════════════════════

  Future<dynamic> pumpEstado(WidgetTester tester) async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth()),
      ],
      child: const MaterialApp(home: PedidoEstadoScreen()),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> pedirCuenta(WidgetTester tester) async {
    await tester.tap(find.text('Pedir la cuenta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('CUENTA con permission-denied → habla del PERMISO, no de la conexión',
      (tester) async {
    final db = await pumpEstado(tester);
    final trazas = _Trazas();
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(_fb('permission-denied'));

    await pedirCuenta(tester);

    trazas.esperar('permission-denied', CausaFallo.permisoDenegado);

    expect(
        find.text(mensajeDe(CausaFallo.permisoDenegado,
            contexto: Contexto.solicitarCuenta)),
        findsOneWidget);
    expect(find.text(_mensajeCiego), findsNothing);
  });

  testWidgets('CUENTA con unavailable → habla de la CONEXIÓN', (tester) async {
    final db = await pumpEstado(tester);
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('sesiones/$_mesa'))
        .thenThrow(_fb('unavailable'));

    await pedirCuenta(tester);

    expect(
        find.text(mensajeDe(CausaFallo.sinConexion,
            contexto: Contexto.solicitarCuenta)),
        findsOneWidget);
    expect(find.text(_mensajeCiego), findsNothing);
  });

  testWidgets('CUENTA: el mensaje de dominio (sesión ajena) NO cambia',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    await expectLater(
      solicitarCuenta(db, uid: 'intruso', mesaId: _mesa),
      throwsA(isA<PedidoException>().having((e) => e.message, 'message',
          'No pudimos solicitar la cuenta: tu sesión en la mesa no está activa')),
    );
  });

  // ══ 3. Calificar (calificacion_sheet) ═════════════════════════════════

  Future<String> sembrarPedidoServido(dynamic db) async {
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    final id =
        await crearPedido(db, uid: 'test-uid', mesaCodigo: _mesa, items: _items);
    await db.doc('pedidos/$id').update({'estado': 'servido'});
    await db.doc('sesiones/$_mesa').update({
      'estado': 'cerrada',
      'cerradaAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Widget wrapSheet(dynamic db, String pedidoId) => ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseAuthProvider.overrideWithValue(mockAuth()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CalificacionSheet(pedidoId: pedidoId),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> calificarConCincoEstrellas(WidgetTester tester) async {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar calificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('CALIFICAR con permission-denied → habla del PERMISO',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final id = await sembrarPedidoServido(db);
    await tester.pumpWidget(wrapSheet(db, id));
    final trazas = _Trazas();
    // `calificaciones/{pedidoId}` solo lo toca la tx de calificar.
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('calificaciones/$id'))
        .thenThrow(_fb('permission-denied'));

    await calificarConCincoEstrellas(tester);

    trazas.esperar('permission-denied', CausaFallo.permisoDenegado);

    expect(
        find.text(
            mensajeDe(CausaFallo.permisoDenegado, contexto: Contexto.calificar)),
        findsOneWidget);
    expect(find.text(_mensajeCiegoCalificacion), findsNothing,
        reason: 'decía «intenta de nuevo» ante algo que reintentar no arregla');
  });

  testWidgets('CALIFICAR con unavailable → habla de la CONEXIÓN',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    final id = await sembrarPedidoServido(db);
    await tester.pumpWidget(wrapSheet(db, id));
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('calificaciones/$id'))
        .thenThrow(_fb('unavailable'));

    await calificarConCincoEstrellas(tester);

    expect(
        find.text(
            mensajeDe(CausaFallo.sinConexion, contexto: Contexto.calificar)),
        findsOneWidget);
    expect(find.text(_mensajeCiegoCalificacion), findsNothing);
  });

  testWidgets('CALIFICAR: el mensaje de dominio (pedido no servido) NO cambia',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await abrirSesion(db, uid: 'test-uid', codigoQR: _mesa);
    final id =
        await crearPedido(db, uid: 'test-uid', mesaCodigo: _mesa, items: _items);
    await tester.pumpWidget(wrapSheet(db, id));

    await calificarConCincoEstrellas(tester);

    expect(find.text('Solo puedes calificar pedidos servidos'), findsOneWidget);
  });

  // ══ 4. Gate estático: el texto ciego no vuelve al camino crítico ══════

  test('GATE: ningún archivo del flujo de mesa vuelve a afirmar una causa que no conoce',
      () async {
    // El barrido de pantallas solo ve lo que monta (lección de 11-14). Esto
    // lee las FUENTES, así que no tiene puntos ciegos.
    const flujo = <String>[
      'lib/features/sesion_qr/sesion_provider.dart',
      'lib/features/sesion_qr/scan_screen.dart',
      'lib/features/pedidos/pedidos_provider.dart',
      'lib/features/pedidos/menu_mesa_screen.dart',
      'lib/features/pedidos/pedido_estado_screen.dart',
      'lib/features/pagos/calificacion_sheet.dart',
    ];
    final infracciones = <String>[];
    for (final ruta in flujo) {
      final lineas = await _leerLineas(ruta);
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        // Los comentarios documentan el bug a propósito: se saltan.
        if (linea.trimLeft().startsWith('//')) continue;
        if (linea.contains(_mensajeCiego) ||
            linea.contains(_mensajeCiegoCalificacion)) {
          infracciones.add('$ruta:${i + 1}: ${linea.trim()}');
        }
      }
    }
    expect(infracciones, isEmpty,
        reason: 'estos textos afirman una causa concreta para CUALQUIER fallo;'
            ' el mensaje tiene que salir de mensajeDe/mensajeDeFallo');
  });
}

Future<List<String>> _leerLineas(String ruta) async {
  final archivo = File(ruta);
  expect(await archivo.exists(), isTrue, reason: 'no existe $ruta');
  return archivo.readAsLines();
}
