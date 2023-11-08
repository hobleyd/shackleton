import 'dart:io';

import 'package:flutter/cupertino.dart';
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

    final mockMetadataProvider = container.read(metadataProvider(foi));
    expect(mockMetadataProvider.tags.length, 0);
    container.read(metadataProvider(foi).notifier).updateTagsFromString(foi, 'one, two');
  });

  test('can add tags to populated set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    final mockMetadataProvider = container.read(metadataProvider(foi));
    expect(mockMetadataProvider.tags.length, 0);

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, 2);
    });

    container.read(metadataProvider(foi).notifier).replaceTagsFromString(foi, 'two, three',);

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, 3);
    });
    container.read(metadataProvider(foi).notifier).updateTagsFromString(foi, 'one, two',);
  });
}