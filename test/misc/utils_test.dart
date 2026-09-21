import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/misc/utils.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('StringFuncs', () {
    group('trimCharLeft', () {
      test('removes a single leading occurrence', () {
        expect('/path'.trimCharLeft('/'), 'path');
      });

      test('removes repeated leading occurrences', () {
        expect('///path'.trimCharLeft('/'), 'path');
      });

      test('leaves the string unchanged when the pattern is not a prefix', () {
        expect('path/'.trimCharLeft('/'), 'path/');
      });

      test('returns the original string when empty', () {
        expect(''.trimCharLeft('/'), '');
      });

      test('returns the original string when the pattern is empty', () {
        expect('/path'.trimCharLeft(''), '/path');
      });

      test('returns the original string when the pattern is longer than the string', () {
        expect('/'.trimCharLeft('//'), '/');
      });
    });

    group('trimCharRight', () {
      test('removes a single trailing occurrence', () {
        expect('path/'.trimCharRight('/'), 'path');
      });

      test('removes repeated trailing occurrences', () {
        expect('path///'.trimCharRight('/'), 'path');
      });

      test('leaves the string unchanged when the pattern is not a suffix', () {
        expect('/path'.trimCharRight('/'), '/path');
      });
    });

    group('trimChar', () {
      test('removes the pattern from both ends', () {
        expect('//path//'.trimChar('/'), 'path');
      });

      test('leaves an internal occurrence untouched', () {
        expect('/a/b/'.trimChar('/'), 'a/b');
      });
    });
  });

  group('convertLatLng', () {
    test('formats a positive latitude as North', () {
      expect(convertLatLng(27.4698, true), '27 deg 28\' 11.28" N');
    });

    test('formats a negative latitude as South', () {
      expect(convertLatLng(-27.4698, true), '27 deg 28\' 11.28" S');
    });

    test('formats a positive longitude as East', () {
      expect(convertLatLng(153.0251, false), '153 deg 1\' 30.36" E');
    });

    test('formats a negative longitude as West', () {
      expect(convertLatLng(-153.0251, false), '153 deg 1\' 30.36" W');
    });
  });

  group('getSizeString', () {
    test('returns 0b for zero size', () {
      expect(getSizeString(0), '0b');
    });

    test('formats bytes below 1024 with the b suffix', () {
      expect(getSizeString(512), '512b');
    });

    test('formats kilobytes with the k suffix', () {
      expect(getSizeString(2048), '2k');
    });

    test('formats megabytes with the m suffix', () {
      expect(getSizeString(5 * 1024 * 1024), '5m');
    });

    test('formats gigabytes with the g suffix', () {
      expect(getSizeString(3 * 1024 * 1024 * 1024), '3g');
    });

    test('respects the decimals parameter', () {
      expect(getSizeString(1536, decimals: 2), '1.50k');
    });
  });

  group('getLocation', () {
    test('returns an empty string for null metadata', () {
      expect(getLocation(null, true), '');
    });

    test('returns an empty string when gpsLocation is null', () {
      const metadata = FileMetaData(tags: []);
      expect(getLocation(metadata, true), '');
    });

    test('returns the formatted latitude when gpsLocation is set', () {
      const metadata = FileMetaData(tags: [], gpsLocation: LatLng(27.4698, 153.0251));
      expect(getLocation(metadata, true), convertLatLng(27.4698, true));
    });

    test('returns the formatted longitude when gpsLocation is set', () {
      const metadata = FileMetaData(tags: [], gpsLocation: LatLng(27.4698, 153.0251));
      expect(getLocation(metadata, false), convertLatLng(153.0251, false));
    });
  });

  group('getEntity', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('get_entity_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('returns a Directory for a directory path', () {
      expect(getEntity(tempDir.path), isA<Directory>());
    });

    test('returns a File for an existing file path', () {
      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      expect(getEntity(file.path), isA<File>());
    });

    test('defaults to File for a path that does not exist', () {
      expect(getEntity('${tempDir.path}/missing.jpg'), isA<File>());
    });
  });

  group('getEntitySizeString', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('get_entity_size_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('formats the size of the underlying file', () {
      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync(List.filled(2048, 0));
      final entity = FileOfInterest(entity: file);

      expect(getEntitySizeString(entity: entity), '2k');
    });
  });

  group('getZipName', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('get_zip_name_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('replaces a single file\'s extension with .zip', () {
      final folder = FileOfInterest(entity: tempDir);
      final file = FileOfInterest(entity: File('${tempDir.path}/photo.jpg'));

      final zip = getZipName(folder, {file});

      expect(zip.path, '${tempDir.path}/photo.zip');
    });

    test('appends .zip when the single file has no extension', () {
      final folder = FileOfInterest(entity: tempDir);
      final file = FileOfInterest(entity: File('${tempDir.path}/README'));

      final zip = getZipName(folder, {file});

      expect(zip.path, '${tempDir.path}/README.zip');
    });

    test('names multiple files Archive.zip', () {
      final folder = FileOfInterest(entity: tempDir);
      final a = FileOfInterest(entity: File('${tempDir.path}/a.jpg'));
      final b = FileOfInterest(entity: File('${tempDir.path}/b.jpg'));

      final zip = getZipName(folder, {a, b});

      expect(zip.path, '${tempDir.path}/Archive.zip');
    });

    test('avoids colliding with an existing Archive.zip', () {
      File('${tempDir.path}/Archive.zip').writeAsBytesSync([]);
      final folder = FileOfInterest(entity: tempDir);
      final a = FileOfInterest(entity: File('${tempDir.path}/a.jpg'));
      final b = FileOfInterest(entity: File('${tempDir.path}/b.jpg'));

      final zip = getZipName(folder, {a, b});

      expect(zip.path, '${tempDir.path}/Archive-1.zip');
    });

    test('finds the next free suffix past multiple existing archives', () {
      File('${tempDir.path}/Archive.zip').writeAsBytesSync([]);
      File('${tempDir.path}/Archive-1.zip').writeAsBytesSync([]);
      final folder = FileOfInterest(entity: tempDir);
      final a = FileOfInterest(entity: File('${tempDir.path}/a.jpg'));
      final b = FileOfInterest(entity: File('${tempDir.path}/b.jpg'));

      final zip = getZipName(folder, {a, b});

      expect(zip.path, '${tempDir.path}/Archive-2.zip');
    });
  });

  group('createZip', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('create_zip_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('returns null when there is nothing to zip', () async {
      final folder = FileOfInterest(entity: tempDir);

      final result = await createZip(folder, {});

      expect(result, isNull);
    });

    test('creates a zip archive containing the given file', () async {
      final folder = FileOfInterest(entity: tempDir);
      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final entity = FileOfInterest(entity: file);

      final result = await createZip(folder, {entity});

      expect(result, isNotNull);
      expect(File(result!.path).existsSync(), isTrue);
      expect(result.path, '${tempDir.path}/photo.zip');
    });
  });
}
