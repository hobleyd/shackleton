import 'dart:convert';
import 'dart:typed_data';

/// Encodes keywords as IPTC Information Interchange Model (IIM) binary data.
///
/// Each keyword is stored as a separate record 2 / dataset 25 tag — the
/// format expected by all IPTC-aware tools and `IptcReader`.
class IptcWriter {
  static const int _tagMarker = 0x1C;
  static const int _keywordsRecord = 0x02;
  static const int _keywordsDataset = 0x19; // dataset 25

  /// Encodes [keywords] as raw IPTC IIM bytes suitable for embedding in a
  /// Photoshop APP13 8BIM resource (ID 0x0404).
  static Uint8List encodeKeywords(List<String> keywords) {
    final buf = BytesBuilder(copy: false);
    for (final kw in keywords) {
      if (kw.isEmpty) continue;
      final encoded = utf8.encode(kw);
      buf.addByte(_tagMarker);
      buf.addByte(_keywordsRecord);
      buf.addByte(_keywordsDataset);
      buf.addByte((encoded.length >> 8) & 0xFF);
      buf.addByte(encoded.length & 0xFF);
      buf.add(encoded);
    }
    return buf.takeBytes();
  }
}
