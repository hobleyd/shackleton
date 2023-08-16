import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'misc/provider_logger.dart';
import 'providers/theme.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/folder_settings_repository.dart';
import 'widgets/shackleton.dart';

Future<void> loadCachedStorage() async {
  AppDatabase db = AppDatabase();

  await db.openDatabase();
  await AppSettingsRepository(db).getSettings();
  await FolderSettingsRepository(db).getSettings();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadCachedStorage();

  runApp(ProviderScope(
      observers: [ProviderLogger()],
      child: const ShackletonApp()));
}

class ShackletonApp extends ConsumerWidget {
  const ShackletonApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Shackleton',
      home: const Shackleton(),
      theme: ref.watch(themeProvider).theme,
    );
  }
}