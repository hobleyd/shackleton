import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/contents/grid_tags.dart';
import 'package:shackleton/providers/contents/selected_folder_contents.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';
import 'package:shackleton/providers/metadata.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../../helpers/test_database.dart';

final Map<String, FileMetaData> _stubMetadataByPath = {};

class _StubMetadata extends Metadata {
  @override
  FileMetaData build(FileOfInterest entity) =>
      _stubMetadataByPath[entity.path] ?? FileMetaData(entity: entity, tags: const []);
}

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('grid_tags_test_');
    _stubMetadataByPath.clear();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith(InMemoryAppDatabase.new),
      metadataProvider.overrideWith2((entity) => _StubMetadata()),
    ]);
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name) => FileOfInterest(entity: File('${tempDir.path}/$name'));

  group('GridTags -- entities selected', () {
    test('returns the union of tags across the selection, sorted', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      _stubMetadataByPath[a.path] = FileMetaData(entity: a, tags: [Tag(tag: 'zebra')]);
      _stubMetadataByPath[b.path] = FileMetaData(entity: b, tags: [Tag(tag: 'apple'), Tag(tag: 'zebra')]);
      container.read(selectedGridEntitiesProvider.notifier).addAll({a, b});

      final tags = container.read(gridTagsProvider);

      expect(tags.map((t) => t.tag), ['apple', 'zebra']);
    });
  });

  group('GridTags -- nothing selected', () {
    test('batch-loads the union of tags for the visible grid entities', () async {
      final a = file('a.jpg');
      final b = file('b.jpg');
      final tagsRepo = container.read(fileTagsRepositoryProvider.notifier);
      await tagsRepo.writeTags(Entity(path: a.path, metadata: FileMetaData(entity: a, tags: [Tag(tag: 'nature')])));
      await tagsRepo.writeTags(Entity(path: b.path, metadata: FileMetaData(entity: b, tags: [Tag(tag: 'travel')])));
      container.read(selectedFolderContentsProvider.notifier).addAll({a, b});

      final sub = container.listen(gridTagsProvider, (_, _) {});
      addTearDown(sub.close);
      // Initial build returns [] synchronously; the batch load is async.
      expect(container.read(gridTagsProvider), isEmpty);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(gridTagsProvider).map((t) => t.tag), containsAll(['nature', 'travel']));
    });

    test('stays empty when there are no grid entities to load tags for', () {
      expect(container.read(gridTagsProvider), isEmpty);
    });
  });
}
