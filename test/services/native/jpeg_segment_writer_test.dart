import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/iptc_reader.dart';
import '../../../lib/services/native/iptc_writer.dart';
import '../../../lib/services/native/jpeg_segment_reader.dart';
import '../../../lib/services/native/jpeg_segment_writer.dart';
import '../../../lib/services/native/xmp_reader.dart';
import '../../../lib/services/native/xmp_writer.dart';
import '../../helpers/jpeg_builder.dart';
import '../../helpers/tiff_builder.dart';

void main() {
  group('JpegSegmentWriter', () {
    group('writeMetadata with IPTC', () {
      test('inserts IPTC into JPEG that had none', () {
        // Start with a JPEG that only has EXIF (no IPTC)
        final tiff = TiffBuilder.withGps(
          latDeg: 27, latMin: 0, latSec: 0, latRef: 'N',
          lngDeg: 153, lngMin: 0, lngSec: 0, lngRef: 'E',
        );
        final original = JpegBuilder.withExif(tiff);

        final iptc = IptcWriter.encodeKeywords(['inserted']);
        final updated = JpegSegmentWriter.writeMetadata(original, iptcIimBytes: iptc);

        final reader = JpegSegmentReader(updated);
        final iptcBytes = reader.getIptcBytes();
        expect(iptcBytes, isNotNull);
        expect(IptcReader.readKeywords(iptcBytes!), equals(['inserted']));
      });

      test('replaces existing IPTC keywords', () {
        final iptcOriginal = JpegBuilder.encodeIptcKeywords(['old-tag']);
        final original = JpegBuilder.withIptc(iptcOriginal);

        final iptcNew = IptcWriter.encodeKeywords(['new-tag']);
        final updated = JpegSegmentWriter.writeMetadata(original, iptcIimBytes: iptcNew);

        final reader = JpegSegmentReader(updated);
        final iptcBytes = reader.getIptcBytes();
        expect(IptcReader.readKeywords(iptcBytes!), equals(['new-tag']));
      });

      test('preserves existing EXIF when inserting IPTC', () {
        final tiff = TiffBuilder.withGps(
          latDeg: 27, latMin: 28, latSec: 30, latRef: 'N',
          lngDeg: 153, lngMin: 1, lngSec: 12, lngRef: 'E',
        );
        final original = JpegBuilder.withExif(tiff);

        final iptc = IptcWriter.encodeKeywords(['nature']);
        final updated = JpegSegmentWriter.writeMetadata(original, iptcIimBytes: iptc);

        final reader = JpegSegmentReader(updated);
        expect(reader.getExifBytes(), isNotNull); // EXIF preserved
        expect(reader.getIptcBytes(), isNotNull); // IPTC added
      });

      test('round-trip: write and read back multiple keywords', () {
        final keywords = ['nature', 'travel', 'brisbane'];
        final original = JpegBuilder.withIptc(JpegBuilder.encodeIptcKeywords(['old']));

        final iptc = IptcWriter.encodeKeywords(keywords);
        final updated = JpegSegmentWriter.writeMetadata(original, iptcIimBytes: iptc);

        final reader = JpegSegmentReader(updated);
        final iptcBytes = reader.getIptcBytes();
        expect(IptcReader.readKeywords(iptcBytes!), equals(keywords));
      });
    });

    group('writeMetadata with XMP', () {
      test('inserts XMP into JPEG that had none', () {
        final original = JpegBuilder.withIptc(JpegBuilder.encodeIptcKeywords(['tag']));

        final xmp = XmpWriter.buildXmpWithSubjects(['xmp-subject']);
        final updated = JpegSegmentWriter.writeMetadata(original, xmpXml: xmp);

        final reader = JpegSegmentReader(updated);
        final xmpBytes = reader.getXmpBytes();
        expect(xmpBytes, isNotNull);
        expect(XmpReader.readSubjects(xmpBytes!), equals(['xmp-subject']));
      });

      test('replaces existing XMP subjects', () {
        final original = JpegBuilder.withXmp(
          XmpWriter.buildXmpWithSubjects(['old-subject']),
        );

        final xmp = XmpWriter.buildXmpWithSubjects(['new-subject']);
        final updated = JpegSegmentWriter.writeMetadata(original, xmpXml: xmp);

        final reader = JpegSegmentReader(updated);
        final xmpBytes = reader.getXmpBytes();
        expect(XmpReader.readSubjects(xmpBytes!), equals(['new-subject']));
      });
    });

    group('writeMetadata with both IPTC and XMP', () {
      test('inserts both when neither exists', () {
        final tiff = TiffBuilder.withDate('2023:01:15 12:00:00');
        final original = JpegBuilder.withExif(tiff);

        final iptc = IptcWriter.encodeKeywords(['tag']);
        final xmp = XmpWriter.buildXmpWithSubjects(['tag']);
        final updated = JpegSegmentWriter.writeMetadata(
            original, iptcIimBytes: iptc, xmpXml: xmp);

        final reader = JpegSegmentReader(updated);
        expect(reader.getIptcBytes(), isNotNull);
        expect(reader.getXmpBytes(), isNotNull);
        expect(reader.getExifBytes(), isNotNull); // EXIF preserved
      });

      test('replaces both when both already exist', () {
        final original = JpegBuilder.withAll(
          iptcIimBytes: JpegBuilder.encodeIptcKeywords(['old']),
          xmpXml: XmpWriter.buildXmpWithSubjects(['old']),
        );

        final iptc = IptcWriter.encodeKeywords(['new']);
        final xmp = XmpWriter.buildXmpWithSubjects(['new']);
        final updated = JpegSegmentWriter.writeMetadata(
            original, iptcIimBytes: iptc, xmpXml: xmp);

        final reader = JpegSegmentReader(updated);
        expect(IptcReader.readKeywords(reader.getIptcBytes()!), equals(['new']));
        expect(XmpReader.readSubjects(reader.getXmpBytes()!), equals(['new']));
      });
    });

    group('edge cases', () {
      test('returns original bytes unchanged for non-JPEG input', () {
        final notJpeg = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final result = JpegSegmentWriter.writeMetadata(
          notJpeg,
          iptcIimBytes: IptcWriter.encodeKeywords(['tag']),
        );
        expect(result, equals(notJpeg));
      });

      test('returns original bytes when no changes requested', () {
        final original = JpegBuilder.withIptc(JpegBuilder.encodeIptcKeywords(['tag']));
        final result = JpegSegmentWriter.writeMetadata(original);
        expect(result, equals(original));
      });

      test('output is a valid JPEG (starts with SOI)', () {
        final original = JpegBuilder.withExif(TiffBuilder.withDate('2023:01:01 00:00:00'));
        final iptc = IptcWriter.encodeKeywords(['test']);
        final updated = JpegSegmentWriter.writeMetadata(original, iptcIimBytes: iptc);

        expect(updated.length, greaterThan(4));
        expect(updated[0], equals(0xFF));
        expect(updated[1], equals(0xD8)); // SOI
      });

      test('image body is preserved after rewrite', () {
        // The image body (SOS + compressed data) must survive the rewrite unchanged.
        final original = JpegBuilder.withExif(TiffBuilder.withDate('2023:01:01 00:00:00'));
        final iptc = IptcWriter.encodeKeywords(['tag']);
        final updated = JpegSegmentWriter.writeMetadata(original, iptcIimBytes: iptc);

        // Find SOS in both
        int sosSrc = _findSos(original);
        int sosDst = _findSos(updated);
        expect(original.sublist(sosSrc), equals(updated.sublist(sosDst)));
      });
    });
  });
}

int _findSos(Uint8List jpeg) {
  int pos = 2;
  while (pos + 1 < jpeg.length) {
    if (jpeg[pos] != 0xFF) break;
    if (jpeg[pos + 1] == 0xDA) return pos;
    if (jpeg[pos + 1] == 0xD9) return pos;
    pos += 2;
    if (pos + 2 > jpeg.length) break;
    final len = (jpeg[pos] << 8) | jpeg[pos + 1];
    if (len < 2) break;
    pos += len;
  }
  return jpeg.length;
}
