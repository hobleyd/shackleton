import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'misc/logger.dart';
import 'providers/theme_notifier.dart';
import 'widgets/shackleton.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(ProviderScope(observers: [Logger()], child: const ShackletonApp()));
}

class ShackletonApp extends ConsumerWidget {
  const ShackletonApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Shackleton',
      home: const Shackleton(),
      theme: ref.watch(themeNotifierProvider).theme,
    );
  }
}