import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'equipo_provider.dart';
import 'staff_form_dialog.dart';
import '../shared/responsive_page.dart';

/// Gestión de equipo del restaurante (BOOT-04) — la pieza que hace al
/// restaurante autosuficiente: hasta aquí, dar de alta a un mesero exigía
/// `scripts/seed_firebase.mjs` con la clave de servicio del proyecto.
///
/// UNA SOLA PANTALLA ADAPTATIVA, no dos. Los dos llamadores autorizados
/// (`super_admin` y `admin_restaurante`) hacen exactamente lo mismo y solo
/// difieren en un campo del formulario —el selector de restaurante—; dos
/// pantallas duplicarían formulario, validación, tabla y manejo de errores
/// para ahorrarse un `if`.
///
/// ⚠️ ESTA PANTALLA NO ES UNA FRONTERA DE SEGURIDAD. El ítem del sidebar y el
/// `redirect` del router evitan que un mesero se tropiece con ella, pero quien
/// decide de verdad es (a) `firestore.rules` para el listado —solo el
/// `admin_restaurante` de ese rid puede leer `usuarios` de su tenant— y (b) la
/// callable `crearUsuarioStaff` para el alta. Las dos tienen suite propia
/// contra emuladores.
///
/// Nota sobre "eliminar": no existe y no es un olvido. `firestore.rules`
/// prohíbe `delete` en `usuarios` (`allow delete: if false`) y el alcance de
/// la fase es crear, no borrar. Anotado como deuda conocida.
class EquipoScreen extends ConsumerWidget {
  const EquipoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipoAsync = ref.watch(equipoProvider);

    // Material ancestor: en producción lo provee el Scaffold del AppShell;
    // standalone (tests) sin esto Flutter inyecta estilos fallback
    // (patrón clientes_screen).
    return Material(
      color: GriColors.background,
      child: ResponsivePage(
        padding: const EdgeInsets.all(24),
        builder: (context, ancho) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equipo del restaurante',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GriColors.text,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Personal con acceso al panel — administradores, '
                        'meseros y cocina',
                        style: TextStyle(color: GriColors.gray, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('equipo-nuevo'),
                  onPressed: () => _abrirFormulario(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Nuevo usuario'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: equipoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo cargar el equipo',
                        style: TextStyle(color: GriColors.gray),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(equipoProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (equipo) => equipo.isEmpty
                    ? const _EquipoVacio()
                    : _TablaEquipo(equipo: equipo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _abrirFormulario(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const StaffFormDialog(),
  );
}

/// Estado vacío GUIADO (patrón `EmptyState` de 11-09, que vive en la app
/// cliente y no se puede importar desde aquí: son dos proyectos Flutter
/// independientes). Lo que se conserva es el contrato que allí se fijó:
/// la guía es OBLIGATORIA — constatar el vacío sin explicar qué hacer deja al
/// operador sin saber si la pantalla falló.
class _EquipoVacio extends StatelessWidget {
  const _EquipoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('equipo-vacio'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪪', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay nadie en el equipo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GriColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 420,
              child: Text(
                key: Key('equipo-vacio-guia'),
                'Da de alta a tu personal con "Nuevo usuario": cada persona '
                'entra al panel con su propio correo y contraseña, y solo ve '
                'lo que su rol le permite.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GriColors.gray, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tabla del equipo. `DataTable2` con `minWidth` y dentro de bounds finitos
/// (Expanded), igual que `clientes_screen` — el README del paquete prohíbe
/// montarlo en un scroll sin límite.
class _TablaEquipo extends StatelessWidget {
  const _TablaEquipo({required this.equipo});

  final List<MiembroEquipo> equipo;

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing: 12,
      minWidth: 600,
      columns: const [
        DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
        DataColumn2(label: Text('Correo'), size: ColumnSize.L),
        DataColumn(label: Text('Rol')),
      ],
      rows: [
        for (final m in equipo)
          DataRow2(
            cells: [
              DataCell(
                Text(
                  m.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(m.email)),
              DataCell(Text(etiquetaRol(m.rol))),
            ],
          ),
      ],
    );
  }
}
