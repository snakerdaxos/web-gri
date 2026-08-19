import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import 'sesion_provider.dart';

/// Escanear QR de la mesa (MESA-05) — dos vías, ambas de primera clase:
///
/// * **Cámara** ([MobileScanner]): se monta SOLO tras tap "Escanear con
///   cámara" — en widget tests la cámara no existe (Pitfall 5 research) y
///   en web sin secure context/CDN falla (Pitfall 9): el `errorBuilder`
///   ofrece el código manual.
/// * **Input manual** `GRI-MESA-{rid}-{numero}`: SIEMPRE visible, fuera
///   del condicional de cámara — única vía testeable y fallback garantizado.
///
/// Anti doble-disparo: `DetectionSpeed.noDuplicates` + `_navigating` flag +
/// `controller.stop()` tras el primer hit.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();

  MobileScannerController? _cameraController;
  bool _cameraOn = false;

  /// True desde que un código dispara la tx hasta éxito/navegación —
  /// bloquea re-disparos del scanner y taps extra.
  bool _navigating = false;
  bool _sending = false;

  /// Doc ID de mesa = código QR: `GRI-MESA-{slug-restaurante}-{numero:03d}`
  /// (ej. GRI-MESA-demo-001 — research 10).
  static final _codigoRegExp = RegExp(r'^GRI-MESA-[a-z0-9-]+-\d{3}$');

  @override
  void dispose() {
    _cameraController?.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _encenderCamara() {
    _cameraController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    setState(() => _cameraOn = true);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _navigating) return;
    _navigating = true;
    try {
      await _cameraController?.stop();
    } catch (_) {
      // Cámara ya detenida — irrelevante, seguimos con el código.
    }
    await _abrir(raw);
  }

  void _submitManual() {
    if (!_formKey.currentState!.validate()) return;
    _navigating = true;
    _abrir(_codigoCtrl.text.trim());
  }

  Future<void> _abrir(String codigo) async {
    setState(() => _sending = true);
    try {
      final sesion =
          await ref.read(sesionControllerProvider.notifier).abrir(codigo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('¡Sesión abierta en la Mesa ${sesion.mesaNumero}!'),
          backgroundColor: GriColors.green,
        ),
      );
      context.pushReplacement('/mesa');
    } on SesionException catch (e) {
      if (!mounted) return;
      _navigating = false; // permite reintentar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } catch (e) {
      // Log del error inesperado — el usuario ve el SnackBar genérico, pero
      // la causa queda trazada (nunca catch silencioso).
      debugPrint('abrir sesión falló: $e');
      if (!mounted) return;
      _navigating = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Intenta de nuevo.'),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene vivo el (autoDispose) SesionController mientras la pantalla
    // existe — sin un listener, Riverpod 3 lo dispone tras el ref.read y el
    // `state =` post-await del controller explota.
    ref.watch(sesionControllerProvider);

    return Scaffold(
      backgroundColor: GriColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: const Text('Escanear QR de la mesa'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Apunta la cámara al código QR de la mesa, o escribe el código '
            'que aparece debajo de él.',
            style: TextStyle(color: GriColors.gray),
          ),
          const SizedBox(height: 20),

          // ── Sección cámara (colapsada — solo tras tap) ─────────────────
          if (_cameraOn)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 220,
                child: MobileScanner(
                  controller: _cameraController!,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'No pudimos iniciar la cámara 😕\n' // EMOJI-OK: tono empático
                      'Usa el código manual de abajo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _encenderCamara,
                style: OutlinedButton.styleFrom(
                  foregroundColor: GriColors.primary,
                  side: const BorderSide(color: GriColors.primaryTintBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text(
                  'Escanear con cámara',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 28),

          // ── Sección manual (SIEMPRE visible) ────────────────────────────
          const Text(
            'O escribe el código de la mesa',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: GriColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _codigoCtrl,
                  enabled: !_sending,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sending ? null : _submitManual(),
                  decoration: InputDecoration(
                    hintText: 'GRI-MESA-demo-001',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: GriColors.primaryTintBorder),
                    ),
                  ),
                  validator: (v) => v != null && _codigoRegExp.hasMatch(v.trim())
                      ? null
                      : 'El código tiene formato GRI-MESA-demo-001',
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _sending ? null : _submitManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: GriColors.primaryTint,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Abrir mesa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
