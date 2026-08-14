import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/categoria_staff.dart';
import '../dashboard/restaurante_provider.dart';
import 'menu_provider.dart';

/// Form crear/editar categoría (MENU-01).
///
/// * [categoria] == null → crear (`POST /staff/categorias {nombre, orden?}`):
///   el POST NO acepta `activo` (server default true, contrato 08-01) — el
///   switch 'Activo' aparece SOLO en edición.
/// * Editar → `PATCH /staff/categorias/{id}` con SOLO los campos modificados
///   (null-aware elements). El switch 'Activo' es el soft-delete: la
///   categoría desaparece de /public pero sigue aquí para gestión.
/// * Tras éxito: pop + SnackBar + `ref.invalidate(staffMenuProvider)` — el
///   menú NO tiene WS (refresh on-demand, decisión research 08).
/// * DioException 409 (nombre dup por tenant) → SnackBar accionable.
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
  late final bool _activo;
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

  /// Editar sin cambios → nada que enviar (backend 422 "Nada que
  /// actualizar"): Guardar queda deshabilitado (patrón mesa_form_dialog).
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
    final user = ref.read(authStateProvider).value;
    final rid = ref.read(currentRestauranteIdProvider) ?? user?.restaurantId;
    final queryRid = user?.isSuperAdmin == true ? rid : null;
    final client = ref.read(apiClientProvider);

    try {
      if (!_editando) {
        await client.createCategoria(nombre, orden: orden,
            restauranteId: queryRid);
      } else {
        final original = widget.categoria!;
        await client.updateCategoria(
          original.id,
          nombre: nombre != original.nombre ? nombre : null,
          orden: orden != original.orden ? orden : null,
          activo: _activo != original.activo ? _activo : null,
          restauranteId: queryRid,
        );
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.response?.statusCode == 409
                ? 'Ya existe una categoría con ese nombre'
                : 'No se pudo guardar la categoría',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
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

    // Éxito: cerrar + confirmar + refresh on-demand (sin WS — invalidate).
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          _editando ? 'Categoría actualizada' : 'Categoría "$nombre" creada',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    ref.invalidate(staffMenuProvider);
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
              // Soft-delete: solo en edición (el POST no acepta activo).
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
