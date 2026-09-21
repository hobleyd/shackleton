import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/editing_timestamp.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  final entity = FileOfInterest(entity: File('/a.jpg'));

  group('EditingTimestamp', () {
    test('starts at -1', () {
      expect(container.read(editingTimestampProvider(entity)), -1);
    });

    test('setLastClickTimestamp updates the state for that entity', () {
      container.read(editingTimestampProvider(entity).notifier).setLastClickTimestamp(1234);

      expect(container.read(editingTimestampProvider(entity)), 1234);
    });

    test('different entities have independent state', () {
      final other = FileOfInterest(entity: File('/b.jpg'));
      container.read(editingTimestampProvider(entity).notifier).setLastClickTimestamp(1234);

      expect(container.read(editingTimestampProvider(other)), -1);
    });
  });
}
