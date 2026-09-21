import 'dart:convert';
import 'dart:io';

import 'package:desktop_updater/updater_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/services/update_recovery_store.dart';

void main() {
  late Directory tempDir;
  late File markerFile;
  late ShackletonUpdateRecoveryStore store;

  UpdateInstallRecoveryMarker marker({String channel = 'stable'}) {
    return UpdateInstallRecoveryMarker(
      createdAt: DateTime.utc(2026, 1, 1),
      packageVersion: '3.1.6',
      platform: 'macos',
      channel: channel,
      appVersion: '2.0.0',
      updateVersion: '2.1.0',
      updateBuildNumber: 3,
      expectedPackageId: 'au.com.sharpblue.shackleton',
      stagingPath: '/staging/path',
      stageProvenanceSha256: 'a' * 64,
      diagnosticsText: 'diagnostics',
      transactionId: 'txn-1',
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update_recovery_store_test_');
    markerFile = File('${tempDir.path}/recovery-marker.json');
    store = ShackletonUpdateRecoveryStore(markerFile);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('readPendingInstall', () {
    test('returns null when no marker file exists', () async {
      final result = await store.readPendingInstall(channel: 'stable');
      expect(result, isNull);
    });

    test('returns null when the stored marker is for a different channel', () async {
      await store.writePendingInstall(marker(channel: 'stable'));

      final result = await store.readPendingInstall(channel: 'beta');

      expect(result, isNull);
    });

    test('throws a FormatException when the file is not a JSON object', () async {
      await markerFile.writeAsString('[1, 2, 3]');

      expect(() => store.readPendingInstall(channel: 'stable'), throwsA(isA<FormatException>()));
    });

    test('throws a FormatException when a required field is missing', () async {
      await markerFile.writeAsString(jsonEncode({'createdAt': DateTime.now().toIso8601String()}));

      expect(() => store.readPendingInstall(channel: 'stable'), throwsA(isA<FormatException>()));
    });
  });

  group('writePendingInstall / readPendingInstall round-trip', () {
    test('reads back everything that was written', () async {
      final written = marker();

      await store.writePendingInstall(written);
      final read = await store.readPendingInstall(channel: 'stable');

      expect(read, isNotNull);
      expect(read!.createdAt, written.createdAt);
      expect(read.packageVersion, written.packageVersion);
      expect(read.platform, written.platform);
      expect(read.channel, written.channel);
      expect(read.appVersion, written.appVersion);
      expect(read.updateVersion, written.updateVersion);
      expect(read.updateBuildNumber, written.updateBuildNumber);
      expect(read.expectedPackageId, written.expectedPackageId);
      expect(read.stagingPath, written.stagingPath);
      expect(read.stageProvenanceSha256, written.stageProvenanceSha256);
      expect(read.diagnosticsText, written.diagnosticsText);
      expect(read.transactionId, written.transactionId);
    });

    test('creates the parent directory if it does not exist', () async {
      final nested = File('${tempDir.path}/nested/dir/marker.json');
      final nestedStore = ShackletonUpdateRecoveryStore(nested);

      await nestedStore.writePendingInstall(marker());

      expect(nested.existsSync(), isTrue);
    });

    test('a second write replaces the first, leaving only the new marker file', () async {
      await store.writePendingInstall(marker(channel: 'stable'));
      await store.writePendingInstall(marker(channel: 'beta'));

      final read = await store.readPendingInstall(channel: 'beta');
      expect(read, isNotNull);

      // Only the final marker file should remain -- no leftover .pending-/.backup- files.
      final leftovers = tempDir.listSync().map((e) => e.path.split(Platform.pathSeparator).last);
      expect(leftovers, [markerFile.path.split(Platform.pathSeparator).last]);
    });

    test('does not leave a .pending- file behind after a successful write', () async {
      await store.writePendingInstall(marker());

      final pendingFiles = tempDir.listSync().where((e) => e.path.contains('.pending-'));
      expect(pendingFiles, isEmpty);
    });
  });

  group('clearPendingInstall', () {
    test('deletes the marker file when one exists for the channel', () async {
      await store.writePendingInstall(marker(channel: 'stable'));

      await store.clearPendingInstall(channel: 'stable');

      expect(markerFile.existsSync(), isFalse);
    });

    test('does nothing when no marker file exists', () async {
      await expectLater(store.clearPendingInstall(channel: 'stable'), completes);
    });

    test('does not delete a marker file belonging to a different channel', () async {
      await store.writePendingInstall(marker(channel: 'stable'));

      await store.clearPendingInstall(channel: 'beta');

      expect(markerFile.existsSync(), isTrue);
    });
  });
}
