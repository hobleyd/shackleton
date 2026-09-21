import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/folder_path.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() {
    container.dispose();
  });

  FolderPath notifier() => container.read(folderPathProvider.notifier);

  group('FolderPath', () {
    test('starts with just the home folder', () {
      final state = container.read(folderPathProvider);
      expect(state, hasLength(1));
    });

    test('setFolder replaces the whole breadcrumb trail', () {
      notifier().setFolder(Directory('/a'));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a']);
    });

    test('addFolder appends when the clicked path is the last breadcrumb', () {
      notifier().setFolder(Directory('/a'));

      notifier().addFolder(Directory('/a'), Directory('/a/b'));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a', '/a/b']);
    });

    test('addFolder truncates back to the clicked breadcrumb before appending', () {
      notifier().setFolder(Directory('/a'));
      notifier().addFolder(Directory('/a'), Directory('/a/b'));
      notifier().addFolder(Directory('/a/b'), Directory('/a/b/c'));

      // Clicking back on '/a' and drilling into a different child should
      // drop '/a/b' and '/a/b/c', not just append.
      notifier().addFolder(Directory('/a'), Directory('/a/d'));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a', '/a/d']);
    });

    test('addFolder is a no-op when the clicked path is not in the trail', () {
      notifier().setFolder(Directory('/a'));

      notifier().addFolder(Directory('/nowhere'), Directory('/a/b'));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a']);
    });

    test('addFolder does not add a duplicate of an already-visible folder', () {
      notifier().setFolder(Directory('/a'));
      notifier().addFolder(Directory('/a'), Directory('/a/b'));

      notifier().addFolder(Directory('/a'), Directory('/a/b'));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a', '/a/b']);
    });

    test('contains checks by path', () {
      notifier().setFolder(Directory('/a'));

      expect(notifier().contains(FileOfInterest(entity: Directory('/a'))), isTrue);
      expect(notifier().contains(FileOfInterest(entity: Directory('/b'))), isFalse);
    });

    test('remove truncates the trail before the removed folder', () {
      notifier().setFolder(Directory('/a'));
      notifier().addFolder(Directory('/a'), Directory('/a/b'));
      notifier().addFolder(Directory('/a/b'), Directory('/a/b/c'));

      notifier().remove(FileOfInterest(entity: Directory('/a/b')));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a']);
    });

    test('remove is a no-op when the folder is not in the trail', () {
      notifier().setFolder(Directory('/a'));

      notifier().remove(FileOfInterest(entity: Directory('/nowhere')));

      expect(container.read(folderPathProvider).map((d) => d.path), ['/a']);
    });
  });
}
