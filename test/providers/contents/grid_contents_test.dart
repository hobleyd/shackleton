import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/grid_contents.dart';
import 'package:shackleton/providers/contents/selected_folder_contents.dart';

import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('grid_contents_test_');
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

  group('GridContents.build', () {
    test('includes a directly-selected previewable file', () {
      final photo = file('photo.jpg');
      container.read(selectedFolderContentsProvider.notifier).add(photo);

      expect(container.read(gridContentsProvider), [photo]);
    });

    test('excludes a directly-selected file that cannot be previewed', () {
      file('archive.zip');
      final zip = FileOfInterest(entity: File('${tempDir.path}/archive.zip'));
      container.read(selectedFolderContentsProvider.notifier).add(zip);

      expect(container.read(gridContentsProvider), isEmpty);
    });

    test('expands a selected directory into its previewable children', () {
      final subDir = Directory('${tempDir.path}/sub')..createSync();
      File('${subDir.path}/photo.jpg').writeAsBytesSync([]);
      File('${subDir.path}/notes.txt').writeAsBytesSync([]);
      container.read(selectedFolderContentsProvider.notifier).add(FileOfInterest(entity: subDir));

      final grid = container.read(gridContentsProvider);

      expect(grid.map((e) => e.name), ['photo.jpg']);
    });

    test('sorts the resulting entities by path', () {
      final b = file('b.jpg');
      final a = file('a.jpg');
      container.read(selectedFolderContentsProvider.notifier).addAll({b, a});

      expect(container.read(gridContentsProvider).map((e) => e.name), ['a.jpg', 'b.jpg']);
    });
  });

  group('GridContents mutators', () {
    GridContents notifier() => container.read(gridContentsProvider.notifier);

    test('add inserts in sorted order and avoids duplicates', () {
      notifier().add(file('b.jpg'));
      notifier().add(file('a.jpg'));
      notifier().add(file('a.jpg'));

      expect(container.read(gridContentsProvider).map((e) => e.name), ['a.jpg', 'b.jpg']);
    });

    test('remove drops the matching entity', () {
      notifier().add(file('a.jpg'));
      notifier().add(file('b.jpg'));

      notifier().remove(file('a.jpg'));

      expect(container.read(gridContentsProvider).map((e) => e.name), ['b.jpg']);
    });

    test('clear and removeAll both empty the list', () {
      notifier().add(file('a.jpg'));
      notifier().clear();
      expect(container.read(gridContentsProvider), isEmpty);

      notifier().add(file('a.jpg'));
      notifier().removeAll();
      expect(container.read(gridContentsProvider), isEmpty);
    });

    test('replace collapses to a single entity', () {
      notifier().addAll({file('a.jpg'), file('b.jpg')});

      notifier().replace(file('c.jpg'));

      expect(container.read(gridContentsProvider).map((e) => e.name), ['c.jpg']);
    });

    test('contains / isSelected / size reflect current state', () {
      notifier().add(file('a.jpg'));

      expect(notifier().contains(file('a.jpg')), isTrue);
      expect(notifier().isSelected(file('b.jpg')), isFalse);
      expect(notifier().size(), 1);
    });
  });
}
