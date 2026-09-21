import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/selected_folder_contents.dart';

import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('selected_folder_contents_test_');
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name) => FileOfInterest(entity: File('${tempDir.path}/$name'));

  SelectedFolderContents notifier() => container.read(selectedFolderContentsProvider.notifier);

  group('SelectedFolderContents', () {
    test('starts empty', () {
      expect(container.read(selectedFolderContentsProvider), isEmpty);
    });

    test('add and contains', () {
      notifier().add(file('a.jpg'));

      expect(notifier().contains(file('a.jpg')), isTrue);
      expect(notifier().isSelected(file('b.jpg')), isFalse);
    });

    test('add does not duplicate', () {
      notifier().add(file('a.jpg'));
      notifier().add(file('a.jpg'));

      expect(notifier().size(), 1);
    });

    test('addAll merges into the existing set', () {
      notifier().add(file('a.jpg'));
      notifier().addAll({file('b.jpg'), file('c.jpg')});

      expect(notifier().size(), 3);
    });

    test('remove drops a single file by path', () {
      notifier().addAll({file('a.jpg'), file('b.jpg')});

      notifier().remove(file('a.jpg'));

      expect(notifier().contains(file('a.jpg')), isFalse);
      expect(notifier().contains(file('b.jpg')), isTrue);
    });

    test('remove for a directory drops every entity under that path', () {
      final dirEntity = FileOfInterest(entity: Directory('${tempDir.path}/sub'));
      final childA = FileOfInterest(entity: File('${tempDir.path}/sub/a.jpg'));
      final childB = FileOfInterest(entity: File('${tempDir.path}/sub/b.jpg'));
      final unrelated = file('outside.jpg');
      notifier().addAll({childA, childB, unrelated});

      notifier().remove(dirEntity);

      expect(container.read(selectedFolderContentsProvider), {unrelated});
    });

    test('clear / removeAll empty the selection', () {
      notifier().add(file('a.jpg'));
      notifier().clear();
      expect(notifier().size(), 0);

      notifier().add(file('a.jpg'));
      notifier().removeAll();
      expect(notifier().size(), 0);
    });

    test('replace collapses to a single entity', () {
      notifier().addAll({file('a.jpg'), file('b.jpg')});

      notifier().replace(file('c.jpg'));

      expect(container.read(selectedFolderContentsProvider), {file('c.jpg')});
    });

    test('replaceAll replaces the whole set', () {
      notifier().add(file('a.jpg'));

      notifier().replaceAll({file('b.jpg'), file('c.jpg')});

      expect(container.read(selectedFolderContentsProvider), {file('b.jpg'), file('c.jpg')});
    });
  });
}
