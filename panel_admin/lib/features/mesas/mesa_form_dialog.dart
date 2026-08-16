import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../models/mesa.dart';
import '../dashboard/restaurante_provider.dart';
import 'mesas_crud.dart';

/// Form crear/editar mesa (MESA-01) sobre Firestore (10-06).
///
/// * [mesa] == null → crear ([crearMesa] con doc ID determinista
///   `GRI-MESA-{rid}-{numero:03d}`); si no → editar ([actualizarMesa]).
/// * Al editar con un número distinto al original muestra el warning de
///   regeneración de QR ANTES de guardar: el doc ID (= código QR) deriva
///   del número, así que la mesa se MUEVE a un doc nuevo — el impreso
///   anterior queda obsoleto.
/// * [MesaDuplicadaException] (número ya usado) → SnackBar accionable y
///   el dialog permanece abierto para corregir.
/// * Tras éxito: pop + SnackBar. El grid se refresca SOLO por el
///   onSnapshot del `mesasProvider` — JAMÁS se invalida ni muta la lista
///   local desde aquí.
/// * Edición ofrece `Eliminar` (confirmación) → [eliminarMesa].
class MesaFormDialog extends ConsumerStatefulWidget {
  const MesaFormDialog({super.key, this.mesa});

  final Mesa? mesa;

  @override
  ConsumerState<MesaFormDialog> createState() => _MesaFormDialogState();
}

class _MesaFormDialogState extends ConsumerState<MesaFormDialog> {
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _capacidadCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _numeroCtrl = TextEditingController(
      text: widget.mesa?.numero.toString() ?? '',
    );
    _capacidadCtrl = TextEditingController(
      text: widget.mesa?.capacidad.toString() ?? '',
    );
    // Re-render al tipear: el warning de QR aparece/desaparece con el número.
    _numeroCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
  }

  bool get _editando => widget.mesa != null;

  /// El número tipeado difiere del original → la mesa se mueve de doc y el
  /// QR regenera (doc ID determinista).
  bool get _regeneraQr =>
      _editando &&
      (int.tryParse(_numeroCtrl.text.trim()) ?? -1) != widget.mesa!.numero;

  /// Editar sin cambios → nada que escribir: Guardar queda deshabilitado.
  bool get _sinCambios =>
      _editando &&
      (int.tryParse(_numeroCtrl.text.trim()) ?? -1) == widget.mesa!.numero &&
      (int.tryParse(_capacidadCtrl.text.trim()) ?? -1) ==
          widget.mesa!.capacidad;

  String? _validarNumero(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (v == null || v.trim().isEmpty) return 'Requerido';
    if (n == null) return 'Debe ser un número';
    if (n < 1 || n > 999) return 'Entre 1 y 999';
    return null;
  }

  String? _validarCapacidad(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (v == null || v.trim().isEmpty) return 'Requerido';
    if (n == null) return 'Debe ser un número';
    if (n < 1 || n > 20) return 'Entre 1 y 20';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final numero = int.parse(_numeroCtrl.text.trim());
    final capacidad = int.parse(_capacidadCtrl.text.trim());

    // Capturas ANTES del await (patrón cocina_screen — sin context a través
    // del gap async). El [WidgetRef] también se lee síncrono.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final db = ref.read(firestoreProvider);
    final rid = await ref.read(ridActivoProvider.future);

    try {
      if (rid == null) throw StateError('No hay restaurante seleccionado');
      if (!_editando) {
        await crearMesa(db, rid: rid, numero: numero, capacidad: capacidad);
      } else {
        final original = widget.mesa!;
        await actualizarMesa(
          db,
          mesa: original,
          rid: rid,
          numero: numero != original.numero ? numero : null,
          capacidad: capacidad != original.capacidad ? capacidad : null,
        );
      }
    } on MesaDuplicadaException {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Ya existe una mesa con ese número'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la mesa'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Éxito: cerrar + confirmar. El refresh del grid llega por el
    // onSnapshot del mesasProvider (NO invalidar ni mutar listas locales).
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(_editando ? 'Mesa actualizada' : 'Mesa $numero creada'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _eliminar() async {
    final mesa = widget.mesa!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final db = ref.read(firestoreProvider);

    // Confirmación explícita: borrar invalida el QR impreso para siempre.
    final confirmo = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Eliminar mesa ${mesa.numero}?'),
        content: const Text(
          'El código QR impreso para esta mesa dejará de funcionar. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmo != true) return;

    try {
      await eliminarMesa(db, mesaId: mesa.id);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar la mesa'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Mesa ${mesa.numero} eliminada'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editando ? 'Editar mesa ${widget.mesa!.numero}' : 'Nueva mesa'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _numeroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número',
                  hintText: 'Ej: 9',
                ),
                keyboardType: TextInputType.number,
                autofocus: !_editando,
                validator: _validarNumero,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _capacidadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Capacidad',
                  hintText: 'Ej: 4',
                ),
                keyboardType: TextInputType.number,
                validator: _validarCapacidad,
              ),
              if (_regeneraQr)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '⚠️ Cambiar el número regenera el código QR de la mesa '
                    '— el QR impreso anterior quedará obsoleto',
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (_editando)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _saving ? null : _eliminar,
            child: const Text('Eliminar'),
          ),
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
