import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder MINIMAL del Task 2 — el Task 3 lo sustituye por el sidebar
/// completo (250px + 7 ítems + topbar con nombre del restaurante).
/// El contrato (recibe `child` del ShellRoute) queda idéntico.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(body: child);
  }
}
