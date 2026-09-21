import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/providers/preview.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('Preview', () {
    test('starts with the default height', () {
      final defaultHeight = container.read(previewProvider).height;
      expect(defaultHeight, greaterThan(0));
    });

    test('changeHeight grows the height by delta', () {
      final start = container.read(previewProvider).height;

      container.read(previewProvider.notifier).changeHeight(10);

      expect(container.read(previewProvider).height, start + 10);
    });

    test('changeHeight is rejected when it would drop to or below the 250 floor', () {
      final notifier = container.read(previewProvider.notifier);
      // Push height comfortably above the floor first.
      notifier.changeHeight(500);
      final grown = container.read(previewProvider).height;

      notifier.changeHeight(-(grown - 250));

      // The rejected change leaves state untouched.
      expect(container.read(previewProvider).height, grown);
    });

    test('changeHeight applies a shrink that stays above the floor', () {
      final notifier = container.read(previewProvider.notifier);
      notifier.changeHeight(500);
      final grown = container.read(previewProvider).height;

      notifier.changeHeight(-10);

      expect(container.read(previewProvider).height, grown - 10);
    });
  });
}
