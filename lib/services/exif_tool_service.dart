import 'dart:io';

import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:process_run/process_run.dart';

import '../domain/services/i_exif_tool_service.dart';
import '../misc/utils.dart';
import '../models/tag.dart';

class ExifToolService implements IExifToolService {
  @override
  String? findExifTool() {
    String? exifPath = whichSync('exiftool');
    if (exifPath != null) return exifPath;

    // Fallback for macOS Homebrew installation not on PATH.
    exifPath = '/opt/homebrew/bin/exiftool';
    if (File(exifPath).existsSync()) return exifPath;

    return null;
  }

  @override
  Future<List<Tag>> readTags(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return [];

    final output = await runExecutableArguments(exifTool, ['-s', '-s', '-s', '-subject', path]);
    if (output.exitCode == 0 && output.stdout.isNotEmpty) {
      return parseTagsFromString(output.stdout);
    }
    return [];
  }

  @override
  Future<LatLng?> readLocation(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return null;

    final output = await runExecutableArguments(exifTool, ['-n', '-s', '-s', '-s', '-gpslatitude', '-gpslongitude', path]);
    if (output.exitCode == 0 && output.stdout.isNotEmpty) {
      final parts = output.stdout.split('\n');
      try {
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<Map<String, ({String orig, String reset})>> readAllExifData(String path) async {
    final exifTool = findExifTool();
    final Map<String, ({String orig, String reset})> exifTags = {};
    if (exifTool == null) return exifTags;

    var output = await runExecutableArguments(exifTool, ['-s', '-s', path]);
    if (output.exitCode == 0 && output.stdout.isNotEmpty) {
      for (var line in output.outLines) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          exifTags[parts[0].trim()] = (orig: parts[1].trim(), reset: '');
        }
      }
    }

    output = await runExecutableArguments(exifTool, ['-s', '-s', '${path}_original']);
    if (output.exitCode == 0 && output.stdout.isNotEmpty) {
      for (var line in output.outLines) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final previous = exifTags[parts[0].trim()];
          exifTags[parts[0].trim()] = (orig: previous?.orig ?? '', reset: parts[1].trim());
        }
      }
    }

    return exifTags;
  }

  @override
  Future<bool> writeTags(String path, List<Tag> tags, {LatLng? location}) async {
    final exifTool = findExifTool();
    if (exifTool == null) return false;

    final tagString = formatTagsToString(tags);

    final locationArgs = <String>[];
    if (location != null) {
      final latitude = convertLatLng(location.latitude, true).replaceAll("'", "\\'").replaceAll('"', '\\"');
      final longitude = convertLatLng(location.longitude, false).replaceAll("'", "\\'").replaceAll('"', '\\"');
      locationArgs.addAll(['-gpslatitude=$latitude', '-gpslongitude=$longitude']);
    }

    final output = await runExecutableArguments(exifTool, ['-overwrite_original', '-subject=$tagString', ...locationArgs, path]);
    return output.exitCode == 0 && output.outText.trim() == '1 image files updated';
  }

  @override
  Future<bool> fixMetadata(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return false;

    final output = await runExecutableArguments(exifTool, ['-all=', '-tagsfromfile', '@', '-all:all', '-unsafe', '-icc_profile', path]);
    return output.exitCode == 0 && output.outText.trim() == '1 image files updated';
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
  Future<DateTime?> readCreationDate(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return null;

    final output = await runExecutableArguments(exifTool, ['-s', '-s', '-s', '-CreateDate', path]);
    if (output.exitCode == 0 && output.stdout.isNotEmpty) {
      try {
        return DateFormat('yyyy:MM:dd HH:mm:ss').parse(output.stdout.trim());
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  List<Tag> parseTagsFromString(String tags) {
    return tags.split(',').map((e) => Tag(tag: e.trim())).where((t) => t.tag.isNotEmpty).toList();
  }

  @override
  String formatTagsToString(List<Tag> tags) {
    return tags.map((t) => t.tag).join(', ');
  }
}
