import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/exif_reader.dart';
import '../../helpers/tiff_builder.dart';

void main() {
  group('ExifReader', () {
    // ── GPS ──────────────────────────────────────────────────────────────────

    group('readGps', () {
      test('returns coordinates for a northern/eastern fix', () async {
        // 27° 28' 30" N, 153° 1' 12" E
        // = 27 + 28/60 + 30/3600 ≈ 27.475° N
        // = 153 + 1/60 + 12/3600 ≈ 153.020° E
        final tiff = TiffBuilder.withGps(
          latDeg: 27, latMin: 28, latSec: 30, latRef: 'N',
          lngDeg: 153, lngMin: 1, lngSec: 12, lngRef: 'E',
        );
        final result = await ExifReader.readGps(tiff);
        expect(result, isNotNull);
        expect(result!.latitude, closeTo(27.475, 0.01));
        expect(result.longitude, closeTo(153.020, 0.01));
      });

      test('returns negative latitude for southern fix', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 33, latMin: 52, latSec: 0, latRef: 'S',
          lngDeg: 151, lngMin: 12, lngSec: 0, lngRef: 'E',
        );
        final result = await ExifReader.readGps(tiff);
        expect(result, isNotNull);
        expect(result!.latitude, isNegative);
        expect(result.latitude, closeTo(-33.867, 0.01));
        expect(result.longitude, closeTo(151.2, 0.01));
      });

      test('returns negative longitude for western fix', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 40, latMin: 42, latSec: 46, latRef: 'N',
          lngDeg: 74, lngMin: 0, lngSec: 22, lngRef: 'W',
        );
        final result = await ExifReader.readGps(tiff);
        expect(result, isNotNull);
        expect(result!.longitude, isNegative);
      });

      test('returns null for TIFF with no GPS IFD', () async {
        final tiff = TiffBuilder.withDate('2023:01:15 12:34:56');
        final result = await ExifReader.readGps(tiff);
        expect(result, isNull);
      });

      test('returns null for empty bytes', () async {
        final result = await ExifReader.readGps([]);
        expect(result, isNull);
      });
    });

    // ── Creation date ─────────────────────────────────────────────────────────

    group('readCreationDate', () {
      test('parses DateTimeOriginal correctly', () async {
        final tiff = TiffBuilder.withDate('2023:06:15 09:30:45');
        final result = await ExifReader.readCreationDate(tiff);
        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
        expect(result.hour, equals(9));
        expect(result.minute, equals(30));
        expect(result.second, equals(45));
      });

      test('returns null for TIFF with no date field', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 0, latMin: 0, latSec: 0, latRef: 'N',
          lngDeg: 0, lngMin: 0, lngSec: 0, lngRef: 'E',
        );
        final result = await ExifReader.readCreationDate(tiff);
        expect(result, isNull);
      });

      test('returns null for empty bytes', () async {
        final result = await ExifReader.readCreationDate([]);
        expect(result, isNull);
      });
    });

    // ── Thumbnail ─────────────────────────────────────────────────────────────

    group('readThumbnail', () {
      test('returns thumbnail bytes from IFD1', () async {
        // A tiny fake "JPEG" thumbnail (just needs to be non-empty bytes)
        final fakeThumb = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
        final tiff = TiffBuilder.withThumbnail(fakeThumb);
        final result = await ExifReader.readThumbnail(tiff);
        expect(result, isNotNull);
        expect(result, equals(fakeThumb));
      });

      test('returns null for TIFF with no IFD1 thumbnail', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 0, latMin: 0, latSec: 0, latRef: 'N',
          lngDeg: 0, lngMin: 0, lngSec: 0, lngRef: 'E',
        );
        final result = await ExifReader.readThumbnail(tiff);
        expect(result, isNull);
      });

      test('returns null for empty bytes', () async {
        final result = await ExifReader.readThumbnail([]);
        expect(result, isNull);
      });

      test('thumbnail bytes match exactly', () async {
        final fakeThumb = Uint8List.fromList(
            List.generate(100, (i) => i & 0xFF)); // 100 bytes
        final tiff = TiffBuilder.withThumbnail(fakeThumb);
        final result = await ExifReader.readThumbnail(tiff);
        expect(result, isNotNull);
        expect(result!.length, equals(100));
        expect(result, equals(fakeThumb));
      });
    });
  });
}
