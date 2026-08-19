import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../shared/password_field.dart';
import 'bootstrap_controller.dart';
import '../shared/responsive_page.dart';

/// Pantalla `/bootstrap` (BOOT-01): crea el PRIMER `super_admin` de la
/// plataforma invocando la callable `bootstrapPlataforma`.
///
/// Conserva la identidad visual del login (misma card de 400px, mismo badge,
/// misma paleta): el alcance visual de la Fase 11 es consistencia, no rediseño.
///
/// La navegación de salida la hace ESTA pantalla con `context.go('/')` cuando
/// la operación termina — el guard del router tiene `/bootstrap` exenta en
/// ambos sentidos justamente para no interferir mientras está en vuelo.
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _secretoCtrl = TextEditingController();

  bool _enVuelo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nombreCtrl,
      _emailCtrl,
      _passCtrl,
      _pass2Ctrl,
      _secretoCtrl,
    ]) {
      c.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _emailCtrl,
      _passCtrl,
      _pass2Ctrl,
      _secretoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChange() => setState(() {});

  /// Un único sitio decide si las contraseñas coinciden: lo comparten el
  /// `validator` del segundo campo y la condición que habilita el botón, así
  /// el aviso y el botón no pueden contradecirse (patrón de 11-06).
  String? get _errorConfirmacion {
    if (_pass2Ctrl.text.isEmpty) return null;
    return _passCtrl.text == _pass2Ctrl.text
        ? null
        : 'Las contraseñas no coinciden';
  }

  bool get _canSubmit =>
      !_enVuelo &&
      _nombreCtrl.text.trim().isNotEmpty &&
      _emailRe.hasMatch(_emailCtrl.text.trim()) &&
      _passCtrl.text.length >= 8 &&
      _pass2Ctrl.text == _passCtrl.text &&
      _secretoCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    // Segundo cerrojo del doble envío: aunque llegara un tap con el botón ya
    // apagado (rebuild a medias), aquí no entra una segunda operación.
    if (_enVuelo) return;
    setState(() {
      _enVuelo = true;
      _error = null;
    });
    try {
      await ref.read(bootstrapAccionProvider)(
        nombre: _nombreCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
        secreto: _secretoCtrl.text,
      );
      if (!mounted) return;
      context.go('/');
    } on BootstrapException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'No se pudo inicializar la plataforma. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _enVuelo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GriColors.background,
      // Mismo patrón que login_screen: [ResponsivePage] sustituye al
      // `Center + scroll(padding 24) + ConstrainedBox(400)` copiado a mano, y
      // el techo lleva el padding sumado para que la tarjeta siga en 400.
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
                            'Inicializar plataforma',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: GriColors.text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Crea la cuenta de administrador de la '
                            'plataforma. Solo funciona una vez y requiere el '
                            'correo autorizado y el secreto de inicialización.',
                            style: TextStyle(
                              color: GriColors.gray,
                              fontSize: 13,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('bootstrap-nombre'),
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Escribe tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('bootstrap-email'),
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo autorizado',
                        helperText: 'Debe coincidir con el del despliegue',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => _emailRe.hasMatch((v ?? '').trim())
                          ? null
                          : 'Correo inválido',
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      fieldKey: const ValueKey('bootstrap-password'),
                      controller: _passCtrl,
                      labelText: 'Contraseña',
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) =>
                          (v ?? '').length >= 8 ? null : 'Mínimo 8 caracteres',
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      fieldKey: const ValueKey('bootstrap-password-2'),
                      controller: _pass2Ctrl,
                      labelText: 'Confirmar contraseña',
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (_) => _errorConfirmacion,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      fieldKey: const ValueKey('bootstrap-secreto'),
                      controller: _secretoCtrl,
                      labelText: 'Secreto de inicialización',
                      helperText: 'Lo fija quien despliega la plataforma',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Pega el secreto de inicialización'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: GriColors.mesaOcupadaDot,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      key: const ValueKey('bootstrap-submit'),
                      onPressed: _canSubmit ? _submit : null,
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
                      child: _enVuelo
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear super admin'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed:
                            _enVuelo ? null : () => context.go('/login'),
                        child: const Text('Volver al inicio de sesión'),
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
        child: Text('🍽️', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}
