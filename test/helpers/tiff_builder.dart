import 'dart:typed_data';

/// Builds minimal little-endian TIFF byte arrays for unit testing.
///
/// All offsets are computed from the desired data layout rather than stored as
/// class state, keeping the builder stateless and easy to reason about.
class TiffBuilder {
  // ─── GPS ──────────────────────────────────────────────────────────────────

  /// Builds a minimal TIFF containing a GPS IFD.
  ///
  /// Coordinates are split into integer DMS components for simplicity; the
  /// caller supplies degrees, minutes, and seconds as separate integers.
  ///
  /// Example: (latDeg:27, latMin:28, latSec:30, latRef:'N', ...) → 27.475° N
  static Uint8List withGps({
    required int latDeg,
    required int latMin,
    required int latSec,
    required String latRef,
    required int lngDeg,
    required int lngMin,
    required int lngSec,
    required String lngRef,
  }) {
    // Layout:
    //   [0-7]   TIFF header
    //   [8-25]  IFD0: 1 entry (GPSInfo pointer) + next-IFD ptr
    //   [26-79] GPS IFD: 4 entries + next-IFD ptr
    //   [80-127] GPS data: 3 rationals for lat, 3 for lng
    const gpsIfdOffset = 26;
    const latRationalsOffset = 80;
    const lngRationalsOffset = 104; // 80 + 3*8

    final buf = BytesBuilder(copy: false);

    // TIFF header
    buf.add([0x49, 0x49]); // "II" little-endian
    buf.add(_u16(42)); // magic
    buf.add(_u32(8)); // IFD0 at offset 8

    // IFD0: 1 entry
    buf.add(_u16(1));
    buf.add(_ifdEntry(tag: 0x8825, type: 4, count: 1, value: gpsIfdOffset));
    buf.add(_u32(0)); // no IFD1

    // GPS IFD: 4 entries
    buf.add(_u16(4));
    // GPSLatitudeRef: ASCII, 2 bytes, value "N\0" or "S\0" fits in 4-byte field
    buf.add(_ifdEntryBytes(
        tag: 0x0001, type: 2, count: 2, bytes: [latRef.codeUnitAt(0), 0, 0, 0]));
    // GPSLatitude: 3 RATIONAL values
    buf.add(_ifdEntry(
        tag: 0x0002, type: 5, count: 3, value: latRationalsOffset));
    // GPSLongitudeRef
    buf.add(_ifdEntryBytes(
        tag: 0x0003, type: 2, count: 2, bytes: [lngRef.codeUnitAt(0), 0, 0, 0]));
    // GPSLongitude: 3 RATIONAL values
    buf.add(_ifdEntry(
        tag: 0x0004, type: 5, count: 3, value: lngRationalsOffset));
    buf.add(_u32(0)); // no next GPS IFD

    // Rational data for latitude (deg, min, sec as x/1)
    buf.add(_rational(latDeg, 1));
    buf.add(_rational(latMin, 1));
    buf.add(_rational(latSec, 1));

    // Rational data for longitude
    buf.add(_rational(lngDeg, 1));
    buf.add(_rational(lngMin, 1));
    buf.add(_rational(lngSec, 1));

    return buf.takeBytes();
  }

  // ─── Date ─────────────────────────────────────────────────────────────────

  /// Builds a minimal TIFF containing DateTimeOriginal in an ExifIFD.
  ///
  /// [dateString] must be in EXIF format: "yyyy:MM:dd HH:mm:ss" (19 chars).
  static Uint8List withDate(String dateString) {
    // ASCII string including null terminator = 20 bytes
    final dateBytes = [...dateString.codeUnits, 0]; // 20 bytes
    assert(dateBytes.length == 20, 'EXIF date must be 19 chars + null = 20');

    // Layout:
    //   [0-7]   header
    //   [8-25]  IFD0: 1 entry (ExifIFD pointer) + next-IFD ptr
    //   [26-43] ExifIFD: 1 entry (DateTimeOriginal) + next-IFD ptr
    //   [44-63] date string (20 bytes)
    const exifIfdOffset = 26;
    const dateOffset = 44;

    final buf = BytesBuilder(copy: false);

    buf.add([0x49, 0x49]);
    buf.add(_u16(42));
    buf.add(_u32(8));

    // IFD0
    buf.add(_u16(1));
    buf.add(_ifdEntry(tag: 0x8769, type: 4, count: 1, value: exifIfdOffset));
    buf.add(_u32(0));

    // ExifIFD: DateTimeOriginal (tag 0x9003, ASCII, 20 bytes)
    buf.add(_u16(1));
    buf.add(_ifdEntry(tag: 0x9003, type: 2, count: 20, value: dateOffset));
    buf.add(_u32(0));

    // Date string
    buf.add(dateBytes);

    return buf.takeBytes();
  }

  // ─── Thumbnail ────────────────────────────────────────────────────────────

  /// Builds a minimal TIFF whose IFD1 points to [thumbnailBytes].
  static Uint8List withThumbnail(Uint8List thumbnailBytes) {
    // Layout:
    //   [0-7]   header
    //   [8-13]  IFD0: 0 entries + next-IFD pointer → IFD1
    //   [14-43] IFD1: 2 entries + next-IFD ptr
    //   [44...] thumbnail bytes
    const ifd1Offset = 14;
    const thumbnailOffset = 44;

    final buf = BytesBuilder(copy: false);

    buf.add([0x49, 0x49]);
    buf.add(_u16(42));
    buf.add(_u32(8));

    // IFD0: 0 entries, next IFD = IFD1
    buf.add(_u16(0));
    buf.add(_u32(ifd1Offset));

    // IFD1: JPEGInterchangeFormat + JPEGInterchangeFormatLength
    buf.add(_u16(2));
    buf.add(_ifdEntry(tag: 0x0201, type: 4, count: 1, value: thumbnailOffset));
    buf.add(_ifdEntry(
        tag: 0x0202, type: 4, count: 1, value: thumbnailBytes.length));
    buf.add(_u32(0));

    // Thumbnail bytes
    buf.add(thumbnailBytes);

    return buf.takeBytes();
  }

  // ─── byte helpers ─────────────────────────────────────────────────────────

  static List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  static List<int> _u32(int v) => [
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ];

  static List<int> _ifdEntry(
      {required int tag,
      required int type,
      required int count,
      required int value}) {
    return [..._u16(tag), ..._u16(type), ..._u32(count), ..._u32(value)];
  }

  static List<int> _ifdEntryBytes(
      {required int tag,
      required int type,
      required int count,
      required List<int> bytes}) {
    assert(bytes.length == 4);
    return [..._u16(tag), ..._u16(type), ..._u32(count), ...bytes];
  }

  static List<int> _rational(int num, int den) => [..._u32(num), ..._u32(den)];
}
