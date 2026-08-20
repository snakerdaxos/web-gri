import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/categoria_staff.dart';
import 'categoria_form_dialog.dart';
import 'menu_provider.dart';
import 'producto_form_dialog.dart';
import '../shared/responsive_page.dart';

import '../../core/design_tokens.dart';
/// Gestión del menú (MENU-01/02) — vive como tab de /configuracion
/// (decisión discreta 08: el sidebar de 7 ítems no tiene entrada Menú).
///
/// Categorías como ExpansionTile; el staff ve TODO (incluidos inactivos y
/// agotados con sus flags — /public filtra, NUNCA filtrar client-side).
/// El refresh es on-demand: los forms invalidan [staffMenuProvider] tras
/// cada mutación exitosa (el menú NO tiene WS — decisión research 08).
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(staffMenuProvider);

    // Material ancestor: en producción lo provee el Scaffold del AppShell;
    // standalone (tests) sin esto Flutter inyecta estilos fallback
    // (patrón cocina_screen).
    return Material(
      color: GriColors.background,
      // Sin `padding` propio: esta pantalla ya lo pone en sus hijos
      // (fromLTRB(24,16,24,4) en la cabecera y fromLTRB(24,8,24,24) en la
      // lista) y homogeneizarlos sería un cambio visual, fuera de alcance.
      child: ResponsivePage(
        builder: (context, ancho) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(GriSpacing.lg, GriSpacing.md, GriSpacing.lg, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Categorías y productos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const CategoriaFormDialog(),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva categoría'),
                ),
              ],
            ),
          ),
          Expanded(
            child: menuAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error cargando el menú',
                      style: TextStyle(color: GriColors.gray),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(staffMenuProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (categorias) => categorias.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sin categorías',
                            style: TextStyle(
                              fontSize: 18,
                              color: GriColors.gray,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Crea la primera categoría para armar el menú',
                            style: TextStyle(
                              color: GriColors.gray,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          GriSpacing.lg, GriSpacing.sm, GriSpacing.lg, GriSpacing.lg),
                      children: [
                        for (final c in categorias) _CategoriaTile(categoria: c),
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

/// Una categoría expandible: título (nombre + badge 'Inactiva' si aplica) +
/// editar + 'Nuevo producto' visible SOLO expandido; hijos = productos.
class _CategoriaTile extends StatefulWidget {
  const _CategoriaTile({required this.categoria});

  final CategoriaStaff categoria;

  @override
  State<_CategoriaTile> createState() => _CategoriaTileState();
}

class _CategoriaTileState extends State<_CategoriaTile> {
  bool _expandida = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.categoria;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        onExpansionChanged: (v) => setState(() => _expandida = v),
        title: Row(
          children: [
            Expanded(
              child: Text(
                c.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            // Soft-delete visible (naranja): el badge de categoría.
            if (!c.activo) const _MenuBadge('Inactiva', GriColors.badgeCategoriaInactiva),
          ],
        ),
        subtitle: Text(
          '${c.productos.length} producto${c.productos.length == 1 ? '' : 's'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              // El tooltip NOMBRA la categoría (11-25): con varias categorías
              // en pantalla, un 'Editar categoría' repetido no dice cuál se
              // edita — ni al pasar el ratón ni en el árbol de semántica, que
              // es donde acaba el `tooltip` de un IconButton.
              tooltip: 'Editar la categoría ${c.nombre}',
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: GriColors.gray),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CategoriaFormDialog(categoria: c),
              ),
            ),
            // Visible SOLO expandido (plan): acceso rápido a crear producto
            // dentro de esta categoría.
            if (_expandida)
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      ProductoFormDialog(categoriaId: c.id),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nuevo producto'),
              ),
          ],
        ),
        children: [
          if (c.productos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sin productos en esta categoría',
                  style: TextStyle(color: GriColors.gray, fontSize: 13),
                ),
              ),
            )
          else
            for (final p in c.productos)
              ListTile(
                dense: true,
                title: Row(
                  children: [
                    Expanded(child: Text(p.nombre)),
                    // Agotado = !disponible (ámbar, transitorio).
                    if (!p.disponible)
                      const _MenuBadge('Agotado', GriColors.badgeAgotado),
                    // Inactivo = soft-delete (gris) — semántica DISTINTA.
                    if (!p.activo)
                      const _MenuBadge('Inactivo', GriColors.badgeInactivo),
                  ],
                ),
                subtitle: (p.descripcion ?? '').isEmpty
                    ? null
                    : Text(
                        p.descripcion!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                trailing: Text(
                  formatCOP(p.precio),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => ProductoFormDialog(
                    producto: p,
                    categoriaId: p.categoriaId,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Badge compacto para flags del menú (Inactiva/Agotado/Inactivo) —
/// etiquetas SIEMPRE visibles, nunca un toggle ambiguo (threat model).
class _MenuBadge extends StatelessWidget {
  const _MenuBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
