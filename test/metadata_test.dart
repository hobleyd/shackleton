import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/metadata.dart';

void main() {
  test('can add tags to empty set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, 2);
    });

    container.read(metadataProvider(foi).notifier).updateTagsFromString('one, two', updateFile: false);
  });

  test('can add tags to populated set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    int expectedTags = 0;
    final mockMetadataProvider = container.read(metadataProvider(foi));
    expect(mockMetadataProvider.tags.length, expectedTags);

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, expectedTags);
    });

    expectedTags = 2;
    container.read(metadataProvider(foi).notifier).replaceTagsFromString('two, three', updateFile: false);

    expectedTags = 3;
    container.read(metadataProvider(foi).notifier).updateTagsFromString('one, two', updateFile: false);
  });
}