import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../../core/tx_mutex.dart';
import '../../core/design_tokens.dart';

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
  return db.runTransaction<void>((tx) async {
    // 1) El pedido debe existir, ser del emisor y estar SERVIDO.
    final pedidoSnap = await tx.get(db.doc('pedidos/$pedidoId'));
    final pedidoData = pedidoSnap.data();
    if (!pedidoSnap.exists || pedidoData == null) {
      throw const CalificacionException('Pedido no encontrado');
    }
    if (pedidoData['usuarioId'] != uid) {
      throw const CalificacionException(
          'Solo puedes calificar tus propios pedidos');
    }
    if (pedidoData['estado'] != 'servido') {
      throw const CalificacionException(
          'Solo puedes calificar pedidos servidos');
    }

    // 2) La sesión debe estar CERRADA (locked: calificación tras cierre).
    final sesionId = pedidoData['sesionId'] as String? ?? '';
    final sesionSnap = await tx.get(db.doc('sesiones/$sesionId'));
    if (sesionSnap.data()?['estado'] != 'cerrada') {
      throw const CalificacionException(
          'Podrás calificar cuando el restaurante cierre tu sesión');
    }

    // 3) 1:1 — el doc ID es el pedidoId; si ya existe, ya fue calificado.
    final califRef = db.doc('calificaciones/$pedidoId');
    if ((await tx.get(califRef)).exists) {
      throw const CalificacionException('Este pedido ya fue calificado');
    }

    // 4) Agregado leído y recomputado EN LA MISMA tx (atómico).
    final rid = pedidoData['restauranteId'] as String? ?? '';
    final restSnap = await tx.get(db.doc('restaurantes/$rid'));
    final restData = restSnap.data() ?? const <String, dynamic>{};
    final count = (restData['califCount'] as num?)?.toInt() ?? 0;
    final prom = (restData['califProm'] as num?)?.toDouble() ?? 0.0;
    final nuevoProm =
        ((prom * count + estrellas) / (count + 1) * 100).round() / 100;

    tx.set(califRef, <String, dynamic>{
      'restauranteId': rid,
      'usuarioId': uid,
      'pedidoId': pedidoId,
      'estrellas': estrellas,
      'comentario': comentario ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.update(db.doc('restaurantes/$rid'), <String, dynamic>{
      'califProm': nuevoProm,
      'califCount': count + 1,
    });
  });
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
          content: Text('¡Gracias por calificar! 🙌'), // EMOJI-OK: celebración
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
            style: GriText.tituloSeccion,
          ),
          const SizedBox(height: GriSpacing.xs),
          Text(
            'Tu calificación ayuda a otros comensales',
            style: GriText.auxiliar.copyWith(color: GriColors.gray),
          ),
          const SizedBox(height: GriSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _estrellas = i),
                  icon: Icon(
                    i <= _estrellas ? Icons.star : Icons.star_border,
                    color: GriColors.calificacionEstrella,
                  ),
                  iconSize: 36,
                ),
            ],
          ),
          const SizedBox(height: GriSpacing.md),
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
          const SizedBox(height: GriSpacing.md),
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
                style: GriText.boton,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
