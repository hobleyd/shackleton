import 'dart:convert';
import 'dart:typed_data';

/// Rewrites JPEG metadata segments without touching image data.
///
/// Walks the APP-segment chain before the SOS marker, replaces or inserts
/// Photoshop APP13 (IPTC) and XMP APP1 segments as requested, and preserves
/// all other segments verbatim. The compressed image body (from SOS onwards)
/// is never decoded or modified.
class JpegSegmentWriter {
  static const int _ff = 0xFF;
  static const int _soiMarker = 0xD8;
  static const int _app1Marker = 0xE1;
  static const int _app13Marker = 0xED;
  static const int _sosMarker = 0xDA;
  static const int _eoiMarker = 0xD9;

  // "Photoshop 3.0\0"
  static const List<int> _photoshopPrefix = [
    0x50, 0x68, 0x6F, 0x74, 0x6F, 0x73, 0x68, 0x6F, 0x70,
    0x20, 0x33, 0x2E, 0x30, 0x00,
  ];

  /// Rewrites [jpeg] with updated IPTC and/or XMP segments.
  ///
  /// Pass [iptcIimBytes] to replace or insert the Photoshop APP13 resource.
  /// Pass [xmpXml] to replace or insert the XMP APP1 segment.
  /// Null arguments leave the corresponding existing segment unchanged.
  ///
  /// Returns the original bytes unchanged if the file is not a valid JPEG.
  static Uint8List writeMetadata(
    Uint8List jpeg, {
    Uint8List? iptcIimBytes,
    String? xmpXml,
  }) {
    if (jpeg.length < 2 || jpeg[0] != _ff || jpeg[1] != _soiMarker) {
      return jpeg;
    }
    if (iptcIimBytes == null && xmpXml == null) return jpeg;

    final sosPos = _sosPosition(jpeg);
    final buf = BytesBuilder(copy: false);

    buf.add([_ff, _soiMarker]); // SOI

    bool iptcWritten = false;
    bool xmpWritten = false;
    int pos = 2; // position of the next segment's 0xFF byte

    while (pos + 3 <= sosPos) {
      if (jpeg[pos] != _ff) break;
      final marker = jpeg[pos + 1];
      if (marker == _sosMarker || marker == _eoiMarker) break;

      pos += 2; // now points at the 2-byte length field
      if (pos + 2 > jpeg.length) break;
      final segLen = (jpeg[pos] << 8) | jpeg[pos + 1]; // includes 2 len bytes
      if (segLen < 2 || pos + segLen > jpeg.length) break;

      // Content starts 2 bytes after the length field (skipping the length itself).
      final contentStart = pos + 2;
      final contentLen = segLen - 2;

      bool replaced = false;

      if (marker == _app13Marker && iptcIimBytes != null &&
          _contentStartsWith(jpeg, contentStart, contentLen, _photoshopPrefix)) {
        buf.add(_buildPhotoshopSegment(iptcIimBytes));
        iptcWritten = true;
        replaced = true;
      } else if (marker == _app1Marker && xmpXml != null &&
          _contentStartsWith(jpeg, contentStart, contentLen, _xmpPrefixBytes())) {
        buf.add(_buildXmpSegment(xmpXml));
        xmpWritten = true;
        replaced = true;
      }

      if (!replaced) {
        // Copy the raw segment bytes: FF + marker + length + content
        buf.add(jpeg.sublist(pos - 2, pos + segLen));
      }

      pos += segLen;
    }

    // Insert any segments that were not found in the original.
    if (!iptcWritten && iptcIimBytes != null) {
      buf.add(_buildPhotoshopSegment(iptcIimBytes));
    }
    if (!xmpWritten && xmpXml != null) {
      buf.add(_buildXmpSegment(xmpXml));
    }

    // Append image body (SOS + compressed data + EOI).
    buf.add(jpeg.sublist(sosPos));

    return buf.takeBytes();
  }

  // ─── private helpers ─────────────────────────────────────────────────────

  /// Returns the offset of the SOS (0xDA) or EOI (0xD9) marker, or
  /// [jpeg.length] if neither is found.
  static int _sosPosition(Uint8List jpeg) {
    int pos = 2;
    while (pos + 1 < jpeg.length) {
      if (jpeg[pos] != _ff) break;
      final marker = jpeg[pos + 1];
      if (marker == _sosMarker || marker == _eoiMarker) return pos;
      pos += 2;
      if (pos + 2 > jpeg.length) break;
      final segLen = (jpeg[pos] << 8) | jpeg[pos + 1];
      if (segLen < 2 || pos + segLen > jpeg.length) break;
      pos += segLen;
    }
    return jpeg.length;
  }

  static bool _contentStartsWith(
      Uint8List jpeg, int offset, int length, List<int> prefix) {
    if (length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (jpeg[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  static List<int> _xmpPrefixBytes() =>
      utf8.encode('http://ns.adobe.com/xap/1.0/\x00');

  static List<int> _buildPhotoshopSegment(Uint8List iptcIimBytes) {
    final resourceLen = iptcIimBytes.length;
    final content = [
      ..._photoshopPrefix, // "Photoshop 3.0\0"
      0x38, 0x42, 0x49, 0x4D, // "8BIM"
      0x04, 0x04, // resource ID 0x0404 (IPTC-NAA)
      0x00, 0x00, // Pascal name: empty, padded to 2 bytes
      (resourceLen >> 24) & 0xFF,
      (resourceLen >> 16) & 0xFF,
      (resourceLen >> 8) & 0xFF,
      resourceLen & 0xFF,
      ...iptcIimBytes,
    ];
    return _segment(_app13Marker, content);
  }

  static List<int> _buildXmpSegment(String xmpXml) {
    final content = [..._xmpPrefixBytes(), ...utf8.encode(xmpXml)];
    return _segment(_app1Marker, content);
  }

  static List<int> _segment(int marker, List<int> content) {
    final length = content.length + 2; // length field includes itself
    return [
      _ff,
      marker,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...content,
    ];
  }
}
