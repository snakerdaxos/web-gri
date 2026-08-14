import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/mesa.dart';
import '../dashboard/restaurante_provider.dart';
import 'mesa_form_dialog.dart';
import 'qr_dialog.dart';

/// Espejo client-side de `MESA_TRANSITIONS` (backend
/// `app/core/state_machines.py` — única fuente de verdad es el server).
///
/// La UI ofrece SOLO los destinos válidos para el estado actual (UX), pero
/// el 409 del backend SIEMPRE se maneja: la carrera entre dos staff la
/// gana el server (ver [_cambiarEstado]).
const kMesaTransitions = <String, Set<String>>{
  'disponible': {'reservada', 'ocupada'},
  'reservada': {'ocupada', 'disponible'},
  'ocupada': {'limpieza'},
  'limpieza': {'disponible'},
};

/// Labels de negocio por (origen, destino) — el staff nunca ve nombres
/// crudos de estado salvo en el header del sheet.
const kMesaActionLabels = <(String, String), String>{
  ('disponible', 'reservada'): 'Marcar reservada',
  ('disponible', 'ocupada'): 'Marcar ocupada',
  ('reservada', 'ocupada'): 'Marcar ocupada',
  ('reservada', 'disponible'): 'Liberar reserva',
  ('ocupada', 'limpieza'): 'Marcar en limpieza',
  ('limpieza', 'disponible'): 'Liberar',
};

/// Orden estable de los destinos en el sheet (los Sets no garantizan
/// orden; esta lista fija lo hace determinista para tests y UX).
const _ordenDestinos = <String>['disponible', 'reservada', 'ocupada', 'limpieza'];

String _estadoLabel(String e) => e[0].toUpperCase() + e.substring(1);

/// Abre el bottom sheet de acciones de una mesa (ADMN-04).
///
/// * Acciones de estado: SOLO los destinos válidos según
///   [kMesaTransitions] para `mesa.estado`.
/// * `📷 Ver código QR` siempre disponible; `✏️ Editar mesa` solo si
///   [showEdit] (la edición vive en /mesas, no en el mapa operacional).
///
/// Los callbacks cierran el sheet ANTES de abrir el siguiente diálogo, y
/// las mutaciones usan el `ref`/`context` del CALLER (capturados de forma
/// síncrona antes del await — patrón cocina_screen).
Future<void> showMesaActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Mesa mesa, {
  bool showEdit = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _MesaActionsSheet(
      mesa: mesa,
      showEdit: showEdit,
      onEstado: (destino) => _cambiarEstado(context, ref, mesa, destino),
      onVerQr: () {
        Navigator.of(context).pop();
        showQrDialog(context, mesa);
      },
      onEditar: () {
        Navigator.of(context).pop();
        showDialog<void>(
          context: context,
          builder: (_) => MesaFormDialog(mesa: mesa),
        );
      },
    ),
  );
}

class _MesaActionsSheet extends StatelessWidget {
  const _MesaActionsSheet({
    required this.mesa,
    required this.showEdit,
    required this.onEstado,
    required this.onVerQr,
    required this.onEditar,
  });

  final Mesa mesa;
  final bool showEdit;
  final void Function(String destino) onEstado;
  final VoidCallback onVerQr;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final origen = mesa.estado.name;
    final validos = kMesaTransitions[origen] ?? const <String>{};
    final destinos = [
      for (final d in _ordenDestinos)
        if (validos.contains(d)) d,
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                Text(
                  'Mesa ${mesa.numero}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text('— ${_estadoLabel(origen)}'),
              ],
            ),
          ),
          const Divider(height: 1),
          // SOLO transiciones válidas para el estado actual (mirror).
          for (final d in destinos)
            ListTile(
              title: Text(kMesaActionLabels[(origen, d)] ?? d),
              onTap: () => onEstado(d),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Text('📷', style: TextStyle(fontSize: 20)),
            title: const Text('Ver código QR'),
            onTap: onVerQr,
          ),
          if (showEdit)
            ListTile(
              leading: const Text('✏️', style: TextStyle(fontSize: 20)),
              title: const Text('Editar mesa'),
              onTap: onEditar,
            ),
        ],
      ),
    );
  }
}

/// `POST /staff/mesas/{id}/estado` + feedback. El server es la autoridad:
/// 409 = la transición ya no era válida (otro staff la movió primero) →
/// SnackBar y la lista se refresca sola por el evento WS `mesa.estado`
/// (kick-to-refetch del backend — JAMÁS se muta estado local).
Future<void> _cambiarEstado(
  BuildContext context,
  WidgetRef ref,
  Mesa mesa,
  String destino,
) async {
  // Capturas síncronas ANTES del await (patrón cocina_screen).
  final messenger = ScaffoldMessenger.maybeOf(context);
  final user = ref.read(authStateProvider).value;
  final rid = ref.read(currentRestauranteIdProvider) ?? user?.restaurantId;
  final queryRid = user?.isSuperAdmin == true ? rid : null;
  final client = ref.read(apiClientProvider);

  // Cerrar el sheet primero: el feedback (SnackBar) vive en la pantalla.
  Navigator.of(context).pop();

  try {
    await client.setMesaEstado(mesa.id, destino, restauranteId: queryRid);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Mesa ${mesa.numero} → $destino'),
        duration: const Duration(seconds: 3),
      ),
    );
  } on DioException catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          e.response?.statusCode == 409
              ? 'La mesa cambió de estado (otro usuario la actualizó) '
                  '— se refrescó la lista'
              : 'No se pudo actualizar la mesa',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('No se pudo actualizar la mesa'),
        duration: Duration(seconds: 3),
      ),
    );
  }
  // Sin invalidate local: el evento WS `mesa.estado` (emitido post-commit
  // por el backend) dispara el kick-to-refetch del mesasProvider.
}
