import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/services/i_exif_tool_service.dart';
import '../providers/exif_tool_service_provider.dart';
import '../providers/notify.dart';

part 'exif.g.dart';

@riverpod
class Exif extends _$Exif {
  late final IExifToolService _exif;
  late final dynamic _notify;

  @override
  Map<String, ({ String orig, String reset })> build(String path) {
    ref.keepAlive();
    _exif = ref.read(exifToolServiceProvider);
    _notify = ref.read(notifyProvider.notifier);
    loadExifTags(path);
    return const {};
  }

  Future<bool> fixMetadata(String path) async {
    if (_exif.findExifTool() == null) {
      _notify.addNotification(message: 'exiftool not installed, please refer to https://github.com/hobleyd/shackleton for installation instructions.');
      return false;
    }

    final success = await _exif.fixMetadata(path);
    if (success) {
      loadExifTags(path);
    } else {
      _notify.addNotification(message: 'Resetting exif data failed for $path');
    }
    return success;
  }

  Future<void> loadExifTags(String path) async {
    if (_exif.findExifTool() == null) {
      _notify.addNotification(message: 'exiftool not installed.');
      return;
    }

    final data = await _exif.readAllExifData(path);
    if (ref.mounted) state = data;
  }

  /// Accepts the metadata fix: removes the exiftool backup and refreshes.
  Future<void> acceptFix(String path) async {
    await _exif.deleteBackup(path);
    await loadExifTags(path);
  }

  /// Reverts the metadata fix: restores the exiftool backup and refreshes.
  Future<void> rejectFix(String path) async {
    await _exif.restoreBackup(path);
    await loadExifTags(path);
  }
}
