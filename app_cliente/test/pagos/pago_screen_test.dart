import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/core/env.dart';
import 'package:gri_cliente/features/pagos/pago_controller.dart';
import 'package:gri_cliente/features/pagos/pago_screen.dart';
import 'package:gri_cliente/models/pago.dart';

/// Fake del ApiClient para el flujo de pago (patrón cuenta_test): cuenta
/// intenciones/polls y devuelve respuestas fijas. [error] se lanza al
/// crear la intención (p.ej. DioException 409).
class _PagoClient extends ApiClient {
  _PagoClient({required this.intencion, this.estado, this.error});

  final PagoIntencion intencion;
  final PagoEstado? estado;
  final Object? error;

  int intencionesCreadas = 0;
  int polls = 0;

  @override
  Future<PagoIntencion> crearIntencionPago() async {
    intencionesCreadas++;
    if (error != null) throw error!;
    return intencion;
  }

  @override
  Future<PagoEstado> getPagoEstado(int pagoId) async {
    polls++;
    return estado ??
        PagoEstado(
          pagoId: pagoId,
          estado: 'pendiente',
          referencia: intencion.referencia,
          monto: intencion.monto,
          pedidoIds: const [7],
        );
  }
}

/// Launcher spy (inyectado via pagoLauncherProvider): registra la URI y
/// retorna true (Pitfall 8: el launch real solo ocurre en user action).
class _SpyLauncher {
  final uris = <Uri>[];

  Future<bool> call(Uri url) async {
    uris.add(url);
    return true;
  }
}

PagoIntencion _intencion({String checkoutUrl = '/pagos/sandbox/GRI-PAGO-XYZ'}) =>
    PagoIntencion(
      pagoId: 5,
      referencia: 'GRI-PAGO-XYZ',
      monto: 50000,
      estado: 'pendiente',
      checkoutUrl: checkoutUrl,
    );

PagoEstado _estadoFinal(String estado) => PagoEstado(
      pagoId: 5,
      estado: estado,
      referencia: 'GRI-PAGO-XYZ',
      monto: 50000,
      pedidoIds: const [7],
    );

Widget _wrap({required ApiClient client, required _SpyLauncher launcher}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      pagoLauncherProvider.overrideWithValue(launcher.call),
    ],
    child: const MaterialApp(home: PagoScreen()),
  );
}

/// Sin timers reales: invocamos poll() directo (patrón estado_test).
PagoController _controller(WidgetTester tester) {
  final ctx = tester.element(find.byType(PagoScreen));
  return ProviderScope.containerOf(ctx, listen: false)
      .read(pagoControllerProvider.notifier);
}

/// pump inicial: postFrameCallback → iniciar() → resolución async.
Future<void> _pumpInicio(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('renderiza el monto de la intención (formatCOP)', (tester) async {
    await tester.pumpWidget(_wrap(
      client: _PagoClient(intencion: _intencion()),
      launcher: _SpyLauncher(),
    ));
    await _pumpInicio(tester);

    expect(find.text('Total a pagar'), findsOneWidget);
    expect(find.textContaining('50.000'), findsOneWidget);
    expect(find.byKey(const ValueKey('pago-referencia')), findsOneWidget);
  });

  testWidgets(
      'tap Pagar → launcher con URL absoluta; sin mutación local a aprobado',
      (tester) async {
    final spy = _SpyLauncher();
    final client = _PagoClient(intencion: _intencion()); // URL relativa
    await tester.pumpWidget(_wrap(client: client, launcher: spy));
    await _pumpInicio(tester);

    await tester.tap(find.text('Pagar 💳'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // El launcher recibió la URL absoluta (Env.apiBaseUrl + relativa).
    expect(spy.uris, hasLength(1));
    expect(
      spy.uris.first.toString(),
      startsWith(Env.apiBaseUrl),
      reason: 'la checkout_url relativa debe anteponer la base del backend',
    );
    expect(spy.uris.first.toString(), endsWith('/pagos/sandbox/GRI-PAGO-XYZ'));

    // Threat 1: el estado NUNCA se muta localmente — sigue esperando
    // hasta que GET /cliente/pagos/{id} diga otra cosa.
    expect(find.textContaining('Pago aprobado'), findsNothing);
    expect(find.textContaining('Esperando'), findsOneWidget);
    expect(find.text('Pagar 💳'), findsNothing);
  });

  testWidgets('poll → aprobado: éxito + CTA de calificación visible',
      (tester) async {
    await tester.pumpWidget(_wrap(
      client: _PagoClient(intencion: _intencion(), estado: _estadoFinal('aprobado')),
      launcher: _SpyLauncher(),
    ));
    await _pumpInicio(tester);

    await _controller(tester).poll();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Pago aprobado'), findsOneWidget);
    expect(find.textContaining('50.000'), findsOneWidget);
    expect(find.textContaining('Califica tu experiencia'), findsOneWidget);
  });

  testWidgets(
      'poll → rechazado: error + Intentar de nuevo crea nueva intención',
      (tester) async {
    final client =
        _PagoClient(intencion: _intencion(), estado: _estadoFinal('rechazado'));
    await tester.pumpWidget(_wrap(client: client, launcher: _SpyLauncher()));
    await _pumpInicio(tester);

    await _controller(tester).poll();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Pago rechazado'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);

    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // El pago anterior quedó terminal → el backend crea uno nuevo.
    expect(client.intencionesCreadas, 2);
  });

  testWidgets('409 al crear intención → SnackBar con el detail del server',
      (tester) async {
    final opts = RequestOptions(path: '/cliente/pagos/intencion');
    final err = DioException(
      requestOptions: opts,
      response: Response<Object?>(
        requestOptions: opts,
        statusCode: 409,
        data: {'detail': 'Tienes pedidos en curso'},
      ),
    );
    await tester.pumpWidget(_wrap(
      client: _PagoClient(intencion: _intencion(), error: err),
      launcher: _SpyLauncher(),
    ));
    await _pumpInicio(tester);
    await tester.pump(const Duration(milliseconds: 300)); // SnackBar anim

    // El detail del server llega por SnackBar (y persiste en la vista de
    // error — por eso el matcher es descendant del SnackBar).
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Tienes pedidos en curso'),
      ),
      findsOneWidget,
    );
  });
}
