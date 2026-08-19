import 'package:flutter/material.dart';

/// Campo de contraseña con botón para **revisar lo escrito** (11-06).
///
/// SINCRONIZAR con `app_cliente/lib/features/shared/password_field.dart` —
/// misma API y mismo comportamiento. La duplicación es deliberada: son dos
/// proyectos Flutter independientes, con `pubspec.yaml` y paleta propios;
/// un paquete `path:` compartido para un solo widget cuesta más de lo que
/// ahorra y añade riesgo en `flutter build web`.
///
/// Contrato (lo que los tests fijan):
///  * arranca SIEMPRE oculto — revelar es una acción explícita del usuario,
///    no persiste entre pantallas ni entre sesiones (T-11-06-01);
///  * cada instancia guarda su propio estado: revelar un campo no revela
///    los demás;
///  * el botón lleva `tooltip`, que Material expone también como etiqueta
///    semántica para lectores de pantalla, y un área táctil de 48x48.
///
/// NO es un rediseño: la decoración replica la que ya usaban las pantallas
/// (mismo `labelText`, mismo `OutlineInputBorder`, mismo prefijo de candado).
/// Solo se añade el sufijo.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.validator,
    this.autofillHints,
    this.fieldKey,
    this.textInputAction,
    this.onFieldSubmitted,
    this.helperText,
    this.prefixIcon = const Icon(Icons.lock_outline),
  });

  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final List<String>? autofillHints;

  /// Key del `TextFormField` interno. Las pantallas la usan para conservar
  /// las `ValueKey` que ya buscaban los tests (p. ej. `login-password`).
  final Key? fieldKey;

  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? helperText;
  final Widget? prefixIcon;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  /// Estado por defecto: oculto. Nunca se persiste.
  bool _obscure = true;

  void _alternar() => setState(() => _obscure = !_obscure);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        border: const OutlineInputBorder(),
        prefixIcon: widget.prefixIcon,
        suffixIcon: IconButton(
          // El icono anuncia lo que PASARÁ al pulsarlo, igual que el tooltip.
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          // Área táctil mínima accesible; no depende del tamaño del glifo.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _alternar,
        ),
      ),
    );
  }
}
