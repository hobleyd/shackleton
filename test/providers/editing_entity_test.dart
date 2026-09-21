import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/folder_contents.dart';
import 'package:shackleton/providers/editing_entity.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('editing_entity_test_');
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('EditingEntity', () {
    test('starts null', () {
      expect(container.read(editingEntityProvider), isNull);
    });

    test('setEditingEntity(true) sets the state and marks the entity editable in its folder', () {
      final file = File('${tempDir.path}/a.jpg')..writeAsBytesSync([]);
      final entity = FileOfInterest(entity: file);
      // Establish the folder listing before editing so setEditableState finds the entity.
      container.read(folderContentsProvider(tempDir.path));

      container.read(editingEntityProvider.notifier).setEditingEntity(entity, true);

      expect(container.read(editingEntityProvider), entity);
      final folderEntity =
          container.read(folderContentsProvider(tempDir.path)).firstWhere((e) => e.path == entity.path);
      expect(folderEntity.editing, isTrue);
    });

    test('setEditingEntity(false) clears the state', () {
      final file = File('${tempDir.path}/a.jpg')..writeAsBytesSync([]);
      final entity = FileOfInterest(entity: file);
      container.read(folderContentsProvider(tempDir.path));
      container.read(editingEntityProvider.notifier).setEditingEntity(entity, true);

      container.read(editingEntityProvider.notifier).setEditingEntity(entity, false);

      expect(container.read(editingEntityProvider), isNull);
      final folderEntity =
          container.read(folderContentsProvider(tempDir.path)).firstWhere((e) => e.path == entity.path);
      expect(folderEntity.editing, isFalse);
    });
  });
}
