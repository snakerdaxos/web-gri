import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/password_policy.dart';
import '../../core/theme.dart';
import '../dashboard/restaurante_provider.dart';
import '../dashboard/restaurantes_list_provider.dart';
import '../shared/password_field.dart';
import 'equipo_controller.dart';
import 'equipo_provider.dart';

/// Roles que este formulario ofrece.
///
/// ⚠️ SINCRONIZAR con `ROLES_ASIGNABLES` de `functions/src/auth-matrix.js`.
/// `super_admin` NO está y no debe estarlo nunca: el único super de la
/// plataforma nace de `bootstrapPlataforma` (11-07), una sola vez.
///
/// Esta lista es UX, no seguridad. Aunque alguien manipulara el desplegable,
/// la callable rechaza el rol: la allow-list del servidor está probada con 19
/// filas de tabla y 48 combinaciones de propiedad (11-08).
const rolesAsignables = <String>['admin_restaurante', 'mesero', 'cocina'];

// La regla de contraseña NO vive aquí. Está en `core/password_policy.dart`,
// idéntica byte a byte a la de la app cliente y con la MISMA redacción que la
// del servidor (`functions/src/password-policy.js`). Aquí solo se consulta:
// exigirla en el formulario evita gastar una llamada para descubrir lo que la
// callable ya rechaza (11-22).

/// Alta de una persona del equipo (BOOT-03/BOOT-04).
///
/// Una SOLA pantalla para los dos llamadores. La única diferencia es el
/// selector de restaurante:
///  * `super_admin` → lo ve y es obligatorio (la matriz exige `restauranteId`).
///  * `admin_restaurante` → NO existe, y el cliente NO manda `restauranteId`:
///    la callable lo DERIVA de su claim (prohibición 2 de la matriz).
///
/// Dos avisos del copy que no son decorativos:
///  * **idempotencia** — repetir el alta con el mismo correo REPARA un alta que
///    quedó a medias. Es la única mitigación de la no-atomicidad Auth/Firestore
///    (11-08) y el operador tiene que saberlo.
///  * **propagación de claims** — si la persona ya tenía sesión abierta, su
///    token viejo no lleva el rol nuevo hasta que vuelve a entrar.
class StaffFormDialog extends ConsumerStatefulWidget {
  const StaffFormDialog({super.key});

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _rol = rolesAsignables[1]; // 'mesero': el alta más frecuente
  String? _restauranteId;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    // Para el super: arrancar en el restaurante que ya tiene activo en el
    // topbar. Es lo que espera después de haberlo elegido allí.
    _restauranteId = ref.read(seleccionRestauranteProvider);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validarNombre(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String? _validarEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    // Misma comprobación mínima que hace la callable (`includes('@')`): validar
    // más aquí solo produciría rechazos que el servidor sí aceptaría.
    if (!s.contains('@')) return 'Correo inválido';
    return null;
  }

  /// Delega ENTERA en la política. Ni siquiera el caso vacío se trata aparte:
  /// el mensaje de la política ya dice todo lo que falta, que es más útil que
  /// un "Requerido" que obliga a adivinar el resto.
  String? _validarPassword(String? v) => validarPassword(v ?? '');

  Future<void> _guardar(bool esSuper) async {
    // Guarda de doble envío: el botón ya está deshabilitado, pero un `tap`
    // encolado antes del rebuild llegaría igual.
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;
    if (esSuper && (_restauranteId == null || _restauranteId!.isEmpty)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Elige el restaurante de destino')),
      );
      return;
    }

    setState(() => _enviando = true);

    // Capturas ANTES del await (patrón restaurante_form_dialog): nada de
    // `context` a través del gap async.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final accion = ref.read(crearStaffAccionProvider);

    final ResultadoAlta resultado;
    try {
      resultado = await accion(
        nombre: _nombreCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        rol: _rol,
        // El admin NO lo manda: su rid sale de su claim.
        restauranteId: esSuper ? _restauranteId : null,
      );
    } on EquipoException catch (e) {
      // El diálogo SIGUE ABIERTO para corregir.
      if (mounted) setState(() => _enviando = false);
      messenger?.showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 5)),
      );
      return;
    } catch (_) {
      if (mounted) setState(() => _enviando = false);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo crear el usuario. Intenta de nuevo.'),
        ),
      );
      return;
    }

    // Refresco de la lista: el doc espejo ya existe cuando la callable
    // responde.
    ref.invalidate(equipoProvider);

    navigator.pop(true);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          resultado.creado
              ? 'Usuario creado como ${etiquetaRol(resultado.rol)}. '
                  'Si esa persona ya tenía sesión abierta, pídele que cierre '
                  'sesión y vuelva a entrar para que su nuevo rol tenga efecto.'
              : 'Esa cuenta ya existía y quedó reparada como '
                  '${etiquetaRol(resultado.rol)}. Si ya tenía sesión abierta, '
                  'pídele que cierre sesión y vuelva a entrar.',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final claims = ref.watch(claimsProvider).value;
    final esSuper = claims?.role == 'super_admin';

    return AlertDialog(
      title: const Text('Nuevo usuario del equipo'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('staff-nombre'),
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Ana Gómez',
                  ),
                  autofocus: true,
                  validator: _validarNombre,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('staff-email'),
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    hintText: 'ana@turestaurante.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validarEmail,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  fieldKey: const Key('staff-password'),
                  controller: _passwordCtrl,
                  labelText: 'Contraseña temporal',
                  helperText:
                      '$ayudaPolitica. Se la dictas tú; esa persona podrá '
                      'cambiarla desde su perfil.',
                  validator: _validarPassword,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const Key('staff-rol'),
                  initialValue: _rol,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: [
                    for (final r in rolesAsignables)
                      DropdownMenuItem(value: r, child: Text(etiquetaRol(r))),
                  ],
                  onChanged: _enviando
                      ? null
                      : (v) => setState(() => _rol = v ?? _rol),
                ),
                if (esSuper) ...[
                  const SizedBox(height: 14),
                  _SelectorRestaurante(
                    valor: _restauranteId,
                    habilitado: !_enviando,
                    onChanged: (v) => setState(() => _restauranteId = v),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Si un alta quedó a medias, vuelve a crearla con el mismo '
                  'correo: la operación es idempotente y repara la cuenta sin '
                  'duplicarla.',
                  style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('staff-guardar'),
          onPressed: _enviando ? null : () => _guardar(esSuper),
          child: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear usuario'),
        ),
      ],
    );
  }
}

/// Selector de restaurante destino — SOLO para `super_admin`.
///
/// Reutiliza `restaurantesListProvider`, el mismo que alimenta el desplegable
/// del topbar: no se inventa una fuente nueva de restaurantes.
class _SelectorRestaurante extends ConsumerWidget {
  const _SelectorRestaurante({
    required this.valor,
    required this.habilitado,
    required this.onChanged,
  });

  final String? valor;
  final bool habilitado;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(restaurantesListProvider);

    return listaAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text(
        'No se pudo cargar la lista de restaurantes',
        style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 12),
      ),
      data: (lista) => DropdownButtonFormField<String>(
        key: const Key('staff-restaurante'),
        initialValue: lista.any((r) => r.id == valor) ? valor : null,
        decoration: const InputDecoration(
          labelText: 'Restaurante',
          helperText: 'Obligatorio: define a qué restaurante pertenece',
        ),
        items: [
          for (final r in lista)
            DropdownMenuItem(value: r.id, child: Text(r.nombre)),
        ],
        onChanged: habilitado ? onChanged : null,
      ),
    );
  }
}
