import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/exif_tool_service_provider.dart';
import 'package:shackleton/providers/metadata_cache_warmer.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../helpers/test_database.dart';

class MockExifToolService extends Mock implements IExifToolService {}

void main() {
  late ProviderContainer container;
  late Directory tempDir;
  late MockExifToolService mockExif;

  setUpAll(() {
    registerFallbackValue(<Tag>[]);
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // A dedicated temp dir stands in for the library path -- the warmer reads
    // this from appSettingsRepositoryProvider, which otherwise defaults to
    // the real ~/Pictures. Never let this provider build without seeding
    // app_settings first, or it will recursively scan and watch the user's
    // actual photo library.
    tempDir = await Directory.systemTemp.createTemp('metadata_cache_warmer_test_');
    mockExif = MockExifToolService();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith(InMemoryAppDatabase.new),
      exifToolServiceProvider.overrideWithValue(mockExif),
    ]);
    final db = container.read(appDatabaseProvider.notifier);
    await container.read(appDatabaseProvider.future);
    await db.insert('app_settings', {'id': 0, 'libraryPath': tempDir.path, 'fontSize': 12});
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> settle() async {
    final sub = container.listen(metadataCacheWarmerProvider, (_, _) {});
    // Give the background enqueue/scan loop time to finish against these
    // few small temp files (no real exiftool calls -- all mocked).
    await Future.delayed(const Duration(milliseconds: 300));
    sub.close();
  }

  group('MetadataCacheWarmer', () {
    test('loads metadata for unindexed, metadata-supported files under the library path', () async {
      File('${tempDir.path}/photo.jpg').writeAsBytesSync([]);
      when(() => mockExif.readTagsAndLocation(any())).thenAnswer(
        (_) async => (tags: [Tag(tag: 'nature')], location: null),
      );

      await settle();

      final tagsRepo = container.read(fileTagsRepositoryProvider.notifier);
      final tags = await tagsRepo.getTagsForPaths(['${tempDir.path}/photo.jpg']);
      expect(tags.map((t) => t.tag), contains('nature'));
    });

    test('does not re-load a file that is already indexed', () async {
      final path = '${tempDir.path}/photo.jpg';
      File(path).writeAsBytesSync([]);
      final tagsRepo = container.read(fileTagsRepositoryProvider.notifier);
      await tagsRepo.writeTags(Entity(
        path: path,
        metadata: FileMetaData(entity: null, tags: [Tag(tag: 'already-indexed')]),
      ));

      await settle();

      verifyNever(() => mockExif.readTagsAndLocation(any()));
    });

    test('ignores files with unsupported extensions', () async {
      File('${tempDir.path}/notes.txt').writeAsBytesSync([]);

      await settle();

      verifyNever(() => mockExif.readTagsAndLocation(any()));
    });

    test('state returns to not-visible once the queue drains', () async {
      File('${tempDir.path}/photo.jpg').writeAsBytesSync([]);
      when(() => mockExif.readTagsAndLocation(any())).thenAnswer(
        (_) async => (tags: <Tag>[], location: null),
      );

      await settle();

      expect(container.read(metadataCacheWarmerProvider).isVisible, isFalse);
    });
  });
}
