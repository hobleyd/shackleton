import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Parses the APP segment headers of a JPEG file without decoding image data.
///
/// Walks segment markers up to the Start-Of-Scan (0xDA) boundary; image-data
/// bytes are never read.
class JpegSegmentReader {
  static const int _ff = 0xFF;
  static const int _soiMarker = 0xD8;
  static const int _app1Marker = 0xE1;
  static const int _app13Marker = 0xED;
  static const int _sosMarker = 0xDA;
  static const int _eoiMarker = 0xD9;

  // "Exif\0\0"
  static const List<int> _exifPrefix = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];

  // "Photoshop 3.0\0"
  static const List<int> _photoshopPrefix = [
    0x50, 0x68, 0x6F, 0x74, 0x6F, 0x73, 0x68, 0x6F, 0x70,
    0x20, 0x33, 0x2E, 0x30, 0x00,
  ];

  final Uint8List _bytes;

  JpegSegmentReader(this._bytes);

  /// Reads only the metadata portion of a JPEG file (APP segments before
  /// SOS), without loading the full image data into memory.
  ///
  /// Stops reading at the first SOS (0xDA) or EOI (0xD9) marker, so a
  /// typical 5 MB photo contributes only its first ~50–200 KB of headers.
  ///
  /// Returns null if the file cannot be read or is not a valid JPEG.
  static Future<JpegSegmentReader?> fromFile(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final out = BytesBuilder();

      Future<Uint8List?> readExact(int count) async {
        final buf = Uint8List(count);
        int offset = 0;
        while (offset < count) {
          final chunk = await raf!.read(count - offset);
          if (chunk.isEmpty) return null;
          buf.setAll(offset, chunk);
          offset += chunk.length;
        }
        return buf;
      }

      // Validate SOI (0xFF 0xD8)
      final soi = await readExact(2);
      if (soi == null || soi[0] != _ff || soi[1] != _soiMarker) return null;
      out.add(soi);

      while (true) {
        final markerBytes = await readExact(2);
        if (markerBytes == null || markerBytes[0] != _ff) break;
        out.add(markerBytes);

        final m = markerBytes[1];
        if (m == _sosMarker || m == _eoiMarker) break;

        // Standalone markers (RST0–RST7 0xD0–0xD7, TEM 0x01) have no length.
        if (m == 0x01 || (m >= 0xD0 && m <= 0xD9)) continue;

        final lenBytes = await readExact(2);
        if (lenBytes == null) break;
        out.add(lenBytes);

        final segLen = (lenBytes[0] << 8) | lenBytes[1];
        if (segLen < 2) break;

        final dataLen = segLen - 2;
        if (dataLen > 0) {
          final data = await readExact(dataLen);
          if (data == null) break;
          out.add(data);
        }
      }

      return JpegSegmentReader(out.toBytes());
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  bool get isValidJpeg =>
      _bytes.length >= 2 && _bytes[0] == _ff && _bytes[1] == _soiMarker;

  /// Returns the raw TIFF block from the EXIF APP1 segment (after the 6-byte
  /// "Exif\0\0" prefix), or null if no EXIF segment is present.
  Uint8List? getExifBytes() {
    final seg = _findApp1WithPrefix(_exifPrefix);
    if (seg == null) return null;
    return seg.sublist(_exifPrefix.length);
  }

  /// Returns the raw XMP XML bytes from the XMP APP1 segment (after the
  /// null-terminated namespace URI), or null if no XMP segment is present.
  Uint8List? getXmpBytes() {
    final prefix = utf8.encode('http://ns.adobe.com/xap/1.0/\x00');
    final seg = _findApp1WithPrefix(prefix);
    if (seg == null) return null;
    return seg.sublist(prefix.length);
  }

  /// Returns the raw IPTC IIM bytes extracted from the Photoshop 8BIM
  /// resource block inside an APP13 segment, or null if not present.
  Uint8List? getIptcBytes() {
    final seg = _findSegment(_app13Marker);
    if (seg == null) return null;
    if (!_startsWith(seg, _photoshopPrefix)) return null;
    return _extractIptcResource(seg.sublist(_photoshopPrefix.length));
  }

  // ─── private helpers ────────────────────────────────────────────────────

  Uint8List? _findApp1WithPrefix(List<int> prefix) {
    return _walk((marker, data) {
      if (marker == _app1Marker && _startsWith(data, prefix)) return data;
      return null;
    });
  }

  Uint8List? _findSegment(int target) {
    return _walk((marker, data) => marker == target ? data : null);
  }

  Uint8List? _walk(Uint8List? Function(int marker, Uint8List data) test) {
    if (!isValidJpeg) return null;
    int pos = 2; // skip SOI
    while (pos + 3 < _bytes.length) {
      if (_bytes[pos] != _ff) break;
      final marker = _bytes[pos + 1];
      if (marker == _sosMarker || marker == _eoiMarker) break;
      pos += 2;
      if (pos + 2 > _bytes.length) break;
      final length = (_bytes[pos] << 8) | _bytes[pos + 1];
      if (length < 2) break;
      final end = pos + length;
      if (end > _bytes.length) break;
      final data = _bytes.sublist(pos + 2, end);
      final result = test(marker, data);
      if (result != null) return result;
      pos = end;
    }
    return null;
  }

  bool _startsWith(List<int> data, List<int> prefix) {
    if (data.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  /// Walks Photoshop 8BIM resources and returns the content of resource 0x0404
  /// (IPTC-NAA), or null if not found.
  Uint8List? _extractIptcResource(Uint8List data) {
    int pos = 0;
    while (pos + 8 <= data.length) {
      // "8BIM"
      if (data[pos] != 0x38 || data[pos + 1] != 0x42 ||
          data[pos + 2] != 0x49 || data[pos + 3] != 0x4D) {
        break;
      }
      final resourceId = (data[pos + 4] << 8) | data[pos + 5];
      pos += 6;
      if (pos >= data.length) break;
      // Pascal string: length byte + name bytes, padded to even total
      final nameLen = data[pos];
      int totalNameLen = nameLen + 1;
      if (totalNameLen % 2 != 0) totalNameLen++;
      pos += totalNameLen;
      if (pos + 4 > data.length) break;
      final resourceLen = (data[pos] << 24) | (data[pos + 1] << 16) |
          (data[pos + 2] << 8) | data[pos + 3];
      pos += 4;
      if (resourceLen < 0 || pos + resourceLen > data.length) break;
      if (resourceId == 0x0404) {
        return data.sublist(pos, pos + resourceLen);
      }
      pos += resourceLen;
      if (resourceLen % 2 != 0) pos++; // pad to even
    }
    return null;
  }
}
