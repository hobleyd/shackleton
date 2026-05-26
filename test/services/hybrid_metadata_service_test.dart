import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import '../../lib/domain/services/i_exif_tool_service.dart';
import '../../lib/models/tag.dart';
import '../../lib/services/hybrid_metadata_service.dart';

class MockExifToolService extends Mock implements IExifToolService {}

void main() {
  late MockExifToolService mockNative;
  late MockExifToolService mockExifTool;
  late HybridMetadataService service;

  setUp(() {
    mockNative = MockExifToolService();
    mockExifTool = MockExifToolService();
    service = HybridMetadataService(native: mockNative, exifTool: mockExifTool);
  });

  group('HybridMetadataService routing', () {
    test('findExifTool delegates to exifTool service', () {
      when(() => mockExifTool.findExifTool()).thenReturn('/usr/bin/exiftool');
      expect(service.findExifTool(), equals('/usr/bin/exiftool'));
      verifyNever(() => mockNative.findExifTool());
    });

    test('findExifTool returns null when exiftool not installed', () {
      when(() => mockExifTool.findExifTool()).thenReturn(null);
      expect(service.findExifTool(), isNull);
    });

    test('readTagsAndLocation delegates to native service', () async {
      final result = (tags: <Tag>[Tag(tag: 'nature')], location: null);
      when(() => mockNative.readTagsAndLocation('img.jpg'))
          .thenAnswer((_) async => result);

      final r = await service.readTagsAndLocation('img.jpg');
      expect(r.tags.first.tag, equals('nature'));
      verifyNever(() => mockExifTool.readTagsAndLocation(any()));
    });

    test('readTags delegates to native service', () async {
      when(() => mockNative.readTags('img.jpg'))
          .thenAnswer((_) async => [Tag(tag: 'travel')]);

      final tags = await service.readTags('img.jpg');
      expect(tags.first.tag, equals('travel'));
      verifyNever(() => mockExifTool.readTags(any()));
    });

    test('readLocation delegates to native service', () async {
      final loc = LatLng(27.47, 153.02);
      when(() => mockNative.readLocation('img.jpg'))
          .thenAnswer((_) async => loc);

      final result = await service.readLocation('img.jpg');
      expect(result, equals(loc));
      verifyNever(() => mockExifTool.readLocation(any()));
    });

    test('readThumbnail delegates to native service', () async {
      final thumb = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      when(() => mockNative.readThumbnail('img.jpg'))
          .thenAnswer((_) async => thumb);

      final result = await service.readThumbnail('img.jpg');
      expect(result, equals(thumb));
      verifyNever(() => mockExifTool.readThumbnail(any()));
    });

    test('readCreationDate delegates to native service', () async {
      final date = DateTime(2023, 6, 15, 9, 30);
      when(() => mockNative.readCreationDate('img.jpg'))
          .thenAnswer((_) async => date);

      final result = await service.readCreationDate('img.jpg');
      expect(result, equals(date));
      verifyNever(() => mockExifTool.readCreationDate(any()));
    });

    test('writeTags delegates to native service', () async {
      final tags = <Tag>[Tag(tag: 'nature')];
      when(() => mockNative.writeTags('img.jpg', tags, location: null))
          .thenAnswer((_) async => true);

      final ok = await service.writeTags('img.jpg', tags);
      expect(ok, isTrue);
      verifyNever(() => mockExifTool.writeTags(any(), any()));
    });

    test('readAllExifData delegates to exiftool service', () async {
      final data = {'Make': (orig: 'Canon', reset: 'Canon')};
      when(() => mockExifTool.readAllExifData('img.jpg'))
          .thenAnswer((_) async => data);

      final result = await service.readAllExifData('img.jpg');
      expect(result['Make']?.orig, equals('Canon'));
      verifyNever(() => mockNative.readAllExifData(any()));
    });

    test('fixMetadata delegates to exiftool service', () async {
      when(() => mockExifTool.fixMetadata('img.jpg'))
          .thenAnswer((_) async => true);

      final ok = await service.fixMetadata('img.jpg');
      expect(ok, isTrue);
      verifyNever(() => mockNative.fixMetadata(any()));
    });

    test('deleteBackup delegates to native service', () async {
      when(() => mockNative.deleteBackup('img.jpg')).thenAnswer((_) async {});

      await service.deleteBackup('img.jpg');
      verifyNever(() => mockExifTool.deleteBackup(any()));
    });

    test('restoreBackup delegates to native service', () async {
      when(() => mockNative.restoreBackup('img.jpg')).thenAnswer((_) async {});

      await service.restoreBackup('img.jpg');
      verifyNever(() => mockExifTool.restoreBackup(any()));
    });

    test('parseTagsFromString delegates to native service', () {
      when(() => mockNative.parseTagsFromString('a, b'))
          .thenReturn([Tag(tag: 'a'), Tag(tag: 'b')]);

      final tags = service.parseTagsFromString('a, b');
      expect(tags.map((t) => t.tag), equals(['a', 'b']));
    });

    test('formatTagsToString delegates to native service', () {
      final tags = <Tag>[Tag(tag: 'a'), Tag(tag: 'b')];
      when(() => mockNative.formatTagsToString(tags)).thenReturn('a, b');

      expect(service.formatTagsToString(tags), equals('a, b'));
    });
  });
}
