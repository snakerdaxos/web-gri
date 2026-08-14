import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  runApp(const ProviderScope(child: _SmokeApp()));
}

/// Smoke test visual del Task 1 — el Task 2 la reemplaza por GriApp
/// (MaterialApp.router con goRouter).
class _SmokeApp extends StatelessWidget {
  const _SmokeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GRI Panel',
      debugShowCheckedModeBanner: false,
      theme: griTheme,
      home: const Scaffold(
        body: Center(child: Text('GRI Panel')),
      ),
    );
  }
}
