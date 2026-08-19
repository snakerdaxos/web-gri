import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../shared/password_field.dart';
import 'perfil_controller.dart';

/// Tab Perfil (AUTH-05) — muestra y edita el perfil del cliente:
/// * nombre editable,
/// * email DISABLED (immutable — se cambia desde Auth, no acá),
/// * password opcional (vacía = no cambiar; para cambiarla pide la actual),
/// * cerrar sesión.
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passActualCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  /// El nombre/email se sincronizan UNA vez que el perfil está disponible
  /// (en producción el redirect ya garantiza sesión; el flag evita pisar
  /// ediciones del usuario en rebuilds posteriores).
  bool _synced = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passActualCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    try {
      await ref
          .read(perfilControllerProvider.notifier)
          .actualizarNombre(_nombreCtrl.text);
      // Password: solo si el user escribió una nueva (vacía = no cambiar).
      final nueva = _passCtrl.text;
      if (nueva.isNotEmpty) {
        await ref
            .read(perfilControllerProvider.notifier)
            .cambiarPassword(_passActualCtrl.text, nueva);
      }
      _passActualCtrl.clear();
      _passCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // ignore: lines_longer_than_80_chars
        const SnackBar(content: Text('Perfil actualizado ✅')), // EMOJI-OK: aviso amable
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (e) {
            StateError s => s.message,
            ArgumentError a => a.message?.toString() ?? 'Entrada inválida',
            _ => 'Error al guardar el perfil',
          }),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await ref.read(logoutControllerProvider.notifier).logout();
    // El refreshListenable del GoRouter redirige a /login solo.
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilProvider).value;
    final saving = ref.watch(perfilControllerProvider).isLoading;

    if (perfil != null && !_synced) {
      _nombreCtrl.text = perfil.nombre;
      _emailCtrl.text = perfil.email;
      _synced = true;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Mi perfil',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: GriColors.text,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('perfil-nombre'),
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('perfil-email'),
                  controller: _emailCtrl,
                  enabled: false, // immutable server-side (Pitfall AUTH-05)
                  decoration: const InputDecoration(
                    labelText: 'Email (no editable)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  fieldKey: const ValueKey('perfil-pass-actual'),
                  controller: _passActualCtrl,
                  labelText: 'Contraseña actual',
                  helperText: 'Solo si vas a cambiar la contraseña',
                ),
                const SizedBox(height: 16),
                PasswordField(
                  fieldKey: const ValueKey('perfil-password'),
                  controller: _passCtrl,
                  labelText: 'Nueva contraseña (opcional)',
                  helperText: 'Déjala vacía para no cambiarla',
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: saving ? null : _guardar,
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
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: GriColors.chipCanceladaFg),
          label: const Text(
            'Cerrar sesión',
            style: TextStyle(color: GriColors.chipCanceladaFg),
          ),
        ),
      ],
    );
  }
}
