import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/contents/pane_tags.dart';
import 'package:shackleton/providers/metadata.dart';

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
    tempDir = await Directory.systemTemp.createTemp('pane_tags_test_');
    _stubMetadataByPath.clear();
    container = ProviderContainer(overrides: [
      metadataProvider.overrideWith2((entity) => _StubMetadata()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name) => FileOfInterest(entity: File('${tempDir.path}/$name'));

  group('PaneTags', () {
    test('starts empty', () {
      expect(container.read(paneTagsProvider), isEmpty);
    });

    test('replace loads and sorts the entity\'s tags', () {
      final entity = file('a.jpg');
      _stubMetadataByPath[entity.path] =
          FileMetaData(entity: entity, tags: [Tag(tag: 'zebra'), Tag(tag: 'apple')]);

      container.read(paneTagsProvider.notifier).replace(entity);

      expect(container.read(paneTagsProvider).map((t) => t.tag), ['apple', 'zebra']);
    });

    test('replace with a different entity overwrites the previous tags', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      _stubMetadataByPath[a.path] = FileMetaData(entity: a, tags: [Tag(tag: 'first')]);
      _stubMetadataByPath[b.path] = FileMetaData(entity: b, tags: [Tag(tag: 'second')]);
      final notifier = container.read(paneTagsProvider.notifier);
      notifier.replace(a);

      notifier.replace(b);

      expect(container.read(paneTagsProvider).map((t) => t.tag), ['second']);
    });
  });
}
