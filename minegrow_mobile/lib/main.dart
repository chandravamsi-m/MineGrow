import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  // HIGH-3: FlutterSecureStorage initializes lazily — no startup override needed.
  // SharedPreferences has been replaced with flutter_secure_storage throughout the app.
  runApp(
    const ProviderScope(
      child: MineGrowApp(),
    ),
  );
}
