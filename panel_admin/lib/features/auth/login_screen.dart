import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../shared/password_field.dart';
import 'login_controller.dart';
import '../shared/responsive_page.dart';
import '../../core/gri_icons.dart';

/// Pantalla de login (PLAT-01) — card centrada con logo GRI, email+password.
///
/// El botón "Iniciar sesión" está disabled mientras el email sea inválido,
/// el password < 8 chars, o haya un submit en curso. El redirect post-login
/// lo hace el GoRouter (aquí no hay navigation manual).
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
      // Sin push manual: el redirect del goRouter manda a '/'.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMsg(e)),
          backgroundColor: GriColors.mesaOcupadaDot,
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
    // Re-watch para que isSubmitting reactive el rebuild del botón.
    ref.watch(loginControllerProvider);
    final submitting = ref.watch(loginControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: GriColors.background,
      // El `Center + SingleChildScrollView(padding 24) + ConstrainedBox(400)`
      // que había aquí es exactamente lo que hace [ResponsivePage]; el techo
      // es 400+24+24 para que la TARJETA siga midiendo 400 clavados (el
      // padding vivía por fuera del cap). Verificado en responsive_test.
      body: ResponsivePage(
        maxWidth: ResponsivePage.anchoMaxFormularioConPadding,
        alineacion: Alignment.center,
        padding: const EdgeInsets.all(24),
        builder: (context, ancho) => SingleChildScrollView(
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
                            'GRI Panel',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: GriColors.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Inicia sesión',
                            style: TextStyle(color: GriColors.gray, fontSize: 14),
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
                      validator: (v) =>
                          _emailRe.hasMatch((v ?? '').trim()) ? null : 'Email inválido',
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
                        disabledBackgroundColor: GriColors.primary.withValues(alpha: 0.4),
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
                          : const Text('Iniciar sesión'),
                    ),
                    const SizedBox(height: 8),
                    // Camino de PRIMER ARRANQUE: sin esto, la pantalla de
                    // bootstrap solo sería alcanzable escribiendo la URL a
                    // mano. Discreto a propósito: se usa una vez en la vida
                    // del proyecto.
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/bootstrap'),
                        child: const Text(
                          '¿Primera vez? Inicializar plataforma',
                          style: TextStyle(
                            color: GriColors.gray,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
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
        child: Icon(
          GriIcons.marca,
          size: 32,
          color: Colors.white,
          semanticLabel: 'GRI',
        ),
      ),
    );
  }
}
