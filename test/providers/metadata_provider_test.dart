import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/exif_tool_service_provider.dart';
import 'package:shackleton/providers/metadata.dart';

import '../helpers/test_database.dart';

class MockExifToolService extends Mock implements IExifToolService {}

void main() {
  late ProviderContainer container;
  late MockExifToolService mockExif;
  late Directory tempDir;
  late File tempFile;

  setUpAll(() {
    registerFallbackValue(<Tag>[]);
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('metadata_test_');
    tempFile = File('${tempDir.path}/photo.jpg');
    await tempFile.writeAsBytes([]);

    mockExif = MockExifToolService();
    when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
    when(() => mockExif.parseTagsFromString(any())).thenAnswer(
      (inv) => (inv.positionalArguments.first as String)
          .split(',')
          .map((s) => Tag(tag: s.trim()))
          .where((t) => t.tag.isNotEmpty)
          .toList(),
    );
    when(() => mockExif.formatTagsToString(any())).thenAnswer(
      (inv) => (inv.positionalArguments.first as List<Tag>).map((t) => t.tag).join(', '),
    );

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith(InMemoryAppDatabase.new),
        exifToolServiceProvider.overrideWithValue(mockExif),
      ],
    );
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await tempDir.delete(recursive: true);
  });

  FileOfInterest jpegEntity() => FileOfInterest(entity: tempFile);

  group('Metadata provider', () {
    test('hasExifTool returns true when service finds exiftool', () async {
      final entity = jpegEntity();
      when(() => mockExif.readTagsAndLocation(any()))
          .thenAnswer((_) async => (tags: <Tag>[], location: null));

      container.read(metadataProvider(entity));
      expect(container.read(metadataProvider(entity).notifier).hasExifTool, isTrue);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('hasExifTool returns false when exiftool is not installed', () async {
      when(() => mockExif.findExifTool()).thenReturn(null);

      final entity = jpegEntity();
      container.read(metadataProvider(entity));
      expect(container.read(metadataProvider(entity).notifier).hasExifTool, isFalse);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('loadMetadataFromFile populates state tags from exiftool', () async {
      final entity = jpegEntity();
      when(() => mockExif.readTagsAndLocation(entity.path)).thenAnswer(
        (_) async => (tags: [Tag(tag: 'nature'), Tag(tag: 'travel')], location: null),
      );

      container.read(metadataProvider(entity));

      // Allow the fire-and-forget loadMetadataFromFile to complete.
      await Future.delayed(const Duration(milliseconds: 50));

      final loaded = container.read(metadataProvider(entity));
      expect(loaded.tags.map((t) => t.tag), containsAll(['nature', 'travel']));
    });

    test('replaceTagsFromString updates state without writing to file', () async {
      final entity = jpegEntity();
      when(() => mockExif.readTagsAndLocation(any()))
          .thenAnswer((_) async => (tags: <Tag>[], location: null));

      // Initialise the provider state with a known entity so entity! is non-null.
      container.read(metadataProvider(entity));
      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(metadataProvider(entity).notifier);
      await notifier.replaceTagsFromString('birds, travel', updateFile: false);

      final result = container.read(metadataProvider(entity));
      expect(result.tags.map((t) => t.tag), containsAll(['birds', 'travel']));
    });
  });
}
