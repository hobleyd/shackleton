import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/repositories/app_statistics_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
    db = container.read(appDatabaseProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('AppStatisticsRepository', () {
    test('reports zero counts for an empty database', () async {
      final stats = await container.read(appStatisticsRepositoryProvider.future);
      expect(stats.tagCount, 0);
      expect(stats.fileCount, 0);
    });

    test('counts files and tags that have been inserted', () async {
      await db.insert('files', {'path': '/a.jpg'});
      await db.insert('files', {'path': '/b.jpg'});
      await db.insert('tags', {'tag': 'nature'});

      final stats = await container.read(appStatisticsRepositoryProvider.notifier).getStatistics();

      expect(stats.fileCount, 2);
      expect(stats.tagCount, 1);
    });

    test('clear empties files, tags, and file_tags and updates state', () async {
      final fileId = await db.insert('files', {'path': '/a.jpg'});
      final tagId = await db.insert('tags', {'tag': 'nature'});
      await db.insert('file_tags', {'fileId': fileId, 'tagId': tagId});
      await container.read(appStatisticsRepositoryProvider.future);

      container.read(appStatisticsRepositoryProvider.notifier).clear();
      // clear() is fire-and-forget (void); wait for its state update to land.
      await Future.delayed(const Duration(milliseconds: 50));

      final files = await db.query('files');
      final tags = await db.query('tags');
      final fileTags = await db.query('file_tags');
      expect(files, isEmpty);
      expect(tags, isEmpty);
      expect(fileTags, isEmpty);

      final state = container.read(appStatisticsRepositoryProvider).value;
      expect(state?.fileCount, 0);
      expect(state?.tagCount, 0);
    });
  });
}
