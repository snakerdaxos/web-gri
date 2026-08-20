import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/cliente_resumen.dart';
import '../../models/pedido_staff.dart';
import 'clientes_provider.dart';

/// Abre el historial de pedidos de [cliente] (`GET /staff/clientes/{id}/
/// historial`, ADMN-03).
///
/// Loading → spinner; VACÍO → «Sin pedidos en este restaurante»; FALLO → el
/// mensaje del clasificador.
///
/// 11-33: antes el error y el vacío compartían texto, con este motivo
/// escrito al lado: «el 404 existence hiding relacional y el vacío son
/// indistinguibles por diseño (08-01)». Ese criterio es correcto para un
/// **404** y falso para todo lo demás: un `permission-denied` o un
/// `unavailable` no ocultan nada, simplemente no se leyeron. Decir «este
/// cliente no tiene pedidos» cuando el listener falló es una afirmación
/// sobre datos que no hemos visto. El 404 sigue saliendo por el texto de
/// vacío, que es lo que 08-01 pedía; el resto, por su causa.
Future<void> showHistorialDialog(
  BuildContext context,
  WidgetRef ref,
  ClienteResumen cliente,
) {
  return showDialog(
    context: context,
    builder: (_) => _HistorialDialog(cliente: cliente),
  );
}

class _HistorialDialog extends ConsumerWidget {
  const _HistorialDialog({required this.cliente});

  final ClienteResumen cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(
      clienteHistorialProvider(cliente.usuarioId),
    );

    return AlertDialog(
      title: Text('Historial de ${cliente.clienteNombre}'),
      content: SizedBox(
        width: 520,
        child: historialAsync.cuandoConFallo(
          cargando: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          // `noEncontrado` (el 404 de existence hiding de 08-01) SIGUE
          // saliendo por el texto de vacío: ahí sí es indistinguible por
          // diseño y decirlo de otra forma filtraría que el cliente existe.
          // Cualquier otra causa se dice.
          fallo: (e) => clasificarFallo(e) == CausaFallo.noEncontrado
              ? const _SinPedidos()
              : _FalloHistorial(
                  mensaje: mensajeDeFallo(e,
                      contexto: Contexto.historialCliente)),
          datos: (pedidos) =>
              pedidos.isEmpty ? const _SinPedidos() : _ListaPedidos(pedidos),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _SinPedidos extends StatelessWidget {
  const _SinPedidos();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Text('Sin pedidos en este restaurante'),
    );
  }
}

/// Lista de pedidos del cliente: mesa + chip de estado + total + fecha +
/// items resumidos ('2× Patacón' por línea, texto secundario).
class _ListaPedidos extends StatelessWidget {
  const _ListaPedidos(this.pedidos);

  final List<PedidoStaff> pedidos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: pedidos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _PedidoTile(pedido: pedidos[i]),
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  const _PedidoTile({required this.pedido});

  final PedidoStaff pedido;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Mesa ${pedido.mesaNumero}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                // Chip de estado con el color semántico del enum.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: pedido.estado.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pedido.estado.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatCOP(pedido.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy · HH:mm').format(pedido.createdAt),
              style: const TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 12),
            ),
            if (pedido.items.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final item in pedido.items)
                Text(
                  '${item.cantidad}× ${item.nombre}',
                  style: const TextStyle(fontSize: 12, color: GriColors.textoSecundarioAccesible),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// El historial no se pudo LEER (11-33) — distinto de «no hay historial».
///
/// Se separa de [_SinPedidos] a propósito: aquel afirma algo sobre los datos
/// («este cliente no ha pedido aquí») y éste sobre nuestra capacidad de
/// leerlos. Confundirlos fue el defecto que este plan repara.
class _FalloHistorial extends StatelessWidget {
  const _FalloHistorial({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: GriColors.textoSecundarioAccesible),
          ),
        ),
      ),
    );
  }
}
