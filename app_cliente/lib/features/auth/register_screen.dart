import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'auth_controller.dart';

/// Registro de cliente — nombre + email + password. Tras un registro
/// exitoso el controller hace AUTO-LOGIN y el redirect del GoRouter lleva
/// a /inicio.
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

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(_onChange);
    _emailCtrl.addListener(_onChange);
    _passCtrl.addListener(_onChange);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  bool get _canSubmit {
    final submitting = ref.read(registerControllerProvider).isLoading;
    return !submitting &&
        _nombreCtrl.text.trim().isNotEmpty &&
        _emailRe.hasMatch(_emailCtrl.text.trim()) &&
        _passCtrl.text.length >= 8;
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

  String _errorMsg(Object e) => switch (e) {
        StateError s => s.message,
        ArgumentError a => a.message?.toString() ?? 'Entrada inválida',
        _ => 'Error al crear la cuenta',
      };

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(registerControllerProvider).isLoading;

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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('register-password'),
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
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
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 16),
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
