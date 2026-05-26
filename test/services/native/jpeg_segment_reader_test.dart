import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/jpeg_segment_reader.dart';
import '../../helpers/jpeg_builder.dart';
import '../../helpers/tiff_builder.dart';

void main() {
  group('JpegSegmentReader', () {
    group('isValidJpeg', () {
      test('returns true for a valid JPEG', () {
        final bytes = JpegBuilder.withExif(
          TiffBuilder.withGps(
              latDeg: 27, latMin: 0, latSec: 0, latRef: 'N',
              lngDeg: 153, lngMin: 0, lngSec: 0, lngRef: 'E'),
        );
        expect(JpegSegmentReader(bytes).isValidJpeg, isTrue);
      });

      test('returns false for empty bytes', () {
        expect(JpegSegmentReader(Uint8List(0)).isValidJpeg, isFalse);
      });

      test('returns false for non-JPEG bytes', () {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG SOI
        expect(JpegSegmentReader(bytes).isValidJpeg, isFalse);
      });

      test('returns false for truncated SOI', () {
        expect(JpegSegmentReader(Uint8List.fromList([0xFF])).isValidJpeg, isFalse);
      });
    });

    group('getExifBytes', () {
      test('returns TIFF bytes when EXIF APP1 is present', () {
        final tiff = TiffBuilder.withGps(
            latDeg: 1, latMin: 0, latSec: 0, latRef: 'N',
            lngDeg: 2, lngMin: 0, lngSec: 0, lngRef: 'E');
        final jpeg = JpegBuilder.withExif(tiff);
        final result = JpegSegmentReader(jpeg).getExifBytes();
        expect(result, isNotNull);
        // Should start with TIFF byte-order mark
        expect(result![0], equals(0x49)); // 'I'
        expect(result[1], equals(0x49)); // 'I' (little-endian)
      });

      test('returns null when no EXIF APP1 is present', () {
        final jpeg = JpegBuilder.withIptc(JpegBuilder.encodeIptcKeywords(['tag']));
        expect(JpegSegmentReader(jpeg).getExifBytes(), isNull);
      });

      test('does not confuse XMP APP1 with EXIF APP1', () {
        final jpeg = JpegBuilder.withXmp('<x:xmpmeta/>');
        expect(JpegSegmentReader(jpeg).getExifBytes(), isNull);
      });
    });

    group('getIptcBytes', () {
      test('returns IPTC IIM bytes when APP13 is present', () {
        final iptc = JpegBuilder.encodeIptcKeywords(['nature', 'travel']);
        final jpeg = JpegBuilder.withIptc(iptc);
        final result = JpegSegmentReader(jpeg).getIptcBytes();
        expect(result, isNotNull);
        // First byte should be the IPTC tag marker 0x1C
        expect(result![0], equals(0x1C));
      });

      test('returns null when no APP13 is present', () {
        final jpeg = JpegBuilder.withXmp('<x:xmpmeta/>');
        expect(JpegSegmentReader(jpeg).getIptcBytes(), isNull);
      });
    });

    group('getXmpBytes', () {
      test('returns XMP bytes when XMP APP1 is present', () {
        const xml = '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF/></x:xmpmeta>';
        final jpeg = JpegBuilder.withXmp(xml);
        final result = JpegSegmentReader(jpeg).getXmpBytes();
        expect(result, isNotNull);
        final decoded = utf8.decode(result!);
        expect(decoded, contains('<x:xmpmeta'));
      });

      test('returns null when no XMP APP1 is present', () {
        final tiff = TiffBuilder.withGps(
            latDeg: 0, latMin: 0, latSec: 0, latRef: 'N',
            lngDeg: 0, lngMin: 0, lngSec: 0, lngRef: 'E');
        final jpeg = JpegBuilder.withExif(tiff);
        expect(JpegSegmentReader(jpeg).getXmpBytes(), isNull);
      });

      test('does not confuse EXIF APP1 with XMP APP1', () {
        final tiff = TiffBuilder.withGps(
            latDeg: 0, latMin: 0, latSec: 0, latRef: 'N',
            lngDeg: 0, lngMin: 0, lngSec: 0, lngRef: 'E');
        final jpeg = JpegBuilder.withExif(tiff);
        expect(JpegSegmentReader(jpeg).getXmpBytes(), isNull);
      });
    });

    group('with multiple segments', () {
      test('finds all segment types in a combined JPEG', () {
        final tiff = TiffBuilder.withGps(
            latDeg: 27, latMin: 0, latSec: 0, latRef: 'N',
            lngDeg: 153, lngMin: 0, lngSec: 0, lngRef: 'E');
        final iptc = JpegBuilder.encodeIptcKeywords(['nature']);
        const xmp = '<x:xmpmeta/>';

        final jpeg = JpegBuilder.withAll(
          exifTiffBytes: tiff,
          iptcIimBytes: iptc,
          xmpXml: xmp,
        );

        final reader = JpegSegmentReader(jpeg);
        expect(reader.getExifBytes(), isNotNull);
        expect(reader.getIptcBytes(), isNotNull);
        expect(reader.getXmpBytes(), isNotNull);
      });
    });
  });
}
