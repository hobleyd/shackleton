import 'dart:convert';
import 'dart:typed_data';

/// Builds minimal JPEG byte arrays for use in unit tests.
///
/// The resulting bytes contain the requested APP segments and a minimal image
/// body. They are valid enough for the metadata parsers under test but are not
/// decoded as images.
class JpegBuilder {
  // Minimal 1×1 grey JPEG image body (SOF+DHT+DQT+SOS+EOI), enough that a
  // JPEG validator sees a complete file. Stored as a compile-time constant.
  static final Uint8List _minimalImageBody = Uint8List.fromList([
    // DQT (minimal 64-byte table, all 1s)
    0xFF, 0xDB, 0x00, 0x43, 0x00,
    ...List.filled(64, 1),
    // SOF0: 1×1, 1 component
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00,
    // DHT (minimal)
    0xFF, 0xC4, 0x00, 0x1F, 0x00,
    0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B,
    // SOS (start of scan — parsers stop here)
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
    // minimal scan data + EOI
    0x7F, 0xFF, 0xD9,
  ]);

  /// Builds a JPEG with an EXIF APP1 segment wrapping [tiffBytes].
  static Uint8List withExif(Uint8List tiffBytes) {
    return _build([_exifApp1(tiffBytes)]);
  }

  /// Builds a JPEG with a Photoshop APP13 segment containing [iptcIimBytes].
  static Uint8List withIptc(Uint8List iptcIimBytes) {
    return _build([_photoshopApp13(iptcIimBytes)]);
  }

  /// Builds a JPEG with an XMP APP1 segment containing [xmpXml].
  static Uint8List withXmp(String xmpXml) {
    return _build([_xmpApp1(xmpXml)]);
  }

  /// Builds a JPEG with all three kinds of metadata segments.
  static Uint8List withAll({
    Uint8List? exifTiffBytes,
    Uint8List? iptcIimBytes,
    String? xmpXml,
  }) {
    return _build([
      if (exifTiffBytes != null) _exifApp1(exifTiffBytes),
      if (iptcIimBytes != null) _photoshopApp13(iptcIimBytes),
      if (xmpXml != null) _xmpApp1(xmpXml),
    ]);
  }

  // ─── raw IPTC IIM helpers ─────────────────────────────────────────────────

  /// Encodes [keywords] as IPTC IIM bytes (record 2, dataset 25).
  static Uint8List encodeIptcKeywords(List<String> keywords) {
    final buf = BytesBuilder(copy: false);
    for (final kw in keywords) {
      final encoded = utf8.encode(kw);
      buf.addByte(0x1C); // tag marker
      buf.addByte(0x02); // record 2
      buf.addByte(0x19); // dataset 25 = Keywords
      buf.addByte((encoded.length >> 8) & 0xFF);
      buf.addByte(encoded.length & 0xFF);
      buf.add(encoded);
    }
    return buf.takeBytes();
  }

  // ─── segment builders ────────────────────────────────────────────────────

  static List<int> _exifApp1(Uint8List tiffBytes) {
    // "Exif\0\0" + TIFF bytes
    final data = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, ...tiffBytes];
    return _segment(0xE1, data);
  }

  static List<int> _photoshopApp13(Uint8List iptcIimBytes) {
    // "Photoshop 3.0\0" + 8BIM header for resource 0x0404 + IPTC data
    final resourceLen = iptcIimBytes.length;
    final data = [
      // "Photoshop 3.0\0"
      0x50, 0x68, 0x6F, 0x74, 0x6F, 0x73, 0x68, 0x6F, 0x70,
      0x20, 0x33, 0x2E, 0x30, 0x00,
      // "8BIM"
      0x38, 0x42, 0x49, 0x4D,
      // Resource ID 0x0404 (IPTC-NAA)
      0x04, 0x04,
      // Pascal string name: length=0, padded to 2 bytes
      0x00, 0x00,
      // Resource data length (4 bytes big-endian)
      (resourceLen >> 24) & 0xFF,
      (resourceLen >> 16) & 0xFF,
      (resourceLen >> 8) & 0xFF,
      resourceLen & 0xFF,
      // IPTC IIM bytes
      ...iptcIimBytes,
    ];
    return _segment(0xED, data);
  }

  static List<int> _xmpApp1(String xmpXml) {
    // "http://ns.adobe.com/xap/1.0/\0" + XMP XML
    final prefix = utf8.encode('http://ns.adobe.com/xap/1.0/\x00');
    final data = [...prefix, ...utf8.encode(xmpXml)];
    return _segment(0xE1, data);
  }

  static List<int> _segment(int marker, List<int> data) {
    // Segment: 0xFF + marker + 2-byte big-endian length (includes length field)
    final length = data.length + 2;
    return [
      0xFF, marker,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...data,
    ];
  }

  static Uint8List _build(List<List<int>> segments) {
    final buf = BytesBuilder(copy: false);
    buf.add([0xFF, 0xD8]); // SOI
    for (final seg in segments) {
      buf.add(seg);
    }
    buf.add(_minimalImageBody);
    return buf.takeBytes();
  }
}
