import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:latlong2/latlong.dart';

/// Reads GPS coordinates, creation dates, and embedded thumbnails from raw
/// TIFF bytes (the bytes after the "Exif\0\0" prefix in an APP1 segment).
///
/// All methods accept the raw TIFF block rather than the full JPEG so that the
/// caller ([NativeMetadataService]) controls segment extraction.
class ExifReader {
  /// Reads GPS coordinates. Returns null when no GPS data is present.
  static Future<LatLng?> readGps(List<int> tiffBytes) async {
    final tags = await readExifFromBytes(tiffBytes);
    return _extractGps(tags);
  }

  /// Reads the image creation date, trying DateTimeOriginal first.
  static Future<DateTime?> readCreationDate(List<int> tiffBytes) async {
    final tags = await readExifFromBytes(tiffBytes);
    for (final key in [
      'EXIF DateTimeOriginal',
      'EXIF DateTimeDigitized',
      'Image DateTime',
    ]) {
      final tag = tags[key];
      if (tag != null) {
        final dt = _parseExifDate(tag.printable);
        if (dt != null) return dt;
      }
    }
    return null;
  }

  /// Reads the embedded JPEG thumbnail stored in IFD1.
  ///
  /// [tiffBytes] must be the raw TIFF block (starting with "II" or "MM").
  /// [package:exif] extracts the thumbnail automatically when IFD1 is present
  /// and stores the result under the 'JPEGThumbnail' key.
  static Future<Uint8List?> readThumbnail(List<int> tiffBytes) async {
    final tags = await readExifFromBytes(tiffBytes);
    final thumbTag = tags['JPEGThumbnail'];
    if (thumbTag == null) return null;
    final vals = thumbTag.values;
    if (vals is IfdBytes && vals.bytes.isNotEmpty) return vals.bytes;
    return null;
  }

  /// Returns the number of clockwise quarter-turns needed to display the image
  /// correctly, based on the EXIF Orientation tag. Returns 0 when absent.
  ///
  /// Mirror-flip orientations (2, 4, 5, 7) are treated as their nearest
  /// rotation equivalent since flip transforms are not supported here.
  static Future<int> readOrientationQuarterTurns(List<int> tiffBytes) async {
    final tags = await readExifFromBytes(tiffBytes);
    final tag = tags['Image Orientation'];
    if (tag == null) return 0;
    return switch (tag.printable.trim()) {
      'Rotate 90 CW'  => 1,
      'Rotate 180'    => 2,
      'Rotate 270 CW' => 3,
      _               => 0,
    };
  }

  // ─── private ────────────────────────────────────────────────────────────

  static LatLng? _extractGps(Map<String, IfdTag> tags) {
    final latTag = tags['GPS GPSLatitude'];
    final latRef = tags['GPS GPSLatitudeRef'];
    final lngTag = tags['GPS GPSLongitude'];
    final lngRef = tags['GPS GPSLongitudeRef'];
    if (latTag == null || lngTag == null) return null;
    final lat = _dmsToDecimal(latTag.values, latRef?.printable);
    final lng = _dmsToDecimal(lngTag.values, lngRef?.printable);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static double? _dmsToDecimal(IfdValues values, String? ref) {
    if (values is! IfdRatios) return null;
    final ratios = values.ratios;
    if (ratios.isEmpty) return null;
    double val = ratios[0].numerator / ratios[0].denominator.toDouble();
    if (ratios.length >= 2) {
      val += ratios[1].numerator / (ratios[1].denominator * 60.0);
    }
    if (ratios.length >= 3) {
      val += ratios[2].numerator / (ratios[2].denominator * 3600.0);
    }
    final r = ref?.trim();
    if (r == 'S' || r == 'W') val = -val;
    return val;
  }

  static DateTime? _parseExifDate(String s) {
    // EXIF date format: "2023:01:15 12:34:56"
    try {
      final parts = s.trim().split(' ');
      if (parts.length != 2) return null;
      final d = parts[0].split(':');
      final t = parts[1].split(':');
      if (d.length != 3 || t.length != 3) return null;
      return DateTime(
        int.parse(d[0]),
        int.parse(d[1]),
        int.parse(d[2]),
        int.parse(t[0]),
        int.parse(t[1]),
        int.parse(t[2]),
      );
    } catch (_) {
      return null;
    }
  }
}
