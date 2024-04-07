import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'database/app_database.dart';
import 'misc/provider_logger.dart';
import 'providers/shackleton_theme.dart';
import 'repositories/app_settings_repository.dart';
import 'widgets/shackleton.dart';

Future<void> openDatabase() async {
  AppDatabase db = AppDatabase();

  await db.openDatabase();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  MediaKit.ensureInitialized();

  // TODO: Should we care about optimising portrait images which could be made marginally smaller?
  // debugInvertOversizedImages = true;

  await openDatabase();

  runApp(ProviderScope(
      observers: [ProviderLogger()],
      child: const ShackletonApp()));
}

class ShackletonApp extends ConsumerWidget {
  const ShackletonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the Fontsize from the database.
    ref.watch(appSettingsRepositoryProvider);
    
    return MaterialApp(
      title: 'Shackleton',
      home: const Shackleton(),
      theme: ref.watch(shackletonThemeProvider),
    );
  }
}