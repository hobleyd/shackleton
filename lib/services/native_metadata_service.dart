import 'dart:io';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../domain/services/i_exif_tool_service.dart';
import '../models/tag.dart';
import 'native/exif_reader.dart';
import 'native/iptc_reader.dart';
import 'native/iptc_writer.dart';
import 'native/jpeg_segment_reader.dart';
import 'native/jpeg_segment_writer.dart';
import 'native/xmp_reader.dart';
import 'native/xmp_writer.dart';

/// Native Dart metadata service for JPEG files.
///
/// Reads IPTC keywords (primary), XMP subjects (fallback), EXIF GPS
/// coordinates, creation dates, and embedded JPEG thumbnails.
///
/// Writes IPTC keywords and XMP subjects; the EXIF GPS segment is preserved
/// verbatim when writing tags (GPS coordinate updates are not yet supported).
///
/// [readAllExifData] and [fixMetadata] require [ExifToolService] and throw
/// [UnsupportedError].
class NativeMetadataService implements IExifToolService {
  @override
  String? findExifTool() => null;

  @override
  Future<List<Tag>> readTags(String path) async =>
      (await readTagsAndLocation(path)).tags;

  @override
  Future<LatLng?> readLocation(String path) async =>
      (await readTagsAndLocation(path)).location;

  @override
  Future<({List<Tag> tags, LatLng? location})> readTagsAndLocation(
      String path) async {
    const empty = (tags: <Tag>[], location: null);
    try {
      final bytes = await File(path).readAsBytes();
      final reader = JpegSegmentReader(bytes);
      if (!reader.isValidJpeg) return empty;

      final tags = await _readTags(reader);
      final location = await _readLocation(reader);
      return (tags: tags, location: location);
    } catch (_) {
      return empty;
    }
  }

  @override
  Future<Uint8List?> readThumbnail(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final reader = JpegSegmentReader(bytes);
      if (!reader.isValidJpeg) return null;
      final exifBytes = reader.getExifBytes();
      if (exifBytes == null) return null;
      return ExifReader.readThumbnail(exifBytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DateTime?> readCreationDate(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final reader = JpegSegmentReader(bytes);
      if (!reader.isValidJpeg) return null;
      final exifBytes = reader.getExifBytes();
      if (exifBytes == null) return null;
      return ExifReader.readCreationDate(exifBytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, ({String orig, String reset})>> readAllExifData(
      String path) {
    throw UnsupportedError(
        'NativeMetadataService does not support readAllExifData');
  }

  /// Writes [tags] as IPTC keywords and XMP subjects.
  ///
  /// The EXIF segment (and any GPS coordinates already in the file) is
  /// preserved unchanged. If [location] is non-null it is accepted but not
  /// written — GPS writing is not yet implemented natively.
  @override
  Future<bool> writeTags(String path, List<Tag> tags,
      {LatLng? location}) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final reader = JpegSegmentReader(bytes);
      if (!reader.isValidJpeg) return false;

      final keywords = tags.map((t) => t.tag).where((s) => s.isNotEmpty).toList();
      final iptcBytes = IptcWriter.encodeKeywords(keywords);
      final xmpXml = XmpWriter.buildXmpWithSubjects(keywords);

      final updated = JpegSegmentWriter.writeMetadata(
        bytes,
        iptcIimBytes: iptcBytes,
        xmpXml: xmpXml,
      );

      await file.writeAsBytes(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> fixMetadata(String path) {
    throw UnsupportedError('NativeMetadataService does not support fixMetadata');
  }

  @override
  Future<void> deleteBackup(String path) async {
    final backup = File('${path}_original');
    if (backup.existsSync()) backup.deleteSync();
  }

  @override
  Future<void> restoreBackup(String path) async {
    final backup = File('${path}_original');
    if (!backup.existsSync()) return;
    File(path).deleteSync();
    backup.renameSync(path);
  }

  @override
  List<Tag> parseTagsFromString(String tags) =>
      tags.split(',').map((e) => Tag(tag: e.trim())).where((t) => t.tag.isNotEmpty).toList();

  @override
  String formatTagsToString(List<Tag> tags) =>
      tags.map((t) => t.tag).join(', ');

  // ─── private ──────────────────────────────────────────────────────────────

  Future<List<Tag>> _readTags(JpegSegmentReader reader) async {
    final iptcBytes = reader.getIptcBytes();
    if (iptcBytes != null) {
      final keywords = IptcReader.readKeywords(iptcBytes);
      if (keywords.isNotEmpty) return keywords.map((k) => Tag(tag: k)).toList();
    }
    final xmpBytes = reader.getXmpBytes();
    if (xmpBytes != null) {
      final subjects = XmpReader.readSubjects(xmpBytes);
      if (subjects.isNotEmpty) return subjects.map((s) => Tag(tag: s)).toList();
    }
    return const [];
  }

  Future<LatLng?> _readLocation(JpegSegmentReader reader) async {
    final exifBytes = reader.getExifBytes();
    if (exifBytes == null) return null;
    return ExifReader.readGps(exifBytes);
  }
}
