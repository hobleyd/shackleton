import 'dart:io';

import 'package:Shackleton/models/file_of_interest.dart';
import 'package:Shackleton/models/tag.dart';
import 'package:Shackleton/providers/metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('can add tags to empty set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, 2);
    });

    final mockMetadataProvider = container.read(metadataProvider(foi));
    expect(mockMetadataProvider.tags.length, 0);
    container.read(metadataProvider(foi).notifier).updateTagsFromString(foi, 'one, two');
  });

  test('can add tags to populated set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, 3);
    });

    final mockMetadataProvider = container.read(metadataProvider(foi));
    expect(mockMetadataProvider.tags.length, 0);
    container.read(metadataProvider(foi).notifier).updateTagsFromString(foi, 'one, two', tagSet: { Tag(tag: 'two'), Tag(tag: 'three') });
  });
}