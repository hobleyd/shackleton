import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/exif_tool_service_provider.dart';
import 'package:shackleton/providers/import.dart';

class MockExifToolService extends Mock implements IExifToolService {}

void main() {
  late ProviderContainer container;
  late Directory tempDir;
  late MockExifToolService mockExif;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('import_test_');
    mockExif = MockExifToolService();
    // findExifTool() returning null makes ImportFilesUseCase.processFile
    // short-circuit before it ever computes a destination under the real
    // ~/Pictures library path, so these tests never touch it.
    when(() => mockExif.findExifTool()).thenReturn(null);
    container = ProviderContainer(overrides: [
      exifToolServiceProvider.overrideWithValue(mockExif),
    ]);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync([]);
    return FileOfInterest(entity: f);
  }

  group('Import.build', () {
    test('marks every entity as not importable when exiftool is missing', () async {
      final entities = {file('a.jpg'), file('b.jpg')};

      final result = await container.read(importProvider(entities).future);

      expect(result, hasLength(2));
      expect(result.every((e) => e.willImport == false), isTrue);
      expect(result.every((e) => e.hasConflict == true), isTrue);
    });

    test('marks a non-media file as not importable regardless of exiftool', () async {
      final textFile = FileOfInterest(entity: File('${tempDir.path}/notes.txt')..writeAsBytesSync([]));

      final result = await container.read(importProvider({textFile}).future);

      expect(result, hasLength(1));
      expect(result.first.willImport, isFalse);
    });

    test('is empty for an empty entity set', () async {
      final result = await container.read(importProvider(const {}).future);

      expect(result, isEmpty);
    });
  });

  group('Import.replace', () {
    test('swaps the entity in state and notifies listeners', () async {
      final a = file('a.jpg');
      final entities = {a};
      final sub = container.listen(importProvider(entities), (_, _) {});
      addTearDown(sub.close);
      final original = (await container.read(importProvider(entities).future)).single;
      final replacement = original.copyWith(willImport: true, hasConflict: false);

      container.read(importProvider(entities).notifier).replace(original, replacement);
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(importProvider(entities)).value;
      expect(state, [replacement]);
    });
  });
}
