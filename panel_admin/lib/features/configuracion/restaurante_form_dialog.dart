import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../dashboard/restaurante_provider.dart';
import 'restaurantes_admin_provider.dart';
import 'slug.dart';

import '../../core/theme.dart';
/// Alta de restaurante (BOOT-02) — la pantalla que saca a la plataforma del
/// callejón sin salida: antes de esto, una base vacía solo se podía poblar con
/// scripts o desde la consola de Firebase.
///
/// Solo lo abre el tab 'Restaurantes' de /configuracion, que ya está acotado a
/// `super_admin`. La autorización real vive en `firestore.rules:88`
/// (`allow create: if isSuper()`), no aquí.
///
/// Piezas que no son decorativas:
///
///  * **Vista previa del identificador.** El slug se deriva del nombre EN VIVO
///    y se muestra en su propio campo antes de confirmar, porque es
///    irreversible: el doc ID no se renombra, y de él dependen los doc ID de
///    todas las mesas (`GRI-MESA-{rid}-{NNN}`) y por tanto los QR impresos.
///  * **Desacople al editar a mano.** En cuanto el operador toca el campo del
///    identificador, el nombre deja de sobreescribirlo — si no, corregir el
///    slug sería imposible mientras se sigue redactando el nombre.
///  * **Guardar deshabilitado con slug inválido** (además del validador
///    inline): la validación no puede depender solo del `validator`, porque el
///    usuario puede escribir cualquier cosa en el campo.
///  * **Selección automática al cerrar** — ver el comentario de [_guardar].
class RestauranteFormDialog extends ConsumerStatefulWidget {
  const RestauranteFormDialog({super.key});

  @override
  ConsumerState<RestauranteFormDialog> createState() =>
      _RestauranteFormDialogState();
}

class _RestauranteFormDialogState
    extends ConsumerState<RestauranteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _tipoCocinaCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  /// El operador ya editó el identificador a mano → el nombre deja de
  /// autocompletarlo.
  bool _slugTocado = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(_onNombre);
    // Re-render al tipear el slug: habilita/deshabilita Guardar en vivo.
    _slugCtrl.addListener(() => setState(() {}));
  }

  void _onNombre() {
    if (!_slugTocado) {
      final derivado = generarSlug(_nombreCtrl.text);
      if (derivado != _slugCtrl.text) {
        // Asignar el texto dispara el listener del slug → setState.
        _slugCtrl.text = derivado;
        return;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _slugCtrl.dispose();
    _tipoCocinaCtrl.dispose();
    _direccionCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  String get _slug => _slugCtrl.text.trim();

  bool get _puedeGuardar =>
      !_saving && _nombreCtrl.text.trim().isNotEmpty && slugEsValido(_slug);

  /// Error del identificador que hay que mostrar SIN esperar a que el operador
  /// toque ese campo.
  ///
  /// Caso real que lo motiva: el nombre no produce ningún slug (`'★★★'`, un
  /// nombre en otro alfabeto…). El campo queda vacío y, con
  /// `AutovalidateMode.onUserInteraction`, el validador NO se dispara —el
  /// usuario nunca tocó ese campo—, así que el formulario se quedaría mudo con
  /// Guardar apagado y sin decir por qué. Aquí se fuerza el mensaje en cuanto
  /// hay un nombre escrito.
  String? get _errorSlugForzado {
    if (_nombreCtrl.text.trim().isEmpty) return null;
    if (_slug.isNotEmpty) return null;
    return 'Escribe un identificador (el nombre no produce ninguno)';
  }

  String? _validarNombre(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String? _validarSlug(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) {
      // Caso real: el nombre no produce ningún slug (solo símbolos, p. ej.).
      return 'Escribe un identificador (el nombre no produce ninguno)';
    }
    if (s.length > 40) return 'Máximo 40 caracteres';
    if (!slugEsValido(s)) {
      return 'Solo minúsculas, números y guiones (sin tildes ni espacios)';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Capturas ANTES del await (patrón mesa_form_dialog): nada de context a
    // través del gap async.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final db = ref.read(firestoreProvider);
    final slug = _slug;

    try {
      await crearRestaurante(
        db,
        slug: slug,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        tipoCocina: _tipoCocinaCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
      );
    } on RestauranteException catch (e) {
      // Identificador repetido o inválido: el diálogo SIGUE ABIERTO para
      // corregir, con el mensaje redactado de la excepción.
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 4)),
      );
      return;
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo crear el restaurante'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // ── Selección automática del restaurante recién creado ────────────────
    // Sin esto, el alta no sirve para nada en el flujo que motiva esta
    // pantalla (plataforma vacía, el super crea el primero):
    //   * `ridActivoProvider` devuelve, para un super_admin, lo que haya en
    //     `seleccionRestauranteProvider` (restaurante_provider.dart:63-70).
    //   * `_maybeInitDefaultRid` (shared/app_shell.dart) solo corre una vez en
    //     `initState` y hace `return` sin seleccionar nada cuando la lista
    //     está vacía — que es exactamente el caso al arrancar.
    // Resultado sin esta línea: la selección se queda en `null` para siempre y
    // el super no puede crear ni una mesa ni una categoría hasta abrir a mano
    // el desplegable del topbar. La plataforma parece rota justo después de la
    // única acción que debía desbloquearla.
    ref.read(seleccionRestauranteProvider.notifier).set(slug);
    ref.invalidate(restaurantesAdminProvider);

    navigator.pop(true);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Restaurante "$slug" creado y seleccionado'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo restaurante'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('campo-nombre'),
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Pizzería Doña Ana',
                  ),
                  autofocus: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validarNombre,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('campo-slug'),
                  controller: _slugCtrl,
                  decoration: InputDecoration(
                    labelText: 'Identificador (no se puede cambiar después)',
                    hintText: 'Ej: pizzeria-dona-ana',
                    errorText: _errorSlugForzado,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) => _slugTocado = true,
                  validator: _validarSlug,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Se usa en los códigos QR de las mesas '
                      '(GRI-MESA-identificador-001).',
                      style: TextStyle(fontSize: 12, color: GriColors.textoSecundarioAccesible),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('campo-tipo-cocina'),
                  controller: _tipoCocinaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cocina',
                    hintText: 'Ej: Colombiana',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('campo-direccion'),
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Ej: Cra. 7 #63-44, Bogotá',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('campo-descripcion'),
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Una línea que lo describa para los clientes',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('guardar-restaurante'),
          onPressed: _puedeGuardar ? _guardar : null,
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
