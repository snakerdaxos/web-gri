// ============================================================================
// GRI — BARRIDO: ninguna pantalla del cliente miente ante un stream roto
// (plan 11-33).
//
// `test/pedidos/errores_de_stream_test.dart` cierra el incidente concreto que
// reportó el usuario. Este archivo es el BARRIDO: recorre las pantallas del
// cliente que consumen un `AsyncValue` y afirma, para cada una, las dos cosas
// que fallaban a la vez:
//
//   1. que un fallo NO se pinta como un indicador de progreso —el default de
//      reintento de Riverpod 3 mantiene el estado en `AsyncLoading` mientras
//      reintenta, así que `when` elegía la rama `loading:` (ver
//      `core/async_fallo.dart`)—, y
//   2. que el texto que se lee dice CUÁL de las causas fue, en vez del
//      «Error al cargar X» que servía igual para un permiso denegado que para
//      una caída de red.
//
// El vector es siempre la MISMA pareja de causas (permiso denegado / sin red)
// y se afirma que los dos textos DIFIEREN. Sin esa comparación, una pantalla
// que devolviera el mismo texto para todo pasaría en verde y habríamos
// reproducido el bug de origen con otra redacción.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/pedidos/menu_mesa_screen.dart';
import 'package:gri_cliente/features/reservas/mis_reservas_screen.dart';
import 'package:gri_cliente/features/reservas/reservas_provider.dart';
import 'package:gri_cliente/features/restaurantes/restaurante_detalle_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_list_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/models/restaurante.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/restaurante_detalle.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

import '../helpers/firebase_fakes.dart';

FirebaseException _denegado() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

FirebaseException _sinRed() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

SesionMesa _sesion() => SesionMesa(
      id: 'GRI-MESA-demo-001',
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-001',
      usuarioId: 'test-uid',
      estado: 'activa',
      cuentaSolicitada: false,
      inicioAt: DateTime(2026, 8, 20, 20),
      restauranteNombre: 'Restaurante Demo GRI',
      mesaNumero: 1,
    );

String _texto(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// Monta [pantalla] con el provider fallando y devuelve todo el texto visible.
Future<String> _conFallo(
  WidgetTester tester, {
  required Widget pantalla,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: pantalla),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return _texto(tester);
}

void main() {
  group('menú de la mesa', () {
    List<Override> ov(Object error) => [
          firebaseAuthProvider.overrideWithValue(mockAuth()),
          sesionActualProvider.overrideWith((ref) => Stream.value(_sesion())),
          restauranteDetalleProvider('demo')
              .overrideWith((ref) => Future<RestauranteDetalle>.error(error)),
        ];

    testWidgets('permiso denegado: no gira y habla de la cuenta',
        (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const MenuMesaScreen(), overrides: ov(_denegado()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(texto, contains('Tu cuenta no puede ver esta carta'));
      expect(texto, isNot(contains('Error al cargar el menú')));
    });

    testWidgets('sin red: habla de la conexión, y NO es el mismo texto',
        (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const MenuMesaScreen(), overrides: ov(_sinRed()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(texto, contains('No pudimos conectar con el servidor'));
      expect(texto, isNot(contains('Tu cuenta no puede')));
    });
  });

  group('detalle de restaurante', () {
    List<Override> ov(Object error) => [
          firebaseAuthProvider.overrideWithValue(mockAuth()),
          restauranteDetalleProvider('demo')
              .overrideWith((ref) => Future<RestauranteDetalle>.error(error)),
        ];

    testWidgets('permiso denegado: no gira y habla de la cuenta',
        (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const RestauranteDetalleScreen(restauranteId: 'demo'),
          overrides: ov(_denegado()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(texto, contains('Tu cuenta no puede ver esta carta'));
      expect(texto, isNot(contains('Error al cargar el restaurante')));
    });

    testWidgets('sin red: habla de la conexión', (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const RestauranteDetalleScreen(restauranteId: 'demo'),
          overrides: ov(_sinRed()));
      expect(texto, contains('No pudimos conectar con el servidor'));
      expect(texto, isNot(contains('Tu cuenta no puede')));
    });
  });

  group('lista de restaurantes', () {
    List<Override> ov(Object error) => [
          firebaseAuthProvider.overrideWithValue(mockAuth()),
          restaurantesListProvider
              .overrideWith((ref) => Future<List<Restaurante>>.error(error)),
        ];

    testWidgets('permiso denegado: no gira y habla de la cuenta',
        (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const RestaurantesListScreen(),
          overrides: ov(_denegado()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(texto, contains('Tu cuenta no puede ver los restaurantes'));
      expect(texto, isNot(contains('Error al cargar restaurantes')));
    });

    testWidgets('sin red: habla de la conexión', (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const RestaurantesListScreen(), overrides: ov(_sinRed()));
      expect(texto, contains('No pudimos conectar con el servidor'));
      expect(texto, isNot(contains('Tu cuenta no puede')));
    });
  });

  group('mis reservas', () {
    List<Override> ov(Object error) => [
          firebaseAuthProvider.overrideWithValue(mockAuth()),
          misReservasProvider('test-uid')
              .overrideWith((ref) => Stream.error(error)),
        ];

    testWidgets('permiso denegado: no gira y habla de la cuenta',
        (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const MisReservasScreen(), overrides: ov(_denegado()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(texto, contains('Tu cuenta no puede ver estas reservas'));
      expect(texto, isNot(contains('Error al cargar tus reservas')));
    });

    testWidgets('sin red: habla de la conexión', (tester) async {
      final texto = await _conFallo(tester,
          pantalla: const MisReservasScreen(), overrides: ov(_sinRed()));
      expect(texto, contains('No pudimos conectar con el servidor'));
      expect(texto, isNot(contains('Tu cuenta no puede')));
    });
  });
}
