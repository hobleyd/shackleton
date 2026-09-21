import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/tag.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('entity_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('exists', () {
    test('is true when the file exists on disk', () {
      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      expect(Entity(path: file.path).exists, isTrue);
    });

    test('is false when the file does not exist on disk', () {
      expect(Entity(path: '${tempDir.path}/missing.jpg').exists, isFalse);
    });
  });

  group('hasTags / tags', () {
    test('are null when there is no metadata', () {
      final entity = Entity(path: '${tempDir.path}/photo.jpg');
      expect(entity.hasTags, isNull);
      expect(entity.tags, isNull);
    });

    test('reflect an empty tag list', () {
      final entity = Entity(
        path: '${tempDir.path}/photo.jpg',
        metadata: const FileMetaData(tags: []),
      );
      expect(entity.hasTags, isFalse);
      expect(entity.tags, isEmpty);
    });

    test('reflect a populated tag list', () {
      final tags = [Tag(tag: 'nature'), Tag(tag: 'travel')];
      final entity = Entity(
        path: '${tempDir.path}/photo.jpg',
        metadata: FileMetaData(tags: tags),
      );
      expect(entity.hasTags, isTrue);
      expect(entity.tags, tags);
    });
  });

  group('fromMap / toMap', () {
    test('round-trips id and path', () {
      final entity = Entity.fromMap({'id': 7, 'path': '/a/b.jpg'});
      expect(entity.id, 7);
      expect(entity.path, '/a/b.jpg');
      expect(entity.toMap(), {'id': 7, 'path': '/a/b.jpg'});
    });
  });

  group('toString', () {
    test('includes the basename and id', () {
      final entity = Entity(path: '${tempDir.path}/photo.jpg', id: 3);
      expect(entity.toString(), contains('photo.jpg'));
      expect(entity.toString(), contains('3'));
    });
  });
}
