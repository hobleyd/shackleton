import 'dart:convert';
import 'dart:typed_data';

/// Parses IPTC Information Interchange Model (IIM) binary data.
///
/// Extracts keyword/subject values from the raw IPTC data block obtained from
/// a JPEG APP13 Photoshop resource (resource ID 0x0404).
class IptcReader {
  static const int _tagMarker = 0x1C;
  static const int _keywordsRecord = 0x02;
  static const int _keywordsDataset = 0x19; // dataset 25

  /// Reads all keyword values (IPTC record 2, dataset 25) from [data].
  ///
  /// Each keyword is a separate IIM tag, so multiple keywords are returned as
  /// separate list elements.
  static List<String> readKeywords(Uint8List data) {
    final keywords = <String>[];
    int pos = 0;
    while (pos + 5 <= data.length) {
      if (data[pos] != _tagMarker) {
        pos++;
        continue;
      }
      final record = data[pos + 1];
      final dataset = data[pos + 2];
      final length = (data[pos + 3] << 8) | data[pos + 4];
      pos += 5;
      if (length < 0 || pos + length > data.length) break;
      if (record == _keywordsRecord && dataset == _keywordsDataset) {
        final value = utf8.decode(
          data.sublist(pos, pos + length),
          allowMalformed: true,
        );
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) keywords.add(trimmed);
      }
      pos += length;
    }
    return keywords;
  }
}
