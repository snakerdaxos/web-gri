import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../models/categoria_staff.dart';
import '../dashboard/restaurante_provider.dart';
import 'menu_provider.dart';

/// Form crear/editar categoría (MENU-01) sobre Firestore (10-06).
///
/// * [categoria] == null → crear ([crearCategoria] con autoId; nace
///   `activo: true` — el switch 'Activa' aparece SOLO en edición).
/// * Editar → [actualizarCategoria] con SOLO los campos modificados
///   (diff quirúrgico). El switch 'Activa' es el soft-delete: la
///   categoría desaparece del menú del cliente pero sigue aquí para
///   gestión.
/// * Tras éxito: pop + SnackBar. El menú es un STREAM (onSnapshot de
///   categorías+productos) — se refresca SOLO, sin invalidate manual.
class CategoriaFormDialog extends ConsumerStatefulWidget {
  const CategoriaFormDialog({super.key, this.categoria});

  final CategoriaStaff? categoria;

  @override
  ConsumerState<CategoriaFormDialog> createState() =>
      _CategoriaFormDialogState();
}

class _CategoriaFormDialogState extends ConsumerState<CategoriaFormDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _ordenCtrl;
  late bool _activo;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.categoria?.nombre ?? '');
    _ordenCtrl = TextEditingController(
      text: (widget.categoria?.orden ?? 0).toString(),
    );
    _activo = widget.categoria?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  bool get _editando => widget.categoria != null;

  /// Editar sin cambios → nada que escribir: Guardar queda deshabilitado
  /// (patrón mesa_form_dialog).
  bool get _sinCambios {
    if (!_editando) return false;
    final original = widget.categoria!;
    final orden = int.tryParse(_ordenCtrl.text.trim()) ?? -1;
    return _nombreCtrl.text.trim() == original.nombre &&
        orden == original.orden &&
        _activo == original.activo;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nombre = _nombreCtrl.text.trim();
    final orden = int.tryParse(_ordenCtrl.text.trim()) ?? 0;

    // Capturas ANTES del await (patrón cocina_screen).
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final db = ref.read(firestoreProvider);
    final rid = await ref.read(ridActivoProvider.future);

    try {
      if (rid == null) throw StateError('No hay restaurante seleccionado');
      if (!_editando) {
        await crearCategoria(db, rid: rid, nombre: nombre, orden: orden);
      } else {
        final original = widget.categoria!;
        await actualizarCategoria(
          db,
          categoria: original,
          nombre: nombre != original.nombre ? nombre : null,
          orden: orden != original.orden ? orden : null,
          activo: _activo != original.activo ? _activo : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la categoría'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Éxito: cerrar + confirmar. El stream del menú re-emite solo.
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          _editando ? 'Categoría actualizada' : 'Categoría "$nombre" creada',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _editando
            ? 'Editar categoría ${widget.categoria!.nombre}'
            : 'Nueva categoría',
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Entradas',
                ),
                autofocus: !_editando,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Requerido';
                  if (t.length > 100) return 'Máximo 100 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ordenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Orden',
                  hintText: 'Posición en el menú (menor = primero)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Requerido';
                  final n = int.tryParse(t);
                  if (n == null) return 'Debe ser un número';
                  if (n < 0) return 'Debe ser 0 o mayor';
                  return null;
                },
              ),
              // Soft-delete: solo en edición (el alta nace activa).
              if (_editando)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activa'),
                  subtitle: const Text(
                    'Una categoría inactiva desaparece del menú del cliente',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _activo,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _activo = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: (_saving || _sinCambios) ? null : _guardar,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
