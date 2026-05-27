import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native_metadata_service.dart';
import '../../helpers/jpeg_builder.dart';
import '../../helpers/tiff_builder.dart';

void main() {
  late Directory tempDir;
  late NativeMetadataService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('native_metadata_test_');
    service = NativeMetadataService();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<String> writeJpeg(String name, Uint8List bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  group('NativeMetadataService', () {
    group('readTagsAndLocation', () {
      test('reads IPTC keywords', () async {
        final iptc = JpegBuilder.encodeIptcKeywords(['nature', 'travel']);
        final path = await writeJpeg('iptc.jpg', JpegBuilder.withIptc(iptc));

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag), containsAll(['nature', 'travel']));
        expect(result.location, isNull);
      });

      test('reads XMP subjects as fallback when no IPTC', () async {
        const xmp = '''<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/">
      <dc:subject>
        <rdf:Bag>
          <rdf:li>sunset</rdf:li>
          <rdf:li>landscape</rdf:li>
        </rdf:Bag>
      </dc:subject>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>''';
        final path = await writeJpeg('xmp.jpg', JpegBuilder.withXmp(xmp));

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag), containsAll(['sunset', 'landscape']));
      });

      test('splits legacy comma-separated IPTC keyword into individual tags', () async {
        // Old exiftool writer stored all tags as one comma-separated IPTC entry.
        final iptc = JpegBuilder.encodeIptcKeywords(['Annette, Bob, David, Diane']);
        final path = await writeJpeg('legacy_iptc.jpg', JpegBuilder.withIptc(iptc));

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag),
            containsAll(['Annette', 'Bob', 'David', 'Diane']));
        expect(result.tags.length, equals(4));
      });

      test('splits legacy comma-separated XMP subject into individual tags', () async {
        const xmp = '''<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/">
      <dc:subject>
        <rdf:Bag>
          <rdf:li>Annette, Bob, David, Diane</rdf:li>
        </rdf:Bag>
      </dc:subject>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>''';
        final path = await writeJpeg('legacy_xmp.jpg', JpegBuilder.withXmp(xmp));

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag),
            containsAll(['Annette', 'Bob', 'David', 'Diane']));
        expect(result.tags.length, equals(4));
      });

      test('prefers IPTC over XMP when both are present', () async {
        final iptc = JpegBuilder.encodeIptcKeywords(['iptc-keyword']);
        const xmp = '''<x:xmpmeta>
  <rdf:RDF><rdf:Description><dc:subject>
    <rdf:Bag><rdf:li>xmp-subject</rdf:li></rdf:Bag>
  </dc:subject></rdf:Description></rdf:RDF>
</x:xmpmeta>''';
        final jpeg = JpegBuilder.withAll(iptcIimBytes: iptc, xmpXml: xmp);
        final path = await writeJpeg('both.jpg', jpeg);

        final result = await service.readTagsAndLocation(path);
        final tagNames = result.tags.map((t) => t.tag).toList();
        expect(tagNames, contains('iptc-keyword'));
        expect(tagNames, isNot(contains('xmp-subject')));
      });

      test('reads GPS coordinates from EXIF', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 27, latMin: 28, latSec: 30, latRef: 'N',
          lngDeg: 153, lngMin: 1, lngSec: 12, lngRef: 'E',
        );
        final path = await writeJpeg('gps.jpg', JpegBuilder.withExif(tiff));

        final result = await service.readTagsAndLocation(path);
        expect(result.location, isNotNull);
        expect(result.location!.latitude, closeTo(27.475, 0.01));
        expect(result.location!.longitude, closeTo(153.020, 0.01));
      });

      test('reads both tags and GPS from combined JPEG', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 27, latMin: 0, latSec: 0, latRef: 'N',
          lngDeg: 153, lngMin: 0, lngSec: 0, lngRef: 'E',
        );
        final iptc = JpegBuilder.encodeIptcKeywords(['brisbane']);
        final jpeg =
            JpegBuilder.withAll(exifTiffBytes: tiff, iptcIimBytes: iptc);
        final path = await writeJpeg('combined.jpg', jpeg);

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag), contains('brisbane'));
        expect(result.location, isNotNull);
        expect(result.location!.latitude, closeTo(27.0, 0.1));
      });

      test('returns empty result for non-JPEG file', () async {
        final file = File('${tempDir.path}/text.txt');
        await file.writeAsString('hello');

        final result = await service.readTagsAndLocation(file.path);
        expect(result.tags, isEmpty);
        expect(result.location, isNull);
      });

      test('returns empty result for missing file', () async {
        final result = await service.readTagsAndLocation('${tempDir.path}/missing.jpg');
        expect(result.tags, isEmpty);
        expect(result.location, isNull);
      });

      test('returns empty tags for JPEG with no metadata', () async {
        // A JPEG with only a GPS EXIF (no IPTC, no XMP)
        final tiff = TiffBuilder.withGps(
          latDeg: 0, latMin: 0, latSec: 0, latRef: 'N',
          lngDeg: 0, lngMin: 0, lngSec: 0, lngRef: 'E',
        );
        final path = await writeJpeg('no_tags.jpg', JpegBuilder.withExif(tiff));
        final result = await service.readTagsAndLocation(path);
        expect(result.tags, isEmpty);
      });
    });

    group('readThumbnail', () {
      test('returns thumbnail bytes from EXIF IFD1', () async {
        final fakeThumb = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
        final tiff = TiffBuilder.withThumbnail(fakeThumb);
        final path = await writeJpeg('thumb.jpg', JpegBuilder.withExif(tiff));

        final result = await service.readThumbnail(path);
        expect(result, isNotNull);
        expect(result, equals(fakeThumb));
      });

      test('returns null for JPEG without embedded thumbnail', () async {
        final tiff = TiffBuilder.withDate('2023:01:01 00:00:00');
        final path = await writeJpeg('no_thumb.jpg', JpegBuilder.withExif(tiff));
        expect(await service.readThumbnail(path), isNull);
      });

      test('returns null for non-JPEG file', () async {
        final file = File('${tempDir.path}/data.bin');
        await file.writeAsBytes([0x00, 0x01, 0x02]);
        expect(await service.readThumbnail(file.path), isNull);
      });

      test('returns null for missing file', () async {
        expect(await service.readThumbnail('${tempDir.path}/nope.jpg'), isNull);
      });
    });

    group('readCreationDate', () {
      test('returns parsed creation date from EXIF', () async {
        final tiff = TiffBuilder.withDate('2023:06:15 09:30:45');
        final path = await writeJpeg('dated.jpg', JpegBuilder.withExif(tiff));

        final result = await service.readCreationDate(path);
        expect(result, isNotNull);
        expect(result!.year, equals(2023));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
      });

      test('returns null for JPEG without date', () async {
        final jpeg = JpegBuilder.withIptc(
          JpegBuilder.encodeIptcKeywords(['tag']),
        );
        final path = await writeJpeg('nodate.jpg', jpeg);
        expect(await service.readCreationDate(path), isNull);
      });

      test('returns null for missing file', () async {
        expect(await service.readCreationDate('${tempDir.path}/x.jpg'), isNull);
      });
    });

    group('writeTags', () {
      test('writes tags and reads them back', () async {
        final path = await writeJpeg('rw.jpg', JpegBuilder.withExif(
          TiffBuilder.withDate('2023:01:01 00:00:00'),
        ));
        final tags = service.parseTagsFromString('nature, travel');

        final ok = await service.writeTags(path, tags);
        expect(ok, isTrue);

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag), containsAll(['nature', 'travel']));
      });

      test('overwrites existing IPTC keywords', () async {
        final path = await writeJpeg('overwrite.jpg',
          JpegBuilder.withIptc(JpegBuilder.encodeIptcKeywords(['old'])));
        final tags = service.parseTagsFromString('new');

        final ok = await service.writeTags(path, tags);
        expect(ok, isTrue);

        final result = await service.readTagsAndLocation(path);
        expect(result.tags.map((t) => t.tag).toList(), equals(['new']));
      });

      test('preserves EXIF GPS coordinates after writing tags', () async {
        final tiff = TiffBuilder.withGps(
          latDeg: 27, latMin: 28, latSec: 30, latRef: 'N',
          lngDeg: 153, lngMin: 1, lngSec: 12, lngRef: 'E',
        );
        final path = await writeJpeg('gps_preserve.jpg', JpegBuilder.withExif(tiff));
        final tags = service.parseTagsFromString('tagged');

        await service.writeTags(path, tags);
        final result = await service.readTagsAndLocation(path);

        expect(result.location, isNotNull);
        expect(result.location!.latitude, closeTo(27.475, 0.01));
        expect(result.tags.map((t) => t.tag), contains('tagged'));
      });

      test('returns false for non-JPEG file', () async {
        final file = File('${tempDir.path}/data.bin');
        await file.writeAsBytes([0x00, 0x01]);
        final ok = await service.writeTags(
            file.path, service.parseTagsFromString('tag'));
        expect(ok, isFalse);
      });

      test('returns false for missing file', () async {
        final ok = await service.writeTags(
            '${tempDir.path}/missing.jpg', service.parseTagsFromString('tag'));
        expect(ok, isFalse);
      });

      test('writes empty tag list (clears tags)', () async {
        final path = await writeJpeg('clear.jpg',
          JpegBuilder.withIptc(JpegBuilder.encodeIptcKeywords(['remove'])));

        final ok = await service.writeTags(path, []);
        expect(ok, isTrue);

        final result = await service.readTagsAndLocation(path);
        expect(result.tags, isEmpty);
      });
    });

    group('write operations still unsupported', () {
      test('fixMetadata throws', () {
        expect(() => service.fixMetadata('x.jpg'), throwsUnsupportedError);
      });

      test('readAllExifData throws', () {
        expect(() => service.readAllExifData('x.jpg'), throwsUnsupportedError);
      });
    });

    group('utility methods', () {
      test('parseTagsFromString splits comma-separated tags', () {
        final result = service.parseTagsFromString('nature, travel, sunset');
        expect(result.map((t) => t.tag), equals(['nature', 'travel', 'sunset']));
      });

      test('parseTagsFromString ignores empty entries', () {
        final result = service.parseTagsFromString('one,,two');
        expect(result.map((t) => t.tag), equals(['one', 'two']));
      });

      test('formatTagsToString joins with comma-space', () {
        // Use a Tag-compatible object by accessing parseTagsFromString output
        final tags = service.parseTagsFromString('a, b, c');
        expect(service.formatTagsToString(tags), equals('a, b, c'));
      });

      test('findExifTool returns null', () {
        expect(service.findExifTool(), isNull);
      });
    });
  });
}
