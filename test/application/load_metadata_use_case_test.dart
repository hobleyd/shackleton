import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/application/use_cases/load_metadata_use_case.dart';
import 'package:shackleton/domain/repositories/i_file_tags_repository.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';

class MockExifToolService extends Mock implements IExifToolService {}

class MockFileTagsRepository extends Mock implements IFileTagsRepository {}

void main() {
  late MockExifToolService mockExif;
  late MockFileTagsRepository mockTags;
  late LoadMetadataUseCase useCase;
  late Directory tempDir;
  late File jpegFile;
  late File txtFile;

  setUpAll(() {
    registerFallbackValue(Entity(path: '/tmp/photo.jpg'));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('load_metadata_test_');
    jpegFile = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
    txtFile = File('${tempDir.path}/note.txt')..writeAsBytesSync([]);

    mockExif = MockExifToolService();
    mockTags = MockFileTagsRepository();

    when(() => mockTags.writeTags(any())).thenAnswer((_) async {});

    useCase = LoadMetadataUseCase(exifService: mockExif, tagsRepository: mockTags);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  FileOfInterest jpeg() => FileOfInterest(entity: jpegFile);
  FileOfInterest txt() => FileOfInterest(entity: txtFile);

  group('LoadMetadataUseCase', () {
    test('returns null when exiftool is not installed', () async {
      when(() => mockExif.findExifTool()).thenReturn(null);

      final result = await useCase.execute(jpeg());

      expect(result, isNull);
      verifyNever(() => mockTags.writeTags(any()));
    });

    test('returns null for unsupported file types', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');

      final result = await useCase.execute(txt());

      expect(result, isNull);
      verifyNever(() => mockTags.writeTags(any()));
    });

    test('reads tags and location then persists to repository', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readTags(any()))
          .thenAnswer((_) async => [Tag(tag: 'nature'), Tag(tag: 'travel')]);
      when(() => mockExif.readLocation(any())).thenAnswer((_) async => null);

      final result = await useCase.execute(jpeg());

      expect(result, isNotNull);
      expect(result!.tags.map((t) => t.tag), containsAll(['nature', 'travel']));
      expect(result.entity, equals(jpeg()));
      verify(() => mockTags.writeTags(any())).called(1);
    });

    test('includes GPS location when exiftool returns coordinates', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readTags(any())).thenAnswer((_) async => []);
      when(() => mockExif.readLocation(any()))
          .thenAnswer((_) async => const LatLng(27.47, 153.02));

      final result = await useCase.execute(jpeg());

      expect(result!.gpsLocation, isNotNull);
      expect(result.gpsLocation!.latitude, closeTo(27.47, 0.001));
    });
  });
}
