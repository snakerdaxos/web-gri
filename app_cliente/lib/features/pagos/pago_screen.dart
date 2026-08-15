import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'pago_controller.dart';

/// Pantalla de pago de la cuenta (PAGO-02 UI): resumen con el total
/// SERVER-SIDE, botón "Pagar" que abre el checkout externo (user action —
/// Pitfall 8) y polling cada 2.5s de `GET /cliente/pagos/{id}` — la única
/// fuente de verdad del estado (threat 1: jamás mutamos localmente).
///
/// Al volver del navegador (lifecycle resumed) consulta inmediato, sin
/// esperar el próximo tick.
class PagoScreen extends ConsumerStatefulWidget {
  const PagoScreen({super.key});

  @override
  ConsumerState<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends ConsumerState<PagoScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pagoControllerProvider.notifier).iniciar();
    });
    // poll() se auto-guarda: solo consulta mientras fase == pendiente.
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) => ref.read(pagoControllerProvider.notifier).poll(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Volvió de la pestaña del checkout → consulta inmediata.
      ref.read(pagoControllerProvider.notifier).poll();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _pagar() => ref.read(pagoControllerProvider.notifier).pagar();
  void _consultarAhora() => ref.read(pagoControllerProvider.notifier).poll();
  void _abrirCheckout() =>
      ref.read(pagoControllerProvider.notifier).abrirCheckout();
  Future<void> _reiniciar() =>
      ref.read(pagoControllerProvider.notifier).iniciar();

  /// Task 2 conecta aquí el CalificacionSheet (post-pago).
  void _abrirCalificacion() {}

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(pagoControllerProvider);

    ref.listen(pagoControllerProvider, (prev, next) {
      if (next.fase == PagoFase.error && prev?.fase != PagoFase.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(next.errorDetail ?? 'No pudimos iniciar el pago.'),
            backgroundColor: GriColors.chipCanceladaFg,
          ),
        );
      }
      if (next.launchFallido &&
          !(prev?.launchFallido ?? false) &&
          next.urlAbsoluta != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se abrió el checkout. Entra a esta URL: ${next.urlAbsoluta}',
            ),
            backgroundColor: GriColors.gray,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: const Text('Pagar'),
      ),
      body: switch (flow.fase) {
        PagoFase.idle ||
        PagoFase.creando =>
          const Center(child: CircularProgressIndicator()),
        PagoFase.pendiente => flow.lanzado
            ? _EsperandoView(
                flow: flow,
                onConsultar: _consultarAhora,
                onAbrir: _abrirCheckout,
              )
            : _ResumenView(flow: flow, onPagar: _pagar),
        PagoFase.aprobado => _ExitoView(
            flow: flow,
            onCalificar: _abrirCalificacion,
          ),
        PagoFase.rechazado => _RechazadoView(onReintentar: _reiniciar),
        PagoFase.error => _ErrorView(
            detail: flow.errorDetail,
            onReintentar: _reiniciar,
          ),
      },
    );
  }
}

/// Resumen pre-launch: total server-side + botón Pagar (abre checkout).
class _ResumenView extends StatelessWidget {
  const _ResumenView({required this.flow, required this.onPagar});

  final PagoFlowState flow;
  final VoidCallback onPagar;

  @override
  Widget build(BuildContext context) {
    final monto = flow.intencion?.monto ?? 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'Total a pagar',
              style: TextStyle(color: GriColors.gray, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              formatCOP(monto),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: GriColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ref: ${flow.intencion?.referencia ?? ''}',
              key: const ValueKey('pago-referencia'),
              style: const TextStyle(color: GriColors.gray, fontSize: 12),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPagar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GriColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.credit_card),
                label: const Text(
                  'Pagar 💳',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Te llevaremos al checkout seguro para completar el pago',
              textAlign: TextAlign.center,
              style: TextStyle(color: GriColors.gray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checkout ya abierto: espera activa con consulta manual y re-apertura.
class _EsperandoView extends StatelessWidget {
  const _EsperandoView({
    required this.flow,
    required this.onConsultar,
    required this.onAbrir,
  });

  final PagoFlowState flow;
  final VoidCallback onConsultar;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'Esperando el pago…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aprueba el pago en la pestaña del navegador y vuelve aquí — '
              'el estado se actualiza solo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GriColors.gray),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onConsultar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Consultar ahora'),
                ),
                TextButton.icon(
                  onPressed: onAbrir,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir checkout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pago aprobado (según GET /cliente/pagos/{id}) + CTA de calificación.
class _ExitoView extends StatelessWidget {
  const _ExitoView({required this.flow, required this.onCalificar});

  final PagoFlowState flow;
  final VoidCallback onCalificar;

  @override
  Widget build(BuildContext context) {
    final monto = flow.ultimoEstado?.monto ?? flow.intencion?.monto ?? 0;
    final pedidoIds = flow.ultimoEstado?.pedidoIds ?? const <int>[];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            const Text(
              '¡Pago aprobado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: GriColors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCOP(monto),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: GriColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gracias por tu compra',
              style: TextStyle(color: GriColors.gray),
            ),
            if (pedidoIds.isNotEmpty) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCalificar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primaryTint,
                    foregroundColor: GriColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.star, color: Color(0xFFF5A623)),
                  label: const Text(
                    'Califica tu experiencia ⭐',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pago rechazado (terminal): reintento = intención nueva.
class _RechazadoView extends StatelessWidget {
  const _RechazadoView({required this.onReintentar});

  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('❌', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'Pago rechazado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: GriColors.chipCanceladaFg,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No se realizó ningún cobro. Puedes intentar el pago de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GriColors.gray),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onReintentar,
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error preparando la intención (p.ej. 409 pedidos en curso) — el detail
/// del server también llega por SnackBar (ref.listen de la screen).
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.detail, required this.onReintentar});

  final String? detail;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😞', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'No pudimos preparar tu pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GriColors.chipCanceladaFg),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
