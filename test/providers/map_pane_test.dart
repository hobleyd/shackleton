import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/providers/map_pane.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('MapPane', () {
    test('starts with the default settings', () {
      final state = container.read(mapPaneProvider);
      expect(state.visible, isFalse);
    });

    test('changeWidth shrinks width by delta', () {
      final start = container.read(mapPaneProvider).width;

      container.read(mapPaneProvider.notifier).changeWidth(20);

      expect(container.read(mapPaneProvider).width, start - 20);
    });

    test('setVisibility toggles visibility', () {
      final notifier = container.read(mapPaneProvider.notifier);

      notifier.setVisibility(true);
      expect(container.read(mapPaneProvider).visible, isTrue);

      notifier.setVisibility(false);
      expect(container.read(mapPaneProvider).visible, isFalse);
    });
  });
}
