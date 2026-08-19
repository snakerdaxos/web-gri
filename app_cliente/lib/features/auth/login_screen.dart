import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../shared/google_boton.dart';
import '../shared/password_field.dart';
import 'auth_controller.dart';

/// Pantalla de login del cliente — card centrada con logo GRI, email +
/// password, link a registro. El redirect post-login lo hace el GoRouter
/// (aquí no hay navigation manual).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onChange);
    _passCtrl.addListener(_onChange);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  bool get _canSubmit {
    final submitting = ref.read(loginControllerProvider).isLoading;
    return !submitting &&
        _emailRe.hasMatch(_emailCtrl.text.trim()) &&
        _passCtrl.text.length >= 8;
  }

  Future<void> _submit() async {
    try {
      await ref
          .read(loginControllerProvider.notifier)
          .submit(_emailCtrl.text, _passCtrl.text);
      // Sin push manual: el redirect del goRouter manda a /inicio.
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

  /// Ingreso con Google (11-17). Una cancelación devuelve false y NO se
  /// muestra como error: el usuario vuelve a esta misma pantalla en silencio.
  Future<void> _google() async {
    try {
      await ref.read(googleSignInControllerProvider.notifier).ingresar();
      // Sin push manual: el redirect del goRouter manda a /inicio.
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
        _ => 'Error al iniciar sesión',
      };

  @override
  Widget build(BuildContext context) {
    // Re-watch para que isLoading reactive el rebuild del botón.
    final submitting = ref.watch(loginControllerProvider).isLoading;
    final googleEnVuelo = ref.watch(googleSignInControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: GriColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(32),
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
                    const Center(
                      child: Column(
                        children: [
                          _LogoBadge(),
                          SizedBox(height: 16),
                          Text(
                            'GRI',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: GriColors.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Reserva y pide desde tu mesa',
                            style: TextStyle(
                              color: GriColors.gray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const ValueKey('login-email'),
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
                    const SizedBox(height: 16),
                    PasswordField(
                      fieldKey: const ValueKey('login-password'),
                      controller: _passCtrl,
                      labelText: 'Contraseña',
                      autofillHints: const [AutofillHints.password],
                      validator: (v) =>
                          (v ?? '').length >= 8 ? null : 'Mínimo 8 caracteres',
                      onFieldSubmitted: (_) => _canSubmit ? _submit() : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: (submitting || !_canSubmit) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GriColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            GriColors.primary.withValues(alpha: 0.4),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                          : const Text('Ingresar'),
                    ),
                    const SizedBox(height: 20),
                    const SeparadorAuth(),
                    const SizedBox(height: 20),
                    GoogleBoton(
                      botonKey: const ValueKey('login-google'),
                      cargando: googleEnVuelo,
                      onPressed: _google,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('¿No tienes cuenta? Regístrate'),
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

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: GriColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('🍽️', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}
