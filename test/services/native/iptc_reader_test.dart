import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/iptc_reader.dart';
import '../../helpers/jpeg_builder.dart';

void main() {
  group('IptcReader', () {
    group('readKeywords', () {
      test('extracts a single keyword', () {
        final data = JpegBuilder.encodeIptcKeywords(['nature']);
        final result = IptcReader.readKeywords(data);
        expect(result, equals(['nature']));
      });

      test('extracts multiple keywords as separate entries', () {
        final data = JpegBuilder.encodeIptcKeywords(['nature', 'travel', 'sunset']);
        final result = IptcReader.readKeywords(data);
        expect(result, equals(['nature', 'travel', 'sunset']));
      });

      test('returns empty list for empty data', () {
        expect(IptcReader.readKeywords(Uint8List(0)), isEmpty);
      });

      test('returns empty list for data with no keyword tags', () {
        // Record 2, dataset 5 (Object Name) — not keywords
        final data = Uint8List.fromList([0x1C, 0x02, 0x05, 0x00, 0x04, 0x54, 0x65, 0x73, 0x74]);
        expect(IptcReader.readKeywords(data), isEmpty);
      });

      test('skips non-tag bytes before finding a valid tag', () {
        // Some padding before the first valid IPTC tag
        final keywords = JpegBuilder.encodeIptcKeywords(['bird']);
        final padded = Uint8List.fromList([0x00, 0x00, ...keywords]);
        final result = IptcReader.readKeywords(padded);
        expect(result, equals(['bird']));
      });

      test('trims whitespace from keyword values', () {
        // Manually encode a keyword with leading/trailing spaces
        final value = '  padded  '.codeUnits;
        final data = Uint8List.fromList([
          0x1C, 0x02, 0x19, // tag marker + record + dataset
          (value.length >> 8) & 0xFF, value.length & 0xFF,
          ...value,
        ]);
        final result = IptcReader.readKeywords(data);
        expect(result, equals(['padded']));
      });

      test('handles mixed record types, extracting only keywords', () {
        final buf = <int>[];
        // Record 2, dataset 5 (Object Name): "MyPhoto"
        final name = 'MyPhoto'.codeUnits;
        buf.addAll([0x1C, 0x02, 0x05, 0x00, name.length, ...name]);
        // Record 2, dataset 25 (Keywords): "bird"
        final kw = 'bird'.codeUnits;
        buf.addAll([0x1C, 0x02, 0x19, 0x00, kw.length, ...kw]);
        final result = IptcReader.readKeywords(Uint8List.fromList(buf));
        expect(result, equals(['bird']));
      });

      test('handles truncated data gracefully', () {
        // Tag marker + record + dataset + length claiming 100 bytes, but only 3 follow
        final data = Uint8List.fromList([0x1C, 0x02, 0x19, 0x00, 0x64, 0x61, 0x62, 0x63]);
        expect(() => IptcReader.readKeywords(data), returnsNormally);
      });
    });
  });
}
