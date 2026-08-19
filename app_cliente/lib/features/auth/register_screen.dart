import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../shared/google_boton.dart';
import '../shared/password_field.dart';
import '../../core/design_tokens.dart';
import 'auth_controller.dart';

/// Registro de cliente — nombre + email + password + confirmación. Tras un
/// registro exitoso el controller hace AUTO-LOGIN y el redirect del GoRouter
/// lleva a /inicio.
///
/// La confirmación es puramente de UI (11-06, T-11-06-02): evita que el
/// usuario se equivoque a ciegas, pero NO viaja a `RegisterController.submit`
/// ni se almacena en ningún sitio.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(_onChange);
    _emailCtrl.addListener(_onChange);
    _passCtrl.addListener(_onChange);
    _pass2Ctrl.addListener(_onChange);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  /// Mensaje único de la confirmación: lo comparte el validador del campo
  /// (que pinta el error) y `_canSubmit` (que apaga el botón), para que no
  /// puedan desincronizarse.
  String? _errorConfirmacion(String? v) =>
      (v ?? '') == _passCtrl.text ? null : 'Las contraseñas no coinciden';

  void _onChange() => setState(() {});

  bool get _canSubmit {
    final submitting = ref.read(registerControllerProvider).isLoading;
    return !submitting &&
        _nombreCtrl.text.trim().isNotEmpty &&
        _emailRe.hasMatch(_emailCtrl.text.trim()) &&
        _passCtrl.text.length >= 8 &&
        _errorConfirmacion(_pass2Ctrl.text) == null;
  }

  Future<void> _submit() async {
    try {
      await ref.read(registerControllerProvider.notifier).submit(
            _nombreCtrl.text,
            _emailCtrl.text,
            _passCtrl.text,
          );
      // Sin push manual: auto-login → redirect del goRouter a /inicio.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMsg(e)),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }

  /// Registro con Google (11-17). El primer ingreso crea el espejo
  /// `usuarios/{uid}` como cliente; una cancelación no muestra error.
  Future<void> _google() async {
    try {
      await ref.read(googleSignInControllerProvider.notifier).ingresar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMsg(e)),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }

  String _errorMsg(Object e) => switch (e) {
        StateError s => s.message,
        ArgumentError a => a.message?.toString() ?? 'Entrada inválida',
        _ => 'Error al crear la cuenta',
      };

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(registerControllerProvider).isLoading;
    final googleEnVuelo = ref.watch(googleSignInControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: GriColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: const Text('Crear cuenta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GriSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(GriSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('register-nombre'),
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'El nombre es obligatorio' : null,
                    ),
                    const SizedBox(height: GriSpacing.md),
                    TextFormField(
                      key: const ValueKey('register-email'),
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => _emailRe.hasMatch((v ?? '').trim())
                          ? null
                          : 'Email inválido',
                    ),
                    const SizedBox(height: GriSpacing.md),
                    PasswordField(
                      fieldKey: const ValueKey('register-password'),
                      controller: _passCtrl,
                      labelText: 'Contraseña',
                      // Paridad con el login: el gestor de contraseñas del
                      // sistema debe tratar ambos campos igual (T-11-06-03).
                      autofillHints: const [AutofillHints.password],
                      validator: (v) =>
                          (v ?? '').length >= 8 ? null : 'Mínimo 8 caracteres',
                    ),
                    const SizedBox(height: GriSpacing.md),
                    PasswordField(
                      fieldKey: const ValueKey('register-password-2'),
                      controller: _pass2Ctrl,
                      labelText: 'Confirmar contraseña',
                      autofillHints: const [AutofillHints.password],
                      validator: _errorConfirmacion,
                      onFieldSubmitted: (_) => _canSubmit ? _submit() : null,
                    ),
                    const SizedBox(height: GriSpacing.lg),
                    ElevatedButton(
                      onPressed: (submitting || !_canSubmit) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GriColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            GriColors.primary.withValues(alpha: 0.4),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: GriText.botonGrande,
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 20),
                    const SeparadorAuth(),
                    const SizedBox(height: 20),
                    GoogleBoton(
                      botonKey: const ValueKey('register-google'),
                      cargando: googleEnVuelo,
                      onPressed: _google,
                    ),
                    const SizedBox(height: GriSpacing.md),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Ya tengo cuenta — Ingresar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
