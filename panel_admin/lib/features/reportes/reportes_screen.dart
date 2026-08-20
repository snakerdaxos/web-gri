import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/reporte.dart';
import 'reportes_provider.dart';
import '../shared/responsive_page.dart';
import '../../core/gri_icons.dart';

import '../../core/design_tokens.dart';
/// Pantalla /reportes (REPO-01/02, 10-06): ventas por rango + top platos,
/// computados EN EL CLIENTE desde pedidos `servido` (fold — sin backend).
///
/// **Rango**: pickers Inicio/Fin + 'Consultar' dispara la consulta del
/// [reporteProvider] family (rango efectivo: sin fechas aplica últimos 7
/// días). Validación desde<=hasta ANTES de consultar (SnackBar, sin query).
///
/// **Estado LOCAL del screen** (decisión plan 08-05): consultas one-shot
/// por rango — el family cachea por (desde, hasta) y la pantalla decide
/// cuándo mostrar la sección de resultados.
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => ReportesScreenState();
}

class ReportesScreenState extends ConsumerState<ReportesScreen> {
  DateTime? _desde;
  DateTime? _hasta;

  /// Rango efectivo de la ÚLTIMA consulta (null = nunca consultado).
  ({DateTime desde, DateTime hasta})? _consulta;

  static final DateFormat _fmt = DateFormat('dd/MM/yyyy');

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

  /// Rango efectivo: fechas elegidas o default últimos 7 días (paridad
  /// con el default server-side de la era REST). Inicio a medianoche,
  /// fin a fin de día (todo el día terminal computa).
  ({DateTime desde, DateTime hasta}) _rangoEfectivo() {
    final hoy = DateTime.now();
    if (_desde != null || _hasta != null) {
      final desde = _desde ?? _hasta!;
      final hasta = _hasta ?? _desde!;
      return (
        desde: DateTime(desde.year, desde.month, desde.day),
        hasta: DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999),
      );
    }
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return (
      desde: inicioHoy.subtract(const Duration(days: 6)),
      hasta: DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59, 999),
    );
  }

  void _consultar() {
    final error = validarRango(_desde, _hasta);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return; // SIN consulta (ahorra la query).
    }
    setState(() => _consulta = _rangoEfectivo());
  }

  @override
  Widget build(BuildContext context) {
    final consulta = _consulta;

    return Material(
      // Material ancestor: en producción lo provee el Scaffold del AppShell;
      // standalone (tests) sin esto Flutter inyecta estilos fallback.
      color: GriColors.background,
      child: ResponsivePage(
        padding: const EdgeInsets.all(GriSpacing.lg),
        builder: (context, ancho) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDesde,
                  // size 14 = el labelLarge que el emoji heredaba del boton.
                  icon: const Icon(GriIcons.reservas, size: 14),
                  label: Text(
                    _desde != null ? _fmt.format(_desde!) : 'Inicio',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickHasta,
                  icon: const Icon(GriIcons.reservas, size: 14),
                  label: Text(
                    _hasta != null ? _fmt.format(_hasta!) : 'Fin',
                  ),
                ),
                ElevatedButton(
                  onPressed: _consultar,
                  child: const Text('Consultar'),
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
              'Sin rango: se consultan los últimos 7 días',
              style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: consulta == null
                  ? const Center(
                      child: Text(
                        'Elige un rango de fechas y presiona Consultar',
                        style: TextStyle(color: GriColors.textoSecundarioAccesible),
                      ),
                    )
                  : _Resultados(
                      desde: consulta.desde,
                      hasta: consulta.hasta,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultados: watches del [reporteProvider] con el rango consultado.
class _Resultados extends ConsumerWidget {
  const _Resultados({required this.desde, required this.hasta});

  final DateTime desde;
  final DateTime hasta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporteAsync = ref.watch(reporteProvider(desde, hasta));

    return reporteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Error al consultar los reportes',
              style: TextStyle(color: GriColors.textoSecundarioAccesible),
            ),
            TextButton(
              onPressed: () => ref.invalidate(reporteProvider(desde, hasta)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (reporte) => _Contenido(
        reporte: reporte,
        desde: desde,
        hasta: hasta,
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.reporte,
    required this.desde,
    required this.hasta,
  });

  final Reporte reporte;
  final DateTime desde;
  final DateTime hasta;

  static final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    if (reporte.numeroPedidos == 0) {
      return const Center(
        child: Text(
          'Sin ventas en el rango',
          style: TextStyle(color: GriColors.textoSecundarioAccesible),
        ),
      );
    }

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: _ResumenCard(
                icono: GriIcons.ventas,
                label: 'Total vendido',
                value: formatCOP(reporte.totalVentas),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResumenCard(
                icono: GriIcons.ticket,
                label: 'Pedidos',
                value: '${reporte.numeroPedidos}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Pedidos servidos (${_fmt.format(desde)} → ${_fmt.format(hasta)})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GriColors.text,
          ),
        ),
        const SizedBox(height: 8),
        if (reporte.topPlatos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Sin ventas en el rango',
              style: TextStyle(color: GriColors.textoSecundarioAccesible),
            ),
          )
        else ...[
          const Text(
            'Platos más vendidos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: GriColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < reporte.topPlatos.length; i++)
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
                    title: Text(reporte.topPlatos[i].nombre),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '×${reporte.topPlatos[i].cantidad}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Text(formatCOP(reporte.topPlatos[i].venta)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Card resumen estilo StatCard del dashboard, con valor String (el total
/// viaja formateado con formatCOP).
class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.icono,
    required this.label,
    required this.value,
  });

  final IconData icono;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: griCardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 14)),
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
              color: GriColors.reporteIconoBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            // size 25 = el fontSize del emoji que sustituye; el color es el
            // azul del propio recuadro, que antes ponia la fuente de emoji.
            child: Icon(icono, size: 25, color: GriColors.reporteIconoFg),
          ),
        ],
      ),
    );
  }
}
