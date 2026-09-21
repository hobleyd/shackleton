import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/folder_contents.dart';

import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('folder_contents_test_');
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  void touch(String name, {DateTime? modified}) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync([]);
    if (modified != null) f.setLastModifiedSync(modified);
  }

  FolderContents notifier() => container.read(folderContentsProvider(tempDir.path).notifier);

  group('build / getFolderContents', () {
    test('lists the files in the directory sorted by name', () {
      touch('b.jpg');
      touch('a.jpg');

      final entities = container.read(folderContentsProvider(tempDir.path));

      expect(entities.map((e) => e.name), ['a.jpg', 'b.jpg']);
    });
  });

  group('sortBy', () {
    test('re-sorts existing state by the requested field', () {
      touch('a.jpg', modified: DateTime(2020));
      touch('b.jpg', modified: DateTime(2024));
      container.read(folderContentsProvider(tempDir.path));

      notifier().sortBy(EntitySortField.modified);

      expect(container.read(folderContentsProvider(tempDir.path)).map((e) => e.name), ['a.jpg', 'b.jpg']);
      expect(notifier().getSortField(), EntitySortField.modified);
    });

    test('calling sortBy with the same field toggles the sort order', () {
      touch('a.jpg');
      touch('b.jpg');
      container.read(folderContentsProvider(tempDir.path));
      expect(notifier().getSortOrder(), EntitySortOrder.asc);

      notifier().sortBy(EntitySortField.name);

      expect(notifier().getSortOrder(), EntitySortOrder.desc);
      expect(container.read(folderContentsProvider(tempDir.path)).map((e) => e.name), ['b.jpg', 'a.jpg']);
    });

    test('sorting by size orders smallest to largest', () {
      File('${tempDir.path}/big.jpg').writeAsBytesSync(List.filled(100, 0));
      File('${tempDir.path}/small.jpg').writeAsBytesSync(List.filled(10, 0));
      container.read(folderContentsProvider(tempDir.path));

      notifier().sortBy(EntitySortField.size);

      expect(container.read(folderContentsProvider(tempDir.path)).map((e) => e.name), ['small.jpg', 'big.jpg']);
    });
  });

  group('add', () {
    test('inserts a new entity in sorted position', () {
      touch('a.jpg');
      touch('c.jpg');
      container.read(folderContentsProvider(tempDir.path));

      notifier().add(FileOfInterest(entity: File('${tempDir.path}/b.jpg')));

      expect(container.read(folderContentsProvider(tempDir.path)).map((e) => e.name), ['a.jpg', 'b.jpg', 'c.jpg']);
    });
  });

  group('delete', () {
    test('removes the entity with the matching path from state', () {
      touch('a.jpg');
      touch('b.jpg');
      final aPath = '${tempDir.path}/a.jpg';
      File(aPath).deleteSync();
      container.read(folderContentsProvider(tempDir.path)); // build snapshot still has a.jpg

      notifier().delete(aPath, FileOfInterest(entity: File(aPath)));

      expect(container.read(folderContentsProvider(tempDir.path)).map((e) => e.name), ['b.jpg']);
    });
  });

  group('setEditableState', () {
    test('replaces the entity with an editing copy in place', () {
      touch('a.jpg');
      container.read(folderContentsProvider(tempDir.path));
      final entity = container.read(folderContentsProvider(tempDir.path)).first;

      notifier().setEditableState(entity, true);

      final updated = container.read(folderContentsProvider(tempDir.path)).first;
      expect(updated.editing, isTrue);
      expect(updated.path, entity.path);
    });
  });
}
