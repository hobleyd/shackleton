import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:process_run/process_run.dart';

import '../domain/services/i_exif_tool_service.dart';
import '../misc/utils.dart';
import '../models/tag.dart';
import 'exif_tool_daemon.dart';

/// Limits concurrent one-shot exiftool processes (writes, legacy reads).
/// Reads that go through the daemon are already serialised by the daemon.
final _oneShotSemaphore = _Semaphore(4);

class ExifToolService implements IExifToolService {
  ExifToolDaemon? _daemon;

  @override
  String? findExifTool() {
    String? exifPath = whichSync('exiftool');
    if (exifPath != null) return exifPath;

    // Fallback for macOS Homebrew installation not on PATH.
    exifPath = '/opt/homebrew/bin/exiftool';
    if (File(exifPath).existsSync()) return exifPath;

    return null;
  }

  ExifToolDaemon _getOrCreateDaemon(String exifToolPath) {
    _daemon ??= ExifToolDaemon(exifToolPath);
    return _daemon!;
  }

  @override
  Future<List<Tag>> readTags(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return [];

    return _oneShotSemaphore.run(() async {
      final output = await runExecutableArguments(exifTool, ['-s', '-s', '-s', '-subject', path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        return parseTagsFromString(output.stdout);
      }
      return [];
    });
  }

  @override
  Future<LatLng?> readLocation(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return null;

    return _oneShotSemaphore.run(() async {
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
    });
  }

  @override
  Future<({List<Tag> tags, LatLng? location})> readTagsAndLocation(String path) async {
    const empty = (tags: <Tag>[], location: null);
    final exifTool = findExifTool();
    if (exifTool == null) return empty;

    try {
      final raw = await _getOrCreateDaemon(exifTool)
          .execute(['-j', '-n', '-subject', '-gpslatitude', '-gpslongitude', path]);
      if (raw.isEmpty) return empty;

      final parsed = jsonDecode(raw) as List<dynamic>;
      if (parsed.isEmpty) return empty;
      final data = parsed.first as Map<String, dynamic>;

      // Subject appears as 'Subject' (XMP) or 'Keywords' (IPTC) depending on the file.
      final rawSubject = data['Subject'] ?? data['Keywords'];
      List<Tag> tags = [];
      if (rawSubject is List) {
        tags = rawSubject
            .map((s) => Tag(tag: s.toString().trim()))
            .where((t) => t.tag.isNotEmpty)
            .toList();
      } else if (rawSubject is String && rawSubject.isNotEmpty) {
        tags = parseTagsFromString(rawSubject);
      }

      LatLng? location;
      final lat = data['GPSLatitude'];
      final lng = data['GPSLongitude'];
      if (lat != null && lng != null) {
        try {
          location = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        } catch (_) {}
      }

      return (tags: tags, location: location);
    } catch (_) {
      // Daemon failure (crash, timeout) — reset so the next call restarts it.
      _daemon = null;
      return empty;
    }
  }

  @override
  Future<Uint8List?> readThumbnail(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return null;

    try {
      final bytes = await _getOrCreateDaemon(exifTool)
          .executeBytes(['-b', '-ThumbnailImage', path]);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      _daemon = null;
      return null;
    }
  }

  @override
  Future<Map<String, ({String orig, String reset})>> readAllExifData(String path) async {
    final exifTool = findExifTool();
    final Map<String, ({String orig, String reset})> exifTags = {};
    if (exifTool == null) return exifTags;

    await _oneShotSemaphore.run(() async {
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
    });

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

    return _oneShotSemaphore.run(() async {
      final output = await runExecutableArguments(exifTool, ['-overwrite_original', '-subject=$tagString', ...locationArgs, path]);
      return output.exitCode == 0 && output.outText.trim() == '1 image files updated';
    });
  }

  @override
  Future<bool> fixMetadata(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return false;

    return _oneShotSemaphore.run(() async {
      final output = await runExecutableArguments(exifTool, ['-all=', '-tagsfromfile', '@', '-all:all', '-unsafe', '-icc_profile', path]);
      return output.exitCode == 0 && output.outText.trim() == '1 image files updated';
    });
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

    try {
      final raw = await _getOrCreateDaemon(exifTool)
          .execute(['-s', '-s', '-s', '-CreateDate', path]);
      if (raw.isNotEmpty) {
        return DateFormat('yyyy:MM:dd HH:mm:ss').parse(raw.trim());
      }
    } on FormatException {
      // Not a parseable date — return null below.
    } catch (_) {
      _daemon = null;
    }
    return null;
  }

  @override
  Future<int> readOrientationQuarterTurns(String path) async {
    final exifTool = findExifTool();
    if (exifTool == null) return 0;
    try {
      final raw = await _getOrCreateDaemon(exifTool)
          .execute(['-s', '-s', '-s', '-Orientation', path]);
      return switch (raw.trim()) {
        'Rotate 90 CW'  => 1,
        'Rotate 180'    => 2,
        'Rotate 270 CW' => 3,
        _               => 0,
      };
    } catch (_) {
      _daemon = null;
      return 0;
    }
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

/// Caps concurrent one-shot exiftool processes to avoid spawning too many at once.
class _Semaphore {
  int _count;
  final Queue<Completer<void>> _queue = Queue();

  _Semaphore(int max) : _count = max;

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_count > 0) {
      _count--;
    } else {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    try {
      return await fn();
    } finally {
      if (_queue.isNotEmpty) {
        _queue.removeFirst().complete();
      } else {
        _count++;
      }
    }
  }
}
