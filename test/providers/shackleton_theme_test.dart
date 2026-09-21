import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/providers/shackleton_theme.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('ShackletonTheme', () {
    test('builds with a default font size of 12', () {
      final theme = container.read(shackletonThemeProvider);

      expect(theme.textTheme.bodySmall?.fontSize, 12);
    });

    test('setFontSize rebuilds the theme at the new size', () {
      container.read(shackletonThemeProvider.notifier).setFontSize(20);

      final theme = container.read(shackletonThemeProvider);
      expect(theme.textTheme.bodySmall?.fontSize, 20);
    });

    test('derived text styles stay offset from the base font size', () {
      final theme = container.read(shackletonThemeProvider.notifier).buildThemeData(16);

      expect(theme.textTheme.titleSmall?.fontSize, 14);
      expect(theme.textTheme.bodyMedium?.fontSize, 17);
      expect(theme.textTheme.labelMedium?.fontSize, 17);
      expect(theme.textTheme.labelSmall?.fontSize, 16);
    });

    test('uses Material 3', () {
      expect(container.read(shackletonThemeProvider).useMaterial3, isTrue);
    });
  });
}
