import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/mesa.dart';
import '../dashboard/restaurante_provider.dart';

/// Form crear/editar mesa (MESA-01, 08-03).
///
/// * [mesa] == null → modo crear (`POST /staff/mesas`); si no → editar
///   (`PATCH /staff/mesas/{id}` con SOLO los campos modificados).
/// * Al editar con un número distinto al original muestra el warning de
///   regeneración de QR ANTES de guardar (el server regenera el código
///   determinista — el impreso anterior queda obsoleto).
/// * Tras éxito: pop + SnackBar. El grid se refresca SOLO por el evento WS
///   `mesa.estado` (kick-to-refetch) — JAMÁS se invalida ni muta la lista
///   local desde aquí.
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

  /// El número tipeado difiere del original → el server regenerará el QR.
  bool get _regeneraQr =>
      _editando &&
      (int.tryParse(_numeroCtrl.text.trim()) ?? -1) != widget.mesa!.numero;

  /// Editar sin cambios → nada que enviar (el backend respondería 422
  /// "Nada que actualizar"): Guardar queda deshabilitado.
  bool get _sinCambios =>
      _editando &&
      (int.tryParse(_numeroCtrl.text.trim()) ?? -1) == widget.mesa!.numero &&
      (int.tryParse(_capacidadCtrl.text.trim()) ?? -1) ==
          widget.mesa!.capacidad;

  String? _validarPositivo(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (v == null || v.trim().isEmpty) return 'Requerido';
    if (n == null) return 'Debe ser un número';
    if (n <= 0) return 'Debe ser mayor a 0';
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
    final user = ref.read(authStateProvider).value;
    final rid = ref.read(currentRestauranteIdProvider) ?? user?.restaurantId;
    final queryRid = user?.isSuperAdmin == true ? rid : null;
    final client = ref.read(apiClientProvider);

    try {
      if (!_editando) {
        await client.createMesa(numero, capacidad, restauranteId: queryRid);
      } else {
        final original = widget.mesa!;
        await client.updateMesa(
          original.id,
          numero: numero != original.numero ? numero : null,
          capacidad: capacidad != original.capacidad ? capacidad : null,
          restauranteId: queryRid,
        );
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.response?.statusCode == 409
                ? 'Ya existe una mesa con ese número'
                : 'No se pudo guardar la mesa',
          ),
          duration: const Duration(seconds: 3),
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

    // Éxito: cerrar + confirmar. El refresh del grid llega por el evento WS
    // (NO invalidar mesasProvider ni mutar listas locales).
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(_editando ? 'Mesa actualizada' : 'Mesa $numero creada'),
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
                validator: _validarPositivo,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _capacidadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Capacidad',
                  hintText: 'Ej: 4',
                ),
                keyboardType: TextInputType.number,
                validator: _validarPositivo,
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
