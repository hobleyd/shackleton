import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/application/use_cases/delete_files_use_case.dart';
import 'package:shackleton/domain/repositories/i_file_tags_repository.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_of_interest.dart';

class MockFileTagsRepository extends Mock implements IFileTagsRepository {}

void main() {
  late MockFileTagsRepository mockTags;
  late DeleteFilesUseCase useCase;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(Entity(path: '/tmp/photo.jpg'));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('delete_files_test_');
    mockTags = MockFileTagsRepository();
    when(() => mockTags.removeTagsForEntity(any(), deleteEntity: any(named: 'deleteEntity')))
        .thenAnswer((_) async {});
    useCase = DeleteFilesUseCase(tagsRepository: mockTags);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('DeleteFilesUseCase', () {
    test('removes tags from repository for an existing file', () async {
      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      final entity = FileOfInterest(entity: file);

      await useCase.execute(entity);

      verify(() => mockTags.removeTagsForEntity(any(), deleteEntity: any(named: 'deleteEntity'))).called(1);
    });

    test('still removes tags from repository even when the file does not exist', () async {
      final file = File('${tempDir.path}/missing.jpg'); // never created
      final entity = FileOfInterest(entity: file);

      await useCase.execute(entity);

      verify(() => mockTags.removeTagsForEntity(any(), deleteEntity: any(named: 'deleteEntity'))).called(1);
    });

    test('passes the correct path to the repository', () async {
      final file = File('${tempDir.path}/tagged.jpg')..writeAsBytesSync([]);
      final entity = FileOfInterest(entity: file);

      await useCase.execute(entity);

      final captured = verify(
        () => mockTags.removeTagsForEntity(captureAny(), deleteEntity: any(named: 'deleteEntity')),
      ).captured;
      expect((captured.first as Entity).path, equals(file.path));
    });
  });
}
