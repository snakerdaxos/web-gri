import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // dotenv legacy: core/env.dart aún lo usa (features no migradas). Se
  // elimina en 10-04 junto con la purga de dio/ws_client.
  await dotenv.load(fileName: 'assets/.env');
  // Firebase ANTES de runApp: emuladores (si USE_EMULATORS) deben cablearse
  // antes de que cualquier provider resuelva las instancias (Pitfall 2).
  await bootstrap();
  runApp(const ProviderScope(child: GriClienteApp()));
}
