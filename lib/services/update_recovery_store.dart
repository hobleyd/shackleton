import 'dart:convert';
import 'dart:io';

import 'package:desktop_updater/updater_controller.dart';

/// Durable persistence for `desktop_updater`'s pending-install marker.
///
/// The package ships the abstract [UpdateRecoveryStore] interface and no
/// implementation, so every app has to provide one; this is the JSON-file
/// store from the package's own example. The marker is how a crash -- or a
/// native installer that never came back -- is noticed on the next launch:
/// [DesktopUpdaterController.recoverPendingInstall] reads it before the first
/// check, so a half-finished install is either completed or cleaned up rather
/// than left staged forever.
///
/// The write is a rename dance rather than a plain `writeAsString` for
/// exactly that reason: the file records that an install is in progress, so
/// it must be either wholly the old marker or wholly the new one.
final class ShackletonUpdateRecoveryStore implements UpdateRecoveryStore {
  ShackletonUpdateRecoveryStore(this.file);

  final File file;

  @override
  Future<void> clearPendingInstall({required String channel}) async {
    final marker = await readPendingInstall(channel: channel);
    if (marker != null && await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<UpdateInstallRecoveryMarker?> readPendingInstall({
    required String channel,
  }) async {
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Recovery marker must be a JSON object.');
    }
    final marker = _markerFromJson(decoded);
    return marker.channel == channel ? marker : null;
  }

  @override
  Future<void> writePendingInstall(UpdateInstallRecoveryMarker marker) async {
    await file.parent.create(recursive: true);
    final suffix = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    final pending = File('${file.path}.pending-$suffix');
    final backup = File('${file.path}.backup-$suffix');
    await pending.writeAsString(
      '${jsonEncode(_markerToJson(marker))}\n',
      flush: true,
    );

    var movedExisting = false;
    try {
      if (await file.exists()) {
        await file.rename(backup.path);
        movedExisting = true;
      }
      await pending.rename(file.path);
      if (movedExisting && await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (!await file.exists() && movedExisting && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    } finally {
      if (await pending.exists()) {
        await pending.delete();
      }
    }
  }
}

Map<String, Object?> _markerToJson(UpdateInstallRecoveryMarker marker) {
  return <String, Object?>{
    'createdAt': marker.createdAt.toUtc().toIso8601String(),
    'packageVersion': marker.packageVersion,
    'platform': marker.platform,
    'channel': marker.channel,
    'appVersion': marker.appVersion,
    'updateVersion': marker.updateVersion,
    'updateBuildNumber': marker.updateBuildNumber,
    'expectedPackageId': marker.expectedPackageId,
    'stagingPath': marker.stagingPath,
    'stageProvenanceSha256': marker.stageProvenanceSha256,
    'diagnosticsText': marker.diagnosticsText,
    'transactionId': marker.transactionId,
  };
}

UpdateInstallRecoveryMarker _markerFromJson(Map<String, dynamic> json) {
  return UpdateInstallRecoveryMarker(
    createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
    packageVersion: _requiredString(json, 'packageVersion'),
    platform: _requiredString(json, 'platform'),
    channel: _requiredString(json, 'channel'),
    appVersion: _optionalString(json, 'appVersion'),
    updateVersion: _optionalString(json, 'updateVersion'),
    updateBuildNumber: json['updateBuildNumber'] as int?,
    expectedPackageId: _optionalString(json, 'expectedPackageId'),
    stagingPath: _optionalString(json, 'stagingPath'),
    stageProvenanceSha256: _optionalString(json, 'stageProvenanceSha256'),
    diagnosticsText: _optionalString(json, 'diagnosticsText'),
    transactionId: _optionalString(json, 'transactionId'),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Recovery marker is missing $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('Recovery marker $key must be a string or null.');
  }
  return value as String?;
}
