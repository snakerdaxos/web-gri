import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Bottom sheet de calificación post-pago (CALI-01): 5 estrellas custom
/// (Row de IconButtons — cero deps) + comentario opcional + enviar.
///
/// Solo se abre desde el estado APROBADO de la PagoScreen: el [pedidoId]
/// proviene de `PagoEstado.pedidoIds` (la sesión ya está cerrada — Pitfall
/// 6 del research 09). El backend revalida todo (solo pedidos pagados
/// propios, una calificación por pedido).
class CalificacionSheet extends ConsumerStatefulWidget {
  const CalificacionSheet({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  ConsumerState<CalificacionSheet> createState() => _CalificacionSheetState();
}

class _CalificacionSheetState extends ConsumerState<CalificacionSheet> {
  int _estrellas = 0;
  bool _enviando = false;
  final _comentario = TextEditingController();

  static const _ambar = Color(0xFFF5A623);

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_estrellas == 0 || _enviando) return;
    setState(() => _enviando = true);
    final texto = _comentario.text.trim();
    try {
      await ref.read(apiClientProvider).crearCalificacion(
            widget.pedidoId,
            _estrellas,
            comentario: texto.isEmpty ? null : texto,
          );
      if (!mounted) return;
      // El messenger se captura ANTES del pop: el SnackBar vive en la
      // pantalla que alojó el sheet.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por calificar! 🙌'),
          backgroundColor: GriColors.green,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      final String mensaje;
      if (status == 409) {
        mensaje = 'Este pedido ya fue calificado';
      } else if (detail is String && detail.isNotEmpty) {
        mensaje = detail;
      } else {
        mensaje = 'No pudimos enviar tu calificación. Intenta de nuevo.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Intenta de nuevo.'),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '¿Cómo estuvo todo?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tu calificación ayuda a otros comensales',
            style: TextStyle(color: GriColors.gray, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _estrellas = i),
                  icon: Icon(
                    i <= _estrellas ? Icons.star : Icons.star_border,
                    color: _ambar,
                  ),
                  iconSize: 36,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comentario,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos cómo fue todo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_estrellas == 0 || _enviando) ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: GriColors.primaryTint,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _enviando ? 'Enviando…' : 'Enviar calificación',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
