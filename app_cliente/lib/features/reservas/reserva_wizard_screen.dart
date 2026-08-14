import 'package:flutter/material.dart';

/// Placeholder T1 — reemplazado en Task 3.
class ReservaWizardScreen extends StatelessWidget {
  const ReservaWizardScreen({
    super.key,
    required this.restauranteId,
    required this.restauranteNombre,
  });

  final int restauranteId;
  final String restauranteNombre;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Wizard reserva')));
}
