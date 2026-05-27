import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../domain/services/i_exif_tool_service.dart';
import '../models/tag.dart';
import 'exif_tool_service.dart';
import 'native_metadata_service.dart';

/// Routes metadata operations to either the native Dart implementation
/// or ExifToolService, depending on what each operation requires.
///
/// Reads and tag writes use the native service (no process spawn).
/// [fixMetadata] and [readAllExifData] fall back to ExifToolService.
/// [findExifTool] delegates to ExifToolService so the hasExifTool guard
/// in metadata.dart continues to behave correctly.
class HybridMetadataService implements IExifToolService {
  final IExifToolService _native;
  final IExifToolService _exifTool;

  HybridMetadataService({IExifToolService? native, IExifToolService? exifTool})
      : _native = native ?? NativeMetadataService(),
        _exifTool = exifTool ?? ExifToolService();

  @override
  String? findExifTool() => _exifTool.findExifTool();

  @override
  Future<List<Tag>> readTags(String path) => _native.readTags(path);

  @override
  Future<LatLng?> readLocation(String path) => _native.readLocation(path);

  @override
  Future<({List<Tag> tags, LatLng? location})> readTagsAndLocation(
          String path) =>
      _native.readTagsAndLocation(path);

  @override
  Future<Uint8List?> readThumbnail(String path) => _native.readThumbnail(path);

  @override
  Future<DateTime?> readCreationDate(String path) =>
      _native.readCreationDate(path);

  @override
  Future<bool> writeTags(String path, List<Tag> tags, {LatLng? location}) =>
      _native.writeTags(path, tags, location: location);

  @override
  Future<int> readOrientationQuarterTurns(String path) =>
      _native.readOrientationQuarterTurns(path);

  @override
  Future<Map<String, ({String orig, String reset})>> readAllExifData(
          String path) =>
      _exifTool.readAllExifData(path);

  @override
  Future<bool> fixMetadata(String path) => _exifTool.fixMetadata(path);

  @override
  Future<void> deleteBackup(String path) => _native.deleteBackup(path);

  @override
  Future<void> restoreBackup(String path) => _native.restoreBackup(path);

  @override
  List<Tag> parseTagsFromString(String tags) =>
      _native.parseTagsFromString(tags);

  @override
  String formatTagsToString(List<Tag> tags) =>
      _native.formatTagsToString(tags);
}
