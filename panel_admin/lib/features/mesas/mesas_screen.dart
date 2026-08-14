import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../dashboard/mesas_provider.dart';
import '../dashboard/widgets/mesa_tile.dart';
import 'mesa_actions_sheet.dart';
import 'mesa_form_dialog.dart';

/// Pantalla /mesas (MESA-01, 08-03) — grid vivo de mesas + alta/edición.
///
/// * Watch del [mesasProvider] EXISTENTE del dashboard (Stream WS con
///   kick-to-refetch + safety net 60s) — NO se crea un provider nuevo:
///   crear/editar una mesa emite `mesa.estado` en el backend → este grid
///   se refresca solo (las mesas nuevas aparecen sin invalidate manual).
/// * Tap en un tile → [showMesaActionsSheet] con edición habilitada
///   (transiciones de estado + Ver QR + Editar mesa).
/// * FAB 'Nueva mesa' → [MesaFormDialog] en modo crear.
class MesasScreen extends ConsumerWidget {
  const MesasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesasAsync = ref.watch(mesasProvider);

    return Scaffold(
      backgroundColor: GriColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const MesaFormDialog(),
        ),
        backgroundColor: GriColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva mesa'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive 4/3/2 (mismo criterio del mapa del dashboard).
          final crossAxis = constraints.maxWidth >= 1100
              ? 4
              : (constraints.maxWidth >= 750 ? 3 : 2);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mesas',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Crea, edita y gestiona los códigos QR de tus mesas',
                  style: TextStyle(color: GriColors.gray),
                ),
                const SizedBox(height: 20),
                mesasAsync.when(
                  loading: () => const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _ErrorBox(
                    message: 'Error cargando mesas',
                    onRetry: () => ref.invalidate(mesasProvider),
                  ),
                  data: (mesas) {
                    if (mesas.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(
                            'Sin mesas configuradas',
                            style: TextStyle(color: GriColors.gray),
                          ),
                        ),
                      );
                    }
                    return GridView.count(
                      crossAxisCount: crossAxis,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.1,
                      children: [
                        for (final m in mesas)
                          MesaTile(
                            mesa: m,
                            onTap: () => showMesaActionsSheet(
                              context,
                              ref,
                              m,
                              showEdit: true,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(color: GriColors.gray, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
