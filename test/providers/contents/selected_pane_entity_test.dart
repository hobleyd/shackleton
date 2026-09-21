import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/selected_pane_entity.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SelectedPaneEntity', () {
    test('starts null', () {
      expect(container.read(selectedPaneEntityProvider), isNull);
    });

    test('replace sets the selected entity', () {
      final entity = FileOfInterest(entity: File('/a.jpg'));

      container.read(selectedPaneEntityProvider.notifier).replace(entity);

      expect(container.read(selectedPaneEntityProvider), entity);
    });
  });
}
