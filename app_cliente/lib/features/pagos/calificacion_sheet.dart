import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../../core/tx_mutex.dart';

/// Error de dominio de calificación con mensaje user-friendly.
class CalificacionException implements Exception {
  const CalificacionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Califica un pedido SERVIDO de una sesión CERRADA — `runTransaction`
/// con el agregado del restaurante recalculado ATÓMICAMENTE (locked:
/// calificación tras cierre):
///
/// 1. `tx.get(pedidos/{pedidoId})` — existe, `usuarioId == uid` y estado
///    'servido' (si no → error controlado).
/// 2. `tx.get(sesiones/{sesionId})` — estado 'cerrada'.
/// 3. `tx.get(calificaciones/{pedidoId})` — NO existe (doc ID = pedidoId:
///    1:1, sin duplicados).
/// 4. Lee `califProm`/`califCount` EN LA MISMA tx y escribe ambos
///    recomputados: `califProm = (prom*count + e)/(count+1)` redondeado a
///    2 decimales, `califCount = count + 1`.
Future<void> calificar(
  FirebaseFirestore db, {
  required String uid,
  required String pedidoId,
  required int estrellas,
  String? comentario,
}) {
  if (estrellas < 1 || estrellas > 5) {
    return Future.error(
        const CalificacionException('Las estrellas van de 1 a 5'));
  }
  return seccionCritica(
    () => _calificar(db, uid: uid, pedidoId: pedidoId, estrellas: estrellas,
        comentario: comentario),
  );
}

Future<void> _calificar(
  FirebaseFirestore db, {
  required String uid,
  required String pedidoId,
  required int estrellas,
  String? comentario,
}) {
  throw UnimplementedError();
}

/// Bottom sheet de calificación post-cierre (CALI-01 sobre Firestore):
/// 5 estrellas custom (Row de IconButtons — cero deps) + comentario
/// opcional + enviar.
///
/// Se abre desde la pantalla de pedidos cuando la sesión está CERRADA y
/// el pedido SERVIDO; las rules revalidan todo (solo pedidos servidos
/// propios con sesión cerrada, una calificación por pedido).
class CalificacionSheet extends ConsumerStatefulWidget {
  const CalificacionSheet({super.key, required this.pedidoId});

  final String pedidoId;

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
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _error('Debes iniciar sesión para calificar');
      return;
    }
    try {
      await calificar(
        ref.read(firestoreProvider),
        uid: uid,
        pedidoId: widget.pedidoId,
        estrellas: _estrellas,
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
    } on CalificacionException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _error(e.message);
    } catch (e) {
      debugPrint('calificar falló: $e');
      if (!mounted) return;
      setState(() => _enviando = false);
      _error('No pudimos enviar tu calificación. Intenta de nuevo.');
    }
  }

  void _error(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: GriColors.chipCanceladaFg,
      ),
    );
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
