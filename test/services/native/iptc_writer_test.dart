import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/iptc_reader.dart';
import '../../../lib/services/native/iptc_writer.dart';

void main() {
  group('IptcWriter', () {
    group('encodeKeywords', () {
      test('round-trips a single keyword through IptcReader', () {
        final bytes = IptcWriter.encodeKeywords(['nature']);
        expect(IptcReader.readKeywords(bytes), equals(['nature']));
      });

      test('round-trips multiple keywords through IptcReader', () {
        final keywords = ['nature', 'travel', 'sunset'];
        final bytes = IptcWriter.encodeKeywords(keywords);
        expect(IptcReader.readKeywords(bytes), equals(keywords));
      });

      test('encodes empty list to empty bytes', () {
        final bytes = IptcWriter.encodeKeywords([]);
        expect(bytes, isEmpty);
      });

      test('skips empty strings', () {
        final bytes = IptcWriter.encodeKeywords(['', 'valid', '']);
        expect(IptcReader.readKeywords(bytes), equals(['valid']));
      });

      test('handles keywords with non-ASCII characters', () {
        final keywords = ['Sauðárkrókur', '日本語', 'Ångström'];
        final bytes = IptcWriter.encodeKeywords(keywords);
        expect(IptcReader.readKeywords(bytes), equals(keywords));
      });

      test('encodes each keyword as a separate IIM tag', () {
        const keywords = ['a', 'b', 'c'];
        final bytes = IptcWriter.encodeKeywords(keywords);
        // Each tag: 0x1C + record + dataset + len_hi + len_lo + content
        // All single-char keywords → each tag is 5 + 1 = 6 bytes
        expect(bytes.length, equals(6 * 3));
        // Verify tag markers
        expect(bytes[0], equals(0x1C));
        expect(bytes[6], equals(0x1C));
        expect(bytes[12], equals(0x1C));
      });
    });
  });
}
