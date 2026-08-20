import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import 'clientes_provider.dart';
import 'historial_dialog.dart';
import '../shared/responsive_page.dart';

import '../../core/design_tokens.dart';
/// Tabla de clientes del restaurante (ADMN-03) — usuarios con pedidos en
/// el tenant (DERIVADOS de pedidos: fold distinct por usuarioId con el
/// clienteNombre denormalizado — sin leer usuarios/, que rules prohíben
/// al staff). Tap en una fila → [showHistorialDialog] con sus pedidos.
///
/// DataTable2 con `minWidth: 600` (scroll horizontal en pantallas angostas)
/// y scroll vertical propio con header sticky — SIEMPRE dentro de bounds
/// finitos (Expanded, README data_table_2: jamás en SingleChildScrollView
/// sin límite).
class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesProvider);

    // Material ancestor: en producción lo provee el Scaffold del AppShell;
    // standalone (tests) sin esto Flutter inyecta estilos fallback
    // (patrón cocina_screen).
    return Material(
      color: GriColors.background,
      child: ResponsivePage(
        padding: const EdgeInsets.all(GriSpacing.lg),
        builder: (context, ancho) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Clientes del restaurante',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: GriColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Usuarios que han hecho pedidos — toca una fila para ver su historial',
              style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clientesAsync.cuandoConFallo(
                cargando: () =>
                    const Center(child: CircularProgressIndicator()),
                fallo: (e) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mensajeDeFallo(e, contexto: Contexto.clientes),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GriColors.textoSecundarioAccesible),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(clientesProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                datos: (clientes) => clientes.isEmpty
                    ? const Center(
                        child: Text(
                          'Aún no hay clientes con pedidos',
                          style:
                              TextStyle(fontSize: 16, color: GriColors.textoSecundarioAccesible),
                        ),
                      )
                    : DataTable2(
                        columnSpacing: 12,
                        minWidth: 600,
                        columns: const [
                          DataColumn2(
                            label: Text('Cliente'),
                            size: ColumnSize.L,
                          ),
                          DataColumn(
                            label: Text('Pedidos'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('Total consumo'),
                            numeric: true,
                          ),
                          DataColumn(label: Text('Último pedido')),
                        ],
                        rows: [
                          for (final c in clientes)
                            DataRow2(
                              onSelectChanged: (_) =>
                                  showHistorialDialog(context, ref, c),
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        c.clienteNombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        c.usuarioId,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: GriColors.textoSecundarioAccesible,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(c.nPedidos.toString())),
                                DataCell(Text(formatCOP(c.totalConsumo))),
                                DataCell(
                                  Text(
                                    c.ultimoPedido == null
                                        ? '—'
                                        : DateFormat('dd/MM/yyyy')
                                            .format(c.ultimoPedido!),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
