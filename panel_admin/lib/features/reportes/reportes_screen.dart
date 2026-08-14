import 'package:data_table_2/data_table_2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/token_provider.dart';
import '../../models/reporte.dart';
import '../dashboard/restaurante_provider.dart';

/// Pantalla /reportes (REPO-01/02): ventas por rango + top platos.
///
/// **Estado LOCAL del screen** (decisión plan 08-05, desviación menor del
/// research): son consultas one-shot por rango — no datos vivos que un
/// provider deba cachear/invalidar. 'Consultar' dispara `getReporteVentas`
/// + `getTopPlatos` en paralelo (`Future.wait`).
///
/// **Rango**: si el usuario no fija fechas NO viajan params y el server
/// aplica su default DB-side (últimos 7 días — el Pitfall 3 de TZ queda
/// del lado del server, threat model 08-05). Validación desde<=hasta
/// ANTES de llamar (ahorra el 422); el 422 del server también se maneja.
///
/// DataTable2 SIEMPRE en bounds finitos (regla data_table_2): alto
/// computado por fila — jamás en un contexto de altura infinita.
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => ReportesScreenState();
}

class ReportesScreenState extends ConsumerState<ReportesScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  VentasReporte? _ventas;
  List<TopPlato>? _top;
  bool _cargando = false;

  static final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  /// YYYY-MM-DD o null (null = clave omitida del query — default server).
  String? get _desdeQ => _desde?.toIso8601String().substring(0, 10);
  String? get _hastaQ => _hasta?.toIso8601String().substring(0, 10);

  /// Valida el rango client-side (threat model 08-05): mensaje de error o
  /// null si es válido. Estático/público para testearlo sin pickers.
  static String? validarRango(DateTime? desde, DateTime? hasta) {
    if (desde != null && hasta != null && desde.isAfter(hasta)) {
      return 'La fecha inicial no puede ser mayor que la final';
    }
    return null;
  }

  /// Solo tests: fija el rango sin pasar por los pickers (plan 08-05,
  /// alternativa al manejo frágil del showDatePicker en widget tests).
  @visibleForTesting
  void debugSetFechas(DateTime? desde, DateTime? hasta) {
    setState(() {
      _desde = desde;
      _hasta = hasta;
    });
  }

  Future<void> _pickDesde() => _pick(esDesde: true);

  Future<void> _pickHasta() => _pick(esDesde: false);

  Future<void> _pick({required bool esDesde}) async {
    final actual = esDesde ? _desde : _hasta;
    final otro = esDesde ? _hasta : _desde;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? otro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (elegida == null) return;
    setState(() {
      if (esDesde) {
        _desde = elegida;
      } else {
        _hasta = elegida;
      }
    });
  }

  Future<void> _consultar() async {
    final error = validarRango(_desde, _hasta);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return; // SIN llamada a la API (ahorra el 422 server-side).
    }

    setState(() => _cargando = true);
    try {
      // queryRid como en cocina: super_admin manda el tenant del dropdown;
      // staff viaja sin param (el tenant sale del token).
      final user = ref.read(authStateProvider).value;
      final selectedRid = ref.read(currentRestauranteIdProvider);
      final rid = selectedRid ?? user?.restaurantId;
      final queryRid = user?.isSuperAdmin == true ? rid : null;

      final client = ref.read(apiClientProvider);
      final results = await Future.wait<dynamic>([
        client.getReporteVentas(
          desde: _desdeQ,
          hasta: _hastaQ,
          restauranteId: queryRid,
        ),
        client.getTopPlatos(
          desde: _desdeQ,
          hasta: _hastaQ,
          restauranteId: queryRid,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _ventas = results[0] as VentasReporte;
        _top = results[1] as List<TopPlato>;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_dioMsg(e))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// detail del backend: los HTTPException viajan como string (p.ej. el
  /// 422 'desde no puede ser mayor que hasta' de _rango_reportes, 08-02).
  static String _dioMsg(DioException e) {
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] : null;
    return detail is String ? detail : 'Error al consultar los reportes';
  }

  @override
  Widget build(BuildContext context) {
    final ventas = _ventas;
    final top = _top;

    return Material(
      // Material ancestor: en producción lo provee el Scaffold del AppShell;
      // standalone (tests) sin esto Flutter inyecta estilos fallback.
      color: GriColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDesde,
                  icon: const Text('📅'),
                  label: Text(
                    _desde != null ? _fmt.format(_desde!) : 'Inicio',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickHasta,
                  icon: const Text('📅'),
                  label: Text(_hasta != null ? _fmt.format(_hasta!) : 'Fin'),
                ),
                ElevatedButton(
                  onPressed: _cargando ? null : _consultar,
                  child: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Consultar'),
                ),
                TextButton(
                  onPressed: (_desde == null && _hasta == null)
                      ? null
                      : () => setState(() {
                          _desde = null;
                          _hasta = null;
                        }),
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Sin rango: el servidor usa los últimos 7 días por defecto',
              style: TextStyle(color: GriColors.gray, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ventas == null || top == null
                  ? const Center(
                      child: Text(
                        'Elige un rango de fechas y presiona Consultar',
                        style: TextStyle(color: GriColors.gray),
                      ),
                    )
                  : _Resultados(ventas: ventas, top: top),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultados: cards resumen + tabla por día + top platos.
class _Resultados extends StatelessWidget {
  const _Resultados({required this.ventas, required this.top});

  final VentasReporte ventas;
  final List<TopPlato> top;

  @override
  Widget build(BuildContext context) {
    if (ventas.porDia.isEmpty && top.isEmpty) {
      return const Center(
        child: Text('Sin ventas en el rango', style: TextStyle(color: GriColors.gray)),
      );
    }

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: _ResumenCard(
                emoji: '💵',
                label: 'Total vendido',
                value: formatCOP(ventas.total),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResumenCard(
                emoji: '🧾',
                label: 'Pedidos',
                value: '${ventas.numPedidos}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Ventas por día (${ventas.desde} → ${ventas.hasta})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GriColors.text,
          ),
        ),
        const SizedBox(height: 8),
        if (ventas.porDia.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Sin ventas en el rango', style: TextStyle(color: GriColors.gray)),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            // Bounds finitos (regla data_table_2): alto computado — header
            // 48 + filas 48 + margen inferior.
            child: SizedBox(
              height: 48 + 48.0 * ventas.porDia.length + 8,
              child: DataTable2(
                minWidth: 500,
                headingRowHeight: 48,
                dataRowHeight: 48,
                columnSpacing: 12,
                columns: const [
                  DataColumn2(label: Text('Fecha'), size: ColumnSize.L),
                  DataColumn2(label: Text('Nº pedidos'), numeric: true),
                  DataColumn2(label: Text('Total'), numeric: true),
                ],
                rows: [
                  for (final d in ventas.porDia)
                    DataRow(cells: [
                      DataCell(Text(d.fecha)),
                      DataCell(Text('${d.numPedidos}')),
                      DataCell(Text(formatCOP(d.total))),
                    ]),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Platos más vendidos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GriColors.text,
          ),
        ),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Text('Sin ventas en el rango', style: TextStyle(color: GriColors.gray))
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: GriColors.primary,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(top[i].nombre),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '×${top[i].cantidad}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Text(formatCOP(top[i].total)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Card resumen estilo StatCard del dashboard, con valor String (el total
/// viaja formateado con formatCOP; StatCard exige int).
class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: GriColors.gray, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 25)),
          ),
        ],
      ),
    );
  }
}
