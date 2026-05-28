import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() {
    container.dispose();
  });

  group('FileTagsRepository', () {
    test('getTags returns empty list when no tags exist', () async {
      final tags = await container.read(fileTagsRepositoryProvider.future);
      expect(tags, isEmpty);
    });

    test('writeTags persists tags for an entity', () async {
      final entity = _entityWithTags('/test/photo.jpg', ['holiday', 'beach']);
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity);

      final allTags = await repo.getTags();
      expect(allTags.map((t) => t.tag), containsAll(['holiday', 'beach']));
    });

    test('writeTags is idempotent — writing the same tags twice does not duplicate', () async {
      final entity = _entityWithTags('/test/photo.jpg', ['holiday']);
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity);
      await repo.writeTags(entity);

      final allTags = await repo.getTags();
      expect(allTags.where((t) => t.tag == 'holiday').length, 1);
    });

    test('removeTagsForEntity removes tags and cleans up orphaned tags', () async {
      final entity = _entityWithTags('/test/photo.jpg', ['solo']);
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity);

      var allTags = await repo.getTags();
      expect(allTags.map((t) => t.tag), contains('solo'));

      await repo.removeTagsForEntity(entity);

      allTags = await repo.getTags();
      expect(allTags.map((t) => t.tag), isNot(contains('solo')));
    });

    test('shared tag is kept when only one file is removed', () async {
      final entity1 = _entityWithTags('/test/a.jpg', ['shared']);
      final entity2 = _entityWithTags('/test/b.jpg', ['shared']);
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity1);
      await repo.writeTags(entity2);

      await repo.removeTagsForEntity(entity1);

      final allTags = await repo.getTags();
      expect(allTags.map((t) => t.tag), contains('shared'));
    });

    test('writeTags tracks untagged files so DB-first lookup finds them', () async {
      final entity = Entity(path: '/test/untagged.jpg')
        ..metadata = const FileMetaData(entity: null, tags: []);
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity);

      final foi = FileOfInterest(entity: File('/test/untagged.jpg'));
      final result = await repo.getMetadataForFile('/test/untagged.jpg', foi);
      expect(result, isNotNull);
      expect(result!.tags, isEmpty);
    });

    test('writeTags caches GPS coordinates', () async {
      final entity = Entity(path: '/test/gps.jpg')
        ..metadata = FileMetaData(
            entity: null,
            tags: [],
            gpsLocation: const LatLng(27.47, 153.02));
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity);

      final foi = FileOfInterest(entity: File('/test/gps.jpg'));
      final result = await repo.getMetadataForFile('/test/gps.jpg', foi);
      expect(result, isNotNull);
      expect(result!.gpsLocation, isNotNull);
      expect(result.gpsLocation!.latitude, closeTo(27.47, 0.001));
      expect(result.gpsLocation!.longitude, closeTo(153.02, 0.001));
    });

    test('writeTags removes tags deleted from the entity', () async {
      final entity = _entityWithTags('/test/photo.jpg', ['keep', 'remove']);
      final repo = container.read(fileTagsRepositoryProvider.notifier);
      await repo.writeTags(entity);

      // Populate IDs from DB so the diff logic works
      final allTags = await repo.getTags();
      final keepTag = allTags.firstWhere((t) => t.tag == 'keep');
      final updatedEntity = Entity(path: '/test/photo.jpg')
        ..metadata = FileMetaData(entity: null, tags: [keepTag]);
      await repo.writeTags(updatedEntity);

      final finalTags = await repo.getTags();
      expect(finalTags.map((t) => t.tag), contains('keep'));
      expect(finalTags.map((t) => t.tag), isNot(contains('remove')));
    });

    group('getMetadataForFile', () {
      test('returns null for an unknown path', () async {
        final repo = container.read(fileTagsRepositoryProvider.notifier);
        final foi = FileOfInterest(entity: File('/unknown/path.jpg'));
        final result = await repo.getMetadataForFile('/unknown/path.jpg', foi);
        expect(result, isNull);
      });

      test('returns tags after writeTags', () async {
        final entity = _entityWithTags('/test/photo.jpg', ['holiday', 'beach']);
        final repo = container.read(fileTagsRepositoryProvider.notifier);
        await repo.writeTags(entity);

        final foi = FileOfInterest(entity: File('/test/photo.jpg'));
        final result = await repo.getMetadataForFile('/test/photo.jpg', foi);
        expect(result, isNotNull);
        expect(result!.tags.map((t) => t.tag),
            containsAll(['holiday', 'beach']));
      });

      test('returns empty tags for a file tracked with no tags', () async {
        final entity = Entity(path: '/test/empty.jpg')
          ..metadata = const FileMetaData(entity: null, tags: []);
        final repo = container.read(fileTagsRepositoryProvider.notifier);
        await repo.writeTags(entity);

        final foi = FileOfInterest(entity: File('/test/empty.jpg'));
        final result = await repo.getMetadataForFile('/test/empty.jpg', foi);
        expect(result, isNotNull);
        expect(result!.tags, isEmpty);
      });
    });
  });
}

Entity _entityWithTags(String path, List<String> tagNames) {
  final tags = tagNames.map((t) => Tag(tag: t)).toList();
  return Entity(path: path)..metadata = FileMetaData(entity: null, tags: tags);
}
