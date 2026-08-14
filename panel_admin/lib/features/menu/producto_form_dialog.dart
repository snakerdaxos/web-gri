import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/token_provider.dart';
import '../../models/producto_staff.dart';
import '../dashboard/restaurante_provider.dart';
import 'menu_provider.dart';

/// Form crear/editar producto (MENU-02).
///
/// * [producto] == null → crear (`POST /staff/productos`); si no → editar
///   (`PATCH /staff/productos/{id}` con SOLO campos modificados).
/// * `imagen_url` es un TextField opcional + preview [Image.network] con
///   `errorBuilder` (icono si la URL falla) — PROHIBIDO upload/multipart
///   (threat model 08-04).
/// * Toggles con semánticas separadas (SOLO en edición — el POST no acepta
///   `disponible`/`activo`, server default true):
///   * 'Agotado' = !disponible (transitorio: SIGUE visible en la app con
///     flag).
///   * 'Activo' = soft-delete (desaparece de /public, sigue aquí).
/// * Tras éxito: pop + SnackBar + `ref.invalidate(staffMenuProvider)`.
class ProductoFormDialog extends ConsumerStatefulWidget {
  const ProductoFormDialog({
    super.key,
    required this.categoriaId,
    this.producto,
  });

  /// Categoría destino (creación) / categoría actual del producto (edición).
  final int categoriaId;

  final ProductoStaff? producto;

  @override
  ConsumerState<ProductoFormDialog> createState() =>
      _ProductoFormDialogState();
}

class _ProductoFormDialogState extends ConsumerState<ProductoFormDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _imagenCtrl;
  // Mutables: los SwitchListTile los reasignan (late final explotaría al
  // segundo toggle — LateError caught en test (c)).
  late bool _agotado;
  late bool _activo;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl = TextEditingController(text: p?.precio.toString() ?? '');
    _imagenCtrl = TextEditingController(text: p?.imagenUrl ?? '');
    // 'Agotado' es la NEGACIÓN de disponible (threat model: switches
    // etiquetados con semántica visible, jamás un toggle ambiguo).
    _agotado = !(p?.disponible ?? true);
    _activo = p?.activo ?? true;
    // Re-render al tipear la URL: la preview aparece/desaparece.
    _imagenCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    _imagenCtrl.dispose();
    super.dispose();
  }

  bool get _editando => widget.producto != null;

  String? _validarPrecio(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Requerido';
    final n = double.tryParse(t);
    if (n == null) return 'Debe ser un número';
    if (n <= 0) return 'Debe ser mayor a 0';
    return null;
  }

  bool get _sinCambios {
    if (!_editando) return false;
    final original = widget.producto!;
    return _nombreCtrl.text.trim() == original.nombre &&
        _descCtrl.text.trim() == (original.descripcion ?? '') &&
        (double.tryParse(_precioCtrl.text.trim()) ?? -1) ==
            original.precio &&
        _imagenCtrl.text.trim() == (original.imagenUrl ?? '') &&
        !_agotado == original.disponible &&
        _activo == original.activo;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nombre = _nombreCtrl.text.trim();
    final descripcion =
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final precio = double.parse(_precioCtrl.text.trim());
    final imagenUrl =
        _imagenCtrl.text.trim().isEmpty ? null : _imagenCtrl.text.trim();

    // Capturas ANTES del await (patrón cocina_screen).
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final user = ref.read(authStateProvider).value;
    final rid = ref.read(currentRestauranteIdProvider) ?? user?.restaurantId;
    final queryRid = user?.isSuperAdmin == true ? rid : null;
    final client = ref.read(apiClientProvider);

    try {
      if (!_editando) {
        await client.createProducto(
          categoriaId: widget.categoriaId,
          nombre: nombre,
          descripcion: descripcion,
          precio: precio,
          imagenUrl: imagenUrl,
          restauranteId: queryRid,
        );
      } else {
        final original = widget.producto!;
        final nuevaDisponible = !_agotado; // 'Agotado' = !disponible.
        // Vaciar descripcion/imagen también viaja ('' limpia el campo en el
        // server — null-aware omitiría la clave y no lo limpiaría).
        await client.updateProducto(
          original.id,
          nombre: nombre != original.nombre ? nombre : null,
          descripcion:
              descripcion != original.descripcion ? (descripcion ?? '') : null,
          precio: precio != original.precio ? precio : null,
          imagenUrl: imagenUrl != original.imagenUrl ? (imagenUrl ?? '') : null,
          disponible:
              nuevaDisponible != original.disponible ? nuevaDisponible : null,
          activo: _activo != original.activo ? _activo : null,
          restauranteId: queryRid,
        );
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.response?.statusCode == 422
                ? 'Revisa los datos: el precio debe ser mayor a 0'
                : 'No se pudo guardar el producto',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el producto'),
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
          _editando ? 'Producto actualizado' : 'Producto "$nombre" creado',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    ref.invalidate(staffMenuProvider);
  }

  @override
  Widget build(BuildContext context) {
    final url = _imagenCtrl.text.trim();
    return AlertDialog(
      title: Text(
        _editando
            ? 'Editar ${widget.producto!.nombre}'
            : 'Nuevo producto',
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Patacón',
                  ),
                  autofocus: !_editando,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Requerido';
                    if (t.length > 150) return 'Máximo 150 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio (COP)',
                    hintText: 'Ej: 15500',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: _validarPrecio,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _imagenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de imagen (opcional)',
                    hintText: 'https://…',
                  ),
                ),
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 80,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        // URL inválida/offline → placeholder, JAMÁS crash
                        // (threat model 08-04).
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFEEEEEE),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ],
                // Toggles solo en edición: el POST no acepta
                // disponible/activo (server default true, contrato 08-01).
                if (_editando)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Agotado'),
                    subtitle: const Text(
                      'Los clientes lo ven marcado como agotado',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _agotado,
                    onChanged:
                        _saving ? null : (v) => setState(() => _agotado = v),
                  ),
                if (_editando)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    subtitle: const Text(
                      'Un producto inactivo desaparece del menú del cliente',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _activo,
                    onChanged: _saving ? null : (v) => setState(() => _activo = v),
                  ),
              ],
            ),
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
