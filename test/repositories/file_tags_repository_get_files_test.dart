import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('getfiles_test_');

    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith(InMemoryAppDatabase.new)],
    );
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await tempDir.delete(recursive: true);
  });

  FileOfInterest makeFile(String name) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync([]);
    return FileOfInterest(entity: f);
  }

  Future<void> tagFile(FileOfInterest foi, List<Tag> tags) async {
    final repo = container.read(fileTagsRepositoryProvider.notifier);
    await repo.writeTags(Entity(
      path: foi.path,
      metadata: FileMetaData(entity: foi, tags: tags),
    ));
  }

  group('FileTagsRepository.getFilesForTag', () {
    test('returns files that have the given tag', () async {
      final photo = makeFile('photo.jpg');
      final video = makeFile('video.mp4');
      await tagFile(photo, [Tag(tag: 'nature')]);
      await tagFile(video, [Tag(tag: 'nature')]);

      final repo = container.read(fileTagsRepositoryProvider.notifier);
      final result = await repo.getFilesForTag(Tag(tag: 'nature'));

      expect(result.map((f) => f.path), containsAll([photo.path, video.path]));
    });

    test('does not return files tagged with a different tag', () async {
      final photo = makeFile('photo.jpg');
      await tagFile(photo, [Tag(tag: 'travel')]);

      final repo = container.read(fileTagsRepositoryProvider.notifier);
      final result = await repo.getFilesForTag(Tag(tag: 'nature'));

      expect(result, isEmpty);
    });

    test('excludes paths that no longer exist on disk', () async {
      final ghost = File('${tempDir.path}/ghost.jpg')..writeAsBytesSync([]);
      final ghostFoi = FileOfInterest(entity: ghost);
      await tagFile(ghostFoi, [Tag(tag: 'landscape')]);
      ghost.deleteSync();

      final repo = container.read(fileTagsRepositoryProvider.notifier);
      final result = await repo.getFilesForTag(Tag(tag: 'landscape'));

      expect(result, isEmpty);
    });
  });
}
