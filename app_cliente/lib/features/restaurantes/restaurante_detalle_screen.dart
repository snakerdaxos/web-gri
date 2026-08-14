import 'package:flutter/material.dart';

/// Placeholder T1 — reemplazado en Task 2.
class RestauranteDetalleScreen extends StatelessWidget {
  const RestauranteDetalleScreen({super.key, required this.restauranteId});

  final int restauranteId;

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Detalle restaurante')),
      );
}
