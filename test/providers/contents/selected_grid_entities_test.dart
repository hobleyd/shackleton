import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';

import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('selected_grid_entities_test_');
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name) => FileOfInterest(entity: File('${tempDir.path}/$name'));

  SelectedGridEntities notifier() => container.read(selectedGridEntitiesProvider.notifier);

  group('SelectedGridEntities', () {
    test('starts empty', () {
      expect(container.read(selectedGridEntitiesProvider), isEmpty);
    });

    test('add inserts and keeps the list sorted by path', () {
      notifier().add(file('b.jpg'));
      notifier().add(file('a.jpg'));

      expect(container.read(selectedGridEntitiesProvider).map((e) => e.name), ['a.jpg', 'b.jpg']);
    });

    test('add does not duplicate an already-selected entity', () {
      notifier().add(file('a.jpg'));
      notifier().add(file('a.jpg'));

      expect(container.read(selectedGridEntitiesProvider), hasLength(1));
    });

    test('addAll merges and sorts, deduplicating by equality', () {
      notifier().add(file('b.jpg'));
      notifier().addAll({file('a.jpg'), file('b.jpg'), file('c.jpg')});

      expect(container.read(selectedGridEntitiesProvider).map((e) => e.name), ['a.jpg', 'b.jpg', 'c.jpg']);
    });

    test('contains / isSelected reflect membership', () {
      notifier().add(file('a.jpg'));

      expect(notifier().contains(file('a.jpg')), isTrue);
      expect(notifier().isSelected(file('b.jpg')), isFalse);
    });

    test('remove drops only the matching entity', () {
      notifier().addAll({file('a.jpg'), file('b.jpg')});

      notifier().remove(file('a.jpg'));

      expect(container.read(selectedGridEntitiesProvider).map((e) => e.name), ['b.jpg']);
    });

    test('clear and removeAll both empty the selection', () {
      notifier().add(file('a.jpg'));
      notifier().clear();
      expect(container.read(selectedGridEntitiesProvider), isEmpty);

      notifier().add(file('a.jpg'));
      notifier().removeAll();
      expect(container.read(selectedGridEntitiesProvider), isEmpty);
    });

    test('replace collapses the selection to a single entity', () {
      notifier().addAll({file('a.jpg'), file('b.jpg')});

      notifier().replace(file('c.jpg'));

      expect(container.read(selectedGridEntitiesProvider).map((e) => e.name), ['c.jpg']);
    });

    test('replaceAll sorts the replacement set', () {
      notifier().replaceAll({file('b.jpg'), file('a.jpg')});

      expect(container.read(selectedGridEntitiesProvider).map((e) => e.name), ['a.jpg', 'b.jpg']);
    });

    test('size reflects the current selection count', () {
      notifier().addAll({file('a.jpg'), file('b.jpg')});
      expect(notifier().size(), 2);
    });
  });

  group('selectedGridPathsProvider', () {
    test('derives the set of selected paths', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      notifier().addAll({a, b});

      expect(container.read(selectedGridPathsProvider), {a.path, b.path});
    });

    test('updates when the selection changes', () {
      notifier().add(file('a.jpg'));
      expect(container.read(selectedGridPathsProvider), {file('a.jpg').path});

      notifier().clear();
      expect(container.read(selectedGridPathsProvider), isEmpty);
    });
  });
}
