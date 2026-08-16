import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase ANTES de runApp: emuladores (si USE_EMULATORS) deben cablearse
  // antes de que cualquier provider resuelva las instancias (Pitfall 2).
  await bootstrap();
  // dotenv legacy: MANTENER hasta el purge (10-06) — features aún no
  // migradas (mesas CRUD/menú/clientes/reportes/reservas/config) viven
  // sobre la capa REST.
  await dotenv.load(fileName: 'assets/.env');
  runApp(const ProviderScope(child: GriApp()));
}
