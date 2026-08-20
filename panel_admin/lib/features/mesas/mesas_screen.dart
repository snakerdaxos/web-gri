import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import '../dashboard/mesas_provider.dart';
import '../dashboard/widgets/mesa_tile.dart';
import 'mesa_actions_sheet.dart';
import 'mesa_form_dialog.dart';
import '../dashboard/dashboard_screen.dart' show mesaGridDelegate;
import '../shared/error_box.dart';
import '../shared/responsive_page.dart';

/// Pantalla /mesas (MESA-01, 10-06) — grid vivo de mesas + alta/edición.
///
/// * Watch del [mesasProvider] EXISTENTE del dashboard (`mesas where
///   restauranteId == rid orderBy numero → snapshots()`) — NO se crea un
///   provider nuevo: crear/editar/eliminar una mesa (mesas_crud) muta los
///   docs → este grid se refresca solo por el onSnapshot.
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
        icon: const Icon(Icons.add),
        label: const Text('Nueva mesa'),
      ),
      body: ResponsivePage(
        builder: (context, ancho) {
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
                  style: TextStyle(color: GriColors.textoSecundarioAccesible),
                ),
                const SizedBox(height: 20),
                mesasAsync.cuandoConFallo(
                  cargando: () => const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  fallo: (e) => ErrorBox(
                    message: mensajeDeFallo(e, contexto: Contexto.mesas),
                    onRetry: () => ref.invalidate(mesasProvider),
                  ),
                  datos: (mesas) {
                    if (mesas.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(
                            'Sin mesas configuradas',
                            style: TextStyle(color: GriColors.textoSecundarioAccesible),
                          ),
                        ),
                      );
                    }
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // El MISMO delegate que el mapa del dashboard: las dos
                      // rejillas de mesas no pueden divergir.
                      gridDelegate: mesaGridDelegate,
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

