import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/pane_contents.dart';
import 'package:shackleton/providers/contents/selected_folder_contents.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';

import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pane_contents_test_');
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name, {List<int> bytes = const []}) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
    return FileOfInterest(entity: f);
  }

  group('PaneContents.build', () {
    test('falls back to grid contents when nothing is selected in the grid', () {
      final photo = file('photo.jpg');
      container.read(selectedFolderContentsProvider.notifier).add(photo);

      expect(container.read(paneContentsProvider), [photo]);
    });

    test('prefers the grid selection when one exists', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      container.read(selectedFolderContentsProvider.notifier).addAll({a, b});
      container.read(selectedGridEntitiesProvider.notifier).add(a);

      expect(container.read(paneContentsProvider), [a]);
    });

    test('sorts the resulting entities', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      container.read(selectedFolderContentsProvider.notifier).addAll({b, a});

      expect(container.read(paneContentsProvider).map((e) => e.name), ['a.jpg', 'b.jpg']);
    });
  });

  group('PaneContents mutators', () {
    PaneContents notifier() => container.read(paneContentsProvider.notifier);

    test('clear and removeAll both empty the state', () {
      container.read(selectedFolderContentsProvider.notifier).add(file('a.jpg'));
      container.read(paneContentsProvider); // trigger build

      notifier().clear();
      expect(container.read(paneContentsProvider), isEmpty);
    });

    test('remove drops the matching entity by path', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      container.read(selectedFolderContentsProvider.notifier).addAll({a, b});
      container.read(paneContentsProvider); // trigger build

      notifier().remove(a);

      expect(container.read(paneContentsProvider).map((e) => e.name), ['b.jpg']);
    });

    test('contains / isSelected reflect current state', () {
      final a = file('a.jpg');
      container.read(selectedFolderContentsProvider.notifier).add(a);
      container.read(paneContentsProvider); // trigger build

      expect(notifier().contains(a), isTrue);
      expect(notifier().isSelected(file('missing.jpg')), isFalse);
    });

    test('size reflects the current entity count', () {
      container.read(selectedFolderContentsProvider.notifier).addAll({file('a.jpg'), file('b.jpg')});

      expect(notifier().size(), 2);
    });
  });
}
