import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';
import 'package:shackleton/providers/contents/selected_grid_metadata.dart';
import 'package:shackleton/providers/metadata.dart';

// Real Metadata.build() fires off an unawaited exiftool/DB load; these tests
// only care about SelectedGridMetadata's own aggregation/sort logic, so stub
// it with metadata keyed by entity path (mirrors folder_pane_keyboard_test's
// _StubMetadata).
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
    tempDir = await Directory.systemTemp.createTemp('selected_grid_metadata_test_');
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

  group('SelectedGridMetadata', () {
    test('is empty when nothing is selected', () {
      expect(container.read(selectedGridMetadataProvider), isEmpty);
    });

    test('returns metadata for each selected entity', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      _stubMetadataByPath[a.path] = FileMetaData(entity: a, tags: [Tag(tag: 'nature')]);
      _stubMetadataByPath[b.path] = FileMetaData(entity: b, tags: [Tag(tag: 'travel')]);
      container.read(selectedGridEntitiesProvider.notifier).addAll({a, b});

      final metadata = container.read(selectedGridMetadataProvider);

      expect(metadata, hasLength(2));
      expect(metadata.expand((m) => m.tags).map((t) => t.tag), containsAll(['nature', 'travel']));
    });

    test('sorts the resulting metadata', () {
      final a = file('a.jpg');
      final b = file('b.jpg');
      // FileMetaData sorts by its toString(), which is its tag list -- give
      // them clearly different tag sets so the order is unambiguous.
      _stubMetadataByPath[a.path] = FileMetaData(entity: a, tags: [Tag(tag: 'zzz')]);
      _stubMetadataByPath[b.path] = FileMetaData(entity: b, tags: [Tag(tag: 'aaa')]);
      container.read(selectedGridEntitiesProvider.notifier).addAll({a, b});

      final metadata = container.read(selectedGridMetadataProvider);

      expect(metadata.first.tags.first.tag, 'aaa');
      expect(metadata.last.tags.first.tag, 'zzz');
    });

    test('reflects a change in the underlying selection', () {
      final a = file('a.jpg');
      container.read(selectedGridEntitiesProvider.notifier).add(a);
      expect(container.read(selectedGridMetadataProvider), hasLength(1));

      container.read(selectedGridEntitiesProvider.notifier).clear();

      expect(container.read(selectedGridMetadataProvider), isEmpty);
    });
  });
}
