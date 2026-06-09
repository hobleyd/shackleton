import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'misc/provider_logger.dart';
import 'providers/shackleton_theme.dart';
import 'repositories/app_settings_repository.dart';
import 'widgets/shackleton_prime.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await WindowController.fromCurrentEngine();
  MediaKit.ensureInitialized();

  Logger.level = Level.error;

  // Desktop photo library: thumbnails are ~1.5 MB each at grid resolution.
  // 256 MB ≈ 170 thumbnails ≈ 8+ screenfuls before any eviction.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;

  // desktop_multi_window passes ["multi_window", windowId, arguments] as args to sub-windows.
  if (args.isNotEmpty && args[0] == 'multi_window') {
    windowManager.waitUntilReadyToShow(null, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

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
      home: const ShackletonPrime(),
      theme: ref.watch(shackletonThemeProvider),
    );
  }
}