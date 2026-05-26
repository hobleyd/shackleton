import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:shackleton/application/use_cases/import_files_use_case.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/file_of_interest.dart';

class MockExifToolService extends Mock implements IExifToolService {}

void main() {
  late MockExifToolService mockExif;
  late Directory tempDir;
  late Directory libraryDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_test_');
    libraryDir = await Directory('${tempDir.path}/library').create();
    mockExif = MockExifToolService();
  });

  tearDown(() async => tempDir.delete(recursive: true));

  ImportFilesUseCase useCase() => ImportFilesUseCase(
        exifService: mockExif,
        libraryPath: libraryDir.path,
      );

  group('ImportFilesUseCase', () {
    test('marks file as no-import when exiftool is missing', () async {
      when(() => mockExif.findExifTool()).thenReturn(null);

      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      final result = await useCase().processFile(FileOfInterest(entity: file));

      expect(result.willImport, isFalse);
      expect(result.hasConflict, isTrue);
    });

    test('marks file as no-import when it does not exist', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');

      final file = File('${tempDir.path}/missing.jpg'); // never created
      final result = await useCase().processFile(FileOfInterest(entity: file));

      expect(result.willImport, isFalse);
    });

    test('returns willImport=true for a fresh file with valid creation date', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readCreationDate(any()))
          .thenAnswer((_) async => DateTime(2023, 6, 15));

      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      final result = await useCase().processFile(FileOfInterest(entity: file));

      expect(result.willImport, isTrue);
      expect(result.hasConflict, isFalse);
      expect(result.renamedFile, contains('2023'));
      expect(result.renamedFile, contains('06 - June'));
    });

    test('falls back to current date when readCreationDate returns null', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readCreationDate(any())).thenAnswer((_) async => null);

      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      final before = DateTime.now();

      final result = await useCase().processFile(FileOfInterest(entity: file));

      expect(result.renamedFile, contains(before.year.toString()));
    });

    test('processes a directory recursively', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readCreationDate(any()))
          .thenAnswer((_) async => DateTime(2022, 3, 10));

      final subDir = await Directory('${tempDir.path}/camera').create();
      File('${subDir.path}/img1.jpg').writeAsBytesSync([]);
      File('${subDir.path}/img2.jpg').writeAsBytesSync([]);

      final results = await useCase().processEntities({FileOfInterest(entity: subDir)});


      expect(results.length, 2);
    });

    test('destination path uses libraryPath as root', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readCreationDate(any()))
          .thenAnswer((_) async => DateTime(2021, 1, 5));

      final file = File('${tempDir.path}/shot.jpg')..writeAsBytesSync([]);
      final result = await useCase().processFile(FileOfInterest(entity: file));

      expect(result.renamedFile, startsWith(libraryDir.path));
      expect(result.renamedFile,
          p.join(libraryDir.path, '2021', '01 - January', 'shot.jpg'));
    });
  });
}
