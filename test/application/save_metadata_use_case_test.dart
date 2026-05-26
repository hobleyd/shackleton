import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/application/exceptions.dart';
import 'package:shackleton/application/use_cases/save_metadata_use_case.dart';
import 'package:shackleton/domain/repositories/i_file_tags_repository.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/entity.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';

class MockExifToolService extends Mock implements IExifToolService {}

class MockFileTagsRepository extends Mock implements IFileTagsRepository {}

void main() {
  late MockExifToolService mockExif;
  late MockFileTagsRepository mockTags;
  late SaveMetadataUseCase useCase;
  late Directory tempDir;
  late File jpegFile;

  setUpAll(() {
    registerFallbackValue(Entity(path: '/tmp/photo.jpg'));
    registerFallbackValue(<Tag>[]);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('save_metadata_test_');
    jpegFile = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);

    mockExif = MockExifToolService();
    mockTags = MockFileTagsRepository();

    when(() => mockTags.writeTags(any())).thenAnswer((_) async {});

    useCase = SaveMetadataUseCase(exifService: mockExif, tagsRepository: mockTags);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  FileMetaData metadataWith(List<Tag> tags) => FileMetaData(
        entity: FileOfInterest(entity: jpegFile),
        tags: tags,
      );

  group('SaveMetadataUseCase', () {
    test('writes to tags repository even when updateFile is false', () async {
      final metadata = metadataWith([Tag(tag: 'birds')]);

      await useCase.execute(metadata, updateFile: false);

      verify(() => mockTags.writeTags(any())).called(1);
      verifyNever(() => mockExif.writeTags(any(), any()));
    });

    test('throws ExifToolMissingException when exiftool is absent and updateFile is true', () async {
      when(() => mockExif.findExifTool()).thenReturn(null);

      final metadata = metadataWith([Tag(tag: 'birds')]);

      expect(
        () => useCase.execute(metadata, updateFile: true),
        throwsA(isA<ExifToolMissingException>()),
      );
    });

    test('writes tags to file when updateFile is true and exiftool is present', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.writeTags(any(), any(), location: any(named: 'location')))
          .thenAnswer((_) async => true);

      final metadata = metadataWith([Tag(tag: 'travel')]);
      final result = await useCase.execute(metadata, updateFile: true);

      expect(result.corruptedMetadata, isFalse);
      verify(() => mockExif.writeTags(any(), any(), location: any(named: 'location'))).called(1);
    });

    test('throws MetadataWriteException when file write fails', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.writeTags(any(), any(), location: any(named: 'location')))
          .thenAnswer((_) async => false);

      final metadata = metadataWith([Tag(tag: 'travel')]);

      expect(
        () => useCase.execute(metadata, updateFile: true),
        throwsA(isA<MetadataWriteException>()),
      );
    });

    test('passes GPS location to exiftool when entity supports location', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.writeTags(any(), any(), location: any(named: 'location')))
          .thenAnswer((_) async => true);

      final metadata = FileMetaData(
        entity: FileOfInterest(entity: jpegFile),
        tags: [],
        gpsLocation: const LatLng(27.47, 153.02),
      );

      await useCase.execute(metadata, updateFile: true);

      final captured = verify(
              () => mockExif.writeTags(any(), any(), location: captureAny(named: 'location')))
          .captured;
      expect(captured.first, isNotNull);
    });
  });
}
