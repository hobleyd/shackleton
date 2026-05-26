import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/native/xmp_reader.dart';
import '../../../lib/services/native/xmp_writer.dart';

Uint8List _toBytes(String xml) => Uint8List.fromList(utf8.encode(xml));

void main() {
  group('XmpWriter', () {
    group('buildXmpWithSubjects', () {
      test('round-trips a single subject through XmpReader', () {
        final xml = XmpWriter.buildXmpWithSubjects(['nature']);
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(['nature']));
      });

      test('round-trips multiple subjects through XmpReader', () {
        final subjects = ['nature', 'travel', 'sunset'];
        final xml = XmpWriter.buildXmpWithSubjects(subjects);
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(subjects));
      });

      test('produces empty Bag for empty list', () {
        final xml = XmpWriter.buildXmpWithSubjects([]);
        expect(XmpReader.readSubjects(_toBytes(xml)), isEmpty);
      });

      test('skips empty strings', () {
        final xml = XmpWriter.buildXmpWithSubjects(['', 'valid', '']);
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(['valid']));
      });

      test('escapes & in subject values', () {
        final xml = XmpWriter.buildXmpWithSubjects(['rock & roll']);
        expect(xml, contains('&amp;'));
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(['rock & roll']));
      });

      test('escapes < in subject values', () {
        final xml = XmpWriter.buildXmpWithSubjects(['a < b']);
        expect(xml, contains('&lt;'));
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(['a < b']));
      });

      test('escapes > in subject values', () {
        final xml = XmpWriter.buildXmpWithSubjects(['a > b']);
        expect(xml, contains('&gt;'));
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(['a > b']));
      });

      test('output is valid UTF-8 XML', () {
        final xml = XmpWriter.buildXmpWithSubjects(['test']);
        expect(xml, contains('<?xpacket'));
        expect(xml, contains('<x:xmpmeta'));
        expect(xml, contains('dc:subject'));
        expect(xml, contains('<rdf:Bag>'));
        expect(xml, contains('</x:xmpmeta>'));
      });

      test('handles non-ASCII characters', () {
        final subjects = ['日本語', 'Ångström'];
        final xml = XmpWriter.buildXmpWithSubjects(subjects);
        expect(XmpReader.readSubjects(_toBytes(xml)), equals(subjects));
      });
    });
  });
}
