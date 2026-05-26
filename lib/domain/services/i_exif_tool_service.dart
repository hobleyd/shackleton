import 'package:latlong2/latlong.dart';

import '../../models/tag.dart';

abstract class IExifToolService {
  /// Returns the path to the exiftool binary, or null if not installed.
  String? findExifTool();

  /// Read IPTC subject tags from [path]. Returns [] if exiftool is not found
  /// or the file has no subject tags.
  Future<List<Tag>> readTags(String path);

  /// Read GPS coordinates from [path]. Returns null if not present.
  Future<LatLng?> readLocation(String path);

  /// Read all raw exif key/value pairs from [path] and its _original backup.
  Future<Map<String, ({String orig, String reset})>> readAllExifData(String path);

  /// Write [tags] (and optionally [location]) to [path] in-place.
  /// Returns true on success.
  Future<bool> writeTags(String path, List<Tag> tags, {LatLng? location});

  /// Reset corrupted metadata in [path] using -all= -tagsfromfile.
  /// Returns true on success.
  Future<bool> fixMetadata(String path);

  /// Deletes the exiftool backup file ([path]_original) created by [fixMetadata].
  Future<void> deleteBackup(String path);

  /// Restores the exiftool backup: deletes [path] and renames [path]_original
  /// to [path], reverting any metadata changes.
  Future<void> restoreBackup(String path);

  /// Read the original creation date from [path]. Returns null if unavailable.
  Future<DateTime?> readCreationDate(String path);

  /// Parse a comma-separated tag string into [Tag] objects.
  List<Tag> parseTagsFromString(String tags);

  /// Format [tags] to a comma-separated string for exiftool.
  String formatTagsToString(List<Tag> tags);
}
