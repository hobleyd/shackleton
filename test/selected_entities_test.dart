import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';

void main() {
  test('can add files to selectedEntity provider', () async {
    final ProviderContainer container = ProviderContainer();

    int expectedEntitiesLength = 0;
    container.listen(selectedGridEntitiesProvider, (previous, next) {
      expect(next.length, expectedEntitiesLength);
    });

    expectedEntitiesLength = 5;
    container.read(selectedGridEntitiesProvider.notifier).addAll({
      FileOfInterest(entity: File('aaa')),
      FileOfInterest(entity: File('bbb')),
      FileOfInterest(entity: File('/a/b/c/a')),
      FileOfInterest(entity: File('/a/b/c/d')),
      FileOfInterest(entity: File('/a/b/d/e')),
    });

    expectedEntitiesLength = 4;
    container.read(selectedGridEntitiesProvider.notifier).remove(
      FileOfInterest(entity: File('bbb')),
    );

    expectedEntitiesLength = 2;
    container.read(selectedGridEntitiesProvider.notifier).remove(
      FileOfInterest(entity: Directory('/a/b/c')),
    );
  });
}