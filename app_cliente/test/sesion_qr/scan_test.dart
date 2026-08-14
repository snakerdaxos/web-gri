import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/features/sesion_qr/scan_screen.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Fake del ApiClient — devuelve una sesión fija (o lanza [error]) al
/// abrir sesión por código. La cámara NUNCA se instancia: todos los flujos
/// van por el input manual (Pitfall 5 research).
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.sesion, this.error});

  final SesionMesa? sesion;
  final Object? error;

  String? lastCodigo;

  @override
  Future<SesionMesa> abrirSesion(String codigoQr) async {
    lastCodigo = codigoQr;
    final e = error;
    if (e != null) throw e;
    return sesion ?? _sesion(1);
  }
}

SesionMesa _sesion(int mesaNumero, {bool solicitaCuenta = false}) =>
    SesionMesa(
      id: 10,
      restauranteId: 1,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: mesaNumero,
      mesaNumero: mesaNumero,
      abiertaEn: DateTime(2026, 8, 14, 12, 30),
      solicitaCuenta: solicitaCuenta,
      solicitadaEn: null,
    );

/// Router de test: /mesa es una página dummy para verificar la navegación
/// tras abrir sesión (pushReplacement necesita GoRouter real en el árbol).
Widget _wrap({required ApiClient client}) {
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
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
      'render inicial muestra input manual SIN instanciar MobileScanner',
      (tester) async {
    await tester.pumpWidget(_wrap(client: _FakeApiClient()));
    await tester.pumpAndSettle();

    // Cámara solo tras tap — en el render inicial no existe.
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('Escanear con cámara'), findsOneWidget);

    // Input manual SIEMPRE visible (vía de primera clase).
    expect(find.text('O escribe el código de la mesa'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Abrir mesa'), findsOneWidget);
  });

  testWidgets('código inválido (GRI-123) queda bloqueado por el validator',
      (tester) async {
    final client = _FakeApiClient();
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'GRI-123');
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();

    // Mensaje de validación visible, sin llamada al backend ni navegación.
    expect(find.textContaining('formato GRI-MESA-001'), findsOneWidget);
    expect(client.lastCodigo, isNull);
    expect(find.text('Escanear QR de la mesa'), findsOneWidget);
  });

  testWidgets('GRI-MESA-001 válido → sesión abierta (Mesa 1) + navegación',
      (tester) async {
    final client = _FakeApiClient(sesion: _sesion(1));
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'GRI-MESA-001');
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Llegó el código exacto al backend y la sesión se abrió.
    expect(client.lastCodigo, 'GRI-MESA-001');
    expect(find.textContaining('Mesa 1'), findsOneWidget);
    // pushReplacement a /mesa.
    expect(find.text('MESA_PAGE'), findsOneWidget);
  });

  testWidgets('409 del backend muestra el detail en SnackBar rojo',
      (tester) async {
    final client = _FakeApiClient(
      error: DioException(
        requestOptions: RequestOptions(path: '/cliente/sesiones'),
        response: Response(
          requestOptions: RequestOptions(path: '/cliente/sesiones'),
          statusCode: 409,
          data: {'detail': 'La mesa ya está ocupada por otro comensal'},
        ),
      ),
    );
    await tester.pumpWidget(_wrap(client: client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'GRI-MESA-003');
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // El detail del server, accionable — sin crash, sin navegación.
    expect(find.textContaining('ocupada por otro comensal'), findsOneWidget);
    expect(find.text('MESA_PAGE'), findsNothing);
    expect(find.text('Abrir mesa'), findsOneWidget);
  });
}
