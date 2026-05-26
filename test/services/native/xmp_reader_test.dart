import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/xmp_reader.dart';

Uint8List _encode(String xml) => Uint8List.fromList(utf8.encode(xml));

void main() {
  group('XmpReader', () {
    group('readSubjects', () {
      test('extracts a single subject', () {
        final xml = '''
<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/">
      <dc:subject>
        <rdf:Bag>
          <rdf:li>nature</rdf:li>
        </rdf:Bag>
      </dc:subject>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>''';
        final result = XmpReader.readSubjects(_encode(xml));
        expect(result, equals(['nature']));
      });

      test('extracts multiple subjects', () {
        final xml = '''
<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/">
      <dc:subject>
        <rdf:Bag>
          <rdf:li>nature</rdf:li>
          <rdf:li>travel</rdf:li>
          <rdf:li>sunset</rdf:li>
        </rdf:Bag>
      </dc:subject>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>''';
        final result = XmpReader.readSubjects(_encode(xml));
        expect(result, equals(['nature', 'travel', 'sunset']));
      });

      test('returns empty list when no dc:subject element', () {
        const xml = '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF/></x:xmpmeta>';
        expect(XmpReader.readSubjects(_encode(xml)), isEmpty);
      });

      test('returns empty list for empty rdf:Bag', () {
        const xml = '''
<x:xmpmeta>
  <rdf:RDF>
    <rdf:Description>
      <dc:subject><rdf:Bag/></dc:subject>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>''';
        expect(XmpReader.readSubjects(_encode(xml)), isEmpty);
      });

      test('returns empty list for empty bytes', () {
        expect(XmpReader.readSubjects(Uint8List(0)), isEmpty);
      });

      test('trims whitespace from subject values', () {
        const xml = '''<x:xmpmeta>
  <rdf:RDF><rdf:Description><dc:subject>
    <rdf:Bag>
      <rdf:li>  padded  </rdf:li>
    </rdf:Bag>
  </dc:subject></rdf:Description></rdf:RDF>
</x:xmpmeta>''';
        final result = XmpReader.readSubjects(_encode(xml));
        expect(result, equals(['padded']));
      });

      test('handles rdf:li with xml:lang attribute', () {
        const xml = '''<x:xmpmeta>
  <rdf:RDF><rdf:Description><dc:subject>
    <rdf:Bag>
      <rdf:li xml:lang="en">landscape</rdf:li>
    </rdf:Bag>
  </dc:subject></rdf:Description></rdf:RDF>
</x:xmpmeta>''';
        final result = XmpReader.readSubjects(_encode(xml));
        expect(result, equals(['landscape']));
      });

      test('returns empty list for malformed bytes gracefully', () {
        final bytes = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01]);
        expect(() => XmpReader.readSubjects(bytes), returnsNormally);
      });
    });
  });
}
